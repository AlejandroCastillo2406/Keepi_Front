import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../core/decorative_background.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../services/config_service.dart' as config_dto;
import '../../services/cloud_storage_service.dart';
import '../../services/document_upload_service.dart';
import '../../services/drive_structure_service.dart';
import '../../services/subscription_service.dart';
import 'folder_contents_screen.dart';
import 'settings_screen.dart';

/// Duración estándar para transiciones suaves estilo iOS.
const Duration _kIOSTransitionDuration = Duration(milliseconds: 380);

/// Formatea fecha ISO (ej. 2033-01-01T00:00:00Z) a "día mes año" en español. Ignora hora y zona.
String formatExpiryDateForDisplay(String? isoDate) {
  if (isoDate == null || isoDate.isEmpty) return '—';
  try {
    final datePart = isoDate.split('T').first;
    final parts = datePart.split('-');
    if (parts.length != 3) return isoDate;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null || month < 1 || month > 12) return isoDate;
    const months = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    return '$day ${months[month - 1]} $year';
  } catch (_) {
    return isoDate;
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  config_dto.UserConfigResponse? _config;
  bool _loading = true;
  String? _error;
  bool _storageModalShown = false;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri?>? _linkSubscription;

  List<DriveFolder>? _driveFolders;
  bool _loadingDrive = false;
  String? _driveError;
  int _totalKeepi = 0;
  int _expiringSoonCount = 0;
  List<ExpiringDocumentItem> _expiringSoon = const [];
  List<DriveFile> _rootFiles = const [];
  int? _analysisUsed;
  int? _analysisLimit;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _listenForGoogleDriveCallback();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _listenForGoogleDriveCallback() {
    _appLinks.getInitialLink().then((uri) {
      _onGoogleDriveCallback(uri);
    });
    _linkSubscription = _appLinks.uriLinkStream.listen(_onGoogleDriveCallback);
  }

  void _onGoogleDriveCallback(Uri? uri) {
    if (uri == null) return;
    final s = uri.toString();
    if (s.contains('oauth2redirect') && uri.queryParameters['success'] == '1' && mounted) {
      _loadSettings();
      return;
    }
    if (s.contains('stripe-success') && mounted) {
      _loadSettings();
    }
  }

  Future<void> _loadSettings() async {
    setState(() {
      _loading = true;
      _error = null;
      _driveError = null;
    });
    try {
      final api = context.read<ApiClient>();
      final configService = config_dto.ConfigService(api);
      final config = await configService.getUserConfig();
      if (!mounted) return;
      setState(() {
        _config = config;
        _loading = false;
      });
      _maybeShowStorageChoiceModal(config);
      if (config.isGoogleDrive || config.isKeepiCloud) {
        _loadDriveStructure(api);
      } else {
        setState(() {
          _driveFolders = null;
          _loadingDrive = false;
          _driveError = null;
          _totalKeepi = 0;
          _expiringSoonCount = 0;
          _expiringSoon = const [];
          _rootFiles = const [];
          _analysisUsed = null;
          _analysisLimit = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadDriveStructure(ApiClient api) async {
    setState(() {
      _loadingDrive = true;
      _driveError = null;
    });
    try {
      final driveService = DriveStructureService(api);
      final subscriptionService = SubscriptionService(api);
      final res = await driveService.getMobileDashboard();
      List<DriveFolder>? folders = res.folders;
      List<DriveFile> rootFiles = res.rootFiles;
      if (_config != null && _config!.isKeepiCloud) {
        try {
          final rootRes = await driveService.getKeepiCloudRoot();
          folders = rootRes.folders;
          rootFiles = rootRes.rootFiles;
        } catch (_) {
        }
      }
      UsageStatsResponse? usage;
      try {
        usage = await subscriptionService.getUsageStats();
      } catch (_) {
        usage = null;
      }
      if (mounted) {
        setState(() {
          _driveFolders = folders;
          _totalKeepi = res.totalKeepi;
          _expiringSoonCount = res.expiringSoonCount;
          _expiringSoon = res.expiringSoon;
          _rootFiles = rootFiles;
          _analysisUsed = usage?.analysisUsed;
          _analysisLimit = usage?.analysisLimit;
          _loadingDrive = false;
          _driveError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _driveFolders = null;
          _totalKeepi = 0;
          _expiringSoonCount = 0;
          _expiringSoon = const [];
          _rootFiles = const [];
          _analysisUsed = null;
          _analysisLimit = null;
          _loadingDrive = false;
          _driveError = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      floatingActionButton: _config != null && (_config!.isGoogleDrive || _config!.isKeepiCloud)
          ? _IOSFAB(
              onPressed: _onAddFileTap,
            )
          : null,
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/logo.png',
                height: 36,
                width: 36,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.folder_rounded,
                  size: 36,
                  color: KeepiColors.orange,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Keepi',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: KeepiColors.slate,
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            iconSize: 24,
            style: IconButton.styleFrom(
              foregroundColor: KeepiColors.slate,
              splashFactory: InkRipple.splashFactory,
            ),
            onPressed: () async {
              await Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (context) => const SettingsScreen(),
                ),
              );
              if (context.mounted) _loadSettings();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            iconSize: 24,
            style: IconButton.styleFrom(
              foregroundColor: KeepiColors.slate,
              splashFactory: InkRipple.splashFactory,
            ),
            onPressed: () async {
              await auth.logout();
              if (context.mounted) {}
            },
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: DecorativeBackground(
        blobOpacity: 0.2,
        child: SafeArea(
          child: RefreshIndicator(
          onRefresh: _loadSettings,
          color: KeepiColors.orange,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
            child: TweenAnimationBuilder<double>(
              key: ValueKey('content_$_loading'),
              tween: Tween<double>(begin: 0, end: 1),
              duration: _kIOSTransitionDuration,
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Opacity(opacity: value, child: child),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: KeepiColors.cardBorder.withOpacity(0.5),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: KeepiColors.slate.withOpacity(0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: KeepiColors.skyBlue.withOpacity(0.06),
                        blurRadius: 28,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: KeepiColors.orange.withOpacity(0.03),
                        blurRadius: 16,
                        offset: const Offset(-2, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              KeepiColors.orange,
                              KeepiColors.orangeLight,
                              KeepiColors.skyBlue,
                            ],
                            stops: [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hola, ${auth.name ?? auth.email ?? "Usuario"}',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                    color: KeepiColors.slate,
                                  ),
                            ),
                            if (auth.email != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                auth.email!,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: KeepiColors.slateLight,
                                      fontSize: 14,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: KeepiColors.orange,
                        ),
                      ),
                    ),
                  )
                else if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: KeepiColors.orange.withOpacity(0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: KeepiColors.slate.withOpacity(0.05),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: KeepiColors.orange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.error_outline_rounded, color: KeepiColors.orange, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Error al cargar',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      color: KeepiColors.slate,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _error!,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: KeepiColors.slateLight,
                                      height: 1.4,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_config != null && (_config!.isGoogleDrive || _config!.isKeepiCloud))
                  _DriveFoldersSection(
                    isKeepiCloud: _config!.isKeepiCloud,
                    keepiCloudUserId: _config!.isKeepiCloud ? auth.userId : null,
                    driveFolders: _driveFolders,
                    rootFiles: _rootFiles,
                    loadingDrive: _loadingDrive,
                    driveError: _driveError,
                    totalKeepi: _totalKeepi,
                    expiringSoonCount: _expiringSoonCount,
                    expiringSoon: _expiringSoon,
                    analysisUsed: _analysisUsed,
                    analysisLimit: _analysisLimit,
                    onFolderTap: (folder) {
                      Navigator.of(context).push(
                        CupertinoPageRoute<void>(
                          builder: (context) => FolderContentsScreen(
                            folderId: folder.id,
                            folderName: folder.name,
                          ),
                        ),
                      );
                    },
                  )
                else
                  _StorageSection(config: _config!),
              ],
            ),
          ),
        ),
      ),
    ),
    ),
    );
  }

  Future<void> _maybeShowStorageChoiceModal(
    config_dto.UserConfigResponse config,
  ) async {
    if (_storageModalShown || !mounted) return;
    if (!config.isNotConfigured) return;
    _storageModalShown = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: KeepiColors.slate.withOpacity(0.12),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: KeepiColors.skyBlueSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/logo.png',
                        height: 52,
                        width: 52,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.folder_rounded,
                          size: 52,
                          color: KeepiColors.orange,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '¿Dónde quieres guardar tus documentos?',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: KeepiColors.slate,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Elige tu proveedor de almacenamiento principal. '
                  'Podrás cambiarlo más adelante.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: KeepiColors.slateLight,
                      ),
                ),
                const SizedBox(height: 24),
                _StorageOptionButton(
                  icon: Icons.cloud_rounded,
                  title: 'Keepi Cloud',
                  subtitle: 'Almacenamiento seguro optimizado para Keepi.',
                  highlight: true,
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    _applyStorageChoice('keepi_cloud');
                  },
                ),
                const SizedBox(height: 12),
                _StorageOptionButton(
                  icon: Icons.folder_rounded,
                  title: 'Google Drive',
                  subtitle: 'Conecta tu Google Drive para usar tus carpetas.',
                  highlight: false,
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    _applyStorageChoice('google_drive');
                  },
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text(
                    'Ahora no',
                    style: TextStyle(color: KeepiColors.slateLight),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _applyStorageChoice(String storageType) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiClient>();

      if (storageType == 'google_drive') {
        final cloudService = CloudStorageService(api);
        final res = await cloudService.setupStorage('google_drive');
        if (!mounted) return;
        if (res.authorizationRequired && res.authorizationUrl != null && res.authorizationUrl!.isNotEmpty) {
          final uri = Uri.parse(res.authorizationUrl!);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Completa la autorización en el navegador y vuelve a la app.'),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 4),
              ),
            );
          }
          if (mounted) await _loadSettings();
        } else {
          await _loadSettings();
        }
        if (mounted) setState(() => _loading = false);
      } else {
        final cloudService = CloudStorageService(api);
        try {
          await cloudService.setupStorage(storageType);
          if (mounted) await _loadSettings();
        } on DioException catch (e) {
          if (e.response?.statusCode == 402) {
            final checkoutService = SubscriptionCheckoutService(api);
            try {
              final session = await checkoutService.createCheckoutSession();
              if (!mounted) return;
              final url = session.checkoutUrl;
              if (url.isNotEmpty) {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Completa el pago en el navegador. Al terminar vuelve a la app.'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 5),
                    ),
                  );
                }
              }
            } on DioException catch (e2) {
              if (mounted) {
                final detail = e2.response?.data is Map ? (e2.response?.data as Map)['detail'] : null;
                final msg = detail is String ? detail : 'Error al obtener la URL de pago.';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
                );
              }
            }
            if (mounted) await _loadSettings();
          } else {
            rethrow;
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onAddFileTap() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: false,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final platformFile = result.files.single;
    final path = platformFile.path;
    if (path == null || path.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo acceder al archivo seleccionado.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    final file = File(path);
    if (!await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El archivo ya no existe.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final api = context.read<ApiClient>();
    final uploadService = DocumentUploadService(api);
    final scaffold = ScaffoldMessenger.of(context);

    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: KeepiColors.orange),
                ),
                SizedBox(height: 16),
                Text('Analizando documento…'),
              ],
            ),
          ),
        ),
      ),
    );

    AnalyzeResult analyzeResult;
    try {
      analyzeResult = await uploadService.analyze(file);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      final err = e.toString();
      final isTimeout = err.toLowerCase().contains('timeout');
      final msg = isTimeout
          ? 'El análisis tardó demasiado. Revisa tu conexión o intenta con un archivo más pequeño.'
          : err.replaceFirst('DioException [bad response]: ', '').replaceFirst('DioException [connection timeout]: ', '').replaceFirst('DioException [send timeout]: ', '').replaceFirst('DioException [receive timeout]: ', '');
      scaffold.showSnackBar(
        SnackBar(
          content: Text(isTimeout ? msg : 'Error al analizar: $msg'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();

    if (analyzeResult.subscriptionRequired) {
      scaffold.showSnackBar(
        SnackBar(
          content: Text(analyzeResult.message ?? 'Se requiere una suscripción activa para analizar documentos.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    final saved = await _showAnalyzeResultModal(
      context: context,
      result: analyzeResult,
      originalFileName: platformFile.name,
    );
    if (saved == null) return;

    final category = saved.category;
    final fileName = saved.fileName;
    final expiryDate = saved.expiryDate;

    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: KeepiColors.orange),
                ),
                SizedBox(height: 16),
                Text('Guardando archivo …'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      await uploadService.saveAnalyzed(
        file: file,
        category: category,
        fileName: fileName,
        expiryDate: expiryDate,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      scaffold.showSnackBar(
        SnackBar(
          content: Text('Error al guardar: ${e.toString().replaceFirst('DioException [bad response]: ', '')}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();
    scaffold.showSnackBar(
      const SnackBar(
        content: Text('Documento guardado correctamente'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: KeepiColors.green,
      ),
    );
    final apiRef = context.read<ApiClient>();
    _loadDriveStructure(apiRef);
  }

  /// Muestra el modal de resumen del análisis. Retorna los datos a guardar o null si canceló.
  static Future<_SaveFormData?> _showAnalyzeResultModal({
    required BuildContext context,
    required AnalyzeResult result,
    required String originalFileName,
  }) async {
    return showDialog<_SaveFormData>(
      context: context,
      builder: (ctx) => _AnalyzeResultModal(
        result: result,
        originalFileName: originalFileName,
      ),
    );
  }
}

class _SaveFormData {
  _SaveFormData({
    required this.category,
    required this.fileName,
    this.expiryDate,
  });
  final String category;
  final String fileName;
  final String? expiryDate;
}

class _AnalyzeResultModal extends StatefulWidget {
  const _AnalyzeResultModal({
    required this.result,
    required this.originalFileName,
  });
  final AnalyzeResult result;
  final String originalFileName;

  @override
  State<_AnalyzeResultModal> createState() => _AnalyzeResultModalState();
}

class _AnalyzeResultModalState extends State<_AnalyzeResultModal> {
  late TextEditingController _categoryController;
  late TextEditingController _fileNameController;

  @override
  void initState() {
    super.initState();
    _categoryController = TextEditingController(
      text: widget.result.manualClassificationRequired
          ? 'Pendiente de clasificación'
          : widget.result.category,
    );
    _fileNameController = TextEditingController(
      text: widget.result.recommendedName.isNotEmpty
          ? widget.result.recommendedName
          : widget.originalFileName,
    );
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _fileNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = widget.result;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 520),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: KeepiColors.slate.withOpacity(0.12),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: KeepiColors.skyBlueSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.analytics_outlined, color: KeepiColors.orange, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Resumen del análisis',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: KeepiColors.slate,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ReadOnlyField(
                      label: 'Fecha de vencimiento',
                      value: formatExpiryDateForDisplay(result.expiryDate),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Categoría',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: KeepiColors.slateLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _categoryController,
                      decoration: InputDecoration(
                        hintText: 'Ej: Facturas, Identificación',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Nombre del archivo',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: KeepiColors.slateLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _fileNameController,
                      decoration: InputDecoration(
                        hintText: 'Nombre con el que se guardará',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    if (result.confidenceScore > 0) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Confianza del análisis: ${(result.confidenceScore * 100).toStringAsFixed(0)}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: KeepiColors.slateLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancelar', style: TextStyle(color: KeepiColors.slateLight)),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: () {
                    final category = _categoryController.text.trim();
                    final fileName = _fileNameController.text.trim();
                    if (category.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Escribe una categoría.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    if (fileName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Escribe el nombre del archivo.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    Navigator.of(context).pop(_SaveFormData(
                      category: category,
                      fileName: fileName,
                      expiryDate: result.expiryDate,
                    ));
                  },
                  style: FilledButton.styleFrom(backgroundColor: KeepiColors.orange),
                  child: const Text('Guardar en Drive'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: KeepiColors.slateLight,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: KeepiColors.slateSoft.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: KeepiColors.cardBorder),
          ),
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(color: KeepiColors.slate),
          ),
        ),
      ],
    );
  }
}

class _StorageSection extends StatelessWidget {
  const _StorageSection({required this.config});
  final config_dto.UserConfigResponse config;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Configuración de almacenamiento',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: KeepiColors.slate,
              ),
        ),
        const SizedBox(height: 12),
        _StorageStatusCard(config: config),
      ],
    );
  }
}

class _DriveFoldersSection extends StatelessWidget {
  const _DriveFoldersSection({
    this.isKeepiCloud = false,
    this.keepiCloudUserId,
    required this.driveFolders,
    this.rootFiles = const [],
    required this.loadingDrive,
    required this.driveError,
    required this.totalKeepi,
    required this.expiringSoonCount,
    required this.expiringSoon,
    this.analysisUsed,
    this.analysisLimit,
    required this.onFolderTap,
  });

  final bool isKeepiCloud;
  /// Para Keepi Cloud: no mostrar la carpeta raíz (users/uid); solo contenido.
  final String? keepiCloudUserId;
  final List<DriveFolder>? driveFolders;
  final List<DriveFile> rootFiles;
  final bool loadingDrive;
  final String? driveError;
  final int totalKeepi;
  final int expiringSoonCount;
  final List<ExpiringDocumentItem> expiringSoon;
  final int? analysisUsed;
  final int? analysisLimit;
  final void Function(DriveFolder folder) onFolderTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final List<DriveFolder>? displayedFolders = driveFolders == null
        ? null
        : (isKeepiCloud && keepiCloudUserId != null)
            ? driveFolders!
                .where((f) =>
                    f.id != 'users/$keepiCloudUserId' &&
                    f.id != 'users/$keepiCloudUserId/')
                .toList()
            : driveFolders!;
    final List<DriveFolder> foldersToShow = displayedFolders ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!loadingDrive && driveError == null) ...[
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  label: 'Con Keepi',
                  value: totalKeepi.toString(),
                  icon: Icons.verified_rounded,
                  color: KeepiColors.orange,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _KpiCard(
                  label: 'Próximos a vencer',
                  value: expiringSoonCount.toString(),
                  icon: Icons.schedule_rounded,
                  color: KeepiColors.skyBlue,
                ),
              ),
            ],
          ),
          if (analysisUsed != null && analysisLimit != null) ...[
            const SizedBox(height: 18),
            _AnalysisUsageBar(used: analysisUsed!, limit: analysisLimit!),
          ],
          const SizedBox(height: 28),
        ],
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isKeepiCloud ? KeepiColors.skyBlue : KeepiColors.orange).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isKeepiCloud ? Icons.cloud_rounded : Icons.folder_rounded,
                size: 22,
                color: isKeepiCloud ? KeepiColors.skyBlue : KeepiColors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              isKeepiCloud ? 'Keepi Cloud' : 'Google Drive',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: KeepiColors.slate,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (loadingDrive)
          _IOSStyleCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: KeepiColors.orange,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Cargando carpetas…',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (driveError != null)
          _IOSStyleCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: colorScheme.error, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      driveError!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onError,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (foldersToShow.isEmpty && (!isKeepiCloud || rootFiles.isEmpty))
          _IOSStyleCard(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isKeepiCloud ? Icons.cloud_rounded : Icons.folder_open_rounded,
                      size: 64,
                      color: KeepiColors.slateLight.withOpacity(0.45),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isKeepiCloud ? 'Sin contenido en Keepi Cloud' : 'No hay carpetas en la raíz',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: KeepiColors.slateLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isKeepiCloud
                          ? 'Añade documentos con el botón +'
                          : 'Crea carpetas en Google Drive para verlas aquí',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: KeepiColors.slateLight.withOpacity(0.9),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          _IOSStyleCard(
            child: Column(
              children: [
                for (int i = 0; i < foldersToShow.length; i++) ...[
                  _DriveFolderTile(
                    folder: foldersToShow[i],
                    isLast: !isKeepiCloud || rootFiles.isEmpty
                        ? (i == foldersToShow.length - 1)
                        : false,
                    onTap: () => onFolderTap(foldersToShow[i]),
                  ),
                  if (i < foldersToShow.length - 1 ||
                      (isKeepiCloud && rootFiles.isNotEmpty))
                    Divider(
                      height: 1,
                      indent: 56,
                      color: KeepiColors.cardBorder.withOpacity(0.8),
                    ),
                ],
                if (isKeepiCloud && rootFiles.isNotEmpty)
                  for (int i = 0; i < rootFiles.length; i++) ...[
                    _RootFileTile(file: rootFiles[i]),
                    if (i < rootFiles.length - 1)
                      Divider(
                        height: 1,
                        indent: 56,
                        color: KeepiColors.cardBorder.withOpacity(0.8),
                      ),
                  ],
                if (foldersToShow.isEmpty && rootFiles.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Sin contenido aún',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: KeepiColors.slateLight,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (expiringSoon.isNotEmpty) ...[
          const SizedBox(height: 28),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: KeepiColors.skyBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.schedule_rounded, size: 22, color: KeepiColors.skyBlue),
              ),
              const SizedBox(width: 12),
              Text(
                'Próximos a vencer',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: KeepiColors.slate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _IOSStyleCard(
            child: Column(
              children: [
                for (int i = 0; i < expiringSoon.length; i++) ...[
                  _ExpiringDocTile(item: expiringSoon[i]),
                  if (i < expiringSoon.length - 1)
                    Divider(
                      height: 1,
                      indent: 56,
                      color: KeepiColors.cardBorder.withOpacity(0.8),
                    ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _AnalysisUsageBar extends StatelessWidget {
  const _AnalysisUsageBar({required this.used, required this.limit});
  final int used;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnlimited = limit < 0;
    final progress = isUnlimited
        ? 1.0
        : (limit == 0 ? 0.0 : (used / limit).clamp(0.0, 1.0));
    final label = isUnlimited
        ? '$used análisis · Ilimitados'
        : '$used / $limit análisis';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: KeepiColors.cardBorder.withOpacity(0.6), width: 1),
        boxShadow: [
          BoxShadow(
            color: KeepiColors.slate.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    size: 18,
                    color: isUnlimited
                        ? KeepiColors.skyBlue
                        : KeepiColors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: KeepiColors.slate,
                    ),
                  ),
                ],
              ),
              if (!isUnlimited)
                Text(
                  'Plan actual',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: KeepiColors.slateLight,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: KeepiColors.slateLight.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                isUnlimited
                    ? KeepiColors.skyBlue
                    : KeepiColors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: KeepiColors.cardBorder.withOpacity(0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: KeepiColors.slate.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: color),
              ),
              const SizedBox(width: 12),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: KeepiColors.slate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: KeepiColors.slateLight,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpiringDocTile extends StatelessWidget {
  const _ExpiringDocTile({required this.item});
  final ExpiringDocumentItem item;

  @override
  Widget build(BuildContext context) {
    final displayName = (item.fileName != null && item.fileName!.isNotEmpty)
        ? item.fileName!
        : item.name;
    final dateStr = formatExpiryDateForDisplay(item.expiryDate);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Row(
        children: [
          const Icon(
            Icons.description_outlined,
            size: 24,
            color: KeepiColors.skyBlue,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: KeepiColors.slate,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Vence: $dateStr',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: KeepiColors.slateLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IOSStyleCard extends StatelessWidget {
  const _IOSStyleCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KeepiColors.cardBorder.withOpacity(0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: KeepiColors.slate.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: KeepiColors.skyBlue.withOpacity(0.04),
            blurRadius: 28,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: KeepiColors.orange.withOpacity(0.02),
            blurRadius: 16,
            offset: const Offset(-1, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _DriveFolderTile extends StatelessWidget {
  const _DriveFolderTile({
    required this.folder,
    required this.isLast,
    required this.onTap,
  });
  final DriveFolder folder;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fileLabel = folder.filesCount == 1
        ? '1 archivo'
        : '${folder.filesCount} archivos';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: KeepiColors.orange.withOpacity(0.12),
        highlightColor: KeepiColors.skyBlueSoft.withOpacity(0.5),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: KeepiColors.orangeSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.folder_rounded,
                  color: KeepiColors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      folder.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.2,
                        color: KeepiColors.slate,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fileLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: KeepiColors.slateLight,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: KeepiColors.slateLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RootFileTile extends StatelessWidget {
  const _RootFileTile({required this.file});
  final DriveFile file;

  static String _formatSize(String? size) {
    if (size == null || size.isEmpty) return '';
    final bytes = int.tryParse(size);
    if (bytes == null) return size;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sizeStr = _formatSize(file.size);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(
            Icons.description_outlined,
            size: 24,
            color: KeepiColors.skyBlue,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  file.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: KeepiColors.slate,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (sizeStr.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        sizeStr,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: KeepiColors.slateLight,
                        ),
                      ),
                      if (file.keepiVerified) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.verified_rounded,
                          size: 16,
                          color: KeepiColors.green,
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StorageStatusCard extends StatelessWidget {
  const _StorageStatusCard({required this.config});

  final config_dto.UserConfigResponse config;

  @override
  Widget build(BuildContext context) {
    final isKeepi = config.isKeepiCloud;
    final isDrive = config.isGoogleDrive;
    final label = isKeepi
        ? 'Keepi Cloud'
        : isDrive
            ? 'Google Drive'
            : 'Sin configurar';
    final subtitle = isKeepi
        ? 'Tu almacenamiento está en Keepi Cloud.'
        : isDrive
            ? 'Tu almacenamiento está en Google Drive.'
            : 'Es tu primera vez. Configura tu almacenamiento en Ajustes.';
    final icon = isKeepi
        ? Icons.cloud_rounded
        : isDrive
            ? Icons.folder_rounded
            : Icons.cloud_off_rounded;
    final accentColor = isKeepi ? KeepiColors.skyBlue : (isDrive ? KeepiColors.orange : KeepiColors.slateLight);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KeepiColors.cardBorder.withOpacity(0.7)),
        boxShadow: [
          BoxShadow(
            color: KeepiColors.slate.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 26, color: accentColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: KeepiColors.slate,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: KeepiColors.slateLight,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón flotante estilo iOS con gradiente del logo y sombra suave.
class _IOSFAB extends StatefulWidget {
  const _IOSFAB({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_IOSFAB> createState() => _IOSFABState();
}

class _IOSFABState extends State<_IOSFAB> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1, end: 0.94).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onPressed,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: KeepiColors.orange.withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: KeepiColors.slate.withOpacity(0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [KeepiColors.orange, KeepiColors.orangeLight],
              stops: [0.0, 1.0],
            ),
          ),
          child: const SizedBox(
            width: 56,
            height: 56,
            child: Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}

class _StorageOptionButton extends StatelessWidget {
  const _StorageOptionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.highlight,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool highlight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bgColor = highlight ? KeepiColors.orangeSoft : KeepiColors.slateSoft;
    final fgColor = highlight ? KeepiColors.orange : KeepiColors.slate;
    final iconBg = highlight
        ? KeepiColors.orange.withOpacity(0.2)
        : KeepiColors.slate.withOpacity(0.08);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: highlight
                  ? KeepiColors.orange.withOpacity(0.35)
                  : KeepiColors.cardBorder.withOpacity(0.6),
            ),
          ),
          child: Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: fgColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: fgColor,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: KeepiColors.slateLight,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: fgColor.withOpacity(0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

