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

  /// UUID de invitación cuando `id` es `intake_{uuid}`.
  String? get clinicalIntakeInvitationId {
    if (!id.startsWith('intake_')) return null;
    final raw = id.substring('intake_'.length);
    return raw.isEmpty ? null : raw;
  }

  factory TimelineEvent.fromJson(Map<String, dynamic> json) {
    return TimelineEvent(
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
  }

  String? get s3Url => null;
}

/// Orden estándar: del evento más reciente al más antiguo.
List<TimelineEvent> sortTimelineNewestFirst(Iterable<TimelineEvent> events) {
  final list = List<TimelineEvent>.from(events);
  list.sort((a, b) {
    final da = DateTime.tryParse(a.occurredAt);
    final db = DateTime.tryParse(b.occurredAt);
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return db.compareTo(da);
  });
  return list;
}
