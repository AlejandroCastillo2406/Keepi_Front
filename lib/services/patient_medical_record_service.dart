import 'package:dio/dio.dart';

import '../core/api_endpoints.dart';
import 'api_client.dart';

class PatientMedicalRecordService {
  PatientMedicalRecordService(this._api);

  final ApiClient _api;

  Future<MedicalRecordDto> fetchMine() async {
    final res = await _api.dio.get<Map<String, dynamic>>(ApiEndpoints.meMedicalRecord);
    return MedicalRecordDto.fromJson(res.data!);
  }

  Future<MedicalRecordDto> patchMine(Map<String, dynamic> body) async {
    final res = await _api.dio.patch<Map<String, dynamic>>(
      ApiEndpoints.meMedicalRecord,
      data: body,
    );
    return MedicalRecordDto.fromJson(res.data!);
  }

  static String messageFromDio(Object e) {
    if (e is! DioException) return e.toString();
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) {
      final d = data['detail'];
      if (d is String) return d;
      return d.toString();
    }
    return e.message ?? e.toString();
  }
}

class MedicalRecordDto {
  MedicalRecordDto({
    required this.id,
    required this.patientUserId,
    this.birthDate,
    this.sex,
    this.bloodType,
    this.allergies,
    this.chronicConditions,
    this.medications,
    this.surgicalHistory,
    this.familyHistory,
    this.notes,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String patientUserId;
  final String? birthDate;
  final String? sex;
  final String? bloodType;
  final String? allergies;
  final String? chronicConditions;
  final String? medications;
  final String? surgicalHistory;
  final String? familyHistory;
  final String? notes;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? createdAt;
  final String? updatedAt;

  factory MedicalRecordDto.fromJson(Map<String, dynamic> j) {
    return MedicalRecordDto(
      id: j['id'] as String,
      patientUserId: j['patient_user_id'] as String,
      birthDate: j['birth_date'] as String?,
      sex: j['sex'] as String?,
      bloodType: j['blood_type'] as String?,
      allergies: j['allergies'] as String?,
      chronicConditions: j['chronic_conditions'] as String?,
      medications: j['medications'] as String?,
      surgicalHistory: j['surgical_history'] as String?,
      familyHistory: j['family_history'] as String?,
      notes: j['notes'] as String?,
      emergencyContactName: j['emergency_contact_name'] as String?,
      emergencyContactPhone: j['emergency_contact_phone'] as String?,
      createdAt: j['created_at'] as String?,
      updatedAt: j['updated_at'] as String?,
    );
  }

  /// Cuerpo PATCH (solo claves presentes; valores null omitidos).
  static Map<String, dynamic> patchBody({
    String? birthDate,
    String? sex,
    String? bloodType,
    String? allergies,
    String? chronicConditions,
    String? medications,
    String? surgicalHistory,
    String? familyHistory,
    String? notes,
    String? emergencyContactName,
    String? emergencyContactPhone,
  }) {
    final m = <String, dynamic>{};
    void put(String k, String? v) {
      if (v != null) m[k] = v.trim().isEmpty ? null : v.trim();
    }

    put('birth_date', birthDate);
    put('sex', sex);
    put('blood_type', bloodType);
    put('allergies', allergies);
    put('chronic_conditions', chronicConditions);
    put('medications', medications);
    put('surgical_history', surgicalHistory);
    put('family_history', familyHistory);
    put('notes', notes);
    put('emergency_contact_name', emergencyContactName);
    put('emergency_contact_phone', emergencyContactPhone);
    m.removeWhere((_, v) => v == null);
    return m;
  }
}
