import 'package:dio/dio.dart';

import '../core/api_endpoints.dart';
import 'api_client.dart';

/// Respuesta de GET /api/v1/documents/drive/structure
class DriveStructureResponse {
  DriveStructureResponse({required this.folders});
  final List<DriveFolder> folders;

  factory DriveStructureResponse.fromJson(Map<String, dynamic> json) {
    final list = json['folders'] as List<dynamic>? ?? [];
    return DriveStructureResponse(
      folders: list
          .map((e) => DriveFolder.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DriveFolder {
  DriveFolder({
    required this.id,
    required this.name,
    this.createdTime,
    this.modifiedTime,
    this.filesCount = 0,
  });

  final String id;
  final String name;
  final String? createdTime;
  final String? modifiedTime;
  final int filesCount;

  factory DriveFolder.fromJson(Map<String, dynamic> json) {
    return DriveFolder(
      id: json['id'] as String,
      name: json['name'] as String,
      createdTime: json['created_time'] as String?,
      modifiedTime: json['modified_time'] as String?,
      filesCount:
          (json['files_count'] ?? json['document_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Respuesta de GET /api/v1/documents/mobile/dashboard (KPIs + carpetas + próximos a vencer)
class MobileDashboardResponse {
  MobileDashboardResponse({
    required this.folders,
    required this.totalKeepi,
    required this.expiringSoonCount,
    required this.expiringSoon,
    this.rootFiles = const [],
    this.requiresDriveAuth = false,
    this.requiresAction,
    this.authorizationUrl,
  });

  final List<DriveFolder> folders;
  final int totalKeepi;
  final int expiringSoonCount;
  final List<ExpiringDocumentItem> expiringSoon;
  final List<DriveFile> rootFiles;
  final bool requiresDriveAuth;
  final String? requiresAction;
  final String? authorizationUrl;

  factory MobileDashboardResponse.fromJson(Map<String, dynamic> json) {
    final list = json['folders'] as List<dynamic>? ?? [];
    final expiringList = json['expiring_soon'] as List<dynamic>? ?? [];
    final rootList = json['root_files'] as List<dynamic>? ?? [];
    return MobileDashboardResponse(
      folders: list
          .map((e) => DriveFolder.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalKeepi: (json['total_keepi'] as num?)?.toInt() ?? 0,
      expiringSoonCount: (json['expiring_soon_count'] as num?)?.toInt() ?? 0,
      expiringSoon: expiringList
          .map((e) => ExpiringDocumentItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      rootFiles: rootList
          .map((e) => DriveFile.fromJson(e as Map<String, dynamic>))
          .toList(),
      requiresDriveAuth: json['requires_drive_auth'] as bool? ?? false,
      requiresAction: json['requires_action'] as String?,
      authorizationUrl: json['authorization_url'] as String?,
    );
  }
}

class ExpiringDocumentItem {
  ExpiringDocumentItem({
    required this.id,
    required this.name,
    this.expiryDate,
    this.category,
    this.fileName,
  });

  final String id;
  final String name;
  final String? expiryDate;
  final String? category;
  final String? fileName;

  factory ExpiringDocumentItem.fromJson(Map<String, dynamic> json) {
    final expiry = json['expiry_date'];
    return ExpiringDocumentItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      expiryDate: expiry?.toString(),
      category: json['category'] as String?,
      fileName: json['file_name'] as String?,
    );
  }
}

/// Archivo en Google Drive (GET .../folders/{id}/contents)
class DriveFile {
  DriveFile({
    required this.id,
    required this.name,
    this.size,
    this.mimeType,
    this.createdTime,
    this.modifiedTime,
    this.keepiVerified = false,
  });

  final String id;
  final String name;
  final String? size;
  final String? mimeType;
  final String? createdTime;
  final String? modifiedTime;
  final bool keepiVerified;

  factory DriveFile.fromJson(Map<String, dynamic> json) {
    final size = json['size'];
    return DriveFile(
      id: json['id'] as String,
      name: json['name'] as String,
      size: size?.toString(),
      mimeType: json['mime_type'] as String?,
      createdTime: json['created_time'] as String?,
      modifiedTime: json['modified_time'] as String?,
      keepiVerified: json['keepi_verified'] as bool? ?? false,
    );
  }
}

/// Respuesta de GET /api/v1/documents/drive/folders/{folder_id}/contents
class DriveFolderContentsResponse {
  DriveFolderContentsResponse({
    required this.folder,
    required this.folders,
    required this.files,
  });

  final DriveFolderInfo folder;
  final List<DriveFolder> folders;
  final List<DriveFile> files;

  factory DriveFolderContentsResponse.fromJson(Map<String, dynamic> json) {
    final folderJson = json['folder'] as Map<String, dynamic>?;
    final folder = folderJson != null
        ? DriveFolderInfo.fromJson(folderJson)
        : DriveFolderInfo(id: 'root', name: 'Mi unidad');
    final foldersList = json['folders'] as List<dynamic>? ?? [];
    final filesList = json['files'] as List<dynamic>? ?? [];
    return DriveFolderContentsResponse(
      folder: folder,
      folders: foldersList
          .map((e) => DriveFolder.fromJson(e as Map<String, dynamic>))
          .toList(),
      files: filesList
          .map((e) => DriveFile.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DriveFolderInfo {
  DriveFolderInfo({required this.id, required this.name});
  final String id;
  final String name;

  factory DriveFolderInfo.fromJson(Map<String, dynamic> json) {
    return DriveFolderInfo(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }
}

class DriveStructureService {
  DriveStructureService(this._api);
  final ApiClient _api;

  Future<DriveStructureResponse> getStructure() async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      ApiEndpoints.documentsDriveStructure,
    );
    return DriveStructureResponse.fromJson(res.data!);
  }

  Future<MobileDashboardResponse> getMobileDashboard() async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      ApiEndpoints.documentsMobileDashboard,
    );
    return MobileDashboardResponse.fromJson(res.data!);
  }

  Future<DriveFolderContentsResponse> getFolderContents(String folderId) async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      ApiEndpoints.documentsDriveFolderContents(folderId),
    );
    return DriveFolderContentsResponse.fromJson(res.data!);
  }

  Future<DriveFileViewInfo> getFileViewUrl(String fileId) async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      ApiEndpoints.documentsDriveFileViewUrl(fileId),
    );
    return DriveFileViewInfo.fromJson(res.data!);
  }

  Future<List<int>> downloadFileContent(String fileId) async {
    final res = await _api.dio.get<List<int>>(
      ApiEndpoints.documentsDriveFileContent(fileId),
      options: Options(responseType: ResponseType.bytes),
    );
    return res.data ?? [];
  }

  Future<void> deleteFile(String fileId) async {
    await _api.dio.delete(ApiEndpoints.documentsDriveFileDelete(fileId));
  }

  Future<DriveFolderContentsResponse> getS3FolderContents(String path) async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      ApiEndpoints.documentsS3FoldersContents,
      queryParameters: {'path': path},
    );
    return DriveFolderContentsResponse.fromJson(res.data!);
  }

  Future<KeepiCloudRootResponse> getKeepiCloudRoot() async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      ApiEndpoints.documentsKeepiCloudRoot,
    );
    return KeepiCloudRootResponse.fromJson(res.data!);
  }
}

/// Respuesta de GET /api/v1/documents/keepi-cloud/root
class KeepiCloudRootResponse {
  KeepiCloudRootResponse({
    this.folders = const [],
    this.rootFiles = const [],
  });

  final List<DriveFolder> folders;
  final List<DriveFile> rootFiles;

  factory KeepiCloudRootResponse.fromJson(Map<String, dynamic> json) {
    final list = json['folders'] as List<dynamic>? ?? [];
    final rootList = json['root_files'] as List<dynamic>? ?? [];
    return KeepiCloudRootResponse(
      folders: list
          .map((e) => DriveFolder.fromJson(e as Map<String, dynamic>))
          .toList(),
      rootFiles: rootList
          .map((e) => DriveFile.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DriveFileViewInfo {
  DriveFileViewInfo({
    required this.viewUrl,
    required this.downloadUrl,
    required this.name,
    this.mimeType,
  });

  final String viewUrl;
  final String downloadUrl;
  final String name;
  final String? mimeType;

  factory DriveFileViewInfo.fromJson(Map<String, dynamic> json) {
    return DriveFileViewInfo(
      viewUrl: json['view_url'] as String? ?? '',
      downloadUrl: json['download_url'] as String? ?? '',
      name: json['name'] as String? ?? '',
      mimeType: json['mime_type'] as String?,
    );
  }
}
