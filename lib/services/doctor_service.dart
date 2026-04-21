import 'package:dio/dio.dart';
import '../core/api_endpoints.dart';
import 'api_client.dart';
import 'patient_medical_record_service.dart';
import 'appointment_service.dart';

/// Llamadas a `/api/v1/doctors/patients` y `/api/v1/analysis-requests`.
class DoctorService {
  DoctorService(this._api);
  final ApiClient _api;

  // --- MÉTODOS EXISTENTES ---

  Future<CreatePatientResult> createPatient({
    required String email,
    required String name,
    required Map<String, dynamic> medicalRecord,
  }) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      ApiEndpoints.doctorsPatients,
      data: {
        'email': email.trim(),
        'name': name.trim(),
        'medical_record': medicalRecord,
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
        .map((e) => PatientListItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }


  // --- NUEVOS MÉTODOS PARA SOLICITUD DE ANÁLISIS ---

  /// [DOCTOR] Crea una nueva solicitud para un paciente.
  Future<void> createAnalysisRequest({
    required String patientId,
    required String description,
  }) async {
    // 1. RASTREADOR ANTES DE ENVIAR
    print("🛑 [DEBUG] INICIANDO POST A ANALYSIS-REQUESTS...");
    print("🛑 [DEBUG] BASE URL DE ESTE CLIENTE: ${_api.dio.options.baseUrl}");
    print("🛑 [DEBUG] DATOS: patient_id: $patientId");

    try {
      final response = await _api.dio.post(
        '/api/v1/analysis-requests/', 
        data: {
          'patient_id': patientId,
          'description': description,
        },
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
    final res = await _api.dio.get<dynamic>('/api/v1/analysis-requests/me'); // <--- AÑADIDO: /api/v1
    final data = res.data;
    if (data is! List) return [];
    return data
        .map((e) => AnalysisRequestDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// [DOCTOR] Obtiene el historial de solicitudes de un paciente específico.
  Future<List<AnalysisRequestDto>> fetchPatientAnalysisRequests(String patientId) async {
    final res = await _api.dio.get<dynamic>('/api/v1/analysis-requests/patient/$patientId'); // <--- AÑADIDO: /api/v1
    final data = res.data;
    if (data is! List) return [];
    return data
        .map((e) => AnalysisRequestDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
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
  }) async {
    final d = await AppointmentService(_api).createDoctorAppointment(
      patientId: patientId,
      startAt: date,
      reason: reason,
    );
    return ScheduleAppointmentResult(
      id: d.id,
      status: d.status,
      message: 'Cita registrada',
    );
  }

  Future<MedicalRecordDto> fetchPatientMedicalRecord(String patientId) async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      ApiEndpoints.doctorsPatientMedicalRecord(patientId),
    );
    return MedicalRecordDto.fromJson(res.data!);
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
  CreatePatientResult({required this.id, required this.email, required this.name, this.message});
}

class ScheduleAppointmentResult {
  final String id, status, message;
  ScheduleAppointmentResult({required this.id, required this.status, required this.message});
}

class PatientListItem {
  final String id, email, name;
  final bool mustChangePassword;
  final String? createdAt;
  PatientListItem({required this.id, required this.email, required this.name, required this.mustChangePassword, this.createdAt});

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