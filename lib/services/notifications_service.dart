import 'package:dio/dio.dart';

import '../core/api_endpoints.dart';
import 'api_client.dart';

class NotificationsService {
  NotificationsService(this._api);
  final ApiClient _api;

  Future<List<AppNotificationDto>> fetchNotifications() async {
    final res = await _api.dio.get<dynamic>(ApiEndpoints.notifications);
    final data = res.data;
    if (data is! List) return [];
    return data
        .map((e) => AppNotificationDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static String messageFromDio(Object e) {
    if (e is! DioException) return e.toString();
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) return data['detail'].toString();
    return e.message ?? e.toString();
  }
}

class AppNotificationDto {
  AppNotificationDto({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.read,
    required this.payload,
    this.createdAt,
  });

  final String id;
  final String title;
  final String message;
  final String type;
  final bool read;
  final Map<String, dynamic> payload;
  final String? createdAt;

  String? get prescriptionId => payload['prescription_id']?.toString();
  String get reminderQuestion =>
      payload['question']?.toString() ?? message;
  String? get appointmentId => payload['appointment_id']?.toString();
  String? get appointmentAction => payload['action']?.toString();
  DateTime? get proposedStartAt {
    final raw = payload['proposed_start_at']?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  factory AppNotificationDto.fromJson(Map<String, dynamic> j) {
    return AppNotificationDto(
      id: j['id'] as String? ?? '',
      title: j['title'] as String? ?? 'Notificación',
      message: j['message'] as String? ?? '',
      type: j['type'] as String? ?? 'info',
      read: (j['read'] as bool?) ?? false,
      payload: Map<String, dynamic>.from((j['payload'] as Map?) ?? const {}),
      createdAt: j['created_at'] as String?,
    );
  }
}

