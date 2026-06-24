import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../models/patient_export_folder.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/doctor_service.dart';
import '../services/document_export_save.dart';
import '../services/document_export_service.dart';
import '../services/drive_structure_service.dart';
import '../utils/patient_folder_name.dart';
import 'notification_web_dialog.dart';

/// Modal web: carpetas de pacientes del médico → ZIP descargable.
Future<void> showPatientFoldersExportSheet(
  BuildContext context, {
  required List<DriveFolder> rootFolders,
}) async {
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) => _PatientFoldersExportDialog(rootFolders: rootFolders),
  );
}

class _PatientFoldersExportDialog extends StatefulWidget {
  const _PatientFoldersExportDialog({required this.rootFolders});

  final List<DriveFolder> rootFolders;

  @override
  State<_PatientFoldersExportDialog> createState() =>
      _PatientFoldersExportDialogState();
}

class _PatientFoldersExportDialogState extends State<_PatientFoldersExportDialog> {
  static const _accent = KeepiColors.orange;

  bool _loading = true;
  String? _error;
  List<PatientExportFolder> _items = [];
  final Set<String> _selectedIds = {};
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  int get _selectedFilesCount => _items
      .where((i) => _selectedIds.contains(i.patientId))
      .fold<int>(0, (sum, i) => sum + i.filesCount);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiClient>();
      final auth = context.read<AuthProvider>();
      final userId = auth.userId;
      if (userId == null || userId.isEmpty) {
        throw Exception('Sesión no válida.');
      }

      final patients = await DoctorService(api).fetchMyPatients();
      final bySanitized = <String, DriveFolder>{};
      for (final f in widget.rootFolders) {
        final name = f.name.trim();
        if (name.isEmpty || reservedRootFolderNames.contains(name)) continue;
        bySanitized[name] = f;
        bySanitized[sanitizePatientFolderName(name)] = f;
      }

      final list = <PatientExportFolder>[];
      for (final p in patients) {
        final key = sanitizePatientFolderName(p.name);
        final folder = bySanitized[key];
        if (folder == null) continue;

        var path = folder.id.trim();
        if (!path.startsWith('users/')) {
          path = 'users/$userId/$key';
        } else if (path.endsWith('/')) {
          path = path.substring(0, path.length - 1);
        }

        list.add(
          PatientExportFolder(
            patientId: p.id,
            patientName: p.name,
            s3FolderPath: path,
            filesCount: folder.filesCount,
          ),
        );
      }

      list.sort(
        (a, b) =>
            a.patientName.toLowerCase().compareTo(b.patientName.toLowerCase()),
      );

      if (!mounted) return;
      setState(() {
        _items = list;
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

  void _togglePatient(String patientId) {
    if (_exporting) return;
    setState(() {
      if (_selectedIds.contains(patientId)) {
        _selectedIds.remove(patientId);
      } else {
        _selectedIds.add(patientId);
      }
    });
  }

  void _toggleSelectAll() {
    if (_exporting) return;
    setState(() {
      if (_selectedIds.length == _items.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(_items.map((e) => e.patientId));
      }
    });
  }

  Future<void> _export() async {
    final selected =
        _items.where((i) => _selectedIds.contains(i.patientId)).toList();
    if (selected.isEmpty) return;

    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final api = context.read<ApiClient>();
      final zip = await DocumentExportService(api).exportPatientFoldersToZip(
        folders: selected,
        onProgress: (current, total, label) {
          if (!mounted) return;
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              content: Text('Descargando $current/$total: $label'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        },
      );
      if (!mounted) return;

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Elige dónde guardar el archivo…'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );

      final savedPath = await DocumentExportSave.promptSaveZip(
        bytes: zip.bytes,
        fileName: zip.fileName,
      );
      if (!mounted) return;

      if (savedPath == null || savedPath.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Exportación cancelada.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Expediente guardado en:\n$savedPath'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade800,
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final p = parts.first;
      return (p.length >= 2 ? p.substring(0, 2) : p).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = NotificationDialogTheme.patientExport();

    return PopScope(
      canPop: !_exporting,
      child: NotificationWebDialog(
        title: theme.titleFallback,
        tag: theme.tag,
        accent: theme.accent,
        icon: theme.icon,
        subtitle:
            'Selecciona pacientes y descarga un ZIP con Análisis, Recetas y más.',
        maxWidth: 640,
        maxHeightFactor: 0.88,
        canClose: !_exporting,
        footer: _buildFooter(),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildFooter() {
    final allSelected =
        _items.isNotEmpty && _selectedIds.length == _items.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_items.isNotEmpty && !_loading)
          Row(
            children: [
              TextButton.icon(
                onPressed: _exporting ? null : _toggleSelectAll,
                icon: Icon(
                  allSelected
                      ? Icons.deselect_outlined
                      : Icons.select_all_rounded,
                  size: 18,
                  color: _accent,
                ),
                label: Text(
                  allSelected ? 'Quitar todos' : 'Seleccionar todos',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const Spacer(),
              if (_selectedIds.isNotEmpty)
                Text(
                  '$_selectedFilesCount archivos',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: KeepiColors.slateLight,
                  ),
                ),
            ],
          ),
        const SizedBox(height: 8),
        _exporting
            ? Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _accent.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: _accent,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Preparando expediente…',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _accent,
                      ),
                    ),
                  ],
                ),
              )
            : FilledButton.icon(
                onPressed: _selectedIds.isEmpty ? null : _export,
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  disabledBackgroundColor:
                      KeepiColors.slateLight.withValues(alpha: 0.35),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.download_rounded, size: 20),
                label: Text(
                  _selectedIds.isEmpty
                      ? 'Selecciona al menos un paciente'
                      : 'Exportar ZIP (${_selectedIds.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: CircularProgressIndicator(color: _accent),
        ),
      );
    }

    if (_error != null) {
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.red.shade100),
            ),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade800, height: 1.4),
            ),
          ),
          const SizedBox(height: 16),
          NotificationPrimaryButton(
            label: 'Reintentar',
            icon: Icons.refresh_rounded,
            accent: _accent,
            onPressed: _load,
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.cloud_off_outlined,
              size: 36,
              color: _accent.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Sin carpetas de pacientes',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: KeepiColors.slate,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Cuando registres pacientes y subas documentos a la nube, '
            'aparecerán aquí listos para exportar.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: KeepiColors.slateLight,
              height: 1.45,
              fontSize: 14,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _StatChip(
                icon: Icons.people_outline_rounded,
                label: 'Pacientes',
                value: '${_items.length}',
                accent: _accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatChip(
                icon: Icons.insert_drive_file_outlined,
                label: 'En nube',
                value: '${_items.fold<int>(0, (s, i) => s + i.filesCount)}',
                accent: KeepiColors.skyBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        NotificationInfoTile(
          icon: Icons.info_outline_rounded,
          label: 'Contenido del ZIP',
          value: 'Cada paciente incluye sus subcarpetas: Análisis, Recetas, '
              'Estudios y documentos clínicos.',
          accent: _accent,
        ),
        const SizedBox(height: 18),
        Text(
          'PACIENTES DISPONIBLES',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.3,
            color: KeepiColors.slateLight.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 10),
        ..._items.map(_buildPatientCard),
      ],
    );
  }

  Widget _buildPatientCard(PatientExportFolder item) {
    final selected = _selectedIds.contains(item.patientId);
    final countLabel = item.filesCount == 1
        ? '1 archivo'
        : '${item.filesCount} archivos';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _togglePatient(item.patientId),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected
                  ? _accent.withValues(alpha: 0.06)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? _accent.withValues(alpha: 0.45)
                    : KeepiColors.cardBorder,
                width: selected ? 1.5 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: _accent.withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: selected
                          ? [_accent, Color.lerp(_accent, Colors.white, 0.25)!]
                          : [
                              KeepiColors.skyBlueSoft,
                              KeepiColors.skyBlue.withValues(alpha: 0.25),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _initials(item.patientName),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: selected ? Colors.white : KeepiColors.skyBlue,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.patientName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: KeepiColors.slate,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.folder_outlined,
                            size: 14,
                            color: selected ? _accent : KeepiColors.slateLight,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            countLabel,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? _accent.withValues(alpha: 0.85)
                                  : KeepiColors.slateLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: selected ? _accent : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? _accent : KeepiColors.cardBorder,
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: accent.withValues(alpha: 0.75),
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: accent,
                    height: 1.1,
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
