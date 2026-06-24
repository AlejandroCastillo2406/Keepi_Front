import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/care_event_style.dart';
import '../models/timeline_event.dart';
import '../services/notifications_service.dart';

/// Modal web centrado para detalle de notificaciones (reemplaza bottom sheets).
class NotificationWebDialog extends StatelessWidget {
  const NotificationWebDialog({
    super.key,
    required this.title,
    required this.tag,
    required this.accent,
    required this.icon,
    required this.child,
    this.subtitle,
    this.footer,
    this.maxWidth = 560,
    this.maxHeightFactor = 0.88,
    this.canClose = true,
    this.onClose,
  });

  final String title;
  final String tag;
  final Color accent;
  final IconData icon;
  final String? subtitle;
  final Widget child;
  final Widget? footer;
  final double maxWidth;
  final double maxHeightFactor;
  final bool canClose;
  final VoidCallback? onClose;

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required String tag,
    required Color accent,
    required IconData icon,
    required Widget child,
    String? subtitle,
    Widget? footer,
    double maxWidth = 560,
    double maxHeightFactor = 0.88,
    bool canClose = true,
    VoidCallback? onClose,
  }) {
    return showDialog<T>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      barrierDismissible: canClose,
      builder: (ctx) => NotificationWebDialog(
        title: title,
        tag: tag,
        accent: accent,
        icon: icon,
        subtitle: subtitle,
        footer: footer,
        maxWidth: maxWidth,
        maxHeightFactor: maxHeightFactor,
        canClose: canClose,
        onClose: onClose,
        child: child,
      ),
    );
  }

  static Future<T?> showForNotification<T>(
    BuildContext context, {
    required AppNotificationDto notification,
    required Widget child,
    Widget? footer,
    double maxWidth = 560,
    double maxHeightFactor = 0.88,
  }) {
    final theme = NotificationDialogTheme.fromNotification(notification);
    return show<T>(
      context,
      title: notification.title.isNotEmpty ? notification.title : theme.titleFallback,
      tag: theme.tag,
      accent: theme.accent,
      icon: theme.icon,
      subtitle: notification.message.trim().isNotEmpty ? notification.message.trim() : null,
      footer: footer,
      maxWidth: maxWidth,
      maxHeightFactor: maxHeightFactor,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * maxHeightFactor;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxH),
        child: Material(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: KeepiColors.cardBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _NotificationHeroHeader(
                title: title,
                tag: tag,
                accent: accent,
                icon: icon,
                subtitle: subtitle,
                canClose: canClose,
                onClose: onClose ?? () => Navigator.of(context).pop(),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: child,
                ),
              ),
              if (footer != null)
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    border: Border(
                      top: BorderSide(
                        color: KeepiColors.slate.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  child: footer!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class NotificationDialogTheme {
  const NotificationDialogTheme({
    required this.accent,
    required this.icon,
    required this.tag,
    required this.titleFallback,
  });

  final Color accent;
  final IconData icon;
  final String tag;
  final String titleFallback;

  factory NotificationDialogTheme.fromNotification(AppNotificationDto n) {
    final eventType = NotificationEventStyle.eventTypeFor(n);
    return NotificationDialogTheme(
      accent: CareEventStyle.colorFor(eventType),
      icon: CareEventStyle.iconFor(eventType),
      tag: CareEventStyle.labelFor(eventType),
      titleFallback: _fallbackTitle(eventType),
    );
  }

  factory NotificationDialogTheme.appointmentPending() {
    return const NotificationDialogTheme(
      accent: KeepiColors.skyBlue,
      icon: Icons.event_available_outlined,
      tag: 'CITA WEB',
      titleFallback: 'Solicitud de cita',
    );
  }

  factory NotificationDialogTheme.questionnaire() {
    return NotificationDialogTheme(
      accent: CareEventStyle.colorFor('questionnaire'),
      icon: CareEventStyle.iconFor('questionnaire'),
      tag: 'CUESTIONARIO',
      titleFallback: 'Cuestionario completado',
    );
  }

  factory NotificationDialogTheme.documentReplaced() {
    return NotificationDialogTheme(
      accent: CareEventStyle.colorFor('document_replaced'),
      icon: CareEventStyle.iconFor('document_replaced'),
      tag: 'DOCUMENTO',
      titleFallback: 'Documento actualizado',
    );
  }

  factory NotificationDialogTheme.timelineNote() {
    return const NotificationDialogTheme(
      accent: KeepiColors.orange,
      icon: Icons.sticky_note_2_outlined,
      tag: 'NOTA CLÍNICA',
      titleFallback: 'Nota del médico',
    );
  }

  factory NotificationDialogTheme.patientExport() {
    return const NotificationDialogTheme(
      accent: KeepiColors.orange,
      icon: Icons.folder_zip_rounded,
      tag: 'EXPORTAR',
      titleFallback: 'Expedientes clínicos',
    );
  }

  static String _fallbackTitle(String eventType) {
    switch (eventType) {
      case 'appointment':
        return 'Cita médica';
      case 'prescription':
        return 'Receta médica';
      case 'analysis_request':
        return 'Análisis clínico';
      case 'questionnaire':
        return 'Cuestionario';
      case 'document_replaced':
        return 'Documento actualizado';
      default:
        return 'Notificación';
    }
  }
}

/// Estilo visual del modal de timeline según tipo de evento.
class TimelineDialogTheme {
  const TimelineDialogTheme({
    required this.accent,
    required this.icon,
    required this.tag,
  });

  final Color accent;
  final IconData icon;
  final String tag;

  factory TimelineDialogTheme.fromEvent(TimelineEvent event) {
    final type = _normalizeEventType(event.eventType);
    return TimelineDialogTheme(
      accent: CareEventStyle.colorFor(type),
      icon: CareEventStyle.iconFor(type),
      tag: CareEventStyle.labelFor(type),
    );
  }

  static String _normalizeEventType(String raw) {
    final t = raw.toLowerCase();
    if (t == 'analysis_upload') return 'analysis_upload';
    if (t.contains('analysis')) return 'analysis_request';
    if (t == 'clinical_intake') return 'clinical_intake';
    if (t == 'questionnaire') return 'questionnaire';
    if (t == 'prior_documents') return 'prior_documents';
    if (t == 'prescription') return 'prescription';
    if (t == 'appointment') return 'appointment';
    if (t == 'registration') return 'registration';
    return t;
  }
}

class _NotificationHeroHeader extends StatelessWidget {
  const _NotificationHeroHeader({
    required this.title,
    required this.tag,
    required this.accent,
    required this.icon,
    this.subtitle,
    required this.onClose,
    this.canClose = true,
  });

  final String title;
  final String tag;
  final Color accent;
  final IconData icon;
  final String? subtitle;
  final VoidCallback onClose;
  final bool canClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 16, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent,
            Color.lerp(accent, Colors.white, 0.22)!,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            top: -24,
            child: Icon(
              icon,
              size: 120,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.35,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: canClose ? onClose : null,
                icon: Icon(
                  Icons.close_rounded,
                  color: canClose ? Colors.white : Colors.white38,
                ),
                tooltip: 'Cerrar',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Fila de información dentro del modal de notificación.
class NotificationInfoTile extends StatelessWidget {
  const NotificationInfoTile({
    super.key,
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
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: KeepiColors.slateLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: KeepiColors.slate,
                    height: 1.35,
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

/// Botón de acción principal del modal de notificación.
class NotificationPrimaryButton extends StatelessWidget {
  const NotificationPrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.accent,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.3),
        ),
      ),
    );
  }
}
