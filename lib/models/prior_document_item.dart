class PriorDocumentItem {
  PriorDocumentItem({
    required this.id,
    required this.name,
    this.fileName,
    this.s3Key,
    this.fileSize,
    this.fileType,
    this.createdAt,
  });

  final String id;
  final String name;
  final String? fileName;
  final String? s3Key;
  final int? fileSize;
  final String? fileType;
  final String? createdAt;

  factory PriorDocumentItem.fromJson(Map<String, dynamic> json) {
    return PriorDocumentItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Documento',
      fileName: json['file_name'] as String?,
      s3Key: json['s3_key'] as String?,
      fileSize: (json['file_size'] as num?)?.toInt(),
      fileType: json['file_type'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}
