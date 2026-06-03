/// Misma lógica que `sanitize_storage_segment` del backend.
String sanitizePatientFolderName(String name) {
  var raw = name.trim();
  if (raw.isEmpty) raw = 'paciente';

  final buffer = StringBuffer();
  for (final codeUnit in raw.runes) {
    if (codeUnit <= 127) {
      buffer.writeCharCode(codeUnit);
    }
  }
  var ascii = buffer.toString().trim();
  if (ascii.isEmpty) ascii = raw;

  ascii = ascii.replaceAll(RegExp(r'[^a-zA-Z0-9\-_]'), '_');
  ascii = ascii.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
  if (ascii.isEmpty) ascii = 'paciente';
  if (ascii.length > 50) ascii = ascii.substring(0, 50);
  return ascii;
}

const patientSubfolderNames = <String>{
  'Analisis',
  'Recetas',
  'Documentos_Previos',
};

const reservedRootFolderNames = <String>{
  'Documentos_Personales',
  'Analisis',
  'Recetas',
  'Documentos_Previos',
  'recetas',
};
