import '../core/api_endpoints.dart';
import 'api_client.dart';

class AuthService {
  AuthService(this._api);

  final ApiClient _api;

  Future<AuthResponse> register({
    required String email,
    required String name,
    required String password,
    required String roleName,
  }) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      ApiEndpoints.authRegister,
      data: {
        'email': email,
        'name': name,
        'password': password,
        'role_name': roleName,
      },
    );
    return AuthResponse.fromJson(res.data!);
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      ApiEndpoints.authLogin,
      data: {'email': email, 'password': password},
    );
    return AuthResponse.fromJson(res.data!);
  }

  Future<AuthResponse> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      ApiEndpoints.authChangePassword,
      data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      },
    );
    return AuthResponse.fromJson(res.data!);
  }

  Future<RefreshResponse> refresh(String refreshToken) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      ApiEndpoints.authRefresh,
      queryParameters: {'refresh_token': refreshToken},
    );
    return RefreshResponse.fromJson(res.data!);
  }

  Future<UserMe> me() async {
    final res = await _api.dio.get<Map<String, dynamic>>(ApiEndpoints.authMe);
    return UserMe.fromJson(res.data!);
  }
}

class AuthResponse {
  AuthResponse({
    required this.accessToken,
    required this.tokenType,
    this.refreshToken,
    this.expiresIn,
    this.id,
    this.email,
    this.name,
    this.createdAt,
    this.mustChangePassword,
    this.roleId,
    this.roleName,
    this.user,
  });

  final String accessToken;
  final String tokenType;
  final String? refreshToken;
  final int? expiresIn;
  final String? id;
  final String? email;
  final String? name;
  final String? createdAt;
  final bool? mustChangePassword;
  final int? roleId;
  final String? roleName;
  final UserMe? user;

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final user = json['user'] != null ? UserMe.fromJson(json['user'] as Map<String, dynamic>) : null;
    return AuthResponse(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
      refreshToken: json['refresh_token'] as String?,
      expiresIn: json['expires_in'] as int?,
      id: json['id'] as String?,
      email: json['email'] as String?,
      name: json['name'] as String?,
      createdAt: json['created_at'] as String?,
      mustChangePassword: json['must_change_password'] as bool?,
      roleId: json['role_id'] as int?,
      roleName: json['role_name'] as String?,
      user: user,
    );
  }
}

class RefreshResponse {
  RefreshResponse({
    required this.accessToken,
    required this.tokenType,
    this.expiresIn,
    this.mustChangePassword,
    this.roleId,
    this.roleName,
  });

  final String accessToken;
  final String tokenType;
  final int? expiresIn;
  final bool? mustChangePassword;
  final int? roleId;
  final String? roleName;

  factory RefreshResponse.fromJson(Map<String, dynamic> json) {
    return RefreshResponse(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
      expiresIn: json['expires_in'] as int?,
      mustChangePassword: json['must_change_password'] as bool?,
      roleId: json['role_id'] as int?,
      roleName: json['role_name'] as String?,
    );
  }
}

class UserMe {
  UserMe({
    required this.id,
    required this.email,
    required this.name,
    this.isActive,
    this.createdAt,
    this.updatedAt,
    this.roleId,
    this.roleName,
    this.mustChangePassword,
  });

  final String id;
  final String email;
  final String name;
  final bool? isActive;
  final String? createdAt;
  final String? updatedAt;
  final int? roleId;
  final String? roleName;
  final bool? mustChangePassword;

  factory UserMe.fromJson(Map<String, dynamic> json) {
    return UserMe(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      isActive: json['is_active'] as bool?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      roleId: json['role_id'] as int?,
      roleName: json['role_name'] as String?,
      mustChangePassword: json['must_change_password'] as bool?,
    );
  }
}
