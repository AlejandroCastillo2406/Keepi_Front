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

  static String displayPercent(double? percent) {
    if (percent == null) return '--';
    final rounded = percent.round();
    return '$rounded%';
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
}

class AttendanceStatsData {
  const AttendanceStatsData({
    this.attended = 0,
    this.noShow = 0,
    this.ratePercent,
  });

  final int attended;
  final int noShow;
  final double? ratePercent;

  factory AttendanceStatsData.fromJson(Map<String, dynamic> json) {
    return AttendanceStatsData(
      attended: json['appointments_attended'] as int? ?? 0,
      noShow: json['appointments_no_show'] as int? ?? 0,
      ratePercent: (json['attendance_rate_percent'] as num?)?.toDouble(),
    );
  }
}
