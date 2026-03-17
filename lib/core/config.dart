import 'package:flutter_dotenv/flutter_dotenv.dart';

class Config {
  /// Lee variable de entorno. Sin valores por defecto: todo debe estar en .env.
  static String _env(String key) => dotenv.env[key]?.trim() ?? '';

  static String get apiBaseUrl => _env('API_BASE_URL');
  static String get apiPathPrefix => _env('API_PATH_PREFIX');

  static String get pathAuthRegister => _env('API_PATH_AUTH_REGISTER');
  static String get pathAuthLogin => _env('API_PATH_AUTH_LOGIN');
  static String get pathAuthRefresh => _env('API_PATH_AUTH_REFRESH');
  static String get pathAuthMe => _env('API_PATH_AUTH_ME');
  static String get pathAuthGoogleMobileAuthorize => _env('API_PATH_AUTH_GOOGLE_MOBILE_AUTHORIZE');
  static String get pathAuthGoogleCallback => _env('API_PATH_AUTH_GOOGLE_CALLBACK');
  static String get pathConfig => _env('API_PATH_CONFIG');
  static String get pathCloudStorageSetup => _env('API_PATH_CLOUD_STORAGE_SETUP');
  static String get pathSubscriptionsUsageStats => _env('API_PATH_SUBSCRIPTIONS_USAGE_STATS');
  static String get pathSubscriptionsCreateCheckout => _env('API_PATH_SUBSCRIPTIONS_CREATE_CHECKOUT');
  static String get pathDocumentsDriveStructure => _env('API_PATH_DOCUMENTS_DRIVE_STRUCTURE');
  static String get pathDocumentsDriveFolderContents => _env('API_PATH_DOCUMENTS_DRIVE_FOLDER_CONTENTS');
  static String get pathDocumentsDriveFileViewUrl => _env('API_PATH_DOCUMENTS_DRIVE_FILE_VIEW_URL');
  static String get pathDocumentsDriveFileContent => _env('API_PATH_DOCUMENTS_DRIVE_FILE_CONTENT');
  static String get pathDocumentsDriveFileDelete => _env('API_PATH_DOCUMENTS_DRIVE_FILE_DELETE');
  static String get pathDocumentsMobileDashboard => _env('API_PATH_DOCUMENTS_MOBILE_DASHBOARD');
  static String get pathDocumentsKeepiCloudRoot => _env('API_PATH_DOCUMENTS_KEEPI_CLOUD_ROOT');
  static String get pathDocumentsS3FoldersContents => _env('API_PATH_DOCUMENTS_S3_FOLDERS_CONTENTS');
  static String get pathDocumentsMobileAnalyze => _env('API_PATH_DOCUMENTS_MOBILE_ANALYZE');
  static String get pathDocumentsMobileSaveAnalyzed => _env('API_PATH_DOCUMENTS_MOBILE_SAVE_ANALYZED');
}
