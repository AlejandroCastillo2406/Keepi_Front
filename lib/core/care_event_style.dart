import 'package:flutter/material.dart';

import 'app_theme.dart';
import '../services/notifications_service.dart';

/// Colores e iconos de eventos clínicos (timeline + notificaciones).
class CareEventStyle {
  CareEventStyle._();

  static const Color registration = Color(0xFF0F766E);
  static const Color appointment = KeepiColors.orange;
  static const Color prescription = Color(0xFF7C3AED);
  static const Color analysisUpload = Color(0xFF0284C7);
  static const Color analysis = Color(0xFF2563EB);
  static const Color priorDocuments = Color(0xFF0D9488);
  static const Color clinicalIntake = Color(0xFF059669);
  static const Color defaultColor = KeepiColors.slate;

  static Color colorFor(String eventType) {
    switch (eventType) {
      case 'registration':
        return registration;
      case 'appointment':
        return appointment;
      case 'prescription':
        return prescription;
      case 'analysis_upload':
        return analysisUpload;
      case 'analysis':
      case 'analysis_request':
        return analysis;
      case 'prior_documents':
      case 'document_replaced':
        return priorDocuments;
      case 'clinical_intake':
      case 'questionnaire':
        return clinicalIntake;
      default:
        return defaultColor;
    }
  }

  static IconData iconFor(String eventType) {
    switch (eventType) {
      case 'registration':
        return Icons.verified_user_outlined;
      case 'appointment':
        return Icons.event_available_outlined;
      case 'prescription':
        return Icons.receipt_long_outlined;
      case 'analysis_upload':
        return Icons.attach_file_rounded;
      case 'analysis':
      case 'analysis_request':
        return Icons.biotech_outlined;
      case 'prior_documents':
        return Icons.folder_shared_outlined;
      case 'document_replaced':
        return Icons.find_replace_rounded;
      case 'clinical_intake':
      case 'questionnaire':
        return Icons.assignment_turned_in_outlined;
      default:
        return Icons.info_outline_rounded;
    }
  }

  static String labelFor(String eventType) {
    switch (eventType) {
      case 'registration':
        return 'CUENTA';
      case 'appointment':
        return 'CITA';
      case 'prescription':
        return 'RECETA';
      case 'analysis_upload':
        return 'ARCHIVO';
      case 'analysis':
      case 'analysis_request':
        return 'ANÁLISIS';
      case 'prior_documents':
        return 'DOCUMENTOS';
      case 'document_replaced':
        return 'DOCUMENTO';
      case 'clinical_intake':
        return 'ANTECEDENTES';
      case 'questionnaire':
        return 'CUESTIONARIO';
      default:
        return 'AVISO';
    }
  }
}

class NotificationEventStyle {
  NotificationEventStyle._();

  static String eventTypeFor(AppNotificationDto notification) {
    if (notification.isDocumentReplaced) return 'document_replaced';
    if (notification.isAnalysisRequestCompleted) return 'analysis_request';
    if (notification.isQuestionnaireCompleted) return 'questionnaire';
    if (notification.appointmentId != null) return 'appointment';
    if (notification.prescriptionId != null) return 'prescription';

    final payloadType =
        (notification.payload['type'] ?? notification.type).toString();
    switch (payloadType) {
      case 'analysis_request_completed':
      case 'analysis_request_deadline':
        return 'analysis_request';
      case 'questionnaire_completed':
        return 'questionnaire';
      case 'document_replaced':
        return 'document_replaced';
      case 'appointment_pending_approval':
      case 'appointment_proposed':
      case 'appointment_confirmed':
      case 'appointment_cancelled':
        return 'appointment';
      default:
        if (payloadType.startsWith('appointment_')) return 'appointment';
        return 'default';
    }
  }

  static Color colorFor(AppNotificationDto notification) =>
      CareEventStyle.colorFor(eventTypeFor(notification));

  static IconData iconFor(AppNotificationDto notification) =>
      CareEventStyle.iconFor(eventTypeFor(notification));

  static String tagFor(AppNotificationDto notification) =>
      CareEventStyle.labelFor(eventTypeFor(notification));

  static String actionHintFor(AppNotificationDto notification) {
    if (notification.isDocumentReplaced) return 'Toca para ver el reemplazo';
    if (notification.isAnalysisRequestCompleted) return 'Toca para ver detalles';
    if (notification.isQuestionnaireCompleted) return 'Toca para ver detalles';
    if (notification.appointmentId != null) return 'Toca para gestionar';
    if (notification.prescriptionId != null) return 'Toca para opciones';
    return 'Ver más';
  }
}
