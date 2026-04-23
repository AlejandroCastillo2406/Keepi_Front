import 'package:dio/dio.dart';
import '../core/api_endpoints.dart';
import 'api_client.dart';

class AppointmentDto {
  AppointmentDto({
    required this.id,
    required this.doctorId,
    required this.patientId,
    required this.status,
    required this.reason,
    this.appointmentDate,
    this.endDate,
    required this.createdAt,
  });

  final String id;
  final String doctorId;
  final String patientId;
  final String status;
  final String reason;
  final DateTime? appointmentDate;
  final DateTime? endDate;
  final DateTime createdAt;

  factory AppointmentDto.fromJson(Map<String, dynamic> json) {
    return AppointmentDto(
      id: json['id'] ?? '',
      doctorId: json['doctor_id'] ?? '',
      patientId: json['patient_id'] ?? '',
      status: json['status'] ?? 'pending_doctor_proposal',
      reason: json['reason'] ?? '',
      appointmentDate: json['appointment_date'] != null ? DateTime.parse(json['appointment_date']) : null,
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
    );
  }
}

class AppointmentService {
  AppointmentService(this._api);
  final ApiClient _api;

  static String messageFromDio(dynamic e) {
    if (e is DioException) {
      final msg = e.response?.data?['detail'];
      if (msg != null && msg is String) return msg;
      return e.message ?? 'Error de conexión';
    }
    return e.toString();
  }

  // --- 1. LECTURA DE DATOS ---

  Future<List<AppointmentDto>> fetchMine() async {
    final res = await _api.dio.get<List<dynamic>>(ApiEndpoints.appointmentsMine);
    final list = res.data ?? [];
    return list.map((e) => AppointmentDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<AppointmentDto>> fetchDoctorCalendar({
    required DateTime from,
    required DateTime to,
  }) async {
    final res = await _api.dio.get<List<dynamic>>(
      ApiEndpoints.appointmentsDoctorCalendar,
      queryParameters: {
        'start_at': from.toUtc().toIso8601String(),
        'end_at': to.toUtc().toIso8601String(),
      },
    );
    final list = res.data ?? [];
    return list.map((e) => AppointmentDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  // --- 2. ACCIONES DEL DOCTOR ---

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

  Future<AppointmentDto> doctorProposeTime({
    required String appointmentId,
    required DateTime proposedStartAt,
    int durationMinutes = 30,
    String? notes,
  }) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      ApiEndpoints.appointmentDoctorPropose(appointmentId),
      data: {
        'proposed_start_at': proposedStartAt.toUtc().toIso8601String(),
        'duration_minutes': durationMinutes,
        'notes': notes,
      },
    );
    return AppointmentDto.fromJson(res.data ?? const {});
  }

  // --- 3. ACCIONES DEL PACIENTE ---

  Future<AppointmentDto> patientRequestAppointment({
    required String doctorId,
    required String reason,
  }) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      ApiEndpoints.appointmentsPatientRequest,
      data: {
        'doctor_id': doctorId,
        'reason': reason.trim(),
      },
    );
    return AppointmentDto.fromJson(res.data ?? const {});
  }

  Future<AppointmentDto> patientRespondProposal({
    required String appointmentId,
    required String action, // 'accept' o 'reject'
  }) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      ApiEndpoints.appointmentPatientRespond(appointmentId),
      data: {
        'action': action,
      },
    );
    return AppointmentDto.fromJson(res.data ?? const {});
  }
}