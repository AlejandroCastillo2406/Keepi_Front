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
  });

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
    );
  }
}
