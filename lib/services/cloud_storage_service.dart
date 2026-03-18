
import '../core/api_endpoints.dart';
import 'api_client.dart';

/// Servicio para configurar el tipo de almacenamiento del usuario.
class CloudStorageService {
  CloudStorageService(this._api);

  final ApiClient _api;

  Future<SetupStorageResponse> setupStorage(String storageType) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      ApiEndpoints.cloudStorageSetup,
      data: {'storage_type': storageType},
    );
    return SetupStorageResponse.fromJson(res.data!);
  }
}

class SetupStorageResponse {
  SetupStorageResponse({
    required this.success,
    required this.message,
    required this.storageType,
    this.authorizationRequired = false,
    this.authorizationUrl,
  });

  final bool success;
  final String message;
  final String storageType;
  final bool authorizationRequired;
  final String? authorizationUrl;

  factory SetupStorageResponse.fromJson(Map<String, dynamic> json) {
    return SetupStorageResponse(
      success: json['success'] as bool? ?? true,
      message: json['message'] as String? ?? '',
      storageType: json['storage_type'] as String? ?? '',
      authorizationRequired: json['authorization_required'] as bool? ?? false,
      authorizationUrl: json['authorization_url'] as String?,
    );
  }
}

