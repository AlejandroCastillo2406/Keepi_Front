import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_theme.dart';
import '../core/decorative_background.dart';
import '../core/file_type_style.dart';
import '../services/api_client.dart';
import '../services/cloud_storage_service.dart';
import '../services/drive_structure_service.dart';

class FolderContentsScreen extends StatefulWidget {
  const FolderContentsScreen({
    super.key,
    required this.folderId,
    required this.folderName,
  });

  final String folderId;
  final String folderName;

  @override
  State<FolderContentsScreen> createState() => _FolderContentsScreenState();
}

class _FolderContentsScreenState extends State<FolderContentsScreen> with WidgetsBindingObserver {
  DriveFolderContentsResponse? _data;
  bool _loading = true;
  String? _error;
  /// True cuando falla 401 en una carpeta de Google Drive (token vencido o revocado).
  bool _needsDriveReauth = false;
  bool _reconnecting = false;

  bool get _isS3Folder => widget.folderId.startsWith('users/');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _needsDriveReauth) _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _needsDriveReauth = false;
    });
    try {
      final api = context.read<ApiClient>();
      final service = DriveStructureService(api);
      final data = _isS3Folder
          ? await service.getS3FolderContents(widget.folderId)
          : await service.getFolderContents(widget.folderId);
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
          _error = null;
          _needsDriveReauth = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      final is401 = e is DioException && e.response?.statusCode == 401;
      final isDriveAuth = !_isS3Folder && (is401 || _isDriveAuthMessage(e.toString()));
      setState(() {
        _data = null;
        _loading = false;
        _error = isDriveAuth
            ? 'La sesión de Google Drive expiró o se revocó.'
            : e.toString();
        _needsDriveReauth = isDriveAuth;
      });
    }
  }

  bool _isDriveAuthMessage(String msg) =>
      msg.contains('Google Drive') || msg.contains('autorizado') || msg.contains('401');

  Future<void> _reconnectGoogleDrive() async {
    if (_reconnecting || !mounted) return;
    setState(() => _reconnecting = true);
    try {
      final api = context.read<ApiClient>();
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
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _reconnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.folderName,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: KeepiColors.slate),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: DecorativeBackground(
        blobOpacity: 0.2,
        child: RefreshIndicator(
        onRefresh: _load,
        color: KeepiColors.orange,
        child: _loading
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: KeepiColors.orange,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Cargando…',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: KeepiColors.slateLight,
                      ),
                    ),
                  ],
                ),
              )
            : _error != null
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _needsDriveReauth ? Icons.cloud_off_rounded : Icons.error_outline_rounded,
                            size: 48,
                            color: KeepiColors.orange,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: KeepiColors.slateLight,
                            ),
                          ),
                          if (_needsDriveReauth) ...[
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: _reconnecting ? null : _reconnectGoogleDrive,
                              icon: _reconnecting
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.link_rounded, size: 20),
                              label: Text(_reconnecting ? 'Conectando…' : 'Volver a conectar Google Drive'),
                              style: FilledButton.styleFrom(
                                backgroundColor: KeepiColors.orange,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : _buildContent(theme, colorScheme),
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, ColorScheme colorScheme) {
    final folders = _data!.folders;
    final files = _data!.files;
    final isEmpty = folders.isEmpty && files.isEmpty;

    if (isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.folder_open_rounded,
                  size: 56,
                  color: KeepiColors.slateLight.withOpacity(0.6),
                ),
                const SizedBox(height: 16),
                Text(
                  'Carpeta vacía',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: KeepiColors.slateLight,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        if (folders.isNotEmpty) ...[
          _sectionLabel(theme, 'Carpetas', Icons.folder_rounded),
          const SizedBox(height: 10),
          _IOSStyleCard(
            child: Column(
              children: [
                for (int i = 0; i < folders.length; i++) ...[
                  _FolderTile(
                    folder: folders[i],
                    isLast: i == folders.length - 1,
                    onTap: () => _openFolder(folders[i]),
                  ),
                  if (i < folders.length - 1)
                    Divider(
                      height: 1,
                      indent: 56,
                      color: KeepiColors.cardBorder.withOpacity(0.8),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (files.isNotEmpty) ...[
          _sectionLabel(theme, 'Archivos', Icons.insert_drive_file_rounded),
          const SizedBox(height: 10),
          _IOSStyleCard(
            child: Column(
              children: [
                for (int i = 0; i < files.length; i++) ...[
                  _FileTile(
                    file: files[i],
                    isLast: i == files.length - 1,
                    onTap: () => _openFilePreview(files[i]),
                    onDownload: () => _downloadFile(files[i]),
                    onDelete: () => _confirmDeleteFile(files[i]),
                  ),
                  if (i < files.length - 1)
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

  Widget _sectionLabel(ThemeData theme, String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: KeepiColors.orange),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: KeepiColors.slateLight,
          ),
        ),
      ],
    );
  }

  void _openFolder(DriveFolder folder) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => FolderContentsScreen(
          folderId: folder.id,
          folderName: folder.name,
        ),
      ),
    );
  }

  Future<void> _openFilePreview(DriveFile file) async {
    final api = context.read<ApiClient>();
    final service = DriveStructureService(api);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Abriendo vista previa…'),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final info = await service.getFileViewUrl(file.id);
      if (info.viewUrl.isEmpty) {
        if (mounted) {
          scaffoldMessenger.hideCurrentSnackBar();
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('No se pudo obtener la vista previa de este archivo.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      final uri = Uri.parse(info.viewUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      if (mounted) scaffoldMessenger.hideCurrentSnackBar();
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.hideCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceFirst('DioException [bad response]: ', '')}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _downloadFile(DriveFile file) async {
    final api = context.read<ApiClient>();
    final service = DriveStructureService(api);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Text('Descargando…'),
          ],
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final bytes = await service.downloadFileContent(file.id);
      if (!mounted) return;
      if (bytes.isEmpty) {
        scaffoldMessenger.hideCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('No se pudo descargar el archivo.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      final dir = await getApplicationDocumentsDirectory();
      final keepiDir = Directory('${dir.path}/KeepiDownloads');
      if (!await keepiDir.exists()) await keepiDir.create(recursive: true);
      final safeName = file.name.replaceAll(RegExp(r'[^\w\s\-\.]'), '_');
      final path = '${keepiDir.path}/$safeName';
      final f = File(path);
      await f.writeAsBytes(bytes);
      scaffoldMessenger.hideCurrentSnackBar();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Guardado: $path'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.hideCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error al descargar: ${e.toString().replaceFirst('DioException [bad response]: ', '')}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteFile(DriveFile file) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar archivo'),
        content: Text(
          '¿Eliminar "${file.name}"?\n\nEste archivo se borrará de forma permanente en Google Drive y no podrás recuperarlo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar', style: TextStyle(color: KeepiColors.slateLight)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD32F2F)),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final api = context.read<ApiClient>();
    final service = DriveStructureService(api);
    try {
      await service.deleteFile(file.id);
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Archivo eliminado'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _load();
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: ${e.toString().replaceFirst('DioException [bad response]: ', '')}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _IOSStyleCard extends StatelessWidget {
  const _IOSStyleCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KeepiColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KeepiColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: KeepiColors.slate.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({
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
                child: Icon(
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
              Icon(
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

class _FileTypeIcon extends StatelessWidget {
  const _FileTypeIcon({required this.file});
  final DriveFile file;

  @override
  Widget build(BuildContext context) {
    final style = FileTypeStyle.forFile(file.name, file.mimeType);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: style.color.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(style.icon, color: style.color, size: 24),
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({
    required this.file,
    required this.isLast,
    required this.onTap,
    required this.onDownload,
    required this.onDelete,
  });
  final DriveFile file;
  final bool isLast;
  final VoidCallback onTap;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

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

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    children: [
                      _FileTypeIcon(file: file),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              file.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.2,
                                color: KeepiColors.slate,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                if (_formatSize(file.size).isNotEmpty)
                                  Text(
                                    _formatSize(file.size),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: KeepiColors.slateLight,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                if (file.keepiVerified) ...[
                                  if (_formatSize(file.size).isNotEmpty) const SizedBox(width: 8),
                                  Tooltip(
                                    message: 'Analizado por Keepi',
                                    child: Icon(
                                      Icons.verified_rounded,
                                      size: 18,
                                      color: KeepiColors.orange,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.more_vert, color: KeepiColors.slateLight, size: 22),
              onSelected: (value) {
                switch (value) {
                  case 'download':
                    onDownload();
                    break;
                  case 'delete':
                    onDelete();
                    break;
                  case 'reclassify':
                  case 'link':
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'reclassify',
                  enabled: false,
                  child: Row(
                    children: [
                      Icon(Icons.category_outlined, size: 20, color: KeepiColors.slateLight),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Re-clasificar', style: TextStyle(color: KeepiColors.slateLight)),
                          Text('Próximamente', style: theme.textTheme.bodySmall?.copyWith(color: KeepiColors.slateLight, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'link',
                  enabled: false,
                  child: Row(
                    children: [
                      Icon(Icons.link_rounded, size: 20, color: KeepiColors.slateLight),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Link temporal', style: TextStyle(color: KeepiColors.slateLight)),
                          Text('Próximamente', style: theme.textTheme.bodySmall?.copyWith(color: KeepiColors.slateLight, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'download',
                  child: Row(
                    children: [
                      Icon(Icons.download_rounded, size: 20, color: KeepiColors.slate),
                      const SizedBox(width: 12),
                      const Text('Descargar'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, size: 20, color: KeepiColors.orange),
                      const SizedBox(width: 12),
                      Text('Eliminar', style: TextStyle(color: KeepiColors.orange, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
