import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Abre el diálogo del sistema para elegir carpeta/nombre del ZIP exportado.
class DocumentExportSave {
  /// Devuelve la ruta elegida por el usuario, o `null` si canceló.
  static Future<String?> promptSaveZip({
    required Uint8List bytes,
    required String fileName,
  }) async {
    var name = fileName.trim();
    if (name.isEmpty) name = 'Expedientes_Keepi.zip';
    if (!name.toLowerCase().endsWith('.zip')) name = '$name.zip';

    return FilePicker.platform.saveFile(
      dialogTitle: '¿Dónde quieres guardar el expediente?',
      fileName: name,
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      bytes: bytes,
    );
  }
}
