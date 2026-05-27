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

/// Modal: solo carpetas de pacientes del médico; exporta todo su contenido a un ZIP.
Future<void> showPatientFoldersExportSheet(
  BuildContext context, {
  required List<DriveFolder> rootFolders,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _PatientFoldersExportSheet(rootFolders: rootFolders),
  );
}

class _PatientFoldersExportSheet extends StatefulWidget {
  const _PatientFoldersExportSheet({required this.rootFolders});

  final List<DriveFolder> rootFolders;

  @override
  State<_PatientFoldersExportSheet> createState() =>
      _PatientFoldersExportSheetState();
}

class _PatientFoldersExportSheetState extends State<_PatientFoldersExportSheet> {
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
        (a, b) => a.patientName.toLowerCase().compareTo(b.patientName.toLowerCase()),
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

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: KeepiColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Exportar expedientes',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: KeepiColors.slate,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Selecciona pacientes. El ZIP incluirá sus carpetas (Análisis, Recetas, etc.) y podrás elegir dónde guardarlo.',
                          style: TextStyle(
                            fontSize: 13,
                            color: KeepiColors.slateLight,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _exporting ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(child: _buildBody()),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    if (_items.isNotEmpty)
                      TextButton(
                        onPressed: _exporting
                            ? null
                            : () {
                                setState(() {
                                  if (_selectedIds.length == _items.length) {
                                    _selectedIds.clear();
                                  } else {
                                    _selectedIds
                                      ..clear()
                                      ..addAll(_items.map((e) => e.patientId));
                                  }
                                });
                              },
                        child: Text(
                          _selectedIds.length == _items.length
                              ? 'Quitar todos'
                              : 'Seleccionar todos',
                        ),
                      ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _exporting || _selectedIds.isEmpty
                          ? null
                          : _export,
                      icon: _exporting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.folder_zip_outlined, size: 20),
                      label: Text(
                        _exporting
                            ? 'Exportando…'
                            : 'Exportar (${_selectedIds.length})',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: KeepiColors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: CircularProgressIndicator(color: KeepiColors.orange),
        ),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(28),
        child: Text(
          'No hay carpetas de pacientes en tu nube.\n'
          'Cuando registres pacientes y subas documentos, aparecerán aquí.',
          textAlign: TextAlign.center,
          style: TextStyle(color: KeepiColors.slateLight, height: 1.4),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        final selected = _selectedIds.contains(item.patientId);
        final countLabel = item.filesCount == 1
            ? '1 archivo'
            : '${item.filesCount} archivos';

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: selected
                ? KeepiColors.orangeSoft.withValues(alpha: 0.5)
                : KeepiColors.cardBg,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: _exporting
                  ? null
                  : () {
                      setState(() {
                        if (selected) {
                          _selectedIds.remove(item.patientId);
                        } else {
                          _selectedIds.add(item.patientId);
                        }
                      });
                    },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? KeepiColors.orange.withValues(alpha: 0.5)
                        : KeepiColors.cardBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: selected,
                      onChanged: _exporting
                          ? null
                          : (_) {
                              setState(() {
                                if (selected) {
                                  _selectedIds.remove(item.patientId);
                                } else {
                                  _selectedIds.add(item.patientId);
                                }
                              });
                            },
                      activeColor: KeepiColors.orange,
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: KeepiColors.skyBlueSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        color: KeepiColors.skyBlue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.patientName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: KeepiColors.slate,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            countLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              color: KeepiColors.slateLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
