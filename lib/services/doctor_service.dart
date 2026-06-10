import 'package:dio/dio.dart';
import '../core/api_endpoints.dart';
import '../models/consultation_context.dart';
import '../models/prior_document_item.dart';
import '../models/clinical_intake_detail.dart';
import '../models/timeline_event.dart';
import 'api_client.dart';
import 'appointment_service.dart';

/// Llamadas a `/api/v1/doctors/patients` y `/api/v1/analysis-requests`.
class DoctorService {
  DoctorService(this._api);
  final ApiClient _api;

  // --- MÉTODOS EXISTENTES ---

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

  Future<List<PatientListItem>> fetchMyPatients() async {
    final res = await _api.dio.get<dynamic>(ApiEndpoints.doctorsPatients);
    final data = res.data;
    if (data is! List) return [];
    return data
        .map((e) =>
            PatientListItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // --- NUEVOS MÉTODOS PARA SOLICITUD DE ANÁLISIS ---

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
    // 1. RASTREADOR ANTES DE ENVIAR
    print("🛑 [DEBUG] INICIANDO POST A ANALYSIS-REQUESTS...");
    print("🛑 [DEBUG] BASE URL DE ESTE CLIENTE: ${_api.dio.options.baseUrl}");
    print("🛑 [DEBUG] DATOS: patient_id: $patientId");

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
      final response = await _api.dio.post(
        '/api/v1/analysis-requests/',
        data: payload,
      );
      // 2. RASTREADOR DE ÉXITO REAL
      print("✅ [DEBUG] RESPUESTA REAL DEL SERVIDOR: ${response.statusCode}");
      print("✅ [DEBUG] DATA DEVUELTA: ${response.data}");
    } catch (e) {
      // 3. RASTREADOR DE ERROR OCULTO
      print("❌ [DEBUG] ERROR EXPLOSIVO DE DIO: $e");
      rethrow; // <-- Esto asegura que la pantalla roja sepa del error
    }
  }

  /// [PACIENTE] Obtiene sus solicitudes de análisis pendientes.
  Future<List<AnalysisRequestDto>> fetchMyPendingRequests() async {
    final res = await _api.dio
        .get<dynamic>('/api/v1/analysis-requests/me'); // <--- AÑADIDO: /api/v1
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
        '/api/v1/analysis-requests/patient/$patientId'); // <--- AÑADIDO: /api/v1
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
    return data
        .map((json) =>
            TimelineEvent.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
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
    return data
        .map((json) =>
            TimelineEvent.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
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
      '/api/v1/analysis-requests/$requestId/complete', // <--- AÑADIDO: /api/v1
      queryParameters: {
        'document_id': documentId,
      },
    );
  }

  // --- UTILIDADES ---

  Future<ScheduleAppointmentResult> scheduleAppointment({
    required String patientId,
    required DateTime date,
    required String reason,
    String? doctorNote,
  }) async {
    final d = await AppointmentService(_api).createDoctorAppointment(
      patientId: patientId,
      startAt: date,
      reason: reason,
      notes: doctorNote,
    );
    return ScheduleAppointmentResult(
      id: d.id,
      status: d.status,
      message: 'Cita registrada',
    );
  }

  // --- NUEVOS MÉTODOS PARA SOLICITUD DE ANÁLISIS ---

  // --- UTILIDADES ---

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

// --- MODELOS DE DATOS ---

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
  final String id, email, name;
  final bool mustChangePassword;
  final String? createdAt;
  PatientListItem(
      {required this.id,
      required this.email,
      required this.name,
      required this.mustChangePassword,
      this.createdAt});

  factory PatientListItem.fromJson(Map<String, dynamic> json) {
    return PatientListItem(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      mustChangePassword: json['must_change_password'] as bool? ?? false,
      createdAt: json['created_at'] as String?,
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

  AnalysisRequestDto({
    required this.id,
    required this.doctorId,
    required this.patientId,
    required this.description,
    required this.status,
    required this.createdAt,
    this.documentId,
    this.completedAt,
  });

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
    );
  }
}
