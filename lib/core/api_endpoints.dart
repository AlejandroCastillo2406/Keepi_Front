import 'config.dart';

/// Rutas de la API. Prefijo y rutas relativas vienen de Config (env). Cero rutas hardcodeadas.
class ApiEndpoints {
  ApiEndpoints._();

  static String _path(String relative) {
    final p = Config.apiPathPrefix;
    final r = relative.startsWith('/') ? relative.substring(1) : relative;
    return p.endsWith('/') ? p + r : '$p/$r';
  }

  static String get authRegister => _path(Config.pathAuthRegister);
  static String get authLogin => _path(Config.pathAuthLogin);
  static String get authRefresh => _path(Config.pathAuthRefresh);
  static String get authMe => _path(Config.pathAuthMe);
  static String get authChangePassword => _path(Config.pathAuthChangePassword);
  static String get doctorsPatients => _path(Config.pathDoctorsPatients);
  static String get meMedicalRecord => _path(Config.pathMeMedicalRecord);
  static String doctorsPatientMedicalRecord(String patientId) =>
      _path('${Config.pathDoctorsPatients}/$patientId/medical-record');
  static String get authGoogleMobileAuthorize => _path(Config.pathAuthGoogleMobileAuthorize);
  static String get authGoogleCallback => _path(Config.pathAuthGoogleCallback);

  static String get config => _path(Config.pathConfig);

  static String get cloudStorageSetup => _path(Config.pathCloudStorageSetup);

  static String get subscriptionsUsageStats => _path(Config.pathSubscriptionsUsageStats);
  static String get subscriptionsCreateCheckout => _path(Config.pathSubscriptionsCreateCheckout);

  static String get documentsDriveStructure => _path(Config.pathDocumentsDriveStructure);
  static String documentsDriveFolderContents(String folderId) =>
      _path(Config.pathDocumentsDriveFolderContents.replaceFirst('{folderId}', folderId));
  static String documentsDriveFileViewUrl(String fileId) =>
      _path(Config.pathDocumentsDriveFileViewUrl.replaceFirst('{fileId}', fileId));
  static String documentsDriveFileContent(String fileId) =>
      _path(Config.pathDocumentsDriveFileContent.replaceFirst('{fileId}', fileId));
  static String documentsDriveFileDelete(String fileId) =>
      _path(Config.pathDocumentsDriveFileDelete.replaceFirst('{fileId}', fileId));

  static const String analysisRequests = '/analysis-requests/';
  static String patientAnalysisRequests(String id) => '/analysis-requests/patient/$id';
  static String completeAnalysisRequest(String id) => '/analysis-requests/$id/complete';

  static String get documentsMobileDashboard => _path(Config.pathDocumentsMobileDashboard);
  static String get documentsKeepiCloudRoot => _path(Config.pathDocumentsKeepiCloudRoot);
  static String get documentsS3FoldersContents => _path(Config.pathDocumentsS3FoldersContents);

  static String get documentsMobileAnalyze => _path(Config.pathDocumentsMobileAnalyze);
  static String get documentsMobileSaveAnalyzed => _path(Config.pathDocumentsMobileSaveAnalyzed);

  static String get prescriptionsDraft => _path('/prescriptions/draft');
  static String prescriptionsConfirm(String prescriptionId) => _path('/prescriptions/$prescriptionId/confirm');
  static String get prescriptionsMine => _path('/prescriptions/mine');
  static String prescriptionScanUrl(String prescriptionId) => _path('/prescriptions/$prescriptionId/scan-url');
  static String prescriptionReminderOptIn(String prescriptionId) =>
      _path('/prescriptions/$prescriptionId/reminders-opt-in');

  static String get pushRegister => _path('/push/register');
  static String get notifications => _path('/notifications/');

  static String get appointmentsDoctorCreate => _path('/appointments/doctor');
  static String get appointmentsDoctorCalendar => _path('/appointments/doctor/calendar');
  static String get appointmentsMine => _path('/appointments/mine');
  static String appointmentById(String appointmentId) => _path('/appointments/$appointmentId');
  static String appointmentPatientConfirm(String appointmentId) =>
      _path('/appointments/$appointmentId/patient/confirm');
  static String appointmentPatientRequestChange(String appointmentId) =>
      _path('/appointments/$appointmentId/patient/request-change');
  static String appointmentDoctorAccept(String appointmentId) =>
      _path('/appointments/$appointmentId/doctor/accept');
  static String appointmentDoctorCounterPropose(String appointmentId) =>
      _path('/appointments/$appointmentId/doctor/counter-propose');

  // ──────── Cuestionarios de salud (solo doctor) ────────
  static String get questionnaireSpecialties => _path('/questionnaire/specialties');
  static String questionnaireSpecialtyQuestions(String specialtyId, {String status = 'all'}) =>
      '${_path('/questionnaire/specialties/$specialtyId/questions')}?status=$status';
  static String questionnaireGlobals({String status = 'all'}) =>
      '${_path('/questionnaire/questions/globals')}?status=$status';
  static String get questionnaireQuestions => _path('/questionnaire/questions');
  static String questionnaireQuestionById(String questionId) =>
      _path('/questionnaire/questions/$questionId');
  static String questionnaireQuestionToggle(String questionId) =>
      _path('/questionnaire/questions/$questionId/toggle');
  static String questionnaireQuestionOverrides(String questionId) =>
      _path('/questionnaire/questions/$questionId/overrides');
  static String get questionnaireTemplates => _path('/questionnaire/templates');
  static String questionnaireTemplateById(String templateId) =>
      _path('/questionnaire/templates/$templateId');
  static String questionnaireTemplateQuestions(String templateId) =>
      _path('/questionnaire/templates/$templateId/questions');
}
