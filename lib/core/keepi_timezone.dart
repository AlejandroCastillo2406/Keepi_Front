import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Zona horaria del usuario guardada al iniciar sesión (SharedPreferences / localStorage).
class KeepiTimezone {
  KeepiTimezone._();

  static const prefsKey = 'keepi_timezone';
  static const fallbackIana = 'America/Mexico_City';

  static String _ianaId = fallbackIana;
  static bool _initialized = false;

  static String get ianaId => _ianaId;

  static Future<void> init(SharedPreferences prefs) async {
    if (!_initialized) {
      tz_data.initializeTimeZones();
      _initialized = true;
    }
    final stored = prefs.getString(prefsKey)?.trim();
    if (stored != null && stored.isNotEmpty) {
      _ianaId = stored;
      return;
    }
    _ianaId = await detectDeviceTimezone();
  }

  /// Detecta la zona del dispositivo/navegador y la persiste.
  static Future<void> captureAndSave(SharedPreferences prefs) async {
    if (!_initialized) {
      tz_data.initializeTimeZones();
      _initialized = true;
    }
    _ianaId = await detectDeviceTimezone();
    await prefs.setString(prefsKey, _ianaId);
  }

  static Future<String> detectDeviceTimezone() async {
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      if (name.trim().isNotEmpty) return name.trim();
    } catch (_) {}
    return fallbackIana;
  }

  static tz.Location get _location {
    try {
      return tz.getLocation(_ianaId);
    } catch (_) {
      return tz.getLocation(fallbackIana);
    }
  }

  static DateTime _asNaiveLocal(tz.TZDateTime value) {
    return DateTime(
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
      value.second,
      value.millisecond,
      value.microsecond,
    );
  }

  /// Timestamps UTC del servidor → zona guardada al iniciar sesión.
  static DateTime toUserLocal(DateTime value) {
    if (!value.isUtc) return value;
    return _asNaiveLocal(tz.TZDateTime.from(value, _location));
  }

  /// Citas, procedimientos y slots de agenda.
  /// Los [DateTime] creados en el picker (no UTC) se dejan tal cual.
  static DateTime scheduleLocal(DateTime value) {
    if (!value.isUtc) return value;
    return toUserLocal(value);
  }

  static DateTime? parseUser(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(raw.trim());
    if (parsed == null) return null;
    return parsed.isUtc ? toUserLocal(parsed) : parsed;
  }

  static DateTime? parseSchedule(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(raw.trim());
    if (parsed == null) return null;
    return scheduleLocal(parsed);
  }

  static String formatScheduleTime(DateTime value) {
    final local = scheduleLocal(value);
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  static String formatUserDate(DateTime value) {
    final local = value.isUtc ? toUserLocal(value) : value;
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }

  static String formatUserDateTime(DateTime value) {
    final local = value.isUtc ? toUserLocal(value) : value;
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} · $hour:$minute';
  }

  static bool isSameScheduleDay(DateTime scheduleInstant, DateTime day) {
    final local = scheduleLocal(scheduleInstant);
    return local.year == day.year &&
        local.month == day.month &&
        local.day == day.day;
  }

  /// Hora actual en la zona guardada (solo componentes de calendario).
  static DateTime nowInSavedZone() {
    return _asNaiveLocal(tz.TZDateTime.now(_location));
  }

  static DateTime startOfTodayInSavedZone() {
    final now = nowInSavedZone();
    return DateTime(now.year, now.month, now.day);
  }
}

extension KeepiDateTimeDisplay on DateTime {
  DateTime get asScheduleLocal => KeepiTimezone.scheduleLocal(this);
  DateTime get asUserLocal => KeepiTimezone.toUserLocal(this);
}

extension KeepiNullableDateTimeDisplay on DateTime? {
  DateTime? get asScheduleLocal =>
      this == null ? null : KeepiTimezone.scheduleLocal(this!);
  DateTime? get asUserLocal =>
      this == null ? null : KeepiTimezone.toUserLocal(this!);
}
