import '../utils/timeline_datetime.dart';

/// Evento de línea de tiempo (paciente / médico), alineado con `TimelineEventResponse` del backend.
class TimelineEvent {
  final String id;
  final String date;
  final String time;
  final String title;
  final String actor;
  final String eventType;
  final String? subtitle;
  final String description;
  final String occurredAt;
  final String visualState;
  final String? actionPatientId;
  final int? priorDocumentsCount;
  final bool hasDoctorNote;
  final String? doctorNotePreview;

  TimelineEvent({
    required this.id,
    required this.date,
    required this.time,
    required this.title,
    required this.actor,
    required this.eventType,
    this.subtitle,
    required this.description,
    required this.occurredAt,
    required this.visualState,
    this.actionPatientId,
    this.priorDocumentsCount,
    this.hasDoctorNote = false,
    this.doctorNotePreview,
  });

  bool get isPriorDocuments => eventType == 'prior_documents';

  bool get isClinicalIntake => eventType == 'clinical_intake';

  bool get isPendingStep => visualState == 'current';

  /// UUID de invitación en eventos `intake_{uuid}` o `intake_req_{uuid}`.
  String? get clinicalIntakeInvitationId {
    for (final prefix in ['intake_req_', 'intake_']) {
      if (id.startsWith(prefix)) {
        final raw = id.substring(prefix.length);
        if (raw.isNotEmpty) return raw;
      }
    }
    return null;
  }

  /// UUID de invitación en eventos `priordocs_req_{uuid}` o `priordocs_sent_{uuid}`.
  String? get priorDocsInvitationId {
    for (final prefix in ['priordocs_req_', 'priordocs_sent_']) {
      if (id.startsWith(prefix)) {
        final raw = id.substring(prefix.length);
        if (raw.isNotEmpty) return raw;
      }
    }
    return null;
  }

  factory TimelineEvent.fromJson(Map<String, dynamic> json) {
    final event = TimelineEvent(
      id: json['id']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      actor: json['actor']?.toString() ?? '',
      eventType: json['event_type']?.toString() ?? '',
      subtitle: json['subtitle']?.toString(),
      description: json['description']?.toString() ?? '',
      occurredAt: json['occurred_at']?.toString() ?? '',
      visualState: json['visual_state']?.toString() ?? 'completed',
      actionPatientId: json['action_patient_id'] as String?,
      priorDocumentsCount: (json['prior_documents_count'] as num?)?.toInt(),
      hasDoctorNote: json['has_doctor_note'] == true,
      doctorNotePreview: json['doctor_note_preview']?.toString(),
    );
    return TimelineDateTime.normalizeFromApi(event);
  }

  String? get s3Url => null;
}

/// Orden estándar: del evento más reciente al más antiguo.
List<TimelineEvent> sortTimelineNewestFirst(Iterable<TimelineEvent> events) {
  final list = List<TimelineEvent>.from(events);
  list.sort((a, b) {
    return TimelineDateTime.sortInstant(b).compareTo(TimelineDateTime.sortInstant(a));
  });
  return list;
}
