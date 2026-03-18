import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  bool _isLoading = true;
  bool _isLoggedIn = false;
  String? _accessToken;
  String? _refreshToken;
  String? _userId;
  String? _email;
  String? _name;
  String? _error;

  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  String? get accessToken => _accessToken;
  String? get userId => _userId;
  String? get email => _email;
  String? get name => _name;
  String? get error => _error;

  Future<void> _loadStoredAuth() async {
    _accessToken = _prefs.getString(_keyAccessToken);
    _refreshToken = _prefs.getString(_keyRefreshToken);
    _userId = _prefs.getString(_keyUserId);
    _email = _prefs.getString(_keyEmail);
    _name = _prefs.getString(_keyName);

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
      _accessToken = null;
      _refreshToken = null;
      _userId = _email = _name = null;
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
  }) async {
    await _prefs.setString(_keyAccessToken, accessToken);
    if (refreshToken != null) await _prefs.setString(_keyRefreshToken, refreshToken);
    if (id != null) await _prefs.setString(_keyUserId, id);
    if (email != null) await _prefs.setString(_keyEmail, email);
    if (name != null) await _prefs.setString(_keyName, name);
    _accessToken = accessToken;
    _refreshToken = refreshToken ?? _refreshToken;
    _userId = id ?? _userId;
    _email = email ?? _email;
    _name = name ?? _name;
    _api.setAccessToken(accessToken);
    _isLoggedIn = true;
    _error = null;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _error = null;
    try {
      final res = await _authService.login(email: email, password: password);
      await _saveAuth(
        accessToken: res.accessToken,
        refreshToken: res.refreshToken,
        id: res.id ?? res.user?.id,
        email: res.email ?? res.user?.email,
        name: res.name ?? res.user?.name,
      );
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

  Future<bool> register(String email, String name, String password) async {
    _error = null;
    try {
      final res = await _authService.register(email: email, name: name, password: password);
      await _saveAuth(
        accessToken: res.accessToken,
        id: res.id,
        email: res.email,
        name: res.name,
      );
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
    _accessToken = null;
    _refreshToken = null;
    _userId = _email = _name = null;
    _api.setAccessToken(null);
    _isLoggedIn = false;
    notifyListeners();
  }

  Future<bool> tryRefreshToken() async {
    final refresh = _refreshToken ?? _prefs.getString(_keyRefreshToken);
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final res = await _authService.refresh(refresh);
      await _saveAuth(accessToken: res.accessToken);
      return true;
    } catch (_) {
      return false;
    }
  }
}
