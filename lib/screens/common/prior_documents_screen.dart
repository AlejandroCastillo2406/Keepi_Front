import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/web_layout.dart';
import '../../models/prior_document_item.dart';
import '../../services/api_client.dart';
import '../../services/document_file_opener.dart';
import '../../services/doctor_service.dart';
import '../../services/drive_structure_service.dart';

/// Lista de documentos médicos previos (cuestionario inicial) con botón para abrir cada uno.
class PriorDocumentsScreen extends StatefulWidget {
  const PriorDocumentsScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    this.forPatientView = false,
    this.embedded = false,
    this.onBack,
  });

  final String patientId;
  final String patientName;
  final bool forPatientView;
  final bool embedded;
  final VoidCallback? onBack;

  @override
  State<PriorDocumentsScreen> createState() => _PriorDocumentsScreenState();
}

class _PriorDocumentsScreenState extends State<PriorDocumentsScreen> {
  List<PriorDocumentItem> _items = [];
  bool _loading = true;
  String? _error;
  String? _openingId;

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
      final svc = DoctorService(context.read<ApiClient>());
      final list = widget.forPatientView
          ? await svc.fetchMyPriorDocuments()
          : await svc.fetchPatientPriorDocuments(widget.patientId);
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = DoctorService.messageFromDio(e);
        _loading = false;
      });
    }
  }

  Future<void> _open(PriorDocumentItem doc) async {
    setState(() => _openingId = doc.id);
    try {
      final fileId = (doc.s3Key != null && doc.s3Key!.isNotEmpty)
          ? doc.s3Key!
          : doc.id;
      await DocumentFileOpener.open(
        context,
        file: DriveFile(
          id: fileId,
          name: doc.fileName ?? doc.name,
          mimeType: doc.fileType,
          keepiDocumentId: doc.id,
        ),
      );
    } finally {
      if (mounted) setState(() => _openingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = widget.forPatientView
        ? 'Mis documentos previos'
        : 'Documentos previos';

    if (widget.embedded) {
      return EmbeddedWebPage(
        title: title,
        onBack: widget.onBack,
        child: _buildBody(theme),
      );
    }

    return Scaffold(
      backgroundColor: KeepiColors.surfaceBg,
      appBar: AppBar(title: Text(title)),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: KeepiColors.orange),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No hay documentos previos registrados.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: KeepiColors.slateLight,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text(
          widget.forPatientView
              ? 'Archivos que compartiste al completar tu ficha clínica.'
              : 'Archivos que ${widget.patientName} compartió al completar la ficha clínica.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: KeepiColors.slateLight,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 16),
        ..._items.map((doc) => _DocTile(
              doc: doc,
              opening: _openingId == doc.id,
              onOpen: () => _open(doc),
            )),
      ],
    );
  }
}

class _DocTile extends StatelessWidget {
  const _DocTile({
    required this.doc,
    required this.opening,
    required this.onOpen,
  });

  final PriorDocumentItem doc;
  final bool opening;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: opening ? null : onOpen,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: KeepiColors.cardBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: KeepiColors.skyBlueSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.folder_shared_outlined,
                    color: KeepiColors.skyBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.fileName ?? doc.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: KeepiColors.slate,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (doc.createdAt != null && doc.createdAt!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _formatDate(doc.createdAt!),
                            style: const TextStyle(
                              fontSize: 12,
                              color: KeepiColors.slateLight,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (opening)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: KeepiColors.orange,
                    ),
                  )
                else
                  FilledButton.tonal(
                    onPressed: onOpen,
                    style: FilledButton.styleFrom(
                      backgroundColor: KeepiColors.orangeSoft,
                      foregroundColor: KeepiColors.orange,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                    child: const Text('Ver'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final local = dt.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }
}
