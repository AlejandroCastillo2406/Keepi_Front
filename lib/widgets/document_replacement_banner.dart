import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../screens/doctor/analysis_document_viewer_screen.dart';
import '../services/api_client.dart';
import '../services/doctor_service.dart';
import '../services/drive_structure_service.dart';

/// Modal al abrir notificación de reemplazo: explicación + ver antes/después.
void showDocumentReplacementComparisonSheet(
  BuildContext context, {
  required String oldDocumentId,
  required String newDocumentId,
  String? oldName,
  String? newName,
  String? oldCategory,
  String? newCategory,
}) {
  final beforeName = _label(oldName, 'Documento anterior');
  final afterName = _label(newName, 'Documento nuevo');
  final beforeCat = oldCategory?.trim();
  final afterCat = newCategory?.trim();

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Material(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: KeepiColors.orangeSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.swap_horiz_rounded,
                        color: KeepiColors.orange,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'Documento reemplazado',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: KeepiColors.slate,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: KeepiColors.slateLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Actualizaste un documento vencido o por vencer. '
                  'El archivo anterior quedó marcado como reemplazado.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: KeepiColors.slate,
                  ),
                ),
                const SizedBox(height: 16),
                _DocCompareCard(
                  label: 'ANTES',
                  name: beforeName,
                  category: beforeCat,
                  muted: true,
                ),
                const SizedBox(height: 10),
                const Icon(Icons.arrow_downward_rounded, color: KeepiColors.slateLight),
                const SizedBox(height: 10),
                _DocCompareCard(
                  label: 'DESPUÉS',
                  name: afterName,
                  category: afterCat,
                  muted: false,
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: () => _openKeepiDocument(
                    ctx,
                    documentId: oldDocumentId,
                    title: beforeName,
                  ),
                  icon: const Icon(Icons.history_rounded, size: 20),
                  label: const Text('Ver documento anterior'),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () => _openKeepiDocument(
                    ctx,
                    documentId: newDocumentId,
                    title: afterName,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: KeepiColors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.description_rounded, size: 20),
                  label: const Text('Ver documento nuevo'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openKeepiDocument(
  BuildContext context, {
  required String documentId,
  required String title,
}) async {
  final api = context.read<ApiClient>();
  final token = api.accessToken;
  final headers = <String, String>{
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    'Accept': '*/*',
  };
  final url = DoctorService(api).getMobileDocumentUrl(documentId);
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AnalysisDocumentViewerScreen(
        url: url,
        title: title,
        headers: headers,
      ),
    ),
  );
}

class _DocCompareCard extends StatelessWidget {
  const _DocCompareCard({
    required this.label,
    required this.name,
    required this.muted,
    this.category,
  });

  final String label;
  final String name;
  final String? category;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: muted ? const Color(0xFFF5F5F5) : KeepiColors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: muted
              ? const Color(0xFFB0BEC5)
              : KeepiColors.green.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: muted ? const Color(0xFF78909C) : KeepiColors.green,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: muted ? KeepiColors.slateLight : KeepiColors.slate,
              decoration: muted ? TextDecoration.lineThrough : null,
            ),
          ),
          if (category != null && category!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              category!,
              style: const TextStyle(
                fontSize: 12,
                color: KeepiColors.slateLight,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Muestra detalle del reemplazo (tap en el icono de la fila).
void showDocumentReplacementInfo(BuildContext context, DriveFile file) {
  if (!file.isReplaced && !file.isReplacement) return;

  final isReplaced = file.isReplaced;
  final title = isReplaced ? 'Documento reemplazado' : 'Documento vigente';
  final accent = isReplaced ? const Color(0xFF78909C) : KeepiColors.green;
  final icon = isReplaced ? Icons.history_rounded : Icons.swap_horiz_rounded;

  String body;
  if (isReplaced) {
    final name = _label(file.replacedByName, 'documento nuevo');
    final cat = file.replacedByCategory?.trim();
    body = cat != null && cat.isNotEmpty
        ? 'Este archivo ya no está vigente.\n\nReemplazado por:\n$name\n\nCategoría: $cat'
        : 'Este archivo ya no está vigente.\n\nReemplazado por:\n$name';
  } else {
    final name = _label(file.replacesDocumentName, 'documento anterior');
    final cat = file.replacesDocumentCategory?.trim();
    body = cat != null && cat.isNotEmpty
        ? 'Este archivo sustituye a uno vencido o por vencer.\n\nReemplaza a:\n$name\n\nCategoría: $cat'
        : 'Este archivo sustituye a uno vencido o por vencer.\n\nReemplaza a:\n$name';
  }

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Material(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accent, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: KeepiColors.slate,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close_rounded, color: KeepiColors.slateLight),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                file.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: KeepiColors.slateLight,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: KeepiColors.slate,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: KeepiColors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Entendido'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String _label(String? value, String fallback) {
  final v = value?.trim();
  return (v != null && v.isNotEmpty) ? v : fallback;
}

/// Icono compacto: al pulsar muestra el detalle del reemplazo.
class DocumentReplacementInfoIcon extends StatelessWidget {
  const DocumentReplacementInfoIcon({super.key, required this.file});

  final DriveFile file;

  @override
  Widget build(BuildContext context) {
    if (!file.isReplaced && !file.isReplacement) {
      return const SizedBox.shrink();
    }

    final isReplaced = file.isReplaced;
    final color = isReplaced ? const Color(0xFF78909C) : KeepiColors.green;
    final tooltip = isReplaced
        ? 'Documento reemplazado — pulsa para ver detalle'
        : 'Reemplaza un documento anterior — pulsa para ver detalle';

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => showDocumentReplacementInfo(context, file),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              isReplaced ? Icons.history_rounded : Icons.swap_horiz_rounded,
              size: 20,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

/// Detalle completo (p. ej. editor de metadatos).
class DocumentReplacementBanner extends StatelessWidget {
  const DocumentReplacementBanner({super.key, required this.file});

  final DriveFile file;

  @override
  Widget build(BuildContext context) {
    if (!file.isReplaced && !file.isReplacement) {
      return const SizedBox.shrink();
    }
    return InkWell(
      onTap: () => showDocumentReplacementInfo(context, file),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: KeepiColors.slateSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: KeepiColors.cardBorder),
        ),
        child: Row(
          children: [
            DocumentReplacementInfoIcon(file: file),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                file.isReplaced
                    ? 'Pulsa para ver por qué fue reemplazado'
                    : 'Pulsa para ver qué documento reemplaza',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: KeepiColors.slateLight,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: KeepiColors.slateLight),
          ],
        ),
      ),
    );
  }
}
