import 'package:dio/dio.dart';
import 'dart:typed_data';
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
    this.patientName,
    this.attendanceStatus,
  });

  final String id;
  final String doctorId;
  final String patientId;
  final String status;
  final String reason;
  final DateTime? appointmentDate;
  final DateTime? endDate;
  final DateTime createdAt;
  final String? patientName;
  final String? attendanceStatus;

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
      patientName: json['patient_name'] as String?,
      attendanceStatus: json['attendance_status'] as String?,
    );
  }
}

class ConsultationScheduleDayDto {
  ConsultationScheduleDayDto({
    required this.weekday,
    required this.startTime,
    required this.endTime,
  });

  final int weekday;
  final String startTime;
  final String endTime;

  factory ConsultationScheduleDayDto.fromJson(Map<String, dynamic> json) {
    return ConsultationScheduleDayDto(
      weekday: json['weekday'] as int? ?? 0,
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
    );
  }
}

class ConsultationScheduleDto {
  ConsultationScheduleDto({
    required this.slotDurationMinutes,
    required this.days,
  });

  final int slotDurationMinutes;
  final List<ConsultationScheduleDayDto> days;

  factory ConsultationScheduleDto.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'] as List<dynamic>? ?? [];
    return ConsultationScheduleDto(
      slotDurationMinutes: json['slot_duration_minutes'] as int? ?? 30,
      days: rawDays
          .map((e) => ConsultationScheduleDayDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ProcedureBlockDto {
  ProcedureBlockDto({
    required this.id,
    required this.doctorId,
    required this.title,
    required this.startAt,
    required this.endAt,
    required this.createdAt,
  });

  final String id;
  final String doctorId;
  final String title;
  final DateTime startAt;
  final DateTime endAt;
  final DateTime createdAt;

  factory ProcedureBlockDto.fromJson(Map<String, dynamic> json) {
    return ProcedureBlockDto(
      id: json['id']?.toString() ?? '',
      doctorId: json['doctor_id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      startAt: DateTime.parse(json['start_at'] as String),
      endAt: DateTime.parse(json['end_at'] as String),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

class DoctorCalendarDto {
  DoctorCalendarDto({
    required this.appointments,
    required this.consultationSchedule,
    this.procedures = const [],
  });

  final List<AppointmentDto> appointments;
  final ConsultationScheduleDto consultationSchedule;
  final List<ProcedureBlockDto> procedures;

  factory DoctorCalendarDto.fromJson(Map<String, dynamic> json) {
    final rawAppointments = json['appointments'] as List<dynamic>? ?? [];
    final rawProcedures = json['procedures'] as List<dynamic>? ?? [];
    return DoctorCalendarDto(
      appointments: rawAppointments
          .map((e) => AppointmentDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      procedures: rawProcedures
          .map((e) => ProcedureBlockDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      consultationSchedule: ConsultationScheduleDto.fromJson(
        json['consultation_schedule'] as Map<String, dynamic>? ?? const {},
      ),
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


  Future<List<AppointmentDto>> fetchMine() async {
    final res = await _api.dio.get<List<dynamic>>(ApiEndpoints.appointmentsMine);
    final list = res.data ?? [];
    return list.map((e) => AppointmentDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AppointmentDto> fetchById(String appointmentId) async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      ApiEndpoints.appointmentById(appointmentId),
    );
    return AppointmentDto.fromJson(res.data ?? const {});
  }

  Future<DoctorCalendarDto> fetchDoctorCalendar({
    required DateTime from,
    required DateTime to,
  }) async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      ApiEndpoints.appointmentsDoctorCalendar,
      queryParameters: {
        'start_at': from.toUtc().toIso8601String(),
        'end_at': to.toUtc().toIso8601String(),
      },
    );
    return DoctorCalendarDto.fromJson(res.data ?? const {});
  }

  Future<Uint8List> downloadDoctorCalendarIcs({
    required DateTime from,
    required DateTime to,
    required bool includeScheduled,
    required bool includePending,
    required bool includeProcedures,
  }) async {
    final res = await _api.dio.get<List<int>>(
      ApiEndpoints.appointmentsDoctorExportIcs,
      queryParameters: {
        'start_at': from.toUtc().toIso8601String(),
        'end_at': to.toUtc().toIso8601String(),
        'include_scheduled': includeScheduled,
        'include_pending': includePending,
        'include_procedures': includeProcedures,
      },
      options: Options(responseType: ResponseType.bytes),
    );
    final data = res.data ?? const [];
    return Uint8List.fromList(data);
  }

  Future<ProcedureBlockDto> createDoctorProcedure({
    required String title,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      ApiEndpoints.appointmentsDoctorProcedures,
      data: {
        'title': title.trim(),
        'start_at': startAt.toUtc().toIso8601String(),
        'end_at': endAt.toUtc().toIso8601String(),
      },
    );
    return ProcedureBlockDto.fromJson(res.data ?? const {});
  }

  Future<void> deleteDoctorProcedure(String blockId) async {
    await _api.dio.delete(ApiEndpoints.appointmentDoctorProcedure(blockId));
  }


  Future<List<AppointmentDto>> fetchDoctorPatientAppointments(
    String patientId,
  ) async {
    final res = await _api.dio.get<List<dynamic>>(
      ApiEndpoints.doctorPatientAppointments(patientId),
    );
    final list = res.data ?? [];
    return list
        .map((e) => AppointmentDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }


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

  Future<void> cancelAppointment({
    required String appointmentId,
  }) async {
    await _api.dio.post(
      ApiEndpoints.appointmentDoctorCancel(appointmentId),
    );
  }

  Future<AppointmentDto> doctorApproveAppointment({
    required String appointmentId,
  }) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      ApiEndpoints.appointmentDoctorApprove(appointmentId),
    );
    return AppointmentDto.fromJson(res.data ?? const {});
  }

  Future<AppointmentDto> doctorRejectAppointment({
    required String appointmentId,
  }) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      ApiEndpoints.appointmentDoctorReject(appointmentId),
    );
    return AppointmentDto.fromJson(res.data ?? const {});
  }

  Future<AppointmentDto> doctorRescheduleWebAppointment({
    required String appointmentId,
    required DateTime proposedStartAt,
    int durationMinutes = 30,
  }) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      ApiEndpoints.appointmentDoctorReschedule(appointmentId),
      data: {
        'proposed_start_at': proposedStartAt.toUtc().toIso8601String(),
        'duration_minutes': durationMinutes,
      },
    );
    return AppointmentDto.fromJson(res.data ?? const {});
  }

  Future<AppointmentDto> doctorReassignCanceledAppointment({
    required String appointmentId,
    required DateTime proposedStartAt,
    int durationMinutes = 30,
  }) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      ApiEndpoints.appointmentDoctorReassignCanceled(appointmentId),
      data: {
        'proposed_start_at': proposedStartAt.toUtc().toIso8601String(),
        'duration_minutes': durationMinutes,
      },
    );
    return AppointmentDto.fromJson(res.data ?? const {});
  }

  Future<AppointmentDto> recordAttendance({
    required String appointmentId,
    required String status,
  }) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      ApiEndpoints.appointmentAttendance(appointmentId),
      data: {'status': status},
    );
    return AppointmentDto.fromJson(res.data ?? const {});
  }


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