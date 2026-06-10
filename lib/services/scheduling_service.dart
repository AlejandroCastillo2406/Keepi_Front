import 'package:dio/dio.dart';

import '../core/api_endpoints.dart';
import 'api_client.dart';

class SchedulingSettingsDto {
  SchedulingSettingsDto({
    required this.slotDurationMinutes,
    required this.timezone,
  });

  final int slotDurationMinutes;
  final String timezone;

  factory SchedulingSettingsDto.fromJson(Map<String, dynamic> json) {
    return SchedulingSettingsDto(
      slotDurationMinutes: json['slot_duration_minutes'] as int? ?? 30,
      timezone: json['timezone'] as String? ?? 'America/Mexico_City',
    );
  }
}

class AvailabilityRuleDto {
  AvailabilityRuleDto({
    required this.weekday,
    required this.startTime,
    required this.endTime,
    required this.isEnabled,
    this.id,
  });

  final String? id;
  final int weekday;
  final String startTime;
  final String endTime;
  final bool isEnabled;

  factory AvailabilityRuleDto.fromJson(Map<String, dynamic> json) {
    return AvailabilityRuleDto(
      id: json['id']?.toString(),
      weekday: json['weekday'] as int? ?? 0,
      startTime: json['start_time'] as String? ?? '09:00',
      endTime: json['end_time'] as String? ?? '17:00',
      isEnabled: json['is_enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'weekday': weekday,
        'start_time': startTime,
        'end_time': endTime,
        'is_enabled': isEnabled,
      };
}

class SchedulingService {
  SchedulingService(this._api);

  final ApiClient _api;

  static String messageFromDio(dynamic e) {
    if (e is DioException) {
      final msg = e.response?.data?['detail'];
      if (msg != null && msg is String) return msg;
      return e.message ?? 'Error de conexión';
    }
    return e.toString();
  }

  Future<SchedulingSettingsDto> fetchSettings() async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      ApiEndpoints.doctorSchedulingSettings,
    );
    return SchedulingSettingsDto.fromJson(res.data ?? const {});
  }

  Future<SchedulingSettingsDto> updateSettings({
    required int slotDurationMinutes,
    required String timezone,
  }) async {
    final res = await _api.dio.put<Map<String, dynamic>>(
      ApiEndpoints.doctorSchedulingSettings,
      data: {
        'slot_duration_minutes': slotDurationMinutes,
        'timezone': timezone,
      },
    );
    return SchedulingSettingsDto.fromJson(res.data ?? const {});
  }

  Future<List<AvailabilityRuleDto>> fetchRules() async {
    final res = await _api.dio.get<List<dynamic>>(
      ApiEndpoints.doctorSchedulingAvailabilityRules,
    );
    return (res.data ?? [])
        .map((e) => AvailabilityRuleDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<AvailabilityRuleDto>> saveRules(
    List<AvailabilityRuleDto> rules,
  ) async {
    final res = await _api.dio.put<List<dynamic>>(
      ApiEndpoints.doctorSchedulingAvailabilityRules,
      data: {
        'rules': rules.map((r) => r.toJson()).toList(),
      },
    );
    return (res.data ?? [])
        .map((e) => AvailabilityRuleDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
