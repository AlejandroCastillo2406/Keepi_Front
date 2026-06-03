import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../core/decorative_background.dart';
import '../../core/file_type_style.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../services/config_service.dart' as config_dto;
import '../../services/document_file_opener.dart';
import '../../services/drive_structure_service.dart';
import '../../widgets/document_alert_tile.dart';
import '../../widgets/document_analyze_flow.dart';
import '../../widgets/document_metadata_edit_sheet.dart';
import '../../widgets/document_replacement_banner.dart';
import '../../widgets/ios_export_fab.dart';
import '../../widgets/ios_fab.dart';
import '../../widgets/patient_folders_export_sheet.dart';
import '../common/storage_choice_flow.dart';
import '../user/folder_contents_screen.dart';

class DocumentosScreen extends StatefulWidget {
  const DocumentosScreen({super.key});

  @override
  State<DocumentosScreen> createState() => _DocumentosScreenState();
}

class _DocumentosScreenState extends State<DocumentosScreen> {
  final FirstRunStorageGate _storageGate = FirstRunStorageGate();

  config_dto.UserConfigResponse? _config;
  List<DriveFolder> _folders = [];
  List<DriveFile> _rootFiles = [];
  List<DocumentAlertItem> _alerts = [];
  int _totalKeepi = 0;
  int _alertsCount = 0;
  int _alertsExpiredCount = 0;
  bool _loading = true;
  String? _error;
  bool _requiresDriveAuth = false;
  String? _authorizationUrl;
  bool get _showExportFab {
    if (_loading || _error != null) return false;
    if (_config?.isNotConfigured ?? true) return false;
    return _config?.isKeepiCloud ?? false;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _requiresDriveAuth = false;
    });

    try {
      final api = context.read<ApiClient>();
      final configSvc = config_dto.ConfigService(api);
      final config = await configSvc.getUserConfig();

      if (!mounted) return;
      await maybeShowFirstRunStorageDialog(
        context,
        config: config,
        gate: _storageGate,
        onReloadAfterChoice: _load,
      );
      if (!mounted) return;

      if (config.isNotConfigured) {
        setState(() {
          _config = config;
          _folders = [];
          _rootFiles = [];
          _alerts = [];
          _totalKeepi = 0;
          _alertsCount = 0;
          _alertsExpiredCount = 0;
          _loading = false;
        });
        return;
      }

      if (!config.isGoogleDrive && !config.isKeepiCloud) {
        setState(() {
          _config = config;
          _loading = false;
          _error = 'Almacenamiento no soportado en móvil.';
        });
        return;
      }

      final driveSvc = DriveStructureService(api);
      final dashboard = await driveSvc.getMobileDashboard();

      var folders = dashboard.folders;
      var rootFiles = dashboard.rootFiles;

      if (config.isKeepiCloud) {
        try {
          final rootRes = await driveSvc.getKeepiCloudRoot();
          folders = rootRes.folders;
          rootFiles = rootRes.rootFiles;
        } catch (_) {}
      }

      final userId = mounted ? context.read<AuthProvider>().userId : null;
      if (config.isKeepiCloud && userId != null) {
        folders = folders
            .where(
              (f) =>
                  f.id != 'users/$userId' &&
                  f.id != 'users/$userId/',
            )
            .toList();
      }

      if (!mounted) return;
      setState(() {
        _config = config;
        _folders = folders;
        _rootFiles = rootFiles;
        _alerts = dashboard.alerts;
        _totalKeepi = dashboard.totalKeepi;
        _alertsCount = dashboard.alertsCount;
        _alertsExpiredCount = dashboard.alertsExpiredCount;
        _requiresDriveAuth = dashboard.requiresDriveAuth;
        _authorizationUrl = dashboard.authorizationUrl;
        _loading = false;
      });

      if (dashboard.requiresDriveAuth) {
        await _promptDriveReconnect();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _messageFromError(e);
        _loading = false;
      });
    }
  }

  String _messageFromError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['detail'] != null) {
        return data['detail'].toString();
      }
      return e.message ?? e.toString();
    }
    return e.toString();
  }

  Future<void> _promptDriveReconnect() async {
    if (!mounted || !_requiresDriveAuth) return;
    final should = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reconectar Google Drive'),
        content: const Text(
          'Tu sesión de Google Drive caducó. Reconéctala para ver tus carpetas y archivos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Después'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reconectar'),
          ),
        ],
      ),
    );
    if (should != true || !mounted) return;
    final url = _authorizationUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openFolder(DriveFolder folder) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FolderContentsScreen(
          folderId: folder.id,
          folderName: folder.name,
        ),
      ),
    );
  }

  Future<void> _openExportModal() async {
    await showPatientFoldersExportSheet(
      context,
      rootFolders: _folders,
    );
  }

  Future<void> _openFile(DriveFile file) async {
    await DocumentFileOpener.open(context, file: file);
  }

  Future<void> _openAlertDocument(DocumentAlertItem item) async {
    final file = DriveFile(
      id: item.id,
      name: item.fileName ?? item.name,
      keepiDocumentId: item.keepiDocumentId,
      canEditMetadata: item.canEditMetadata,
    );
    await DocumentFileOpener.open(context, file: file);
  }

  Future<void> _replaceAlertDocument(DocumentAlertItem item) async {
    final docId = item.keepiDocumentId;
    if (docId == null || docId.isEmpty || !item.canReplace) return;
    final cfg = _config;
    await runDocumentReplaceFlow(
      context,
      replacesDocumentId: docId,
      onSaved: _load,
      saveButtonLabel: cfg != null && cfg.isKeepiCloud
          ? 'Guardar en Keepi Cloud'
          : 'Guardar en Drive',
    );
  }

  Future<void> _editAlertMetadata(DocumentAlertItem item) async {
    final docId = item.keepiDocumentId;
    if (docId == null || docId.isEmpty) return;
    final saved = await openDocumentMetadataEditor(
      context,
      documentId: docId,
    );
    if (saved && mounted) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Metadatos actualizados')),
      );
    }
  }

  Future<void> _editFileMetadata(DriveFile file) async {
    final docId = file.editableDocumentId;
    if (docId == null || docId.isEmpty) return;
    final saved = await openDocumentMetadataEditor(
      context,
      documentId: docId,
      preview: file,
    );
    if (saved && mounted) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Metadatos actualizados')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    final isKeepi = config?.isKeepiCloud ?? false;
    final isDrive = config?.isGoogleDrive ?? false;
    final notConfigured = config?.isNotConfigured ?? false;

    final canAnalyze = !notConfigured && (isKeepi || isDrive);

    return Scaffold(
      backgroundColor: KeepiColors.surfaceBg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            DecorativeBackground(
              blobOpacity: 0.2,
              child: RefreshIndicator(
                color: KeepiColors.orange,
                onRefresh: _load,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                SliverToBoxAdapter(
                  child: _DocTopBar(onBack: () => Navigator.of(context).maybePop()),
                ),
                SliverToBoxAdapter(
                  child: _DocHero(
                    storageLabel: notConfigured
                        ? 'Sin configurar'
                        : (isKeepi ? 'Keepi Cloud' : 'Google Drive'),
                    isKeepi: isKeepi,
                    totalKeepi: _totalKeepi,
                    alertsCount: _alertsCount,
                    alertsExpiredCount: _alertsExpiredCount,
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    22,
                    4,
                    22,
                    _showExportFab ? 100 : 40,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _buildBody(
                      notConfigured: notConfigured,
                      isKeepi: isKeepi,
                      isDrive: isDrive,
                    ),
                  ),
                ),
                  ],
                ),
              ),
            ),
            if (_showExportFab)
              Positioned(
                left: 20,
                bottom: 20,
                child: IosExportFab(onPressed: _openExportModal),
              ),
            if (canAnalyze)
              Positioned(
                right: 20,
                bottom: 20,
                child: IosFab(
                  onPressed: () => runDocumentAnalyzeFlow(
                    context,
                    onSaved: _load,
                    saveButtonLabel: isKeepi
                        ? 'Guardar en Keepi Cloud'
                        : 'Guardar en Drive',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody({
    required bool notConfigured,
    required bool isKeepi,
    required bool isDrive,
  }) {
    if (_loading) return const _DocLoadingBox();
    if (_error != null) {
      return _DocErrorBox(message: _error!, onRetry: _load);
    }
    if (notConfigured) {
      return const _DocEmptyCard(
        tag: 'ALMACENAMIENTO',
        title: 'Configura tu nube',
        message:
            'Elige Keepi Cloud o Google Drive para ver tus carpetas y documentos aquí.',
        icon: Icons.cloud_outlined,
      );
    }
    if (_requiresDriveAuth && isDrive) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DriveAuthCard(onReconnect: _promptDriveReconnect),
          const SizedBox(height: 16),
        ],
      );
    }

    final hasFolders = _folders.isNotEmpty;
    final hasRoot = _rootFiles.isNotEmpty;
    final hasAlerts = _alerts.isNotEmpty;

    if (!hasFolders && !hasRoot && !hasAlerts) {
      return _DocEmptyCard(
        tag: isKeepi ? 'KEEPI CLOUD' : 'GOOGLE DRIVE',
        title: 'Sin contenido',
        message: isKeepi
            ? 'Sube documentos desde la app para verlos organizados por carpeta.'
            : 'Crea carpetas en Google Drive para verlas aquí.',
        icon: isKeepi ? Icons.cloud_rounded : Icons.folder_open_rounded,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasAlerts) ...[
          _DocSectionDivider(tag: 'ALERTAS', count: _alerts.length),
          const SizedBox(height: 8),
          const Text(
            'Documentos vencidos o por vencer en 30 días (tu nube activa).',
            style: TextStyle(
              fontSize: 12.5,
              color: KeepiColors.slateLight,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          for (final item in _alerts.take(8))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DocumentAlertTile(
                item: item,
                compact: true,
                onTap: () => _openAlertDocument(item),
                onEdit: () => _editAlertMetadata(item),
                onReplace: () => _replaceAlertDocument(item),
              ),
            ),
          const SizedBox(height: 18),
        ],
        if (hasFolders) ...[
          _DocSectionDivider(tag: 'CARPETAS', count: _folders.length),
          const SizedBox(height: 12),
          for (final folder in _folders)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _FolderCard(
                folder: folder,
                accent: isKeepi ? KeepiColors.skyBlue : KeepiColors.orange,
                onTap: () => _openFolder(folder),
              ),
            ),
          const SizedBox(height: 8),
        ],
        if (hasRoot) ...[
          _DocSectionDivider(tag: 'ARCHIVOS EN RAÍZ', count: _rootFiles.length),
          const SizedBox(height: 12),
          for (final file in _rootFiles)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _FileCard(
                file: file,
                onTap: () => _openFile(file),
                onEdit: file.canEditMetadata ? () => _editFileMetadata(file) : null,
              ),
            ),
        ],
      ],
    );
  }
}

// ── Widgets de UI (estilo bandeja / perfil doctor) ───────────────────────────

class _DocTopBar extends StatelessWidget {
  const _DocTopBar({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Row(
        children: [
          _IconPill(icon: Icons.arrow_back_rounded, onTap: onBack),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/logo.png',
              width: 34,
              height: 34,
              fit: BoxFit.cover,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _IconPill extends StatelessWidget {
  const _IconPill({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: KeepiColors.cardBorder),
        ),
        child: Icon(icon, size: 19, color: KeepiColors.slate),
      ),
    );
  }
}

class _DocHero extends StatelessWidget {
  const _DocHero({
    required this.storageLabel,
    required this.isKeepi,
    required this.totalKeepi,
    required this.alertsCount,
    required this.alertsExpiredCount,
  });

  final String storageLabel;
  final bool isKeepi;
  final int totalKeepi;
  final int alertsCount;
  final int alertsExpiredCount;

  @override
  Widget build(BuildContext context) {
    final accent = isKeepi ? KeepiColors.skyBlue : KeepiColors.orange;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 22, height: 2, color: KeepiColors.slate),
              const SizedBox(width: 8),
              const Text(
                'DOCUMENTOS',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                  color: KeepiColors.slate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Tu biblioteca.',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: KeepiColors.slate,
              height: 1.1,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                isKeepi ? Icons.cloud_rounded : Icons.folder_rounded,
                size: 16,
                color: accent,
              ),
              const SizedBox(width: 6),
              Text(
                storageLabel,
                style: TextStyle(
                  fontSize: 13.5,
                  color: accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: KeepiColors.cardBorder),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: _StatCell(
                      value: totalKeepi,
                      label: 'CON KEEPI',
                      color: KeepiColors.orange,
                    ),
                  ),
                  Container(width: 1, color: KeepiColors.cardBorder),
                  Expanded(
                    child: _StatCell(
                      value: alertsCount,
                      label: 'ALERTAS',
                      color: alertsCount > 0
                          ? (alertsExpiredCount > 0
                              ? const Color(0xFFD32F2F)
                              : KeepiColors.orange)
                          : KeepiColors.slate,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.value,
    required this.label,
    required this.color,
  });

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value.toString().padLeft(2, '0'),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: KeepiColors.slateLight,
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocSectionDivider extends StatelessWidget {
  const _DocSectionDivider({required this.tag, required this.count});
  final String tag;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 18,
          height: 1,
          color: KeepiColors.slate.withValues(alpha: 0.45),
        ),
        const SizedBox(width: 10),
        Text(
          tag,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
            color: KeepiColors.slate,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: KeepiColors.slateSoft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            count.toString().padLeft(2, '0'),
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: KeepiColors.slate,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: KeepiColors.slate.withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }
}

class _FolderCard extends StatelessWidget {
  const _FolderCard({
    required this.folder,
    required this.accent,
    required this.onTap,
  });

  final DriveFolder folder;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final countLabel = folder.filesCount == 1
        ? '1 archivo'
        : '${folder.filesCount} archivos';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KeepiColors.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.folder_rounded, color: accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    folder.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: KeepiColors.slate,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    countLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      color: KeepiColors.slateLight,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: KeepiColors.slateLight,
            ),
          ],
        ),
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({
    required this.file,
    required this.onTap,
    this.onEdit,
  });
  final DriveFile file;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final style = FileTypeStyle.forFile(file.name, file.mimeType);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KeepiColors.cardBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: style.backgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(style.icon, color: style.color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                file.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: KeepiColors.slate,
                ),
              ),
            ),
            DocumentReplacementInfoIcon(file: file),
            if (file.keepiVerified)
              const Padding(
                padding: EdgeInsets.only(left: 2),
                child: Icon(
                  Icons.verified_rounded,
                  size: 18,
                  color: KeepiColors.green,
                ),
              ),
            if (onEdit != null)
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(
                    Icons.edit_rounded,
                    size: 20,
                    color: KeepiColors.orange,
                  ),
                  tooltip: 'Editar metadatos',
                ),
            const Icon(
              Icons.open_in_new_rounded,
              size: 18,
              color: KeepiColors.slateLight,
            ),
          ],
        ),
      ),
    );
  }
}

class _DriveAuthCard extends StatelessWidget {
  const _DriveAuthCard({required this.onReconnect});
  final VoidCallback onReconnect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KeepiColors.orangeSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KeepiColors.orange.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cloud_off_rounded, color: KeepiColors.orange),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Google Drive desconectado',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: KeepiColors.slate,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Reconecta tu cuenta para listar carpetas y abrir archivos.',
            style: TextStyle(color: KeepiColors.slateLight, height: 1.4),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onReconnect,
            style: FilledButton.styleFrom(
              backgroundColor: KeepiColors.orange,
            ),
            child: const Text('Reconectar'),
          ),
        ],
      ),
    );
  }
}

class _DocLoadingBox extends StatelessWidget {
  const _DocLoadingBox();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            color: KeepiColors.orange,
            strokeWidth: 2.4,
          ),
        ),
      ),
    );
  }
}

class _DocErrorBox extends StatelessWidget {
  const _DocErrorBox({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KeepiColors.orange.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: KeepiColors.orange),
              SizedBox(width: 8),
              Text(
                'NO PUDIMOS CARGAR',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: KeepiColors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(color: KeepiColors.slate)),
          const SizedBox(height: 10),
          InkWell(
            onTap: onRetry,
            child: const Text(
              'REINTENTAR',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: KeepiColors.slate,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocEmptyCard extends StatelessWidget {
  const _DocEmptyCard({
    required this.tag,
    required this.title,
    required this.message,
    required this.icon,
  });

  final String tag;
  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tag,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
              color: KeepiColors.slate,
            ),
          ),
          const SizedBox(height: 14),
          Icon(icon, size: 40, color: KeepiColors.slateLight),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: KeepiColors.slate,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13.5,
              color: KeepiColors.slateLight,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
