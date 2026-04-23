import 'package:flutter/material.dart';

/// Tipos de respuesta soportados por el módulo de cuestionarios de salud.
enum QuestionResponseType {
  singleChoice,
  multiChoice,
  yesNo,
  numeric,
  shortText,
  longText;

  String get apiValue {
    switch (this) {
      case QuestionResponseType.singleChoice:
        return 'single_choice';
      case QuestionResponseType.multiChoice:
        return 'multi_choice';
      case QuestionResponseType.yesNo:
        return 'yes_no';
      case QuestionResponseType.numeric:
        return 'numeric';
      case QuestionResponseType.shortText:
        return 'short_text';
      case QuestionResponseType.longText:
        return 'long_text';
    }
  }

  String get label {
    switch (this) {
      case QuestionResponseType.singleChoice:
        return 'Opción única';
      case QuestionResponseType.multiChoice:
        return 'Opción múltiple';
      case QuestionResponseType.yesNo:
        return 'Sí / No';
      case QuestionResponseType.numeric:
        return 'Numérica';
      case QuestionResponseType.shortText:
        return 'Texto corto';
      case QuestionResponseType.longText:
        return 'Texto largo';
    }
  }

  String get shortDescription {
    switch (this) {
      case QuestionResponseType.singleChoice:
        return 'Una opción entre varias';
      case QuestionResponseType.multiChoice:
        return 'Varias opciones posibles';
      case QuestionResponseType.yesNo:
        return 'Respuesta binaria';
      case QuestionResponseType.numeric:
        return 'Cifra medible';
      case QuestionResponseType.shortText:
        return 'Frase breve';
      case QuestionResponseType.longText:
        return 'Texto extendido';
    }
  }

  IconData get icon {
    switch (this) {
      case QuestionResponseType.singleChoice:
        return Icons.radio_button_checked_outlined;
      case QuestionResponseType.multiChoice:
        return Icons.check_box_outlined;
      case QuestionResponseType.yesNo:
        return Icons.toggle_on_outlined;
      case QuestionResponseType.numeric:
        return Icons.pin_outlined;
      case QuestionResponseType.shortText:
        return Icons.short_text;
      case QuestionResponseType.longText:
        return Icons.notes_outlined;
    }
  }

  bool get needsOptions =>
      this == QuestionResponseType.singleChoice ||
      this == QuestionResponseType.multiChoice;

  static QuestionResponseType fromApi(String? value) {
    switch (value) {
      case 'single_choice':
        return QuestionResponseType.singleChoice;
      case 'multi_choice':
        return QuestionResponseType.multiChoice;
      case 'yes_no':
        return QuestionResponseType.yesNo;
      case 'numeric':
        return QuestionResponseType.numeric;
      case 'short_text':
        return QuestionResponseType.shortText;
      case 'long_text':
      default:
        return QuestionResponseType.longText;
    }
  }
}

class Specialty {
  Specialty({
    required this.id,
    required this.slug,
    required this.name,
    this.description,
    this.icon,
    this.sortOrder = 0,
    this.totalQuestions = 0,
    this.totalActive = 0,
  });

  final String id;
  final String slug;
  final String name;
  final String? description;
  final String? icon;
  final int sortOrder;
  final int totalQuestions;
  final int totalActive;

  factory Specialty.fromJson(Map<String, dynamic> j) => Specialty(
        id: j['id'] as String,
        slug: j['slug'] as String? ?? '',
        name: j['name'] as String? ?? '',
        description: j['description'] as String?,
        icon: j['icon'] as String?,
        sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
        totalQuestions: (j['total_questions'] as num?)?.toInt() ?? 0,
        totalActive: (j['total_active'] as num?)?.toInt() ?? 0,
      );
}

class Question {
  Question({
    required this.id,
    required this.text,
    required this.responseType,
    required this.origin,
    required this.isActive,
    required this.isRequired,
    required this.showInHistory,
    required this.isRequiredDefault,
    required this.showInHistoryDefault,
    required this.isActiveDefault,
    required this.isMine,
    this.specialtyId,
    this.specialtyName,
    this.ownerUserId,
    this.options,
    this.helpText,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? specialtyId;
  final String? specialtyName;
  final String origin; // 'system' | 'custom'
  final String? ownerUserId;
  final bool isMine;

  final String text;
  final QuestionResponseType responseType;
  final List<String>? options;
  final String? helpText;

  final bool isActive;
  final bool isRequired;
  final bool showInHistory;
  final bool isRequiredDefault;
  final bool showInHistoryDefault;
  final bool isActiveDefault;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isSystem => origin == 'system';
  bool get isCustom => origin == 'custom';
  bool get isGlobal => specialtyId == null;

  factory Question.fromJson(Map<String, dynamic> j) {
    final rawOptions = j['options'];
    final parsedOptions = rawOptions is List
        ? rawOptions.map((e) => e.toString()).toList()
        : null;
    return Question(
      id: j['id'] as String,
      specialtyId: j['specialty_id'] as String?,
      specialtyName: j['specialty_name'] as String?,
      origin: j['origin'] as String? ?? 'system',
      ownerUserId: j['owner_user_id'] as String?,
      isMine: j['is_mine'] as bool? ?? false,
      text: j['text'] as String? ?? '',
      responseType: QuestionResponseType.fromApi(j['response_type'] as String?),
      options: parsedOptions,
      helpText: j['help_text'] as String?,
      isActive: j['is_active'] as bool? ?? true,
      isRequired: j['is_required'] as bool? ?? false,
      showInHistory: j['show_in_history'] as bool? ?? true,
      isRequiredDefault: j['is_required_default'] as bool? ?? false,
      showInHistoryDefault: j['show_in_history_default'] as bool? ?? true,
      isActiveDefault: j['is_active_default'] as bool? ?? true,
      createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(j['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class TemplateSummary {
  TemplateSummary({
    required this.id,
    required this.doctorId,
    required this.name,
    this.description,
    this.specialtyId,
    this.specialtyName,
    this.totalQuestions = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String doctorId;
  final String name;
  final String? description;
  final String? specialtyId;
  final String? specialtyName;
  final int totalQuestions;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory TemplateSummary.fromJson(Map<String, dynamic> j) => TemplateSummary(
        id: j['id'] as String,
        doctorId: j['doctor_id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        description: j['description'] as String?,
        specialtyId: j['specialty_id'] as String?,
        specialtyName: j['specialty_name'] as String?,
        totalQuestions: (j['total_questions'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(j['updated_at']?.toString() ?? '') ?? DateTime.now(),
      );
}

class TemplateDetail extends TemplateSummary {
  TemplateDetail({
    required super.id,
    required super.doctorId,
    required super.name,
    super.description,
    super.specialtyId,
    super.specialtyName,
    super.totalQuestions,
    required super.createdAt,
    required super.updatedAt,
    required this.questions,
  });

  final List<Question> questions;

  factory TemplateDetail.fromJson(Map<String, dynamic> j) {
    final qs = j['questions'];
    return TemplateDetail(
      id: j['id'] as String,
      doctorId: j['doctor_id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      description: j['description'] as String?,
      specialtyId: j['specialty_id'] as String?,
      specialtyName: j['specialty_name'] as String?,
      totalQuestions: (j['total_questions'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(j['updated_at']?.toString() ?? '') ?? DateTime.now(),
      questions: qs is List
          ? qs
              .whereType<Map>()
              .map((e) => Question.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }
}

/// Filtro para listar preguntas por estado.
enum QuestionStatusFilter {
  all,
  active,
  inactive;

  String get apiValue => name;
  String get label {
    switch (this) {
      case QuestionStatusFilter.all:
        return 'Todas';
      case QuestionStatusFilter.active:
        return 'Activas';
      case QuestionStatusFilter.inactive:
        return 'Inactivas';
    }
  }
}

class InvitationSummary {
  InvitationSummary({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.patientEmail,
    required this.status,
    required this.expiresAt,
    required this.totalQuestions,
    this.completedAt,
  });

  final String id;
  final String patientId;
  final String patientName;
  final String patientEmail;
  final String status;
  final DateTime expiresAt;
  final DateTime? completedAt;
  final int totalQuestions;

  factory InvitationSummary.fromJson(Map<String, dynamic> j) => InvitationSummary(
        id: j['id'] as String? ?? '',
        patientId: j['patient_id'] as String? ?? '',
        patientName: j['patient_name'] as String? ?? '',
        patientEmail: j['patient_email'] as String? ?? '',
        status: j['status'] as String? ?? 'pending',
        expiresAt: DateTime.tryParse(j['expires_at']?.toString() ?? '') ?? DateTime.now(),
        completedAt: DateTime.tryParse(j['completed_at']?.toString() ?? ''),
        totalQuestions: (j['total_questions'] as num?)?.toInt() ?? 0,
      );
}

class InvitationSendResult {
  InvitationSendResult({
    required this.invitation,
    required this.publicLink,
    this.emailSent = false,
    this.emailError,
  });

  final InvitationSummary invitation;
  final String publicLink;
  final bool emailSent;
  final String? emailError;

  factory InvitationSendResult.fromJson(Map<String, dynamic> j) => InvitationSendResult(
        invitation: InvitationSummary.fromJson(
          Map<String, dynamic>.from((j['invitation'] as Map?) ?? const {}),
        ),
        publicLink: j['public_link'] as String? ?? '',
        emailSent: j['email_sent'] as bool? ?? false,
        emailError: j['email_error'] as String?,
      );
}
