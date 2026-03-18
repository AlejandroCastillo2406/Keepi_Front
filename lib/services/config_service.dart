
import '../core/api_endpoints.dart';
import 'api_client.dart';

/// Servicio para la configuración del usuario (settings).
class ConfigService {
  ConfigService(this._api);

  final ApiClient _api;

  Future<UserConfigResponse> getUserConfig() async {
    final res = await _api.dio.get<Map<String, dynamic>>(ApiEndpoints.config);
    return UserConfigResponse.fromJson(res.data!);
  }
}

class UserConfigResponse {
  UserConfigResponse({
    required this.id,
    required this.userId,
    required this.cloudProvider,
    this.notificationPreferences,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String cloudProvider;
  final Map<String, dynamic>? notificationPreferences;
  final String? createdAt;
  final String? updatedAt;

  factory UserConfigResponse.fromJson(Map<String, dynamic> json) {
    return UserConfigResponse(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      cloudProvider: json['cloud_provider'] as String? ?? 'google_drive',
      notificationPreferences: json['notification_preferences'] as Map<String, dynamic>?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  bool get isKeepiCloud => cloudProvider == 'keepi_cloud';
  bool get isGoogleDrive => cloudProvider == 'google_drive';
  bool get isNotConfigured => cloudProvider == 'not_configured';
}
