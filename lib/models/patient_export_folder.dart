class PatientExportFolder {
  const PatientExportFolder({
    required this.patientId,
    required this.patientName,
    required this.s3FolderPath,
    required this.filesCount,
  });

  final String patientId;
  final String patientName;
  /// Ruta S3 completa, p. ej. `users/{doctorId}/Julinka_Rosemary`
  final String s3FolderPath;
  final int filesCount;
}
