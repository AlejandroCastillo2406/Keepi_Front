import 'package:dio/dio.dart';

import '../core/config.dart';

typedef TokenRefreshCallback = Future<bool> Function();
typedef SessionExpiredCallback = Future<void> Function();

class ApiClient {
  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: Config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_accessToken != null) {
            options.headers['Authorization'] = 'Bearer $_accessToken';
          }
          return handler.next(options);
        },
      ),
    );
    _dio.interceptors.add(_AuthRefreshInterceptor(this));
  }

  late final Dio _dio;
  String? _accessToken;

  TokenRefreshCallback? onRefreshToken;
  SessionExpiredCallback? onSessionExpired;

  Future<bool>? _refreshInFlight;

  void setAccessToken(String? token) {
    _accessToken = token;
  }

  String? get accessToken => _accessToken;

  Dio get dio => _dio;

  void bindAuthHandlers({
    required TokenRefreshCallback refreshToken,
    required SessionExpiredCallback onSessionExpired,
  }) {
    onRefreshToken = refreshToken;
    this.onSessionExpired = onSessionExpired;
  }

  Future<bool> refreshAccessTokenOnce() {
    final refresh = onRefreshToken;
    if (refresh == null) return Future.value(false);

    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;

    final future = refresh().whenComplete(() {
      _refreshInFlight = null;
    });
    _refreshInFlight = future;
    return future;
  }

  static bool isAuthBypassPath(String path) {
    return path.contains('/auth/refresh') ||
        path.contains('/auth/login') ||
        path.contains('/auth/register');
  }
}

class _AuthRefreshInterceptor extends QueuedInterceptor {
  _AuthRefreshInterceptor(this._client);

  final ApiClient _client;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    if (status != 401) {
      handler.next(err);
      return;
    }

    final path = err.requestOptions.uri.path;
    if (ApiClient.isAuthBypassPath(path)) {
      await _client.onSessionExpired?.call();
      handler.next(err);
      return;
    }

    try {
      final refreshed = await _client.refreshAccessTokenOnce();
      if (!refreshed) {
        await _client.onSessionExpired?.call();
        handler.next(err);
        return;
      }

      final opts = err.requestOptions;
      final token = _client.accessToken;
      if (token != null) {
        opts.headers['Authorization'] = 'Bearer $token';
      }

      final response = await _client.dio.fetch(opts);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    } catch (_) {
      handler.next(err);
    }
  }
}
