import 'package:flutter/foundation.dart';

import '../models/consultation_context.dart';
import '../models/timeline_event.dart';
import '../services/doctor_service.dart';

/// Datos listos para renderizar la pantalla de consulta.
class ConsultationBootstrapData {
  const ConsultationBootstrapData({
    required this.event,
    required this.context,
    required this.timeline,
    required this.analysisRequests,
    required this.doctorNoteContent,
    required this.loadedAt,
  });

  final TimelineEvent event;
  final ConsultationContext context;
  final List<TimelineEvent> timeline;
  final List<AnalysisRequestDto> analysisRequests;
  final String doctorNoteContent;
  final DateTime loadedAt;

  factory ConsultationBootstrapData.fromJson(Map<String, dynamic> json) {
    final timelineRaw = json['timeline'] as List<dynamic>? ?? [];
    final analysisRaw = json['analysis_requests'] as List<dynamic>? ?? [];
    return ConsultationBootstrapData(
      event: TimelineEvent.fromJson(
        Map<String, dynamic>.from(json['appointment_event'] as Map),
      ),
      context: ConsultationContext.fromJson(
        Map<String, dynamic>.from(json['context'] as Map? ?? const {}),
      ),
      timeline: sortTimelineNewestFirst(
        timelineRaw.map(
          (e) => TimelineEvent.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      ),
      analysisRequests: analysisRaw
          .map((e) =>
              AnalysisRequestDto.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      doctorNoteContent: (json['doctor_note_content'] as String?) ?? '',
      loadedAt: DateTime.now(),
    );
  }
}

/// Caché en memoria por paciente + cita (solo sesión actual).
class ConsultationBootstrapProvider extends ChangeNotifier {
  final Map<String, ConsultationBootstrapData> _cache = {};

  static String cacheKey(String patientId, String appointmentId) =>
      '$patientId::$appointmentId';

  ConsultationBootstrapData? peek(String patientId, String appointmentId) {
    return _cache[cacheKey(patientId, appointmentId)];
  }

  void put(String patientId, String appointmentId, ConsultationBootstrapData data) {
    _cache[cacheKey(patientId, appointmentId)] = data;
    notifyListeners();
  }

  void invalidate(String patientId, String appointmentId) {
    if (_cache.remove(cacheKey(patientId, appointmentId)) != null) {
      notifyListeners();
    }
  }

  void invalidatePatient(String patientId) {
    final prefix = '$patientId::';
    final keys = _cache.keys.where((k) => k.startsWith(prefix)).toList();
    if (keys.isEmpty) return;
    for (final k in keys) {
      _cache.remove(k);
    }
    notifyListeners();
  }

  void clear() {
    if (_cache.isEmpty) return;
    _cache.clear();
    notifyListeners();
  }
}
