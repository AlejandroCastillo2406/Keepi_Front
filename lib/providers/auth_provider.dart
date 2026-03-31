import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/roles.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  AuthProvider(this._prefs, this._api, this._authService) {
    _loadStoredAuth();
  }

  final SharedPreferences _prefs;
  final ApiClient _api;
  final AuthService _authService;

  static const _keyAccessToken = 'keepi_access_token';
  static const _keyRefreshToken = 'keepi_refresh_token';
  static const _keyUserId = 'keepi_user_id';
  static const _keyEmail = 'keepi_email';
  static const _keyName = 'keepi_name';
  static const _keyRoleName = 'keepi_role_name';
  static const _keyMustChangePassword = 'keepi_must_change_password';

  bool _isLoading = true;
  bool _isLoggedIn = false;
  String? _accessToken;
  String? _refreshToken;
  String? _userId;
  String? _email;
  String? _name;
  String? _roleName;
  bool _mustChangePassword = false;
  String? _error;

  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  String? get accessToken => _accessToken;
  String? get userId => _userId;
  String? get email => _email;
  String? get name => _name;
  String? get roleName => _roleName;
  bool get mustChangePassword => _mustChangePassword;
  String? get error => _error;

  Future<void> _loadStoredAuth() async {
    _accessToken = _prefs.getString(_keyAccessToken);
    _refreshToken = _prefs.getString(_keyRefreshToken);
    _userId = _prefs.getString(_keyUserId);
    _email = _prefs.getString(_keyEmail);
    _name = _prefs.getString(_keyName);
    _roleName = _prefs.getString(_keyRoleName);
    _mustChangePassword = _prefs.getBool(_keyMustChangePassword) ?? false;

    final refreshTokenStored = _refreshToken ?? _prefs.getString(_keyRefreshToken);
    final hasRefresh = refreshTokenStored != null && refreshTokenStored.isNotEmpty;
    if (hasRefresh) {
      final ok = await tryRefreshToken();
      if (ok) {
        _isLoading = false;
        notifyListeners();
        return;
      }
      await _prefs.remove(_keyAccessToken);
      await _prefs.remove(_keyRefreshToken);
      await _prefs.remove(_keyUserId);
      await _prefs.remove(_keyEmail);
      await _prefs.remove(_keyName);
      await _prefs.remove(_keyRoleName);
      await _prefs.remove(_keyMustChangePassword);
      _accessToken = null;
      _refreshToken = null;
      _userId = _email = _name = null;
      _roleName = null;
      _mustChangePassword = false;
      _api.setAccessToken(null);
      _isLoggedIn = false;
    } else if (_accessToken != null && _accessToken!.isNotEmpty) {
      _api.setAccessToken(_accessToken);
      _isLoggedIn = true;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _saveAuth({
    required String accessToken,
    String? refreshToken,
    String? id,
    String? email,
    String? name,
    String? roleName,
    bool? mustChangePassword,
  }) async {
    await _prefs.setString(_keyAccessToken, accessToken);
    if (refreshToken != null) await _prefs.setString(_keyRefreshToken, refreshToken);
    if (id != null) await _prefs.setString(_keyUserId, id);
    if (email != null) await _prefs.setString(_keyEmail, email);
    if (name != null) await _prefs.setString(_keyName, name);
    if (roleName != null) {
      await _prefs.setString(_keyRoleName, roleName);
    }
    if (mustChangePassword != null) {
      await _prefs.setBool(_keyMustChangePassword, mustChangePassword);
    }
    _accessToken = accessToken;
    _refreshToken = refreshToken ?? _refreshToken;
    _userId = id ?? _userId;
    _email = email ?? _email;
    _name = name ?? _name;
    _roleName = roleName ?? _roleName;
    if (mustChangePassword != null) {
      _mustChangePassword = mustChangePassword;
    }
    _api.setAccessToken(accessToken);
    _isLoggedIn = true;
    _error = null;
    notifyListeners();
  }

  Future<void> _applyAuthResponse(AuthResponse res) async {
    final id = res.id ?? res.user?.id;
    final email = res.email ?? res.user?.email;
    final name = res.name ?? res.user?.name;
    final role = res.roleName ?? res.user?.roleName ?? _roleName ?? 'USER';
    final must = res.mustChangePassword ?? res.user?.mustChangePassword ?? false;
    await _saveAuth(
      accessToken: res.accessToken,
      refreshToken: res.refreshToken,
      id: id,
      email: email,
      name: name,
      roleName: role,
      mustChangePassword: must,
    );
  }

  Future<bool> login(String email, String password) async {
    _error = null;
    try {
      final res = await _authService.login(email: email, password: password);
      await _applyAuthResponse(res);
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('DioException [bad response]: ', '');
      if (e is DioException && e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map && data['detail'] != null) {
          _error = data['detail'] is String ? data['detail'] as String : data['detail'].toString();
        }
      }
      notifyListeners();
      return false;
    }
  }

  /// [roleName] debe ser [AppRole.user] o [AppRole.doctor].
  Future<bool> register(
    String email,
    String name,
    String password, {
    String roleName = AppRole.user,
  }) async {
    _error = null;
    try {
      final res = await _authService.register(
        email: email,
        name: name,
        password: password,
        roleName: roleName,
      );
      await _applyAuthResponse(res);
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('DioException [bad response]: ', '');
      if (e is DioException && e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map && data['detail'] != null) {
          _error = data['detail'] is String ? data['detail'] as String : data['detail'].toString();
        }
      }
      notifyListeners();
      return false;
    }
  }

  Future<bool> changePasswordAndRefreshSession({
    required String currentPassword,
    required String newPassword,
  }) async {
    _error = null;
    try {
      final res = await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      await _applyAuthResponse(res);
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('DioException [bad response]: ', '');
      if (e is DioException && e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map && data['detail'] != null) {
          _error = data['detail'] is String ? data['detail'] as String : data['detail'].toString();
        }
      }
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _prefs.remove(_keyAccessToken);
    await _prefs.remove(_keyRefreshToken);
    await _prefs.remove(_keyUserId);
    await _prefs.remove(_keyEmail);
    await _prefs.remove(_keyName);
    await _prefs.remove(_keyRoleName);
    await _prefs.remove(_keyMustChangePassword);
    _accessToken = null;
    _refreshToken = null;
    _userId = _email = _name = null;
    _roleName = null;
    _mustChangePassword = false;
    _api.setAccessToken(null);
    _isLoggedIn = false;
    notifyListeners();
  }

  Future<bool> tryRefreshToken() async {
    final refresh = _refreshToken ?? _prefs.getString(_keyRefreshToken);
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final res = await _authService.refresh(refresh);
      await _prefs.setString(_keyAccessToken, res.accessToken);
      if (res.mustChangePassword != null) {
        await _prefs.setBool(_keyMustChangePassword, res.mustChangePassword!);
        _mustChangePassword = res.mustChangePassword!;
      }
      if (res.roleName != null) {
        await _prefs.setString(_keyRoleName, res.roleName!);
        _roleName = res.roleName;
      }
      _accessToken = res.accessToken;
      _api.setAccessToken(res.accessToken);
      _isLoggedIn = true;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }
}
