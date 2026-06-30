import 'package:dio/dio.dart';
import '../core/keepi_timezone.dart';
import '../core/api_endpoints.dart';
import '../models/consultation_context.dart';
import '../models/prior_document_item.dart';
import '../models/clinical_intake_detail.dart';
import '../models/timeline_event.dart';
import '../utils/attendance_kpi.dart';
import '../utils/date_labels.dart';
import '../providers/consultation_bootstrap_provider.dart';
import 'api_client.dart';
import 'appointment_service.dart';
import 'scheduling_service.dart';

/// Llamadas a `/api/v1/doctors/patients` y `/api/v1/analysis-requests`.
class DoctorService {
  DoctorService(this._api);
  final ApiClient _api;


  Future<CreatePatientResult> createPatient({
    required String email,
    required String name,
  }) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      ApiEndpoints.doctorsPatients,
      data: {
        'email': email.trim(),
        'name': name.trim(),
      },
    );
    final d = res.data!;
    return CreatePatientResult(
      id: d['id'] as String,
      email: d['email'] as String,
      name: d['name'] as String,
      message: d['message'] as String?,
    );
  }

  Future<void> deletePatient(String patientId) async {
    await _api.dio.delete<void>(ApiEndpoints.doctorsPatient(patientId));
  }

  Future<List<PatientListItem>> fetchMyPatients() async {
    final res = await _api.dio.get<dynamic>(ApiEndpoints.doctorsPatients);
    final data = res.data;
    if (data is! List) return [];
    return data
        .map((e) =>
            PatientListItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }


  /// [DOCTOR] Crea una nueva solicitud para un paciente.
  Future<Map<String, dynamic>> fetchTimelineDoctorNote({
    required String patientId,
    required String eventId,
  }) async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      ApiEndpoints.doctorTimelineEventNote(patientId, eventId),
    );
    return Map<String, dynamic>.from(res.data ?? const {});
  }

  Future<Map<String, dynamic>> upsertTimelineDoctorNote({
    required String patientId,
    required String eventId,
    required String eventType,
    required String doctorNote,
  }) async {
    final res = await _api.dio.put<Map<String, dynamic>>(
      ApiEndpoints.doctorTimelineEventNote(patientId, eventId),
      data: {
        'doctor_note': doctorNote.trim(),
        'event_type': eventType,
      },
    );
    return Map<String, dynamic>.from(res.data ?? const {});
  }

  Future<void> createAnalysisRequest({
    required String patientId,
    required String description,
    DateTime? expiresAt,
    String? doctorNote,
  }) async {

    try {
      final payload = <String, dynamic>{
        'patient_id': patientId,
        'description': description,
      };
      if (expiresAt != null) {
        final endOfDay = DateTime(
          expiresAt.year,
          expiresAt.month,
          expiresAt.day,
          23,
          59,
          59,
        );
        payload['expires_at'] = endOfDay.toUtc().toIso8601String();
      }
      final note = doctorNote?.trim();
      if (note != null && note.isNotEmpty) {
        payload['doctor_note'] = note;
      }
      await _api.dio.post(
        '/api/v1/analysis-requests/',
        data: payload,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// [PACIENTE] Obtiene sus solicitudes de análisis pendientes.
  Future<List<AnalysisRequestDto>> fetchMyPendingRequests() async {
    final res = await _api.dio
        .get<dynamic>('/api/v1/analysis-requests/me');
    final data = res.data;
    if (data is! List) return [];
    return data
        .map((e) =>
            AnalysisRequestDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// [DOCTOR] Obtiene el historial de solicitudes de un paciente específico.
  Future<List<AnalysisRequestDto>> fetchPatientAnalysisRequests(
      String patientId) async {
    final res = await _api.dio.get<dynamic>(
        '/api/v1/analysis-requests/patient/$patientId');
    final data = res.data;
    if (data is! List) return [];
    return data
        .map((e) =>
            AnalysisRequestDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ConsultationContext> fetchConsultationContext(String patientId) async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      '/api/v1/doctors/patients/$patientId/consultation-context',
    );
    return ConsultationContext.fromJson(res.data ?? const {});
  }

  Future<AttendanceStatsData> fetchDoctorAttendanceStats() async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      '/api/v1/doctors/attendance-stats',
    );
    return AttendanceStatsData.fromJson(res.data ?? const {});
  }

  Future<AttendanceDetailResponse> fetchDoctorAttendanceDetail({
  required String status,
  String? patientId,
  DateTime? dateFrom,
  DateTime? dateTo,
}) async {
  final query = <String, dynamic>{
    'status': status,
  };

  if (patientId != null && patientId.isNotEmpty) {
    query['patient_id'] = patientId;
  }
  if (dateFrom != null) {
    query['date_from'] = dateFrom.toIso8601String();
  }
  if (dateTo != null) {
    query['date_to'] = dateTo.toIso8601String();
  }

  final res = await _api.dio.get<Map<String, dynamic>>(
    '/api/v1/doctors/attendance-detail',
    queryParameters: query,
  );

  return AttendanceDetailResponse.fromJson(res.data ?? const {});
}

  Future<PatientProfileBootstrapData> fetchPatientProfileBootstrap(
    String patientId,
  ) async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      ApiEndpoints.doctorPatientProfileBootstrap(patientId),
    );
    return PatientProfileBootstrapData.fromJson(res.data ?? const {});
  }

  Future<ConsultationBootstrapData> fetchConsultationBootstrap({
    required String patientId,
    required String appointmentId,
  }) async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      '/api/v1/doctors/patients/$patientId/consultation-bootstrap',
      queryParameters: {'appointment_id': appointmentId},
    );
    return ConsultationBootstrapData.fromJson(res.data ?? const {});
  }

  Future<ConsultationContext> upsertClinicalProfile({
    required String patientId,
    String? name,
    String? email,
    String? phone,
    String? sex,
    int? ageYears,
    String? bloodType,
    double? weightKg,
    String? allergies,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (email != null) payload['email'] = email;
    if (phone != null) payload['phone'] = phone;
    if (sex != null) payload['sex'] = sex;
    if (ageYears != null) payload['age_years'] = ageYears;
    if (bloodType != null) payload['blood_type'] = bloodType;
    if (weightKg != null) payload['weight_kg'] = weightKg;
    if (allergies != null) payload['allergies'] = allergies;
    final res = await _api.dio.put<Map<String, dynamic>>(
      '/api/v1/doctors/patients/$patientId/clinical-profile',
      data: payload,
    );
    return ConsultationContext.fromJson(res.data ?? const {});
  }

  Future<List<TimelineEvent>> fetchPatientTimeline(String patientId) async {
    final response =
        await _api.dio.get('/api/v1/doctors/patients/$patientId/timeline');
    final List<dynamic> data = response.data as List<dynamic>;
    return sortTimelineNewestFirst(
      data.map(
        (json) => TimelineEvent.fromJson(
          Map<String, dynamic>.from(json as Map),
        ),
      ),
    );
  }

  /// [PACIENTE] Historial y próximos pasos (misma fuente que ve el médico en el timeline).
  Future<ClinicalIntakeDetail> fetchClinicalIntakeDetail({
    required String patientId,
    required String invitationId,
  }) async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      '/api/v1/doctors/patients/$patientId/clinical-intake/$invitationId',
    );
    return ClinicalIntakeDetail.fromJson(res.data ?? const {});
  }

  Future<List<PriorDocumentItem>> fetchPatientPriorDocuments(
    String patientId,
  ) async {
    final res = await _api.dio.get<dynamic>(
      '/api/v1/doctors/patients/$patientId/prior-documents',
    );
    final data = res.data;
    if (data is! List) return [];
    return data
        .map((e) =>
            PriorDocumentItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<PriorDocumentItem>> fetchMyPriorDocuments() async {
    final res = await _api.dio.get<dynamic>('/api/v1/patient/prior-documents');
    final data = res.data;
    if (data is! List) return [];
    return data
        .map((e) =>
            PriorDocumentItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<TimelineEvent>> fetchMyCareTimeline() async {
    final response = await _api.dio.get<dynamic>('/api/v1/patient/timeline');
    final data = response.data;
    if (data is! List) return [];
    return sortTimelineNewestFirst(
      data.map(
        (json) => TimelineEvent.fromJson(
          Map<String, dynamic>.from(json as Map),
        ),
      ),
    );
  }

  /// URL de descarga/visualización para abrir un documento dentro de WebView.
  String getMobileDocumentUrl(String documentId) {
    final relative = ApiEndpoints.documentsMobileDownloadById(documentId);
    final base = _api.dio.options.baseUrl;
    return Uri.parse(base).resolve(relative).toString();
  }

  /// [DOCTOR] Sube un reporte físico y completa la solicitud del paciente.
  Future<void> doctorUploadAnalysisAndComplete({
    required String requestId,
    required FormData formData,
  }) async {
    await _api.dio.patch(
      '/api/v1/analysis-requests/$requestId/doctor-upload',
      data: formData,
    );
  }

  /// [PACIENTE] Marca una solicitud como completada vinculando el ID del documento subido.
  Future<void> completeAnalysisRequest({
    required String requestId,
    required String documentId,
  }) async {
    await _api.dio.patch(
      '/api/v1/analysis-requests/$requestId/complete',
      queryParameters: {
        'document_id': documentId,
      },
    );
  }


  Future<ScheduleAppointmentResult> scheduleAppointment({
    required String patientId,
    required DateTime date,
    required String reason,
    String? doctorNote,
    int? durationMinutes,
  }) async {
    final duration = durationMinutes ??
        (await SchedulingService(_api).fetchSettings()).slotDurationMinutes;
    final d = await AppointmentService(_api).createDoctorAppointment(
      patientId: patientId,
      startAt: date,
      reason: reason,
      durationMinutes: duration,
      notes: doctorNote,
    );
    return ScheduleAppointmentResult(
      id: d.id,
      status: d.status,
      message: 'Cita registrada',
    );
  }


  static String messageFromDio(Object e) {
    if (e is! DioException) return e.toString();
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) {
      final d = data['detail'];
      return d is String ? d : d.toString();
    }
    return e.message ?? e.toString();
  }
}


class CreatePatientResult {
  final String id, email, name;
  final String? message;
  CreatePatientResult(
      {required this.id,
      required this.email,
      required this.name,
      this.message});
}

class ScheduleAppointmentResult {
  final String id, status, message;
  ScheduleAppointmentResult(
      {required this.id, required this.status, required this.message});
}

class PatientListItem {
  final String id;
  final String email;
  final String name;
  final bool mustChangePassword;
  final String? createdAt;

  final bool isActive;
  final String? phone;
  final String? sex;
  final int? ageYears;
  final String? bloodType;
  final double? weightKg;
  final String? allergies;

  final int appointmentsTotal;
  final int appointmentsAttended;
  final int appointmentsNoShow;
  final int appointmentsPendingAttendance;

  final DateTime? lastAppointmentDate;
  final DateTime? nextAppointmentDate;

  final int documentsTotal;
  final bool hasClinicalProfile;

  PatientListItem({
    required this.id,
    required this.email,
    required this.name,
    required this.mustChangePassword,
    this.createdAt,
    this.isActive = true,
    this.phone,
    this.sex,
    this.ageYears,
    this.bloodType,
    this.weightKg,
    this.allergies,
    this.appointmentsTotal = 0,
    this.appointmentsAttended = 0,
    this.appointmentsNoShow = 0,
    this.appointmentsPendingAttendance = 0,
    this.lastAppointmentDate,
    this.nextAppointmentDate,
    this.documentsTotal = 0,
    this.hasClinicalProfile = false,
  });

  static int _readInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _readDouble(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static DateTime? _readScheduleDate(Map<String, dynamic> json, String key) {
    final value = json[key]?.toString();
    if (value == null || value.isEmpty) return null;
    return KeepiTimezone.parseSchedule(value);
  }

  factory PatientListItem.fromJson(Map<String, dynamic> json) {
    return PatientListItem(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Paciente',
      mustChangePassword: json['must_change_password'] as bool? ?? false,
      createdAt: json['created_at']?.toString(),
      isActive: json['is_active'] as bool? ?? true,
      phone: json['phone']?.toString(),
      sex: json['sex']?.toString(),
      ageYears: _readInt(json, 'age_years') == 0
          ? null
          : _readInt(json, 'age_years'),
      bloodType: json['blood_type']?.toString(),
      weightKg: _readDouble(json, 'weight_kg'),
      allergies: json['allergies']?.toString(),
      appointmentsTotal: _readInt(json, 'appointments_total'),
      appointmentsAttended: _readInt(json, 'appointments_attended'),
      appointmentsNoShow: _readInt(json, 'appointments_no_show'),
      appointmentsPendingAttendance:
          _readInt(json, 'appointments_pending_attendance'),
      lastAppointmentDate: _readScheduleDate(json, 'last_appointment_date'),
      nextAppointmentDate: _readScheduleDate(json, 'next_appointment_date'),
      documentsTotal: _readInt(json, 'documents_total'),
      hasClinicalProfile: json['has_clinical_profile'] as bool? ?? false,
    );
  }
}

/// Datos del endpoint profile-bootstrap (contexto + timeline + análisis + cuestionarios).
class PatientProfileBootstrapData {
  const PatientProfileBootstrapData({
    required this.context,
    required this.timeline,
    required this.analysisRequests,
    required this.questionnaireResponses,
    this.questionnairePending = const [],
  });

  final ConsultationContext context;
  final List<TimelineEvent> timeline;
  final List<AnalysisRequestDto> analysisRequests;
  final List<Map<String, dynamic>> questionnaireResponses;
  final List<Map<String, dynamic>> questionnairePending;

  factory PatientProfileBootstrapData.fromJson(Map<String, dynamic> json) {
    final timelineRaw = json['timeline'] as List<dynamic>? ?? [];
    final analysisRaw = json['analysis_requests'] as List<dynamic>? ?? [];
    final questionnaireRaw =
        json['questionnaire_responses'] as List<dynamic>? ?? [];
    final pendingRaw = json['questionnaire_pending'] as List<dynamic>? ?? [];
    return PatientProfileBootstrapData(
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
      questionnaireResponses: questionnaireRaw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
      questionnairePending: pendingRaw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
    );
  }
}

/// DTO para representar una solicitud de análisis.
class AnalysisRequestDto {
  final String id;
  final String doctorId;
  final String patientId;
  final String description;
  final String status;
  final String createdAt;
  final String? documentId;
  final String? completedAt;
  final String? expiresAt;

  AnalysisRequestDto({
    required this.id,
    required this.doctorId,
    required this.patientId,
    required this.description,
    required this.status,
    required this.createdAt,
    this.documentId,
    this.completedAt,
    this.expiresAt,
  });

  String? get deadlineLabel => formatKeepiDate(expiresAt);

  String? get completedAtLabel => formatKeepiDateTime(completedAt);

  String? get createdAtLabel => formatKeepiDateTime(createdAt);

  factory AnalysisRequestDto.fromJson(Map<String, dynamic> json) {
    return AnalysisRequestDto(
      id: json['id']?.toString() ?? '',

      // EL TRUCO ESTÁ AQUÍ: Lee ambas opciones (con guion o con mayúscula)
      doctorId: (json['doctor_id'] ?? json['doctorId'])?.toString() ?? '',
      patientId: (json['patient_id'] ?? json['patientId'])?.toString() ?? '',

      description: json['description']?.toString() ?? 'Sin descripción',
      status: json['status']?.toString() ?? 'pending',

      createdAt: (json['created_at'] ?? json['createdAt'])?.toString() ?? '',
      documentId: (json['document_id'] ?? json['documentId'])?.toString(),
      completedAt: (json['completed_at'] ?? json['completedAt'])?.toString(),
      expiresAt: (json['expires_at'] ?? json['expiresAt'])?.toString(),
    );
  }
}

class AttendanceDetailResponse {
  const AttendanceDetailResponse({
    required this.status,
    required this.total,
    required this.items,
  });

  final String status;
  final int total;
  final List<AttendanceDetailItem> items;

  factory AttendanceDetailResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return AttendanceDetailResponse(
      status: json['status']?.toString() ?? '',
      total: (json['total'] as num?)?.toInt() ?? rawItems.length,
      items: rawItems
          .whereType<Map>()
          .map((e) => AttendanceDetailItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class AttendanceDetailItem {
  const AttendanceDetailItem({
    required this.appointmentId,
    required this.patientId,
    required this.patientName,
    required this.patientEmail,
    required this.appointmentDate,
    required this.endDate,
    required this.reason,
    required this.attendanceStatus,
  });

  final String appointmentId;
  final String patientId;
  final String patientName;
  final String patientEmail;
  final DateTime? appointmentDate;
  final DateTime? endDate;
  final String reason;
  final String attendanceStatus;

  factory AttendanceDetailItem.fromJson(Map<String, dynamic> json) {
    return AttendanceDetailItem(
      appointmentId: json['appointment_id']?.toString() ?? '',
      patientId: json['patient_id']?.toString() ?? '',
      patientName: json['patient_name']?.toString() ?? 'Paciente',
      patientEmail: json['patient_email']?.toString() ?? '',
      appointmentDate: KeepiTimezone.parseSchedule(
        json['appointment_date']?.toString(),
      ),
      endDate: KeepiTimezone.parseSchedule(json['end_date']?.toString()),
      reason: json['reason']?.toString() ?? '',
      attendanceStatus: json['attendance_status']?.toString() ?? '',
    );
  }
}