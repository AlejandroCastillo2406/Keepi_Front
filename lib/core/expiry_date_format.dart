/// Formatea `expiry_date` ISO usando solo la fecha calendario (sin `.toLocal()`),
/// para evitar mostrar un día menos en zonas UTC−X (ej. 21 may UTC → 20 may local).
String formatExpiryDateForDisplay(String? isoDate) {
  if (isoDate == null || isoDate.isEmpty) {
    return '—';
  }
  try {
    final datePart = isoDate.split('T').first.trim();
    final parts = datePart.split('-');
    if (parts.length != 3) return isoDate;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null ||
        month == null ||
        day == null ||
        month < 1 ||
        month > 12) {
      return isoDate;
    }
    const months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return '$day ${months[month - 1]} $year';
  } catch (_) {
    return isoDate;
  }
}

/// Versión corta para listas compactas (ej. alertas).
String formatExpiryDateShort(String? isoDate) {
  if (isoDate == null || isoDate.isEmpty) return '—';
  try {
    final datePart = isoDate.split('T').first.trim();
    final parts = datePart.split('-');
    if (parts.length != 3) return isoDate;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null || month < 1 || month > 12) {
      return isoDate;
    }
    const months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return '${day.toString().padLeft(2, '0')} ${months[month - 1]} $year';
  } catch (_) {
    return isoDate;
  }
}
