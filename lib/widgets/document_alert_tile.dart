import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/expiry_date_format.dart';
import '../services/drive_structure_service.dart';

/// Tarjeta de alerta de vencimiento (vencido vs por vencer).
class DocumentAlertTile extends StatelessWidget {
  const DocumentAlertTile({
    super.key,
    required this.item,
    this.onTap,
    this.onEdit,
    this.onReplace,
    this.compact = false,
  });

  final DocumentAlertItem item;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onReplace;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final expired = item.isExpired;
    final accent = expired ? const Color(0xFFD32F2F) : KeepiColors.orange;
    final bg = expired
        ? const Color(0xFFFFEBEE)
        : KeepiColors.orangeSoft;
    final icon = expired
        ? Icons.event_busy_rounded
        : Icons.schedule_rounded;
    final statusLabel = expired ? 'Vencido' : 'Por vencer';
    final displayName = (item.fileName != null && item.fileName!.isNotEmpty)
        ? item.fileName!
        : item.name;
    final dateStr = formatExpiryDateShort(item.expiryDate);

    final content = Row(
      children: [
        Container(
          width: compact ? 36 : 40,
          height: compact ? 36 : 40,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: accent, size: compact ? 18 : 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    statusLabel.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: KeepiColors.slate,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                expired ? 'Venció: $dateStr' : 'Vence: $dateStr',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: KeepiColors.slateLight,
                ),
              ),
            ],
          ),
        ),
        if (onReplace != null && item.canReplace)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: TextButton(
              onPressed: onReplace,
              style: TextButton.styleFrom(
                foregroundColor: accent,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Reemplazar',
                style: TextStyle(
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
            ),
          ),
        if (onEdit != null)
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_rounded, size: 20, color: KeepiColors.orange),
            tooltip: 'Editar metadatos',
          ),
        if (onTap != null)
          const Icon(
            Icons.chevron_right_rounded,
            color: KeepiColors.slateLight,
          ),
      ],
    );

    if (compact) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: expired
                ? const Color(0xFFD32F2F).withValues(alpha: 0.35)
                : KeepiColors.orange.withValues(alpha: 0.35),
          ),
        ),
        child: content,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: content,
    );
  }
}
