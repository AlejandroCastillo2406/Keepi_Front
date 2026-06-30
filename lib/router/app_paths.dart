/// Rutas declarativas de la app (go_router).
abstract final class AppPaths {
  static const login = '/login';
  static const register = '/registro';
  static const forcePassword = '/cambiar-password';

  static const doctorAttendanceDetail = '/doctor/asistencia-detalle';

  static String doctorAttendanceDetailPath(String status) =>
      '$doctorAttendanceDetail?status=${Uri.encodeComponent(status)}';

  // Usuario (documentos)
  static const userHome = '/app';
  static const userSettings = '/app/configuracion';
  static const userSearch = '/app/busqueda';
  static const userNotifications = '/app/notificaciones';
  static String userGoogleDriveAuth(String authorizationUrl) =>
      '/app/google-drive?url=${Uri.encodeComponent(authorizationUrl)}';
  static String userFolder(String folderId, {String? name}) {
    final base = '/app/carpeta/$folderId';
    if (name == null || name.isEmpty) return base;
    return '$base?name=${Uri.encodeComponent(name)}';
  }

  // Paciente
  static const patientHome = '/paciente';
  static const patientInicio = '/paciente/inicio';
  static const patientRecetas = '/paciente/recetas';
  static const patientConsultas = '/paciente/consultas';
  static const patientPerfil = '/paciente/perfil';
  static const patientNotifications = '/paciente/notificaciones';
  static const patientPriorDocuments = '/paciente/documentos-previos';
  static String patientUploadAnalysis(String requestId, {String? description}) {
    final base = '/paciente/subir-analisis/$requestId';
    if (description == null || description.isEmpty) return base;
    return '$base?desc=${Uri.encodeComponent(description)}';
  }

  // Doctor shell
  static const doctor = '/doctor';
  static const doctorInicio = '/doctor/inicio';
  static const doctorPacientes = '/doctor/pacientes';
  static const doctorAgenda = '/doctor/agenda';
  static const doctorExpedientes = '/doctor/expedientes';
  static String doctorFolder(String folderId, {String? name}) {
    final params = <String, String>{'id': folderId};
    if (name != null && name.isNotEmpty) params['name'] = name;
    return Uri(
      path: '/doctor/expedientes/carpeta',
      queryParameters: params,
    ).toString();
  }

  static bool isDoctorFolderPath(String path) =>
      path == '$doctorExpedientes/carpeta';
  static const doctorSettings = '/doctor/configuracion';
  static const doctorNotifications = '/doctor/notificaciones';
  static const doctorCreatePatient = '/doctor/nuevo-paciente';
  static const doctorSearch = '/doctor/busqueda';
  static const doctorQuestionnaires = '/doctor/cuestionarios';
  static const doctorSchedulingSettings = '/doctor/agenda/configuracion';
  static const doctorQuestionEditor = '/doctor/cuestionarios/pregunta/editor';
  static const doctorTemplateEditor = '/doctor/cuestionarios/plantilla/editor';
  static const doctorSpecialtyQuestions = '/doctor/cuestionarios/especialidad';
  static const doctorQuestionPicker = '/doctor/cuestionarios/pregunta/picker';
  static const documentViewer = '/documento/visor';

  static String doctorConsultation(
    String appointmentId, {
    String? patientId,
    String? name,
    String? email,
  }) {
    final q = <String, String>{};
    if (patientId != null && patientId.isNotEmpty) q['patientId'] = patientId;
    if (name != null && name.isNotEmpty) q['name'] = name;
    if (email != null && email.isNotEmpty) q['email'] = email;
    final base = '/doctor/consulta/$appointmentId';
    if (q.isEmpty) return base;
    return Uri(path: base, queryParameters: q).toString();
  }

  static String doctorPatient(String patientId, {int tab = 0}) =>
      '/doctor/paciente/$patientId${tab > 0 ? '?tab=$tab' : ''}';

  static String doctorPatientTimeline(String patientId) =>
      '/doctor/paciente/$patientId/historial';

  static String doctorRequestAnalysis(String patientId) =>
      '/doctor/paciente/$patientId/solicitar-analisis';

  static String doctorAssignPrescription(String patientId) =>
      '/doctor/paciente/$patientId/receta';

  static String doctorSendQuestionnaire(String patientId) =>
      '/doctor/paciente/$patientId/cuestionario';

  static String doctorPriorDocuments(String patientId) =>
      '/doctor/paciente/$patientId/documentos-previos';

  static String doctorUploadAnalysis(String patientId, String requestId,
      {String? description}) {
    final base = '/doctor/paciente/$patientId/subir-analisis/$requestId';
    if (description == null || description.isEmpty) return base;
    return '$base?desc=${Uri.encodeComponent(description)}';
  }

  static String doctorSchedulingSettingsPath({bool canSkip = false}) =>
      canSkip ? '$doctorSchedulingSettings?canSkip=true' : doctorSchedulingSettings;

  static int patientTabIndexFromPath(String path) {
    if (path.startsWith(patientRecetas)) return 1;
    if (path.startsWith(patientConsultas)) return 2;
    if (path.startsWith(patientPerfil)) return 3;
    return 0;
  }

  static bool isPatientOverlayPath(String path) {
    if (!path.startsWith(patientHome)) return false;
    const tabs = [
      patientInicio,
      patientRecetas,
      patientConsultas,
      patientPerfil,
    ];
    return !tabs.contains(path) && path != patientHome;
  }

  static String patientHomeForTab(int index) {
    switch (index) {
      case 1:
        return patientRecetas;
      case 2:
        return patientConsultas;
      case 3:
        return patientPerfil;
      default:
        return patientInicio;
    }
  }

  static int doctorTabIndexFromPath(String path) {
    if (path.startsWith(doctorPacientes)) return 1;
    if (path.startsWith(doctorAgenda)) return 2;
    if (path.startsWith(doctorExpedientes)) return 3;
    return 0;
  }

  static bool isDoctorOverlayPath(String path) {
    if (!path.startsWith(doctor)) return false;
    const tabs = [doctorInicio, doctorPacientes, doctorAgenda, doctorExpedientes];
    if (tabs.contains(path)) return false;
    if (path == doctor) return false;
    if (path == doctorQuestionnaires ||
        path.startsWith('$doctorQuestionnaires/')) {
      return true;
    }
    if (path == doctorSchedulingSettings) return true;
    if (isDoctorFolderPath(path)) return true;
    return path.contains('/consulta/') ||
        path.contains('/paciente/') ||
        path == doctorSettings ||
        path == doctorNotifications ||
        path == doctorCreatePatient ||
        path == doctorSearch ||
        path == doctorAttendanceDetail;
  }

  static String doctorHomeForTab(int index) {
    switch (index) {
      case 1:
        return doctorPacientes;
      case 2:
        return doctorAgenda;
      case 3:
        return doctorExpedientes;
      default:
        return doctorInicio;
    }
  }

  static String notificationsForRole(String? role) {
    switch (role) {
      case 'DOCTOR':
        return doctorNotifications;
      case 'PATIENT':
        return patientNotifications;
      default:
        return userNotifications;
    }
  }
}

