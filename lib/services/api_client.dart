import 'package:dio/dio.dart';
import '../core/config.dart';

class ApiClient {
  late final Dio _dio;
  String? _accessToken;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: Config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_accessToken != null) {
          options.headers['Authorization'] = 'Bearer $_accessToken';
        }
        return handler.next(options);
      },
    ));
  }

  void setAccessToken(String? token) {
    _accessToken = token;
  }

  Dio get dio => _dio;
}
