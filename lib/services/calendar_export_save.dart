import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'document_export_save_stub.dart'
    if (dart.library.html) 'document_export_save_web.dart';

/// Guarda o descarga un archivo `.ics` en el dispositivo del usuario.
class CalendarExportSave {
  static Future<String?> promptSaveIcs({
    required Uint8List bytes,
    required String fileName,
  }) async {
    var name = fileName.trim();
    if (name.isEmpty) name = 'keepi-agenda.ics';
    if (!name.toLowerCase().endsWith('.ics')) name = '$name.ics';

    if (kIsWeb) {
      await downloadFileInBrowser(bytes, name, mimeType: 'text/calendar');
      return name;
    }

    return FilePicker.platform.saveFile(
      dialogTitle: '¿Dónde quieres guardar el calendario?',
      fileName: name,
      type: FileType.custom,
      allowedExtensions: const ['ics'],
      bytes: bytes,
    );
  }
}
