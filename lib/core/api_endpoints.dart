import 'config.dart';

/// Rutas de la API. Prefijo y rutas relativas vienen de Config (env). Cero rutas hardcodeadas.
class ApiEndpoints {
  ApiEndpoints._();

  static String _path(String relative) {
    final p = Config.apiPathPrefix;
    final r = relative.startsWith('/') ? relative.substring(1) : relative;
    return p.endsWith('/') ? p + r : '$p/$r';
  }

  static String get authRegister => _path(Config.pathAuthRegister);
  static String get authLogin => _path(Config.pathAuthLogin);
  static String get authRefresh => _path(Config.pathAuthRefresh);
  static String get authMe => _path(Config.pathAuthMe);
  static String get authChangePassword => _path(Config.pathAuthChangePassword);
  static String get doctorsPatients => _path(Config.pathDoctorsPatients);
  static String get authGoogleMobileAuthorize => _path(Config.pathAuthGoogleMobileAuthorize);
  static String get authGoogleCallback => _path(Config.pathAuthGoogleCallback);

  static String get config => _path(Config.pathConfig);

  static String get cloudStorageSetup => _path(Config.pathCloudStorageSetup);

  static String get subscriptionsUsageStats => _path(Config.pathSubscriptionsUsageStats);
  static String get subscriptionsCreateCheckout => _path(Config.pathSubscriptionsCreateCheckout);

  static String get documentsDriveStructure => _path(Config.pathDocumentsDriveStructure);
  static String documentsDriveFolderContents(String folderId) =>
      _path(Config.pathDocumentsDriveFolderContents.replaceFirst('{folderId}', folderId));
  static String documentsDriveFileViewUrl(String fileId) =>
      _path(Config.pathDocumentsDriveFileViewUrl.replaceFirst('{fileId}', fileId));
  static String documentsDriveFileContent(String fileId) =>
      _path(Config.pathDocumentsDriveFileContent.replaceFirst('{fileId}', fileId));
  static String documentsDriveFileDelete(String fileId) =>
      _path(Config.pathDocumentsDriveFileDelete.replaceFirst('{fileId}', fileId));

  static String get documentsMobileDashboard => _path(Config.pathDocumentsMobileDashboard);
  static String get documentsKeepiCloudRoot => _path(Config.pathDocumentsKeepiCloudRoot);
  static String get documentsS3FoldersContents => _path(Config.pathDocumentsS3FoldersContents);

  static String get documentsMobileAnalyze => _path(Config.pathDocumentsMobileAnalyze);
  static String get documentsMobileSaveAnalyzed => _path(Config.pathDocumentsMobileSaveAnalyzed);
}
