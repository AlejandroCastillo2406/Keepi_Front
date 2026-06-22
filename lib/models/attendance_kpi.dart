import '../services/appointment_service.dart';
import 'consultation_context.dart';

class AttendanceKpi {
  const AttendanceKpi({
    this.attended = 0,
    this.noShow = 0,
    this.pendingMark = 0,
    this.attendedPercent = 0,
    this.noShowPercent = 0,
  });

  final int attended;
  final int noShow;
  final int pendingMark;
  final double attendedPercent;
  final double noShowPercent;

  int get recorded => attended + noShow;

  bool get hasData => recorded > 0 || pendingMark > 0;

  factory AttendanceKpi.fromStats(ConsultationStats stats) {
    return AttendanceKpi(
      attended: stats.attendanceAttended,
      noShow: stats.attendanceNoShow,
      pendingMark: stats.attendancePending,
      attendedPercent: stats.attendanceAttendedPercent,
      noShowPercent: stats.attendanceNoShowPercent,
    );
  }

  factory AttendanceKpi.fromAppointments(
    Iterable<AppointmentDto> appointments, {
    required int slotMinutes,
  }) {
    final now = DateTime.now();
    var attended = 0;
    var noShow = 0;
    var pendingMark = 0;

    for (final a in appointments) {
      if (a.status != 'scheduled' || a.appointmentDate == null) continue;
      final end = a.endDate?.toLocal() ??
          a.appointmentDate!.toLocal().add(Duration(minutes: slotMinutes));
      if (!now.isAfter(end)) continue;

      final status = a.attendanceStatus;
      if (status == 'attended') {
        attended++;
      } else if (status == 'no_show') {
        noShow++;
      } else {
        pendingMark++;
      }
    }

    final recorded = attended + noShow;
    return AttendanceKpi(
      attended: attended,
      noShow: noShow,
      pendingMark: pendingMark,
      attendedPercent: recorded > 0 ? attended * 100.0 / recorded : 0,
      noShowPercent: recorded > 0 ? noShow * 100.0 / recorded : 0,
    );
  }

  factory AttendanceKpi.fromJson(Map<String, dynamic> json) {
    return AttendanceKpi(
      attended: json['attendance_attended'] as int? ?? 0,
      noShow: json['attendance_no_show'] as int? ?? 0,
      pendingMark: json['attendance_pending'] as int? ?? 0,
      attendedPercent:
          (json['attendance_attended_percent'] as num?)?.toDouble() ?? 0,
      noShowPercent:
          (json['attendance_no_show_percent'] as num?)?.toDouble() ?? 0,
    );
  }
}

String formatAttendancePercent(double value) {
  if (value <= 0) return '—';
  if (value == value.roundToDouble()) {
    return '${value.round()}%';
  }
  return '${value.toStringAsFixed(1)}%';
}
