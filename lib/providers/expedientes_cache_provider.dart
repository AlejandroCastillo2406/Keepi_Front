import 'package:flutter/foundation.dart';

import '../services/config_service.dart' as config_dto;
import '../services/drive_structure_service.dart';

/// Datos cacheados de la raíz de Expedientes / documentos.
class ExpedientesRootSnapshot {
  const ExpedientesRootSnapshot({
    required this.config,
    required this.folders,
    required this.rootFiles,
    required this.alerts,
    required this.totalKeepi,
    required this.alertsCount,
    required this.alertsExpiredCount,
    required this.requiresDriveAuth,
    required this.loadedAt,
    this.authorizationUrl,
  });

  final config_dto.UserConfigResponse config;
  final List<DriveFolder> folders;
  final List<DriveFile> rootFiles;
  final List<DocumentAlertItem> alerts;
  final int totalKeepi;
  final int alertsCount;
  final int alertsExpiredCount;
  final bool requiresDriveAuth;
  final String? authorizationUrl;
  final DateTime loadedAt;
}

/// Caché en memoria de expedientes (raíz + contenido por carpeta).
class ExpedientesCacheProvider extends ChangeNotifier {
  ExpedientesRootSnapshot? _root;
  final Map<String, DriveFolderContentsResponse> _folders = {};

  ExpedientesRootSnapshot? get rootSnapshot => _root;

  DriveFolderContentsResponse? peekFolder(String folderId) =>
      _folders[folderId];

  /// Guarda raíz vacía (sin almacenamiento configurado).
  void putRootEmpty(config_dto.UserConfigResponse config) {
    _root = ExpedientesRootSnapshot(
      config: config,
      folders: const [],
      rootFiles: const [],
      alerts: const [],
      totalKeepi: 0,
      alertsCount: 0,
      alertsExpiredCount: 0,
      requiresDriveAuth: false,
      loadedAt: DateTime.now(),
    );
    notifyListeners();
  }

  /// Guarda raíz con error de almacenamiento no soportado.
  void putRootUnsupported(config_dto.UserConfigResponse config) {
    putRootEmpty(config);
  }

  Future<ExpedientesRootSnapshot> fetchAndCacheRoot({
    required config_dto.UserConfigResponse config,
    required DriveStructureService driveSvc,
    required String? userId,
  }) async {
    final dashboard = await driveSvc.getMobileDashboard();

    var folders = dashboard.folders;
    var rootFiles = dashboard.rootFiles;

    if (config.isKeepiCloud) {
      try {
        final rootRes = await driveSvc.getKeepiCloudRoot();
        folders = rootRes.folders;
        rootFiles = rootRes.rootFiles;
      } catch (_) {}
    }

    if (config.isKeepiCloud && userId != null) {
      folders = folders
          .where(
            (f) =>
                f.id != 'users/$userId' &&
                f.id != 'users/$userId/',
          )
          .toList();
    }

    _root = ExpedientesRootSnapshot(
      config: config,
      folders: folders,
      rootFiles: rootFiles,
      alerts: dashboard.alerts,
      totalKeepi: dashboard.totalKeepi,
      alertsCount: dashboard.alertsCount,
      alertsExpiredCount: dashboard.alertsExpiredCount,
      requiresDriveAuth: dashboard.requiresDriveAuth,
      authorizationUrl: dashboard.authorizationUrl,
      loadedAt: DateTime.now(),
    );
    notifyListeners();
    return _root!;
  }

  Future<DriveFolderContentsResponse> fetchAndCacheFolder({
    required DriveStructureService driveSvc,
    required String folderId,
    required bool isS3,
    bool force = false,
  }) async {
    if (!force) {
      final cached = _folders[folderId];
      if (cached != null) return cached;
    }

    final data = isS3
        ? await driveSvc.getS3FolderContents(folderId)
        : await driveSvc.getFolderContents(folderId);
    _folders[folderId] = data;
    notifyListeners();
    return data;
  }

  void invalidateRoot() {
    if (_root == null) return;
    _root = null;
    notifyListeners();
  }

  void invalidateFolder(String folderId) {
    if (_folders.remove(folderId) != null) {
      notifyListeners();
    }
  }

  void clear() {
    final hadData = _root != null || _folders.isNotEmpty;
    _root = null;
    _folders.clear();
    if (hadData) notifyListeners();
  }
}
