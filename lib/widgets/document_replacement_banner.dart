import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../router/app_navigation.dart';
import '../services/api_client.dart';
import '../services/doctor_service.dart';
import '../services/drive_structure_service.dart';
import 'notification_web_dialog.dart';

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

  final theme = NotificationDialogTheme.documentReplaced();

  NotificationWebDialog.show(
    context,
    title: 'Documento reemplazado',
    tag: theme.tag,
    accent: theme.accent,
    icon: theme.icon,
    maxWidth: 520,
    subtitle:
        'Actualizaste un documento vencido o por vencer. El archivo anterior quedó marcado como reemplazado.',
    footer: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: () => _openKeepiDocument(
            context,
            documentId: oldDocumentId,
            title: beforeName,
          ),
          icon: const Icon(Icons.history_rounded, size: 20),
          label: const Text('Ver documento anterior'),
        ),
        const SizedBox(height: 10),
        NotificationPrimaryButton(
          label: 'VER DOCUMENTO NUEVO',
          icon: Icons.description_rounded,
          accent: theme.accent,
          onPressed: () => _openKeepiDocument(
            context,
            documentId: newDocumentId,
            title: afterName,
          ),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DocCompareCard(
          label: 'ANTES',
          name: beforeName,
          category: beforeCat,
          muted: true,
        ),
        const SizedBox(height: 10),
        const Center(
          child: Icon(Icons.arrow_downward_rounded, color: KeepiColors.slateLight),
        ),
        const SizedBox(height: 10),
        _DocCompareCard(
          label: 'DESPUÉS',
          name: afterName,
          category: afterCat,
          muted: false,
        ),
      ],
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
  await AppNavigation.pushDocumentViewer(
    context,
    url: url,
    title: title,
    headers: headers,
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

  NotificationWebDialog.show(
    context,
    title: title,
    tag: isReplaced ? 'ARCHIVO ANTERIOR' : 'ARCHIVO VIGENTE',
    accent: accent,
    icon: icon,
    maxWidth: 480,
    subtitle: file.name,
    footer: NotificationPrimaryButton(
      label: 'ENTENDIDO',
      icon: Icons.check_rounded,
      accent: accent,
      onPressed: () => Navigator.of(context).pop(),
    ),
    child: NotificationInfoTile(
      icon: Icons.info_outline_rounded,
      label: 'Detalle',
      value: body,
      accent: accent,
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
