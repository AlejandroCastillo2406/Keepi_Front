import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/expiry_date_format.dart';
import '../core/web_layout.dart';
import '../services/api_client.dart';
import '../services/drive_structure_service.dart';
import 'document_replacement_banner.dart';

/// Abre el editor de metadatos; devuelve `true` si guardó cambios.
Future<bool> openDocumentMetadataEditor(
  BuildContext context, {
  required String documentId,
  DriveFile? preview,
}) async {
  final asWebDialog = isWebWide(context);
  if (asWebDialog) {
    final saved = await showDialog<bool>(
      context: context,
      barrierColor: KeepiColors.slate.withValues(alpha: 0.45),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: DocumentMetadataEditSheet(
          documentId: documentId,
          preview: preview,
          asWebDialog: true,
        ),
      ),
    );
    return saved == true;
  }

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DocumentMetadataEditSheet(
      documentId: documentId,
      preview: preview,
      asWebDialog: false,
    ),
  );
  return saved == true;
}

class DocumentMetadataEditSheet extends StatefulWidget {
  const DocumentMetadataEditSheet({
    super.key,
    required this.documentId,
    this.preview,
    this.asWebDialog = false,
  });

  final String documentId;
  final DriveFile? preview;
  final bool asWebDialog;

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

  static final _inputDecoration = InputDecoration(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: KeepiColors.cardBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: KeepiColors.cardBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: KeepiColors.orange, width: 1.6),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
  );

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
      final dto = await DriveStructureService(api)
          .fetchDocumentMetadata(widget.documentId);
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

  void _close() => Navigator.of(context).pop(false);

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final shell = _buildShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.asWebDialog) ...[
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: KeepiColors.slateLight.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
          _buildHeader(),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: CircularProgressIndicator(color: KeepiColors.orange),
              ),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            Flexible(
              child: SingleChildScrollView(
                padding: widget.asWebDialog
                    ? const EdgeInsets.fromLTRB(20, 20, 20, 8)
                    : const EdgeInsets.fromLTRB(22, 0, 22, 22),
                child: widget.asWebDialog
                    ? Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: KeepiColors.cardBorder),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: _buildForm(),
                      )
                    : _buildForm(),
              ),
            ),
          if (!_loading && _error == null) _buildFooter(),
        ],
      ),
    );

    if (widget.asWebDialog) {
      return shell;
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: shell,
    );
  }


  Widget _buildShell({required Widget child}) {
    if (widget.asWebDialog) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 580),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 60,
              offset: const Offset(0, 24),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
    }

    return Container(
      constraints: BoxConstraints(
        maxWidth: double.infinity,
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A46555F),
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _buildHeader() {
    if (widget.asWebDialog) {
      return Stack(
        children: [
          // Fondo degradado oscuro
          Container(
            height: 96,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2D3F4C), Color(0xFF46555F)],
              ),
            ),
          ),
          // Círculo decorativo
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            right: 50,
            bottom: -15,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: KeepiColors.orange.withValues(alpha: 0.15),
              ),
            ),
          ),
          // Contenido
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 16, 0),
            child: SizedBox(
              height: 96,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: KeepiColors.orange.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: KeepiColors.orange.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.edit_document,
                      color: Color(0xFFFFBF7A),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Editar metadatos',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.35,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Actualiza la información del documento.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _close,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Mobile header
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: KeepiColors.orangeSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.edit_note_rounded,
              color: KeepiColors.orange,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Editar metadatos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: KeepiColors.slate,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Actualiza la información del documento.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: KeepiColors.slateLight,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _close,
            style: IconButton.styleFrom(
              backgroundColor: KeepiColors.slateSoft,
              foregroundColor: KeepiColors.slateLight,
            ),
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isReplaced || _isReplacement) ...[
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
          const SizedBox(height: 16),
        ],
        if (widget.asWebDialog) ...[
          _field(_storageFieldLabel, _fileNameCtrl,
              hint: 'Nombre del archivo en la nube'),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _field('Categoría', _categoryCtrl,
                    hint: 'Ej. Recetas médicas'),
              ),
              const SizedBox(width: 14),
              Expanded(child: _expiryField()),
            ],
          ),
          const SizedBox(height: 14),
          _field('Descripción', _descriptionCtrl, maxLines: 2),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _field('Número de documento', _documentNumberCtrl),
              ),
              const SizedBox(width: 14),
              Expanded(child: _field('Organización', _organizationCtrl)),
            ],
          ),
        ] else ...[
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
          _expiryField(),
        ],
      ],
    );
  }

  Widget _buildFooter() {
    final padding = EdgeInsets.fromLTRB(
      22,
      0,
      22,
      22,
    );

    if (widget.asWebDialog) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : _close,
                style: OutlinedButton.styleFrom(
                  foregroundColor: KeepiColors.slateLight,
                  side: const BorderSide(color: KeepiColors.cardBorder),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: KeepiColors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shadowColor: KeepiColors.orange.withValues(alpha: 0.35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(
                  _saving ? 'Guardando…' : 'Guardar cambios',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: padding,
      child: FilledButton(
        onPressed: _saving ? null : _save,
        style: FilledButton.styleFrom(
          backgroundColor: KeepiColors.orange,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
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
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: KeepiColors.slateLight,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          style: const TextStyle(
            color: KeepiColors.slate,
            fontWeight: FontWeight.w600,
          ),
          decoration: _inputDecoration.copyWith(hintText: hint),
        ),
      ],
    );
  }

  Widget _expiryField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'FECHA DE VENCIMIENTO',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: KeepiColors.slateLight,
          ),
        ),
        const SizedBox(height: 6),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _pickExpiry,
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: KeepiColors.cardBorder),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: KeepiColors.orangeSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: KeepiColors.orange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _expiryDate == null
                          ? 'Sin fecha'
                          : formatExpiryDateForDisplay(_expiryIsoForApi()),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _expiryDate == null
                            ? KeepiColors.slateLight
                            : KeepiColors.slate,
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
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
