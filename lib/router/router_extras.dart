import '../models/questionnaire_models.dart';
import '../services/doctor_service.dart';
import '../services/questionnaire_service.dart';

class DocumentViewerExtra {
  const DocumentViewerExtra({
    required this.url,
    required this.title,
    this.headers = const {},
    this.mimeType,
    this.s3Path,
  });

  final String url;
  final String title;
  final Map<String, String> headers;
  final String? mimeType;
  /// Ruta S3 (`users/...`) para descargar vía API y evitar CORS en web.
  final String? s3Path;
}

class GlobalSearchExtra {
  const GlobalSearchExtra({
    this.patients,
    this.onDoctorOpenAgenda,
  });

  final List<PatientListItem>? patients;
  final void Function()? onDoctorOpenAgenda;
}

class QuestionEditorExtra {
  const QuestionEditorExtra({
    required this.service,
    required this.specialties,
    this.initial,
    this.presetSpecialtyId,
    this.presetGlobal = false,
    this.forceDuplicate = false,
  });

  final QuestionnaireService service;
  final List<Specialty> specialties;
  final Question? initial;
  final String? presetSpecialtyId;
  final bool presetGlobal;
  final bool forceDuplicate;
}

class TemplateEditorExtra {
  const TemplateEditorExtra({
    required this.service,
    required this.specialties,
    this.existing,
  });

  final QuestionnaireService service;
  final List<Specialty> specialties;
  final TemplateSummary? existing;
}

class SpecialtyQuestionsExtra {
  const SpecialtyQuestionsExtra({
    required this.specialty,
    required this.service,
    required this.specialties,
  });

  final Specialty specialty;
  final QuestionnaireService service;
  final List<Specialty> specialties;
}

class QuestionPickerExtra {
  const QuestionPickerExtra({
    required this.service,
    required this.specialties,
    required this.initialSelection,
    this.initialSpecialtyId,
  });

  final QuestionnaireService service;
  final List<Specialty> specialties;
  final List<Question> initialSelection;
  final String? initialSpecialtyId;
}
