import 'dart:io';
import 'package:dio/dio.dart';
import '../core/api_endpoints.dart';
import '../models/questionnaire_models.dart';
import 'api_client.dart';

/// Cliente HTTP del módulo Cuestionarios de salud (solo doctor).
class QuestionnaireService {
  QuestionnaireService(this._api);
  final ApiClient _api;

  // ─── Specialties ───

  Future<List<Specialty>> fetchSpecialties() async {
    final res = await _api.dio.get<dynamic>(ApiEndpoints.questionnaireSpecialties);
    final data = res.data;
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => Specialty.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<Question>> fetchSpecialtyQuestions(
    String specialtyId, {
    QuestionStatusFilter status = QuestionStatusFilter.all,
  }) async {
    final res = await _api.dio.get<dynamic>(
      ApiEndpoints.questionnaireSpecialtyQuestions(specialtyId, status: status.apiValue),
    );
    return _parseQuestions(res.data);
  }

  Future<List<Question>> fetchGlobalQuestions({
    QuestionStatusFilter status = QuestionStatusFilter.all,
  }) async {
    final res = await _api.dio.get<dynamic>(
      ApiEndpoints.questionnaireGlobals(status: status.apiValue),
    );
    return _parseQuestions(res.data);
  }

  // ─── Questions CRUD ───

  Future<Question> createQuestion({
    String? specialtyId,
    required String text,
    required QuestionResponseType responseType,
    List<String>? options,
    String? helpText,
    bool isRequired = false,
    bool showInHistory = true,
  }) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      ApiEndpoints.questionnaireQuestions,
      data: {
        if (specialtyId != null) 'specialty_id': specialtyId,
        'text': text.trim(),
        'response_type': responseType.apiValue,
        if (options != null) 'options': options,
        if (helpText != null && helpText.trim().isNotEmpty) 'help_text': helpText.trim(),
        'is_required': isRequired,
        'show_in_history': showInHistory,
      },
    );
    return Question.fromJson(res.data!);
  }

  Future<Question> updateQuestion(
    String questionId, {
    Object? specialtyId = _unset,
    String? text,
    QuestionResponseType? responseType,
    List<String>? options,
    String? helpText,
    bool? isRequired,
    bool? showInHistory,
  }) async {
    final body = <String, dynamic>{};
    if (specialtyId != _unset) body['specialty_id'] = specialtyId;
    if (text != null) body['text'] = text.trim();
    if (responseType != null) body['response_type'] = responseType.apiValue;
    if (options != null) body['options'] = options;
    if (helpText != null) body['help_text'] = helpText.trim().isEmpty ? null : helpText.trim();
    if (isRequired != null) body['is_required'] = isRequired;
    if (showInHistory != null) body['show_in_history'] = showInHistory;

    final res = await _api.dio.patch<Map<String, dynamic>>(
      ApiEndpoints.questionnaireQuestionById(questionId),
      data: body,
    );
    return Question.fromJson(res.data!);
  }

  Future<void> deleteQuestion(String questionId) async {
    await _api.dio.delete<void>(ApiEndpoints.questionnaireQuestionById(questionId));
  }

  Future<Question> toggleQuestion(String questionId, bool isActive) async {
    final res = await _api.dio.patch<Map<String, dynamic>>(
      ApiEndpoints.questionnaireQuestionToggle(questionId),
      data: {'is_active': isActive},
    );
    return Question.fromJson(res.data!);
  }

  Future<Question> overrideQuestion(
    String questionId, {
    bool? isRequired,
    bool? showInHistory,
  }) async {
    final body = <String, dynamic>{};
    if (isRequired != null) body['is_required'] = isRequired;
    if (showInHistory != null) body['show_in_history'] = showInHistory;
    final res = await _api.dio.patch<Map<String, dynamic>>(
      ApiEndpoints.questionnaireQuestionOverrides(questionId),
      data: body,
    );
    return Question.fromJson(res.data!);
  }

  // ─── Templates ───

  Future<List<TemplateSummary>> fetchTemplates() async {
    final res = await _api.dio.get<dynamic>(ApiEndpoints.questionnaireTemplates);
    final data = res.data;
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => TemplateSummary.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<TemplateDetail> fetchTemplate(String templateId) async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      ApiEndpoints.questionnaireTemplateById(templateId),
    );
    return TemplateDetail.fromJson(res.data!);
  }

  Future<TemplateDetail> createTemplate({
    required String name,
    String? description,
    String? specialtyId,
  }) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      ApiEndpoints.questionnaireTemplates,
      data: {
        'name': name.trim(),
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        if (specialtyId != null) 'specialty_id': specialtyId,
      },
    );
    return TemplateDetail.fromJson(res.data!);
  }

  Future<TemplateDetail> updateTemplate(
    String templateId, {
    String? name,
    String? description,
    Object? specialtyId = _unset,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name.trim();
    if (description != null) {
      body['description'] = description.trim().isEmpty ? null : description.trim();
    }
    if (specialtyId != _unset) body['specialty_id'] = specialtyId;
    final res = await _api.dio.patch<Map<String, dynamic>>(
      ApiEndpoints.questionnaireTemplateById(templateId),
      data: body,
    );
    return TemplateDetail.fromJson(res.data!);
  }

  Future<void> deleteTemplate(String templateId) async {
    await _api.dio.delete<void>(ApiEndpoints.questionnaireTemplateById(templateId));
  }

  Future<TemplateDetail> upsertTemplateQuestions(
    String templateId,
    List<String> orderedQuestionIds,
  ) async {
    final items = List<Map<String, dynamic>>.generate(
      orderedQuestionIds.length,
      (i) => {'question_id': orderedQuestionIds[i], 'sort_order': i},
    );
    final res = await _api.dio.put<Map<String, dynamic>>(
      ApiEndpoints.questionnaireTemplateQuestions(templateId),
      data: {'items': items},
    );
    return TemplateDetail.fromJson(res.data!);
  }

  Future<InvitationSendResult> sendInvitationBatch({
    required String patientId,
    List<String> templateIds = const [],
    List<String> questionIds = const [],
    bool collectPriorDocuments = false,
  }) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      ApiEndpoints.questionnaireInvitations,
      data: {
        'patient_id': patientId,
        'template_ids': templateIds,
        'question_ids': questionIds,
        'collect_prior_documents': collectPriorDocuments,
      },
    );
    return InvitationSendResult.fromJson(res.data!);
  }

  Future<InvitationSummary> getInvitationStatus(String invitationId) async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      ApiEndpoints.questionnaireInvitationById(invitationId),
    );
    return InvitationSummary.fromJson(res.data!);
  }

  // ─── Respuestas del Paciente ───

  /// Obtiene las respuestas de los cuestionarios de un paciente específico.
  Future<List<dynamic>> fetchPatientResponses(String patientId) async {
    try {
      final res = await _api.dio.get<dynamic>(
        ApiEndpoints.questionnairePatientResponses(patientId),
      );
      
      final data = res.data;
      if (data is! List) return [];
      
      return data; 
    } catch (e) {
      print("Error obteniendo respuestas: $e");
      return [];
    }
  }

// --- NUEVO: Extracción de KPIs de Salud CORREGIDO ---
  Future<Map<String, dynamic>?> getLatestPatientKPIs(String patientId) async {
    try {
      final responses = await fetchPatientResponses(patientId);
      if (responses.isEmpty) return null;

      double? weight;
      double? height;

      // Iteramos directamente sobre las respuestas porque la API envía una lista plana
      for (var answer in responses) {
        if (answer is Map) {
          // Usamos las llaves exactas que tienes en tu doctor_patient_profile_screen
          final text = (answer['question_text'] ?? '').toString().toLowerCase();
          final valueStr = (answer['answer_value'] ?? '').toString();

          // Limpiamos el string para sacar solo el número. 
          // Esto convertirá el "{value: 166}" de tu base de datos en "166"
          final numericString = valueStr.replaceAll(RegExp(r'[^0-9.]'), '');
          final numericValue = double.tryParse(numericString);

          if (numericValue != null) {
            // Buscamos peso
            if (text.contains('peso') && weight == null) {
              weight = numericValue;
            } 
            // Buscamos estatura
            else if ((text.contains('estatura') || text.contains('altura')) && height == null) {
              height = numericValue;
            }
          }
        }
        
        // Si ya encontramos ambos, dejamos de buscar para no gastar recursos
        if (weight != null && height != null) break;
      }

      // Si no encontró ni peso ni estatura en todo el historial, no muestra el widget
      if (weight == null && height == null) return null;

      double? bmi;
      if (weight != null && height != null && height > 0) {
        // Convertimos centímetros a metros si es necesario (ej: 166 -> 1.66)
        double h = height > 3.0 ? height / 100 : height;
        bmi = weight / (h * h);
        height = h; 
      } else if (height != null && height > 3.0) {
        // Si solo hay estatura, la normalizamos para la vista
        height = height / 100;
      }

      return {
        'weight': weight,
        'height': height,
        'bmi': bmi,
      };
    } catch (e) {
      print('Error en getLatestPatientKPIs: $e');
      return null;
    }
  }
  
  // ─── EXTRACCIÓN OCR CON IA ───

  /// Envía imágenes al backend para extraer preguntas médicas limpias usando AWS Textract + Claude
  Future<List<Map<String, dynamic>>> extractQuestionsFromImages(List<File> images) async {
    try {
      final formData = FormData();

      for (var image in images) {
        String fileName = image.path.split('/').last;
        formData.files.add(MapEntry(
          'imagenes',
          await MultipartFile.fromFile(image.path, filename: fileName),
        ));
      }

      final res = await _api.dio.post<Map<String, dynamic>>(
        ApiEndpoints.questionnaireExtractOcr,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      final data = res.data;
      if (data != null && data['success'] == true) {
        // Ahora devolvemos la lista completa de mapas con texto, tipo y opciones
        return List<Map<String, dynamic>>.from(data['preguntas'] as List);
      } else {
        throw Exception('El servidor no devolvió éxito.');
      }
    } catch (e) {
      print('Error en extractQuestionsFromImages: $e');
      rethrow;
    }
  }

  // ────────────────────────────────────────

  List<Question> _parseQuestions(dynamic data) {
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => Question.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}

const Object _unset = Object();