import '../core/keepi_timezone.dart';

/// Etiquetas de fecha/hora legibles usando la zona guardada al iniciar sesión.
String? formatKeepiDate(String? raw) {
  final dt = KeepiTimezone.parseUser(raw);
  if (dt == null) return null;
  return KeepiTimezone.formatUserDate(dt);
}

String? formatKeepiDateTime(String? raw) {
  final dt = KeepiTimezone.parseUser(raw);
  if (dt == null) return null;
  return KeepiTimezone.formatUserDateTime(dt);
}
