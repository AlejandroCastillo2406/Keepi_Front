import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/patient_export_folder.dart';
import 'api_client.dart';
import 'document_bytes_loader.dart';
import 'document_file_opener.dart';
import 'doctor_service.dart';
import 'drive_structure_service.dart';

class ZipExportResult {
  const ZipExportResult({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}

/// Descarga uno o varios archivos y los empaqueta en un ZIP.
class DocumentExportService {
  DocumentExportService(this._api);

  final ApiClient _api;
  late final DriveStructureService _drive = DriveStructureService(_api);
  late final DoctorService _doctor = DoctorService(_api);

  static String safeFileName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'documento';
    return trimmed.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  /// Sanitiza cada segmento de la ruta sin perder las carpetas del ZIP.
  static String sanitizeZipPath(String path) {
    final parts = path
        .replaceAll('\\', '/')
        .split('/')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '';
    return parts.map(safeFileName).join('/');
  }

  static String _zipDirPath(String path) {
    final normalized = sanitizeZipPath(path);
    if (normalized.isEmpty) return '';
    return normalized.endsWith('/') ? normalized : '$normalized/';
  }

  Future<Uint8List> downloadFileBytes(DriveFile file) async {
    if (DocumentFileOpener.isS3Path(file.id)) {
      final info = await _drive.getS3FileViewUrl(file.id);
      if (info.viewUrl.isEmpty) {
        throw Exception('No se pudo obtener el enlace del archivo en la nube.');
      }
      return DocumentBytesLoader.fetch(url: info.viewUrl);
    }

    final docId = _resolveDocumentId(file);
    if (docId != null) {
      final token = _api.accessToken;
      final headers = <String, String>{'Accept': '*/*'};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      return DocumentBytesLoader.fetch(
        url: _doctor.getMobileDocumentUrl(docId),
        headers: headers,
      );
    }

    final bytes = await _drive.downloadFileContent(file.id);
    if (bytes.isEmpty) {
      throw Exception('El archivo está vacío o no está disponible.');
    }
    return Uint8List.fromList(bytes);
  }

  String? _resolveDocumentId(DriveFile file) {
    if (DocumentFileOpener.isDocumentUuid(file.id)) return file.id;
    final kid = file.keepiDocumentId;
    if (kid != null &&
        kid.isNotEmpty &&
        DocumentFileOpener.isDocumentUuid(kid)) {
      return kid;
    }
    return null;
  }

  Future<({List<({DriveFile file, String archivePath})> files, Set<String> dirs})>
      collectFilesUnderS3Folder(
    String s3FolderPath, {
    required String zipPrefix,
  }) async {
    final path = s3FolderPath.endsWith('/')
        ? s3FolderPath.substring(0, s3FolderPath.length - 1)
        : s3FolderPath;
    final data = await _drive.getS3FolderContents(path);
    final files = <({DriveFile file, String archivePath})>[];
    final dirs = <String>{};

    final prefix = _zipDirPath(zipPrefix);
    if (prefix.isNotEmpty) dirs.add(prefix);

    for (final file in data.files) {
      files.add((
        file: file,
        archivePath: '$prefix${safeFileName(file.name)}',
      ));
    }
    for (final sub in data.folders) {
      final subName = safeFileName(sub.name);
      final subZipPath = '$prefix$subName/';
      dirs.add(subZipPath);

      final subPath = sub.id.startsWith('users/')
          ? sub.id
          : '$path/${sub.name}';
      final nested = await collectFilesUnderS3Folder(
        subPath,
        zipPrefix: subZipPath,
      );
      files.addAll(nested.files);
      dirs.addAll(nested.dirs);
    }
    return (files: files, dirs: dirs);
  }

  Future<ZipExportResult> exportPatientFoldersToZip({
    required List<PatientExportFolder> folders,
    void Function(int current, int total, String label)? onProgress,
  }) async {
    if (folders.isEmpty) {
      throw ArgumentError('Selecciona al menos un paciente.');
    }

    final entries = <({DriveFile file, String archivePath})>[];
    final directoryPaths = <String>{};
    for (final folder in folders) {
      final prefix = safeFileName(folder.patientName);
      final collected = await collectFilesUnderS3Folder(
        folder.s3FolderPath,
        zipPrefix: prefix,
      );
      entries.addAll(collected.files);
      directoryPaths.addAll(collected.dirs);
    }

    if (entries.isEmpty) {
      throw Exception(
        'Los pacientes seleccionados no tienen archivos para exportar.',
      );
    }

    return exportEntriesToZip(
      entries: entries,
      directoryPaths: directoryPaths,
      zipBaseName: folders.length == 1
          ? folders.first.patientName
          : 'Expedientes_Keepi',
      onProgress: onProgress,
    );
  }

  Future<ZipExportResult> exportToZip({
    required List<DriveFile> files,
    String? zipBaseName,
    void Function(int current, int total, String fileName)? onProgress,
  }) async {
    if (files.isEmpty) {
      throw ArgumentError('Selecciona al menos un archivo para exportar.');
    }
    final entries = files
        .map((f) => (file: f, archivePath: safeFileName(f.name)))
        .toList();
    return exportEntriesToZip(
      entries: entries,
      zipBaseName: zipBaseName,
      onProgress: onProgress,
    );
  }

  Future<ZipExportResult> exportEntriesToZip({
    required List<({DriveFile file, String archivePath})> entries,
    Set<String> directoryPaths = const {},
    String? zipBaseName,
    void Function(int current, int total, String label)? onProgress,
  }) async {
    final archive = Archive();
    final usedNames = <String, int>{};

    final dirs = directoryPaths
        .map(_zipDirPath)
        .where((d) => d.isNotEmpty)
        .toSet()
      ..addAll(
        entries.map((e) {
          final parts = sanitizeZipPath(e.archivePath).split('/');
          if (parts.length <= 1) return '';
          return '${parts.sublist(0, parts.length - 1).join('/')}/';
        }).where((d) => d.isNotEmpty),
      );

    for (final dir in dirs) {
      archive.addFile(ArchiveFile.directory(dir));
    }

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      onProgress?.call(i + 1, entries.length, entry.archivePath);
      final bytes = await downloadFileBytes(entry.file);
      final entryName = _uniqueZipPath(entry.archivePath, usedNames);
      archive.addFile(ArchiveFile(entryName, bytes.length, bytes));
    }

    final encoded = ZipEncoder().encode(archive);
    if (encoded.isEmpty) {
      throw Exception('No se pudo generar el archivo ZIP.');
    }

    final stamp = DateTime.now();
    final base = safeFileName(zipBaseName ?? 'Keepi_export');
    final zipName =
        '${base}_${stamp.year}${stamp.month.toString().padLeft(2, '0')}${stamp.day.toString().padLeft(2, '0')}_${stamp.hour.toString().padLeft(2, '0')}${stamp.minute.toString().padLeft(2, '0')}.zip';
    return ZipExportResult(bytes: Uint8List.fromList(encoded), fileName: zipName);
  }

  String _uniqueZipPath(String archivePath, Map<String, int> used) {
    final normalized = sanitizeZipPath(archivePath);
    if (normalized.isEmpty) return 'documento';

    final parts = normalized.split('/');
    final fileName = parts.removeLast();
    final dirPrefix = parts.isEmpty ? '' : '${parts.join('/')}/';

    final ext = _splitExt(fileName);
    var stem = ext.$1;
    final extension = ext.$2;
    if (stem.isEmpty) stem = 'documento';

    var n = 0;
    while (true) {
      final candidateFile = n == 0
          ? (extension.isEmpty ? stem : '$stem$extension')
          : (extension.isEmpty ? '${stem}_$n' : '${stem}_$n$extension');
      final fullPath = '$dirPrefix$candidateFile';
      if (!used.containsKey(fullPath)) {
        used[fullPath] = 1;
        return fullPath;
      }
      n += 1;
    }
  }

  (String, String) _splitExt(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return (name, '');
    return (name.substring(0, dot), name.substring(dot));
  }
}
