import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/expiry_date_format.dart';
import '../services/api_client.dart';
import '../services/document_upload_service.dart';

class AnalyzeSaveFormData {
  AnalyzeSaveFormData({
    required this.category,
    required this.fileName,
    this.expiryDate,
  });

  final String category;
  final String fileName;
  final String? expiryDate;
}

/// Reemplaza un documento vencido o por vencer (marca el anterior como reemplazado).
Future<void> runDocumentReplaceFlow(
  BuildContext context, {
  required String replacesDocumentId,
  VoidCallback? onSaved,
  String saveButtonLabel = 'Guardar en Drive',
}) {
  return runDocumentAnalyzeFlow(
    context,
    replacesDocumentId: replacesDocumentId,
    onSaved: onSaved,
    saveButtonLabel: 'Reemplazar documento',
    dialogTitle: 'Reemplazar documento',
    successMessage:
        'Documento reemplazado. El anterior quedó marcado como reemplazado.',
  );
}

/// Selecciona archivo, analiza con IA y guarda en el almacenamiento activo.
Future<void> runDocumentAnalyzeFlow(
  BuildContext context, {
  VoidCallback? onSaved,
  String saveButtonLabel = 'Guardar',
  String? replacesDocumentId,
  String dialogTitle = 'Resumen del análisis',
  String successMessage = 'Documento guardado correctamente',
}) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.any,
    withData: false,
    allowMultiple: false,
  );
  if (result == null || result.files.isEmpty) return;

  final platformFile = result.files.single;
  final path = platformFile.path;
  if (path == null || path.isEmpty) {
    if (context.mounted) {
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
    if (context.mounted) {
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

  if (!context.mounted) return;
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
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: KeepiColors.orange,
                ),
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
    if (!context.mounted) return;
    Navigator.of(context).pop();
    final err = e.toString();
    final isTimeout = err.toLowerCase().contains('timeout');
    final msg = isTimeout
        ? 'El análisis tardó demasiado. Revisa tu conexión o intenta con un archivo más pequeño.'
        : err
            .replaceFirst('DioException [bad response]: ', '')
            .replaceFirst('DioException [connection timeout]: ', '')
            .replaceFirst('DioException [send timeout]: ', '')
            .replaceFirst('DioException [receive timeout]: ', '');
    scaffold.showSnackBar(
      SnackBar(
        content: Text(isTimeout ? msg : 'Error al analizar: $msg'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
    return;
  }

  if (!context.mounted) return;
  Navigator.of(context).pop();

  if (analyzeResult.subscriptionRequired) {
    scaffold.showSnackBar(
      SnackBar(
        content: Text(
          analyzeResult.message ??
              'Se requiere una suscripción activa para analizar documentos.',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
    return;
  }

  final saved = await showDialog<AnalyzeSaveFormData>(
    context: context,
    builder: (ctx) => _AnalyzeResultModal(
      result: analyzeResult,
      originalFileName: platformFile.name,
      saveButtonLabel: saveButtonLabel,
      dialogTitle: dialogTitle,
    ),
  );
  if (saved == null || !context.mounted) return;

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
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: KeepiColors.orange,
                ),
              ),
              SizedBox(height: 16),
              Text('Guardando archivo…'),
            ],
          ),
        ),
      ),
    ),
  );

  try {
    await uploadService.saveAnalyzed(
      file: file,
      category: saved.category,
      fileName: saved.fileName,
      expiryDate: saved.expiryDate,
      replacesDocumentId: replacesDocumentId,
    );
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(context).pop();
    scaffold.showSnackBar(
      SnackBar(
        content: Text(
          'Error al guardar: ${e.toString().replaceFirst('DioException [bad response]: ', '')}',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  if (!context.mounted) return;
  Navigator.of(context).pop();
  scaffold.showSnackBar(
    SnackBar(
      content: Text(successMessage),
      behavior: SnackBarBehavior.floating,
      backgroundColor: KeepiColors.green,
    ),
  );
  onSaved?.call();
}

class _AnalyzeResultModal extends StatefulWidget {
  const _AnalyzeResultModal({
    required this.result,
    required this.originalFileName,
    required this.saveButtonLabel,
    required this.dialogTitle,
  });

  final AnalyzeResult result;
  final String originalFileName;
  final String saveButtonLabel;
  final String dialogTitle;

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
              color: KeepiColors.slate.withValues(alpha: 0.12),
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
                  child: const Icon(
                    Icons.analytics_outlined,
                    color: KeepiColors.orange,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    widget.dialogTitle,
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
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
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
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
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
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: KeepiColors.slateLight),
                  ),
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
                    Navigator.of(context).pop(
                      AnalyzeSaveFormData(
                        category: category,
                        fileName: fileName,
                        expiryDate: result.expiryDate,
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: KeepiColors.orange,
                  ),
                  child: Text(widget.saveButtonLabel),
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
            color: KeepiColors.slateSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: KeepiColors.cardBorder),
          ),
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: KeepiColors.slate,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
