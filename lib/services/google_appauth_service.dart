import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Servicio de OAuth nativo con Google usando flutter_appauth.
class GoogleAppAuthService {
  GoogleAppAuthService(this._appAuth);

  final FlutterAppAuth _appAuth;

  // Se leen desde el .env de la app móvil.
  static String get _clientId =>
      dotenv.env['GOOGLE_MOBILE_CLIENT_ID'] ?? 'TU_CLIENT_ID.apps.googleusercontent.com';
  static String get _redirectUrl =>
      dotenv.env['GOOGLE_MOBILE_REDIRECT_URI'] ?? 'com.example.keepi:/oauth2redirect';

  static const List<String> _scopes = <String>[
    'openid',
    'email',
    'profile',
    'https://www.googleapis.com/auth/drive.file',
  ];

  Future<AuthorizationTokenResponse?> signInWithGoogleDrive() async {
    final result = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        _clientId,
        _redirectUrl,
        serviceConfiguration: const AuthorizationServiceConfiguration(
          authorizationEndpoint:
              'https://accounts.google.com/o/oauth2/v2/auth',
          tokenEndpoint: 'https://oauth2.googleapis.com/token',
        ),
        scopes: _scopes,
        // access_type=offline para obtener refresh_token
        additionalParameters: const {
          'access_type': 'offline',
        },
        // prompt=consent ahora se pasa como promptValues en flutter_appauth 11
        promptValues: const ['consent'],
      ),
    );
    return result;
  }
}

