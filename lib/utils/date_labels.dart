/// Etiquetas de fecha/hora legibles para la UI (zona horaria local).
String? formatKeepiDate(String? raw) {
  final trimmed = raw?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final dt = DateTime.tryParse(trimmed)?.toLocal();
  if (dt == null) return null;
  final day = dt.day.toString().padLeft(2, '0');
  final month = dt.month.toString().padLeft(2, '0');
  return '$day/$month/${dt.year}';
}

String? formatKeepiDateTime(String? raw) {
  final trimmed = raw?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final dt = DateTime.tryParse(trimmed)?.toLocal();
  if (dt == null) return null;
  final day = dt.day.toString().padLeft(2, '0');
  final month = dt.month.toString().padLeft(2, '0');
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$day/$month/${dt.year} · $hour:$minute';
}
