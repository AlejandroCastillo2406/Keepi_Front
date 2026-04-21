import 'package:dio/dio.dart';

import '../core/api_endpoints.dart';
import 'api_client.dart';

class AppointmentService {
  AppointmentService(this._api);
  final ApiClient _api;

  Future<AppointmentDto> createDoctorAppointment({
    required String patientId,
    required DateTime startAt,
    required String reason,
    int durationMinutes = 30,
    String? notes,
  }) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      ApiEndpoints.appointmentsDoctorCreate,
      data: {
        'patient_id': patientId,
        'appointment_date': startAt.toUtc().toIso8601String(),
        'reason': reason.trim(),
        'duration_minutes': durationMinutes,
        'notes': notes,
      },
    );
    return AppointmentDto.fromJson(res.data ?? const {});
  }

  Future<List<AppointmentDto>> fetchDoctorCalendar({
    required DateTime from,
    required DateTime to,
  }) async {
    final res = await _api.dio.get<dynamic>(
      ApiEndpoints.appointmentsDoctorCalendar,
      queryParameters: {
        'start_at': from.toUtc().toIso8601String(),
        'end_at': to.toUtc().toIso8601String(),
      },
    );
    final data = res.data;
    if (data is! List) return [];
    return data
        .map((e) => AppointmentDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<AppointmentDto> patientConfirm(String appointmentId) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      ApiEndpoints.appointmentPatientConfirm(appointmentId),
    );
    return AppointmentDto.fromJson(res.data ?? const {});
  }

  Future<AppointmentDto> patientRequestChange({
    required String appointmentId,
    required DateTime proposedStartAt,
    int durationMinutes = 30,
    String? notes,
  }) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      ApiEndpoints.appointmentPatientRequestChange(appointmentId),
      data: {
        'proposed_start_at': proposedStartAt.toUtc().toIso8601String(),
        'duration_minutes': durationMinutes,
        'notes': notes,
      },
    );
    return AppointmentDto.fromJson(res.data ?? const {});
  }

  Future<AppointmentDto> doctorAccept(String appointmentId) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      ApiEndpoints.appointmentDoctorAccept(appointmentId),
    );
    return AppointmentDto.fromJson(res.data ?? const {});
  }

  Future<AppointmentDto> doctorCounterPropose({
    required String appointmentId,
    required DateTime proposedStartAt,
    int durationMinutes = 30,
    String? notes,
  }) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      ApiEndpoints.appointmentDoctorCounterPropose(appointmentId),
      data: {
        'proposed_start_at': proposedStartAt.toUtc().toIso8601String(),
        'duration_minutes': durationMinutes,
        'notes': notes,
      },
    );
    return AppointmentDto.fromJson(res.data ?? const {});
  }

  Future<List<AppointmentDto>> fetchMine() async {
    final res = await _api.dio.get<dynamic>(ApiEndpoints.appointmentsMine);
    final data = res.data;
    if (data is! List) return [];
    return data
        .map((e) => AppointmentDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static String messageFromDio(Object e) {
    if (e is! DioException) return e.toString();
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) return data['detail'].toString();
    return e.message ?? e.toString();
  }
}

class AppointmentDto {
  AppointmentDto({
    required this.id,
    required this.doctorId,
    required this.patientId,
    required this.status,
    required this.reason,
    required this.currentStartAt,
    required this.currentEndAt,
    required this.proposedBy,
  });

  final String id;
  final String doctorId;
  final String patientId;
  final String status;
  final String reason;
  final DateTime currentStartAt;
  final DateTime currentEndAt;
  final String proposedBy;

  factory AppointmentDto.fromJson(Map<String, dynamic> json) {
    return AppointmentDto(
      id: json['id']?.toString() ?? '',
      doctorId: json['doctor_id']?.toString() ?? '',
      patientId: json['patient_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending_patient_confirmation',
      reason: json['reason']?.toString() ?? 'Consulta médica',
      currentStartAt: DateTime.tryParse(json['current_start_at']?.toString() ?? '') ?? DateTime.now(),
      currentEndAt: DateTime.tryParse(json['current_end_at']?.toString() ?? '') ?? DateTime.now(),
      proposedBy: json['proposed_by']?.toString() ?? '',
    );
  }
}
