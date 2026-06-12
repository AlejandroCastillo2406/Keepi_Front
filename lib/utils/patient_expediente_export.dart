import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/patient_export_folder.dart';
import '../services/api_client.dart';
import '../services/document_export_save.dart';
import '../services/document_export_service.dart';
import '../utils/patient_folder_name.dart';

Future<void> exportPatientExpedienteZip({
  required BuildContext context,
  required ApiClient api,
  required String doctorId,
  required String patientId,
  required String patientName,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final folderKey = sanitizePatientFolderName(patientName);
  final s3Path = 'users/$doctorId/$folderKey';

  messenger.showSnackBar(
    const SnackBar(
      content: Text('Preparando expediente…'),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 2),
    ),
  );

  final zip = await DocumentExportService(api).exportPatientFoldersToZip(
    folders: [
      PatientExportFolder(
        patientId: patientId,
        patientName: patientName,
        s3FolderPath: s3Path,
        filesCount: 0,
      ),
    ],
    onProgress: (current, total, label) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Descargando $current/$total: $label'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    },
  );

  if (!context.mounted) return;

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    const SnackBar(
      content: Text('Elige dónde guardar el archivo…'),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 2),
    ),
  );

  final savedPath = await DocumentExportSave.promptSaveZip(
    bytes: zip.bytes,
    fileName: zip.fileName,
  );

  if (!context.mounted) return;

  if (savedPath == null || savedPath.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Exportación cancelada.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  messenger.showSnackBar(
    SnackBar(
      content: Text(
        kIsWeb
            ? 'Expediente descargado: $savedPath'
            : 'Expediente guardado en:\n$savedPath',
      ),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5),
    ),
  );
}
