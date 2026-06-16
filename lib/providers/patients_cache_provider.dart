import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/consultation_context.dart';
import '../models/timeline_event.dart';
import '../services/doctor_service.dart';
import '../services/questionnaire_service.dart';
import '../services/api_client.dart';

class PatientProfileSnapshot {
  const PatientProfileSnapshot({
    required this.analysisRequests,
    required this.timeline,
    required this.questionnaireResponses,
    required this.loadedAt,
    this.clinicalContext,
  });

  final List<AnalysisRequestDto> analysisRequests;
  final List<TimelineEvent> timeline;
  final List<Map<String, dynamic>> questionnaireResponses;
  final ConsultationContext? clinicalContext;
  final DateTime loadedAt;

  factory PatientProfileSnapshot.fromBootstrap(PatientProfileBootstrapData data) {
    return PatientProfileSnapshot(
      analysisRequests: data.analysisRequests,
      timeline: data.timeline,
      questionnaireResponses: data.questionnaireResponses,
      clinicalContext: data.context,
      loadedAt: DateTime.now(),
    );
  }
}

/// Caché en memoria del listado de pacientes y perfiles individuales.
class PatientsCacheProvider extends ChangeNotifier {
  List<PatientListItem>? _patients;
  final Map<String, PatientProfileSnapshot> _profiles = {};

  List<PatientListItem>? get patientsList => _patients;

  PatientListItem? peekPatient(String patientId) {
    final list = _patients;
    if (list == null) return null;
    for (final p in list) {
      if (p.id == patientId) return p;
    }
    return null;
  }

  PatientProfileSnapshot? peekProfile(String patientId) =>
      _profiles[patientId];

  Future<List<PatientListItem>> fetchAndCachePatients(
    DoctorService svc, {
    bool force = false,
  }) async {
    if (!force && _patients != null) return _patients!;
    final list = await svc.fetchMyPatients();
    _patients = list;
    notifyListeners();
    return list;
  }

  Future<PatientProfileSnapshot> fetchAndCacheProfile({
    required String patientId,
    required DoctorService doctorSvc,
    ApiClient? apiClient,
    bool force = false,
  }) async {
    if (!force) {
      final cached = _profiles[patientId];
      if (cached != null) return cached;
    }

    PatientProfileSnapshot snap;
    try {
      final bootstrap =
          await doctorSvc.fetchPatientProfileBootstrap(patientId);
      snap = PatientProfileSnapshot.fromBootstrap(bootstrap);
    } on DioException catch (e) {
      if (e.response?.statusCode != 404 || apiClient == null) rethrow;
      snap = await _fetchProfileLegacy(
        patientId: patientId,
        doctorSvc: doctorSvc,
        apiClient: apiClient,
      );
    }

    _profiles[patientId] = snap;
    notifyListeners();
    return snap;
  }

  Future<PatientProfileSnapshot> _fetchProfileLegacy({
    required String patientId,
    required DoctorService doctorSvc,
    required ApiClient apiClient,
  }) async {
    final questionnaireSvc = QuestionnaireService(apiClient);
    final analysisFuture = doctorSvc.fetchPatientAnalysisRequests(patientId);
    final timelineFuture = doctorSvc.fetchPatientTimeline(patientId);
    final responsesFuture = questionnaireSvc.fetchPatientResponses(patientId);
    final contextFuture = doctorSvc.fetchConsultationContext(patientId);

    final analysis = await analysisFuture;
    final timeline = await timelineFuture;
    final responsesRaw = await responsesFuture;
    ConsultationContext? ctx;
    try {
      ctx = await contextFuture;
    } catch (_) {}

    return PatientProfileSnapshot(
      analysisRequests: analysis,
      timeline: timeline,
      questionnaireResponses: responsesRaw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      clinicalContext: ctx,
      loadedAt: DateTime.now(),
    );
  }

  void invalidateList() {
    if (_patients == null) return;
    _patients = null;
    notifyListeners();
  }

  void invalidateProfile(String patientId) {
    if (_profiles.remove(patientId) != null) {
      notifyListeners();
    }
  }

  void invalidatePatient(String patientId) {
    invalidateProfile(patientId);
  }

  void clear() {
    final hadData = _patients != null || _profiles.isNotEmpty;
    _patients = null;
    _profiles.clear();
    if (hadData) notifyListeners();
  }
}
