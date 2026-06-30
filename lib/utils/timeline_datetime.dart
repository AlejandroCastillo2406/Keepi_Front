import '../core/keepi_timezone.dart';
import '../models/timeline_event.dart';

/// Fechas del timeline: UTC → zona guardada, excepto citas (ya vienen correctas).
class TimelineDateTime {
  TimelineDateTime._();

  static const _monthsEsShort = <String>[
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];

  static bool isAppointment(TimelineEvent event) =>
      event.eventType == 'appointment';

  /// Orden cronológico (siempre el instante UTC original).
  static DateTime sortInstant(TimelineEvent event) {
    return DateTime.tryParse(event.occurredAt)?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  /// Fecha/hora para agrupar y mostrar en el rail del timeline.
  static DateTime displayDateTime(TimelineEvent event) {
    if (isAppointment(event)) {
      final fromLabel = _parseBackendDateLabel(event.date);
      if (fromLabel != null) return fromLabel;
      final parsed = DateTime.tryParse(event.occurredAt);
      if (parsed == null) return DateTime.now();
      return parsed.isUtc ? parsed.asScheduleLocal : parsed;
    }
    return KeepiTimezone.parseUser(event.occurredAt) ?? DateTime.now();
  }

  /// Normaliza date/time de eventos que vienen en UTC desde el API.
  static TimelineEvent normalizeFromApi(TimelineEvent event) {
    if (isAppointment(event)) return event;
    final local = KeepiTimezone.parseUser(event.occurredAt);
    if (local == null) return event;
    return TimelineEvent(
      id: event.id,
      date: formatTimelineDate(local),
      time: formatTimelineTime(local),
      title: event.title,
      actor: event.actor,
      eventType: event.eventType,
      subtitle: event.subtitle,
      description: event.description,
      occurredAt: event.occurredAt,
      visualState: event.visualState,
      actionPatientId: event.actionPatientId,
      priorDocumentsCount: event.priorDocumentsCount,
      hasDoctorNote: event.hasDoctorNote,
      doctorNotePreview: event.doctorNotePreview,
    );
  }

  static String formatTimelineDate(DateTime local) {
    final month = _monthsEsShort[local.month - 1];
    return '${local.day} $month ${local.year}';
  }

  static String formatTimelineTime(DateTime local) {
    var hour = local.hour;
    final ampm = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    return '${hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')} $ampm';
  }

  static DateTime? _parseBackendDateLabel(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length < 3) return null;

    final day = int.tryParse(parts.first);
    if (day == null) return null;

    final monthKey = parts[1].toLowerCase();
    final month = _monthsEsShort.indexWhere(
      (m) => m.toLowerCase() == monthKey || m.toLowerCase().startsWith(monthKey),
    );
    if (month < 0) return null;

    final year = int.tryParse(parts[2]);
    if (year == null) return null;

    return DateTime(year, month + 1, day);
  }
}
