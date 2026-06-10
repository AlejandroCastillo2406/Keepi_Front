class ClinicalIntakeFieldDetail {
  ClinicalIntakeFieldDetail({
    required this.key,
    required this.label,
    required this.value,
  });

  final String key;
  final String label;
  final String value;

  factory ClinicalIntakeFieldDetail.fromJson(Map<String, dynamic> json) =>
      ClinicalIntakeFieldDetail(
        key: json['key']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        value: json['value']?.toString() ?? '',
      );
}

class ClinicalIntakeSectionDetail {
  ClinicalIntakeSectionDetail({
    required this.id,
    required this.title,
    this.subtitle,
    required this.fields,
  });

  final String id;
  final String title;
  final String? subtitle;
  final List<ClinicalIntakeFieldDetail> fields;

  factory ClinicalIntakeSectionDetail.fromJson(Map<String, dynamic> json) =>
      ClinicalIntakeSectionDetail(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        subtitle: json['subtitle']?.toString(),
        fields: (json['fields'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((e) => ClinicalIntakeFieldDetail.fromJson(
                  Map<String, dynamic>.from(e),
                ))
            .toList(),
      );
}

class ClinicalIntakeDetail {
  ClinicalIntakeDetail({
    required this.invitationId,
    required this.patientId,
    this.completedAt,
    required this.sections,
  });

  final String invitationId;
  final String patientId;
  final String? completedAt;
  final List<ClinicalIntakeSectionDetail> sections;

  factory ClinicalIntakeDetail.fromJson(Map<String, dynamic> json) =>
      ClinicalIntakeDetail(
        invitationId: json['invitation_id']?.toString() ?? '',
        patientId: json['patient_id']?.toString() ?? '',
        completedAt: json['completed_at']?.toString(),
        sections: (json['sections'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((e) => ClinicalIntakeSectionDetail.fromJson(
                  Map<String, dynamic>.from(e),
                ))
            .toList(),
      );
}
