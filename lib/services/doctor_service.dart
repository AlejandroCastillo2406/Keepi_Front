import 'package:dio/dio.dart';

import '../core/api_endpoints.dart';
import 'api_client.dart';
import 'patient_medical_record_service.dart';

/// Llamadas a `/api/v1/doctors/patients` (crear y listar pacientes).
class DoctorService {
  DoctorService(this._api);

  final ApiClient _api;

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

  /// Extrae mensaje de error legible de una [DioException].
  static String messageFromDio(Object e) {
    if (e is! DioException) return e.toString();
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) {
      final d = data['detail'];
      if (d is String) return d;
      if (d is Map && d['message'] != null) return d['message'].toString();
      return d.toString();
    }
    return e.message ?? e.toString();
  }

  Future<MedicalRecordDto> fetchPatientMedicalRecord(String patientId) async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      ApiEndpoints.doctorsPatientMedicalRecord(patientId),
    );
    return MedicalRecordDto.fromJson(res.data!);
  }
}

class CreatePatientResult {
  CreatePatientResult({
    required this.id,
    required this.email,
    required this.name,
    this.message,
  });

  final String id;
  final String email;
  final String name;
  final String? message;
}

class PatientListItem {
  PatientListItem({
    required this.id,
    required this.email,
    required this.name,
    required this.mustChangePassword,
    this.createdAt,
  });

  final String id;
  final String email;
  final String name;
  final bool mustChangePassword;
  final String? createdAt;

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
