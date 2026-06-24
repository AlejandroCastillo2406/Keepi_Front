import 'package:flutter/material.dart';

enum AttendanceLevel { none, low, regular, medium, high }

class AttendanceKpi {
  AttendanceKpi._();

  static AttendanceLevel levelFor(double? percent) {
    if (percent == null) return AttendanceLevel.none;
    if (percent < 50) return AttendanceLevel.low;
    if (percent < 70) return AttendanceLevel.regular;
    if (percent < 85) return AttendanceLevel.medium;
    return AttendanceLevel.high;
  }

  static Color colorForLevel(AttendanceLevel level) {
    switch (level) {
      case AttendanceLevel.low:
        return const Color(0xFFDC2626);
      case AttendanceLevel.regular:
        return const Color(0xFFEA580C);
      case AttendanceLevel.medium:
        return const Color(0xFF2563EB);
      case AttendanceLevel.high:
        return const Color(0xFF16A34A);
      case AttendanceLevel.none:
        return const Color(0xFF94A3B8);
    }
  }

  static Color colorForPercent(double? percent) =>
      colorForLevel(levelFor(percent));

  /// Sin registros → null (--). Con registros y 0 asistió → 0.0 (0%).
  static double? ratePercentFromCounts({
    required int attended,
    required int noShow,
    double? apiPercent,
  }) {
    final recorded = attended + noShow;
    if (recorded == 0) return null;
    if (apiPercent != null) return apiPercent;
    return attended * 100.0 / recorded;
  }

  static String displayPercent(
    double? percent, {
    int attended = 0,
    int noShow = 0,
  }) {
    final recorded = attended + noShow;
    if (recorded == 0) return '--';
    final rate = percent ?? attended * 100.0 / recorded;
    return '${rate.round()}%';
  }

  static String levelLabel(AttendanceLevel level) {
    switch (level) {
      case AttendanceLevel.low:
        return 'BAJO';
      case AttendanceLevel.regular:
        return 'REGULAR';
      case AttendanceLevel.medium:
        return 'MEDIO';
      case AttendanceLevel.high:
        return 'ALTO';
      case AttendanceLevel.none:
        return 'SIN DATOS';
    }
  }

  static int _readInt(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final v = json[key];
      if (v is num) return v.toInt();
    }
    return 0;
  }

  static double? _readRatePercent(Map<String, dynamic> json) {
    final attended = _readInt(json, [
      'attendance_attended',
      'appointments_attended',
    ]);
    final noShow = _readInt(json, [
      'attendance_no_show',
      'appointments_no_show',
    ]);
    if (attended + noShow == 0) return null;

    for (final key in [
      'attendance_attended_percent',
      'attendance_rate_percent',
    ]) {
      final v = json[key];
      if (v is num) return v.toDouble();
    }
    return attended * 100.0 / (attended + noShow);
  }
}

class AttendanceStatsData {
  const AttendanceStatsData({
    this.attended = 0,
    this.noShow = 0,
    this.pending = 0,
    this.ratePercent,
  });

  final int attended;
  final int noShow;
  final int pending;
  final double? ratePercent;

  factory AttendanceStatsData.fromJson(Map<String, dynamic> json) {
    return AttendanceStatsData(
      attended: AttendanceKpi._readInt(json, [
        'attendance_attended',
        'appointments_attended',
      ]),
      noShow: AttendanceKpi._readInt(json, [
        'attendance_no_show',
        'appointments_no_show',
      ]),
      pending: AttendanceKpi._readInt(json, ['attendance_pending']),
      ratePercent: AttendanceKpi._readRatePercent(json),
    );
  }
}
