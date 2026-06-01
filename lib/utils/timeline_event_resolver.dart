import '../models/timeline_event.dart';
import '../services/appointment_service.dart';
import '../services/doctor_service.dart';
import '../services/search_service.dart';

/// Resuelve o construye un [TimelineEvent] para abrir el detalle unificado.
class TimelineEventResolver {
  static const _monthsEs = [
    'ENE',
    'FEB',
    'MAR',
    'ABR',
    'MAY',
    'JUN',
    'JUL',
    'AGO',
    'SEP',
    'OCT',
    'NOV',
    'DIC',
  ];

  static String _fmtDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')} '
        '${_monthsEs[local.month - 1]} ${local.year}';
  }

  static String _fmtTime(DateTime dt) {
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  static TimelineEvent fromAppointment(AppointmentDto a) {
    final when = (a.appointmentDate ?? a.createdAt).toLocal();
    final reason = a.reason.trim().isNotEmpty ? a.reason.trim() : 'Consulta';
    return TimelineEvent(
      id: 'appt_${a.id}',
      date: _fmtDate(when),
      time: _fmtTime(when),
      title: 'Cita médica',
      actor: 'Doctor',
      eventType: 'appointment',
      subtitle: reason,
      description: reason,
      occurredAt: when.toUtc().toIso8601String(),
      visualState: 'completed',
    );
  }

  static TimelineEvent fromSearchItem(GlobalSearchItem item) {
    final when = item.date.toLocal();
    final type = item.type.toLowerCase();
    String eventType;
    String title;
    String id;

    switch (type) {
      case 'analysis':
        eventType = 'analysis_request';
        title = 'Análisis solicitado por tu médico';
        id = 'anreq_${item.id}';
        break;
      case 'appointment':
        eventType = 'appointment';
        title = 'Cita médica';
        id = 'appt_${item.id}';
        break;
      default:
        eventType = type;
        title = item.title;
        id = item.id;
    }

    final desc = item.subtitle?.trim().isNotEmpty == true
        ? item.subtitle!.trim()
        : item.title;

    return TimelineEvent(
      id: id,
      date: _fmtDate(when),
      time: _fmtTime(when),
      title: title,
      actor: 'Doctor',
      eventType: eventType,
      subtitle: desc,
      description: desc,
      occurredAt: when.toUtc().toIso8601String(),
      visualState: 'completed',
    );
  }

  static Future<TimelineEvent?> findOnTimeline({
    required DoctorService doctorService,
    required String patientId,
    required String eventId,
  }) async {
    try {
      final events = await doctorService.fetchPatientTimeline(patientId);
      for (final e in events) {
        if (e.id == eventId) return e;
      }
      final bare = eventId.replaceAll(RegExp(r'^(appt_|anreq_|anupl_|pres_)'), '');
      for (final e in events) {
        final eBare =
            e.id.replaceAll(RegExp(r'^(appt_|anreq_|anupl_|pres_)'), '');
        if (eBare == bare && bare.isNotEmpty) return e;
      }
    } catch (_) {}
    return null;
  }

  static Future<TimelineEvent> resolveForAppointment({
    required DoctorService doctorService,
    required AppointmentDto appointment,
  }) async {
    final patientId = appointment.patientId;
    final eventId = 'appt_${appointment.id}';
    final fromTimeline = await findOnTimeline(
      doctorService: doctorService,
      patientId: patientId,
      eventId: eventId,
    );
    return fromTimeline ?? fromAppointment(appointment);
  }

  static Future<TimelineEvent?> resolveForSearchItem({
    required DoctorService doctorService,
    required GlobalSearchItem item,
  }) async {
    final patientId = item.patientId?.trim();
    if (patientId == null || patientId.isEmpty) {
      return null;
    }
    final fallback = fromSearchItem(item);
    final fromTimeline = await findOnTimeline(
      doctorService: doctorService,
      patientId: patientId,
      eventId: fallback.id,
    );
    return fromTimeline ?? fallback;
  }
}
