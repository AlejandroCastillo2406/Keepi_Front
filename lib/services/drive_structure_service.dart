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

/// Respuesta de GET /api/v1/documents/mobile/dashboard (KPIs + carpetas + alertas)
class MobileDashboardResponse {
  MobileDashboardResponse({
    required this.folders,
    required this.totalKeepi,
    required this.alertsCount,
    required this.alertsExpiredCount,
    required this.alertsExpiringCount,
    required this.alerts,
    this.rootFiles = const [],
    this.requiresDriveAuth = false,
    this.requiresAction,
    this.authorizationUrl,
    this.storagePreference,
  });

  final List<DriveFolder> folders;
  final int totalKeepi;
  final int alertsCount;
  final int alertsExpiredCount;
  final int alertsExpiringCount;
  final List<DocumentAlertItem> alerts;
  final List<DriveFile> rootFiles;
  final bool requiresDriveAuth;
  final String? requiresAction;
  final String? authorizationUrl;
  final String? storagePreference;

  /// Compatibilidad con código anterior.
  int get expiringSoonCount => alertsCount;
  List<DocumentAlertItem> get expiringSoon => alerts;

  factory MobileDashboardResponse.fromJson(Map<String, dynamic> json) {
    final list = json['folders'] as List<dynamic>? ?? [];
    final alertsList =
        json['alerts'] as List<dynamic>? ?? json['expiring_soon'] as List<dynamic>? ?? [];
    final rootList = json['root_files'] as List<dynamic>? ?? [];
    final alerts = alertsList
        .map((e) => DocumentAlertItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return MobileDashboardResponse(
      folders: list
          .map((e) => DriveFolder.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalKeepi: (json['total_keepi'] as num?)?.toInt() ?? 0,
      alertsCount: (json['alerts_count'] as num?)?.toInt() ??
          (json['expiring_soon_count'] as num?)?.toInt() ??
          alerts.length,
      alertsExpiredCount: (json['alerts_expired_count'] as num?)?.toInt() ??
          alerts.where((a) => a.isExpired).length,
      alertsExpiringCount: (json['alerts_expiring_count'] as num?)?.toInt() ??
          alerts.where((a) => a.isExpiringSoon).length,
      alerts: alerts,
      rootFiles: rootList
          .map((e) => DriveFile.fromJson(e as Map<String, dynamic>))
          .toList(),
      requiresDriveAuth: json['requires_drive_auth'] as bool? ?? false,
      requiresAction: json['requires_action'] as String?,
      authorizationUrl: json['authorization_url'] as String?,
      storagePreference: json['storage_preference'] as String?,
    );
  }
}

enum DocumentAlertStatus { expired, expiringSoon }

class DocumentAlertItem {
  DocumentAlertItem({
    required this.id,
    required this.name,
    required this.status,
    this.expiryDate,
    this.category,
    this.fileName,
    this.cloudProvider,
    this.canReplace = true,
  });

  final String id;
  final String name;
  final DocumentAlertStatus status;
  final String? expiryDate;
  final String? category;
  final String? fileName;
  final String? cloudProvider;
  final bool canReplace;

  bool get isExpired => status == DocumentAlertStatus.expired;
  bool get isExpiringSoon => status == DocumentAlertStatus.expiringSoon;

  String? get keepiDocumentId => id.isNotEmpty ? id : null;
  bool get canEditMetadata => true;

  factory DocumentAlertItem.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['alert_status']?.toString() ?? '';
    final status = rawStatus == 'expired'
        ? DocumentAlertStatus.expired
        : DocumentAlertStatus.expiringSoon;
    final expiry = json['expiry_date'];
    return DocumentAlertItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Documento',
      status: status,
      expiryDate: expiry?.toString(),
      category: json['category']?.toString(),
      fileName: json['file_name']?.toString(),
      cloudProvider: json['cloud_provider']?.toString(),
      canReplace: json['can_replace'] as bool? ?? true,
    );
  }
}

/// Alias legacy.
typedef ExpiringDocumentItem = DocumentAlertItem;

class DocumentMetadataDto {
  DocumentMetadataDto({
    required this.id,
    required this.name,
    required this.category,
    this.fileName,
    this.storageFileName,
    this.cloudProvider,
    this.description,
    this.expiryDate,
    this.documentNumber,
    this.organization,
    this.isReplaced = false,
    this.replacedByName,
    this.replacedByCategory,
    this.isReplacement = false,
    this.replacesDocumentName,
    this.replacesDocumentCategory,
  });

  final String id;
  final String name;
  final String category;
  final String? fileName;
  /// Nombre actual del archivo en Drive o Keepi Cloud (S3).
  final String? storageFileName;
  final String? cloudProvider;
  final String? description;
  final String? expiryDate;
  final String? documentNumber;
  final String? organization;
  final bool isReplaced;
  final String? replacedByName;
  final String? replacedByCategory;
  final bool isReplacement;
  final String? replacesDocumentName;
  final String? replacesDocumentCategory;

  bool get isKeepiCloud => cloudProvider == 'keepi_cloud';
  bool get isGoogleDrive => cloudProvider == 'google_drive';

  factory DocumentMetadataDto.fromJson(Map<String, dynamic> json) {
    return DocumentMetadataDto(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      fileName: json['file_name']?.toString(),
      storageFileName: json['storage_file_name']?.toString(),
      cloudProvider: json['cloud_provider']?.toString(),
      description: json['description']?.toString(),
      expiryDate: json['expiry_date']?.toString(),
      documentNumber: json['document_number']?.toString(),
      organization: json['organization']?.toString(),
      isReplaced: json['is_replaced'] == true,
      replacedByName: json['replaced_by_name']?.toString(),
      replacedByCategory: json['replaced_by_category']?.toString(),
      isReplacement: json['is_replacement'] == true,
      replacesDocumentName: json['replaces_document_name']?.toString(),
      replacesDocumentCategory: json['replaces_document_category']?.toString(),
    );
  }
}

class DocumentMetadataUpdate {
  DocumentMetadataUpdate({
    this.name,
    this.fileName,
    this.category,
    this.description,
    this.expiryDate,
    this.documentNumber,
    this.organization,
  });

  final String? name;
  final String? fileName;
  final String? category;
  final String? description;
  final String? expiryDate;
  final String? documentNumber;
  final String? organization;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (name != null) map['name'] = name;
    if (fileName != null) map['file_name'] = fileName;
    if (category != null) map['category'] = category;
    if (description != null) map['description'] = description;
    if (expiryDate != null) map['expiry_date'] = expiryDate;
    if (documentNumber != null) map['document_number'] = documentNumber;
    if (organization != null) map['organization'] = organization;
    return map;
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
    this.keepiDocumentId,
    this.canEditMetadata = false,
    this.category,
    this.description,
    this.expiryDate,
    this.documentNumber,
    this.organization,
    this.isReplaced = false,
    this.replacedByName,
    this.replacedByCategory,
    this.isReplacement = false,
    this.replacesDocumentName,
    this.replacesDocumentCategory,
  });

  final String id;
  final String name;
  final String? size;
  final String? mimeType;
  final String? createdTime;
  final String? modifiedTime;
  final bool keepiVerified;
  final String? keepiDocumentId;
  final bool canEditMetadata;
  final String? category;
  final String? description;
  final String? expiryDate;
  final String? documentNumber;
  final String? organization;
  final bool isReplaced;
  final String? replacedByName;
  final String? replacedByCategory;
  final bool isReplacement;
  final String? replacesDocumentName;
  final String? replacesDocumentCategory;

  String? get editableDocumentId => keepiDocumentId;

  factory DriveFile.fromJson(Map<String, dynamic> json) {
    final size = json['size'];
    final keepiDocId = json['keepi_document_id']?.toString();
    return DriveFile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Archivo',
      size: size?.toString(),
      mimeType: json['mime_type'] as String?,
      createdTime: json['created_time'] as String?,
      modifiedTime: json['modified_time'] as String?,
      keepiVerified: json['keepi_verified'] as bool? ?? false,
      keepiDocumentId: keepiDocId,
      canEditMetadata:
          json['can_edit_metadata'] as bool? ?? (keepiDocId != null && keepiDocId.isNotEmpty),
      category: json['category']?.toString(),
      description: json['description']?.toString(),
      expiryDate: json['expiry_date']?.toString(),
      documentNumber: json['document_number']?.toString(),
      organization: json['organization']?.toString(),
      isReplaced: json['is_replaced'] == true,
      replacedByName: json['replaced_by_name']?.toString(),
      replacedByCategory: json['replaced_by_category']?.toString(),
      isReplacement: json['is_replacement'] == true,
      replacesDocumentName: json['replaces_document_name']?.toString(),
      replacesDocumentCategory: json['replaces_document_category']?.toString(),
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

  Future<DocumentMetadataDto> fetchDocumentMetadata(String documentId) async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      ApiEndpoints.documentsMobileMetadataById(documentId),
    );
    return DocumentMetadataDto.fromJson(res.data!);
  }

  Future<DocumentMetadataDto> updateDocumentMetadata(
    String documentId,
    DocumentMetadataUpdate body,
  ) async {
    final res = await _api.dio.patch<Map<String, dynamic>>(
      ApiEndpoints.documentsMobileMetadataById(documentId),
      data: body.toJson(),
    );
    return DocumentMetadataDto.fromJson(res.data!);
  }

  Future<DriveFileViewInfo> getS3FileViewUrl(String path) async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      ApiEndpoints.documentsS3FileViewUrl,
      queryParameters: {'path': path},
    );
    return DriveFileViewInfo.fromJson(res.data!);
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
