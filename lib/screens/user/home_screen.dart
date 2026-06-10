import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_endpoints.dart';
import '../../core/app_theme.dart';
import '../../core/web_layout.dart';
import '../../widgets/web_app_shell.dart';
import '../../core/decorative_background.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../services/config_service.dart' as config_dto;
import '../../services/document_file_opener.dart';
import '../../services/drive_structure_service.dart';
import '../../widgets/document_analyze_flow.dart';
import '../../widgets/ios_fab.dart';
import '../../services/subscription_service.dart';
import '../../widgets/document_alert_tile.dart';
import '../../widgets/document_replacement_banner.dart';
import '../../widgets/home_added_search_section.dart';
import '../common/storage_choice_flow.dart';
import 'folder_contents_screen.dart';
import 'settings_screen.dart';

/// Duración estándar para transiciones suaves estilo iOS.
const Duration _kIOSTransitionDuration = Duration(milliseconds: 380);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  config_dto.UserConfigResponse? _config;
  bool _loading = true;
  String? _error;
  final FirstRunStorageGate _storageGate = FirstRunStorageGate();
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri?>? _linkSubscription;

  List<DriveFolder>? _driveFolders;
  bool _loadingDrive = false;
  String? _driveError;
  int _totalKeepi = 0;
  int _alertsCount = 0;
  List<DocumentAlertItem> _alerts = const [];
  List<DriveFile> _rootFiles = const [];
  int? _analysisUsed;
  int? _analysisLimit;
  DateTime? _lastDriveReconnectPromptAt;

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
    if (s.contains('oauth2redirect') &&
        uri.queryParameters['success'] == '1' &&
        mounted) {
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
      await ensureDefaultKeepiCloudStorage(
        context,
        config: config,
        gate: _storageGate,
        onReloadAfterChoice: _loadSettings,
        setLoading: (v) {
          if (mounted) setState(() => _loading = v);
        },
        onApplyError: (e) {
          if (mounted) setState(() => _error = e.toString());
        },
      );
      if (config.isGoogleDrive || config.isKeepiCloud) {
        _loadDriveStructure(api);
      } else {
        setState(() {
          _driveFolders = null;
          _loadingDrive = false;
          _driveError = null;
          _totalKeepi = 0;
          _alertsCount = 0;
          _alerts = const [];
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
      if (res.requiresDriveAuth) {
        await _maybePromptDriveReconnect(
          api: api,
          authorizationUrl: res.authorizationUrl,
        );
      }
      List<DriveFolder>? folders = res.folders;
      List<DriveFile> rootFiles = res.rootFiles;
      if (_config != null && _config!.isKeepiCloud) {
        try {
          final rootRes = await driveService.getKeepiCloudRoot();
          folders = rootRes.folders;
          rootFiles = rootRes.rootFiles;
        } catch (_) {}
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
          _alertsCount = res.alertsCount;
          _alerts = res.alerts;
          _rootFiles = rootFiles;
          _analysisUsed = usage?.analysisUsed;
          _analysisLimit = usage?.analysisLimit;
          _loadingDrive = false;
          _driveError = null;
        });
      }
    } catch (e) {
      final driveAuthDetail = _extractDriveAuthDetail(e);
      if (driveAuthDetail != null) {
        await _maybePromptDriveReconnect(
          api: api,
          authorizationUrl: driveAuthDetail['authorization_url'] as String?,
        );
      }
      if (mounted) {
        setState(() {
          _driveFolders = null;
          _totalKeepi = 0;
          _alertsCount = 0;
          _alerts = const [];
          _rootFiles = const [];
          _analysisUsed = null;
          _analysisLimit = null;
          _loadingDrive = false;
          _driveError = e.toString();
        });
      }
    }
  }

  Map<String, dynamic>? _extractDriveAuthDetail(Object error) {
    if (error is! DioException) return null;
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final requiresDriveAuth = data['requires_drive_auth'] == true;
      if (requiresDriveAuth) return data;
      final detail = data['detail'];
      if (detail is Map<String, dynamic> &&
          detail['requires_drive_auth'] == true) {
        return detail;
      }
    }
    return null;
  }

  Future<void> _maybePromptDriveReconnect({
    required ApiClient api,
    String? authorizationUrl,
  }) async {
    if (!mounted) return;
    final now = DateTime.now();
    if (_lastDriveReconnectPromptAt != null &&
        now.difference(_lastDriveReconnectPromptAt!).inMinutes < 10) {
      return;
    }
    _lastDriveReconnectPromptAt = now;

    String? authUrl = authorizationUrl;
    if (authUrl == null || authUrl.isEmpty) {
      try {
        final res = await api.dio.get<Map<String, dynamic>>(
          ApiEndpoints.authGoogleMobileAuthorize,
        );
        authUrl = res.data?['authorization_url'] as String?;
      } catch (_) {}
    }
    if (!mounted) return;

    final shouldReconnect = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Reconectar Google Drive'),
            content: const Text(
              'Tu sesion de Google Drive caduco o fue revocada. '
              'Necesitas reconectar para ver y guardar documentos.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Ahora no'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Reconectar'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldReconnect || !mounted || authUrl == null || authUrl.isEmpty) {
      return;
    }

    final uri = Uri.tryParse(authUrl);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir la autorizacion de Google Drive.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir el navegador para reconectar Drive.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final showUploadFab =
        _config != null && (_config!.isGoogleDrive || _config!.isKeepiCloud);

    final scaffold = Scaffold(
      floatingActionButton:
          _config != null && (_config!.isGoogleDrive || _config!.isKeepiCloud)
              ? IosFab(
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
                builder: (context, value, child) =>
                    Opacity(opacity: value, child: child),
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
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.3,
                                        color: KeepiColors.slate,
                                      ),
                                ),
                                if (auth.email != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    auth.email!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
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
                    const HomeAddedSearchSection(),
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
                          border: Border.all(
                              color: KeepiColors.orange.withOpacity(0.3)),
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
                              child: const Icon(Icons.error_outline_rounded,
                                  color: KeepiColors.orange, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Error al cargar',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: KeepiColors.slate,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _error!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
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
                    else if (_config != null &&
                        (_config!.isGoogleDrive || _config!.isKeepiCloud))
                      _DriveFoldersSection(
                        isKeepiCloud: _config!.isKeepiCloud,
                        keepiCloudUserId:
                            _config!.isKeepiCloud ? auth.userId : null,
                        driveFolders: _driveFolders,
                        rootFiles: _rootFiles,
                        loadingDrive: _loadingDrive,
                        driveError: _driveError,
                        totalKeepi: _totalKeepi,
                        alertsCount: _alertsCount,
                        alerts: _alerts,
                        analysisUsed: _analysisUsed,
                        analysisLimit: _analysisLimit,
                        onReplaceAlert: _replaceAlertDocument,
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

    if (isWebWide(context)) {
      return WebUserShell(
        userName: auth.name ?? 'Usuario',
        onNotifications: () {},
        onSettings: () async {
          await Navigator.of(context).push(
            CupertinoPageRoute<void>(
              builder: (context) => const SettingsScreen(),
            ),
          );
          if (context.mounted) _loadSettings();
        },
        onLogout: auth.logout,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showUploadFab)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _onAddFileTap,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Subir archivo'),
                    style: FilledButton.styleFrom(
                      backgroundColor: KeepiColors.orange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Scaffold(
                backgroundColor: KeepiColors.surfaceBg,
                body: scaffold.body,
              ),
            ),
          ],
        ),
      );
    }
    return scaffold;
  }

  Future<void> _onAddFileTap() async {
    final cfg = _config;
    await runDocumentAnalyzeFlow(
      context,
      onSaved: () => _loadDriveStructure(context.read<ApiClient>()),
      saveButtonLabel: cfg != null && cfg.isKeepiCloud
          ? 'Guardar en Keepi Cloud'
          : 'Guardar en Drive',
    );
  }

  Future<void> _replaceAlertDocument(DocumentAlertItem item) async {
    final docId = item.keepiDocumentId;
    if (docId == null || docId.isEmpty || !item.canReplace) return;
    final cfg = _config;
    await runDocumentReplaceFlow(
      context,
      replacesDocumentId: docId,
      onSaved: () => _loadDriveStructure(context.read<ApiClient>()),
      saveButtonLabel: cfg != null && cfg.isKeepiCloud
          ? 'Guardar en Keepi Cloud'
          : 'Guardar en Drive',
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
    required this.alertsCount,
    required this.alerts,
    this.analysisUsed,
    this.analysisLimit,
    this.onReplaceAlert,
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
  final int alertsCount;
  final List<DocumentAlertItem> alerts;
  final int? analysisUsed;
  final int? analysisLimit;
  final void Function(DocumentAlertItem item)? onReplaceAlert;
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
                  label: 'Alertas',
                  value: alertsCount.toString(),
                  icon: Icons.notifications_active_outlined,
                  color: alertsCount > 0 ? KeepiColors.orange : KeepiColors.skyBlue,
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
                color: (isKeepiCloud ? KeepiColors.skyBlue : KeepiColors.orange)
                    .withOpacity(0.12),
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
                  Icon(Icons.error_outline_rounded,
                      color: colorScheme.error, size: 24),
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
                      isKeepiCloud
                          ? Icons.cloud_rounded
                          : Icons.folder_open_rounded,
                      size: 64,
                      color: KeepiColors.slateLight.withOpacity(0.45),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isKeepiCloud
                          ? 'Sin contenido en Keepi Cloud'
                          : 'No hay carpetas en la raíz',
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
                    _RootFileTile(
                      file: rootFiles[i],
                      onTap: () => DocumentFileOpener.open(
                        context,
                        file: rootFiles[i],
                      ),
                    ),
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
        if (alerts.isNotEmpty) ...[
          const SizedBox(height: 28),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: KeepiColors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.notifications_active_outlined,
                    size: 22, color: KeepiColors.orange),
              ),
              const SizedBox(width: 12),
              Text(
                'Alertas',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: KeepiColors.slate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Solo de tu almacenamiento activo · vencidos y por vencer (30 días)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: KeepiColors.slateLight,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          _IOSStyleCard(
            child: Column(
              children: [
                for (int i = 0; i < alerts.length; i++) ...[
                  DocumentAlertTile(
                    item: alerts[i],
                    onReplace: onReplaceAlert != null
                        ? () => onReplaceAlert!(alerts[i])
                        : null,
                  ),
                  if (i < alerts.length - 1)
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
    final progress =
        isUnlimited ? 1.0 : (limit == 0 ? 0.0 : (used / limit).clamp(0.0, 1.0));
    final label =
        isUnlimited ? '$used análisis · Ilimitados' : '$used / $limit análisis';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: KeepiColors.cardBorder.withOpacity(0.6), width: 1),
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
                    color:
                        isUnlimited ? KeepiColors.skyBlue : KeepiColors.orange,
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
                isUnlimited ? KeepiColors.skyBlue : KeepiColors.orange,
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
        border: Border.all(
            color: KeepiColors.cardBorder.withOpacity(0.5), width: 1),
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

class _IOSStyleCard extends StatelessWidget {
  const _IOSStyleCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: KeepiColors.cardBorder.withOpacity(0.5), width: 1),
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
    final fileLabel =
        folder.filesCount == 1 ? '1 archivo' : '${folder.filesCount} archivos';

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
  const _RootFileTile({required this.file, this.onTap});
  final DriveFile file;
  final VoidCallback? onTap;

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
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
                    DocumentReplacementInfoIcon(file: file),
                  ],
                ),
              ] else
                DocumentReplacementInfoIcon(file: file),
            ],
          ),
        ),
        if (onTap != null)
          const Icon(
            Icons.chevron_right_rounded,
            size: 22,
            color: KeepiColors.slateLight,
          ),
      ],
    );

    if (onTap == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: row,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: row,
        ),
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
    final accentColor = isKeepi
        ? KeepiColors.skyBlue
        : (isDrive ? KeepiColors.orange : KeepiColors.slateLight);

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
