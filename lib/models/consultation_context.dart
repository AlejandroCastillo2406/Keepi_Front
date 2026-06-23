class ConsultationContext {
  const ConsultationContext({
    this.patientName,
    this.patientEmail,
    this.phone,
    this.sex,
    this.ageYears,
    this.bloodType,
    this.weightKg,
    this.allergies,
    this.hasClinicalIntake = false,
    required this.stats,
  });

  final String? patientName;
  final String? patientEmail;
  final String? phone;
  final String? sex;
  final int? ageYears;
  final String? bloodType;
  final double? weightKg;
  final String? allergies;
  final bool hasClinicalIntake;
  final ConsultationStats stats;

  factory ConsultationContext.fromJson(Map<String, dynamic> json) {
    final statsRaw = json['stats'];
    return ConsultationContext(
      patientName: json['patient_name'] as String?,
      patientEmail: json['patient_email'] as String?,
      phone: json['phone'] as String?,
      sex: json['sex'] as String?,
      ageYears: json['age_years'] as int?,
      bloodType: json['blood_type'] as String?,
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      allergies: json['allergies'] as String?,
      hasClinicalIntake: json['has_clinical_intake'] == true,
      stats: statsRaw is Map
          ? ConsultationStats.fromJson(Map<String, dynamic>.from(statsRaw))
          : const ConsultationStats(),
    );
  }
}

class ConsultationStats {
  const ConsultationStats({
    this.analysisRequested = 0,
    this.analysisUploaded = 0,
    this.analysisPending = 0,
    this.timelineEvents = 0,
    this.attendanceAttended = 0,
    this.attendanceNoShow = 0,
    this.attendancePending = 0,
    this.attendanceAttendedPercent = 0,
    this.attendanceNoShowPercent = 0,
  });

  final int analysisRequested;
  final int analysisUploaded;
  final int analysisPending;
  final int timelineEvents;
  final int attendanceAttended;
  final int attendanceNoShow;
  final int attendancePending;
  final double attendanceAttendedPercent;
  final double attendanceNoShowPercent;

  /// Porcentaje de asistencia para KPIs; null si aún no hay citas registradas.
  double? get attendanceRatePercent {
    if (attendanceAttended + attendanceNoShow == 0) return null;
    if (attendanceAttendedPercent > 0) return attendanceAttendedPercent;
    return attendanceAttended * 100.0 / (attendanceAttended + attendanceNoShow);
  }

  factory ConsultationStats.fromJson(Map<String, dynamic> json) {
    final attended = json['attendance_attended'] as int? ??
        json['appointments_attended'] as int? ??
        0;
    final noShow = json['attendance_no_show'] as int? ??
        json['appointments_no_show'] as int? ??
        0;
    final attendedPct =
        (json['attendance_attended_percent'] as num?)?.toDouble() ??
            (json['attendance_rate_percent'] as num?)?.toDouble() ??
            0.0;
    return ConsultationStats(
      analysisRequested: json['analysis_requested'] as int? ?? 0,
      analysisUploaded: json['analysis_uploaded'] as int? ?? 0,
      analysisPending: json['analysis_pending'] as int? ?? 0,
      timelineEvents: json['timeline_events'] as int? ?? 0,
      attendanceAttended: attended,
      attendanceNoShow: noShow,
      attendancePending: json['attendance_pending'] as int? ?? 0,
      attendanceAttendedPercent: attendedPct,
      attendanceNoShowPercent:
          (json['attendance_no_show_percent'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
