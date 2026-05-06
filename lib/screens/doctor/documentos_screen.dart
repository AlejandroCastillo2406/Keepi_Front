import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/decorative_background.dart';
import '../../services/api_client.dart';
import '../../services/doctor_service.dart';
import '../../services/drive_structure_service.dart';
import '../user/folder_contents_screen.dart';
import 'analysis_document_viewer_screen.dart';

class DocumentosScreen extends StatefulWidget {
  const DocumentosScreen({super.key});

  @override
  State<DocumentosScreen> createState() => _DocumentosScreenState();
}

class _DocumentosScreenState extends State<DocumentosScreen> {
  MobileDashboardResponse? _dashboard;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiClient>();
      final service = DriveStructureService(api);
      final data = await service.getMobileDashboard();
      if (!mounted) return;
      setState(() {
        _dashboard = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openFolder(DriveFolder folder) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FolderContentsScreen(
          folderId: folder.id,
          folderName: folder.name,
        ),
      ),
    );
  }

  Future<void> _openFile(DriveFile file) async {
    final api = context.read<ApiClient>();
    final svc = DoctorService(api);
    final token = api.accessToken;
    final headers = <String, String>{
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      'Accept': '*/*',
    };
    final url = svc.getMobileDocumentUrl(file.id);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnalysisDocumentViewerScreen(
          url: url,
          title: file.name,
          headers: headers,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dashboard = _dashboard;
    final folders = dashboard?.folders ?? const <DriveFolder>[];
    final rootFiles = dashboard?.rootFiles ?? const <DriveFile>[];
    final totalKeepi = dashboard?.totalKeepi ?? 0;
    final expiringCount = dashboard?.expiringSoonCount ?? 0;

    return Scaffold(
      backgroundColor: KeepiColors.surfaceBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Documentos',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: KeepiColors.slate,
          ),
        ),
      ),
      body: DecorativeBackground(
        blobOpacity: 0.2,
        child: RefreshIndicator(
          onRefresh: _load,
          color: KeepiColors.orange,
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: KeepiColors.orange),
                )
              : _error != null
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.red.shade100),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                color: Colors.red.shade800,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Error al cargar documentos:\n$_error',
                                  style: TextStyle(color: Colors.red.shade900),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        Text(
                          'Gestión Documental',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: KeepiColors.slate,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _SummaryCard(
                                title: 'Total Archivos',
                                count: totalKeepi.toString(),
                                bgColor: KeepiColors.skyBlueSoft,
                                iconColor: KeepiColors.skyBlue,
                                icon: Icons.folder_rounded,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _SummaryCard(
                                title: 'Vencimientos',
                                count: expiringCount.toString(),
                                bgColor: Colors.red.shade50,
                                iconColor: Colors.red.shade400,
                                icon: Icons.warning_amber_rounded,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
                        Text(
                          'Carpetas',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: KeepiColors.slate,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (folders.isEmpty)
                          const _InlineInfoCard(
                            icon: Icons.folder_open_rounded,
                            message: 'No hay carpetas disponibles.',
                          )
                        else
                          ...folders.map(
                            (folder) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _FolderCard(
                                folder: folder,
                                onTap: () => _openFolder(folder),
                              ),
                            ),
                          ),
                        const SizedBox(height: 18),
                        Text(
                          'Archivos raíz',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: KeepiColors.slate,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (rootFiles.isEmpty)
                          const _InlineInfoCard(
                            icon: Icons.insert_drive_file_outlined,
                            message: 'No hay archivos en raíz.',
                          )
                        else
                          ...rootFiles.map(
                            (file) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _FileCard(
                                file: file,
                                onTap: () => _openFile(file),
                              ),
                            ),
                          ),
                      ],
                    ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.count,
    required this.bgColor,
    required this.iconColor,
    required this.icon,
  });

  final String title;
  final String count;
  final Color bgColor;
  final Color iconColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KeepiColors.cardBorder.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: KeepiColors.slate.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: KeepiColors.slateLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: KeepiColors.slate,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineInfoCard extends StatelessWidget {
  const _InlineInfoCard({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: KeepiColors.slateLight),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13.3,
                color: KeepiColors.slateLight,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FolderCard extends StatelessWidget {
  const _FolderCard({required this.folder, required this.onTap});

  final DriveFolder folder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final filesLabel =
        folder.filesCount == 1 ? '1 archivo' : '${folder.filesCount} archivos';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: KeepiColors.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: KeepiColors.orangeSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  const Icon(Icons.folder_rounded, color: KeepiColors.orange),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    folder.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.2,
                      fontWeight: FontWeight.w700,
                      color: KeepiColors.slate,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    filesLabel,
                    style: const TextStyle(
                      fontSize: 12.5,
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
  const _FileCard({required this.file, required this.onTap});

  final DriveFile file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: KeepiColors.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: KeepiColors.skyBlueSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.insert_drive_file_rounded,
                color: KeepiColors.skyBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.2,
                  fontWeight: FontWeight.w700,
                  color: KeepiColors.slate,
                ),
              ),
            ),
            const Icon(
              Icons.open_in_new_rounded,
              color: KeepiColors.slateLight,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
