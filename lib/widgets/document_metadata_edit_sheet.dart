import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/expiry_date_format.dart';
import '../services/api_client.dart';
import '../services/drive_structure_service.dart';
import 'document_replacement_banner.dart';

/// Abre el editor de metadatos; devuelve `true` si guardó cambios.
Future<bool> openDocumentMetadataEditor(
  BuildContext context, {
  required String documentId,
  DriveFile? preview,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DocumentMetadataEditSheet(
      documentId: documentId,
      preview: preview,
    ),
  );
  return saved == true;
}

class DocumentMetadataEditSheet extends StatefulWidget {
  const DocumentMetadataEditSheet({
    super.key,
    required this.documentId,
    this.preview,
  });

  final String documentId;
  final DriveFile? preview;

  @override
  State<DocumentMetadataEditSheet> createState() =>
      _DocumentMetadataEditSheetState();
}

class _DocumentMetadataEditSheetState extends State<DocumentMetadataEditSheet> {
  final _fileNameCtrl = TextEditingController();
  String? _cloudProvider;
  final _categoryCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _documentNumberCtrl = TextEditingController();
  final _organizationCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  DateTime? _expiryDate;
  bool _isReplaced = false;
  bool _isReplacement = false;
  String? _replacedByName;
  String? _replacedByCategory;
  String? _replacesDocumentName;
  String? _replacesDocumentCategory;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _storageFieldLabel {
    if (_cloudProvider == 'keepi_cloud') return 'Nombre Keepi Cloud';
    if (_cloudProvider == 'google_drive') return 'Nombre Drive';
    return 'Nombre en la nube';
  }

  @override
  void dispose() {
    _fileNameCtrl.dispose();
    _categoryCtrl.dispose();
    _descriptionCtrl.dispose();
    _documentNumberCtrl.dispose();
    _organizationCtrl.dispose();
    super.dispose();
  }

  void _applyDto(DocumentMetadataDto dto) {
    _cloudProvider = dto.cloudProvider;
    _fileNameCtrl.text =
        dto.storageFileName ?? dto.fileName ?? dto.name;
    _categoryCtrl.text = dto.category;
    _descriptionCtrl.text = dto.description ?? '';
    _documentNumberCtrl.text = dto.documentNumber ?? '';
    _organizationCtrl.text = dto.organization ?? '';
    _expiryDate = _parseExpiryDateOnly(dto.expiryDate);
    _isReplaced = dto.isReplaced;
    _isReplacement = dto.isReplacement;
    _replacedByName = dto.replacedByName;
    _replacedByCategory = dto.replacedByCategory;
    _replacesDocumentName = dto.replacesDocumentName;
    _replacesDocumentCategory = dto.replacesDocumentCategory;
  }

  DateTime? _parseExpiryDateOnly(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final part = iso.split('T').first;
    final p = part.split('-');
    if (p.length != 3) return null;
    final y = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final d = int.tryParse(p[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  String? _expiryIsoForApi() {
    if (_expiryDate == null) return null;
    final d = _expiryDate!;
    return DateTime.utc(d.year, d.month, d.day, 23, 59, 59).toIso8601String();
  }

  Future<void> _load() async {
    final preview = widget.preview;
    if (preview != null &&
        preview.category != null &&
        preview.keepiDocumentId != null) {
      _fileNameCtrl.text = preview.name;
      _categoryCtrl.text = preview.category ?? '';
      _descriptionCtrl.text = preview.description ?? '';
      _documentNumberCtrl.text = preview.documentNumber ?? '';
      _organizationCtrl.text = preview.organization ?? '';
      _expiryDate = _parseExpiryDateOnly(preview.expiryDate);
    }

    try {
      final api = context.read<ApiClient>();
      final dto =
          await DriveStructureService(api).fetchDocumentMetadata(widget.documentId);
      if (!mounted) return;
      setState(() {
        _applyDto(dto);
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (preview != null && _fileNameCtrl.text.isNotEmpty) {
        setState(() {
          _loading = false;
          _error = null;
        });
        return;
      }
      setState(() {
        _loading = false;
        _error = e is DioException
            ? (e.response?.data is Map &&
                    (e.response!.data as Map)['detail'] != null
                ? (e.response!.data as Map)['detail'].toString()
                : e.message ?? e.toString())
            : e.toString();
      });
    }
  }

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 30)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: KeepiColors.orange),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _expiryDate = picked);
    }
  }

  Future<void> _save() async {
    final category = _categoryCtrl.text.trim();
    final fileName = _fileNameCtrl.text.trim();
    if (category.isEmpty || fileName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nombre y categoría son obligatorios.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final api = context.read<ApiClient>();
      await DriveStructureService(api).updateDocumentMetadata(
        widget.documentId,
        DocumentMetadataUpdate(
          fileName: fileName,
          category: category,
          description: _descriptionCtrl.text.trim(),
          expiryDate: _expiryIsoForApi(),
          documentNumber: _documentNumberCtrl.text.trim(),
          organization: _organizationCtrl.text.trim(),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo guardar: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: KeepiColors.slateLight.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: KeepiColors.orangeSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      color: KeepiColors.orange,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Editar metadatos',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: KeepiColors.slate,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded, color: KeepiColors.slateLight),
                  ),
                ],
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: KeepiColors.orange),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(22),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_isReplaced || _isReplacement)
                        DocumentReplacementBanner(
                          file: DriveFile(
                            id: widget.documentId,
                            name: _fileNameCtrl.text,
                            isReplaced: _isReplaced,
                            replacedByName: _replacedByName,
                            replacedByCategory: _replacedByCategory,
                            isReplacement: _isReplacement,
                            replacesDocumentName: _replacesDocumentName,
                            replacesDocumentCategory: _replacesDocumentCategory,
                          ),
                        ),
                      if (_isReplaced || _isReplacement) const SizedBox(height: 14),
                      _field(
                        _storageFieldLabel,
                        _fileNameCtrl,
                        hint: 'Nombre del archivo en Drive o Keepi Cloud',
                      ),
                      const SizedBox(height: 12),
                      _field('Categoría', _categoryCtrl),
                      const SizedBox(height: 12),
                      _field('Descripción', _descriptionCtrl, maxLines: 2),
                      const SizedBox(height: 12),
                      _field('Número de documento', _documentNumberCtrl),
                      const SizedBox(height: 12),
                      _field('Organización', _organizationCtrl),
                      const SizedBox(height: 12),
                      const Text(
                        'Fecha de vencimiento',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: KeepiColors.slateLight,
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _pickExpiry,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: KeepiColors.cardBorder),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 18,
                                color: KeepiColors.orange,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _expiryDate == null
                                      ? 'Sin fecha'
                                      : formatExpiryDateForDisplay(
                                          _expiryIsoForApi(),
                                        ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: KeepiColors.slate,
                                  ),
                                ),
                              ),
                              if (_expiryDate != null)
                                IconButton(
                                  onPressed: () => setState(() => _expiryDate = null),
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    size: 18,
                                    color: KeepiColors.slateLight,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: KeepiColors.orange,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Guardar cambios',
                                style: TextStyle(fontWeight: FontWeight.w800),
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

  Widget _field(
    String label,
    TextEditingController ctrl, {
    int maxLines = 1,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: KeepiColors.slateLight,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }
}
