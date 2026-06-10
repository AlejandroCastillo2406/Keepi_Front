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
  });

  final int analysisRequested;
  final int analysisUploaded;
  final int analysisPending;
  final int timelineEvents;

  factory ConsultationStats.fromJson(Map<String, dynamic> json) {
    return ConsultationStats(
      analysisRequested: json['analysis_requested'] as int? ?? 0,
      analysisUploaded: json['analysis_uploaded'] as int? ?? 0,
      analysisPending: json['analysis_pending'] as int? ?? 0,
      timelineEvents: json['timeline_events'] as int? ?? 0,
    );
  }
}
