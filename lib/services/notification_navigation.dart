import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/roles.dart';
import '../providers/auth_provider.dart';
import '../router/app_navigation.dart';
import '../router/app_paths.dart';
import '../widgets/document_replacement_banner.dart';
import 'api_client.dart';
import 'doctor_service.dart';
import '../widgets/questionnaire_notification_detail_sheet.dart';
import '../widgets/doctor_pending_appointment_review_sheet.dart';
import 'notifications_service.dart';

/// Navegación al abrir notificaciones (bandeja in-app o push).
class NotificationNavigation {
  static String? documentIdFrom(Map<String, dynamic> data) {
    final id = data['document_id']?.toString();
    if (id != null && id.isNotEmpty) return id;
    return null;
  }

  static bool isAnalysisRequestCompleted(Map<String, dynamic> data) {
    final t = data['type']?.toString() ?? '';
    if (t == 'analysis_request_completed') return true;
    final docId = documentIdFrom(data);
    final reqId = data['analysis_request_id']?.toString();
    return docId != null && reqId != null && reqId.isNotEmpty;
  }

  static bool isDocumentReplaced(Map<String, dynamic> data) {
    final t = data['type']?.toString() ?? '';
    if (t == 'document_replaced') return true;
    final oldId = data['old_document_id']?.toString();
    final newId = data['new_document_id']?.toString();
    return oldId != null &&
        oldId.isNotEmpty &&
        newId != null &&
        newId.isNotEmpty;
  }

  static Map<String, dynamic> dataFromNotification(AppNotificationDto n) {
    final merged = <String, dynamic>{...n.payload};
    if (n.documentId != null) merged['document_id'] = n.documentId;
    final payloadType = n.payload['type']?.toString();
    if (payloadType != null && payloadType.isNotEmpty) {
      merged['type'] = payloadType;
    } else if (n.type.isNotEmpty && n.type != 'info') {
      merged['type'] = n.type;
    }
    return merged;
  }

  static Future<void> openDocumentReplacement(
    BuildContext context, {
    required Map<String, dynamic> data,
  }) async {
    final oldId = data['old_document_id']?.toString();
    final newId =
        data['new_document_id']?.toString() ?? documentIdFrom(data);
    if (oldId == null || oldId.isEmpty || newId == null || newId.isEmpty) {
      return;
    }
    showDocumentReplacementComparisonSheet(
      context,
      oldDocumentId: oldId,
      newDocumentId: newId,
      oldName: data['old_name']?.toString(),
      newName: data['new_name']?.toString(),
      oldCategory: data['old_category']?.toString(),
      newCategory: data['new_category']?.toString(),
    );
  }

  static Future<void> openAnalysisDocument(
    BuildContext context, {
    required Map<String, dynamic> data,
    String? title,
  }) async {
    final documentId = documentIdFrom(data);
    if (documentId == null) return;

    final api = context.read<ApiClient>();
    final svc = DoctorService(api);
    final token = api.accessToken;
    final headers = <String, String>{
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      'Accept': '*/*',
    };
    final url = svc.getMobileDocumentUrl(documentId);

    if (!context.mounted) return;
    await AppNavigation.pushDocumentViewer(
      context,
      url: url,
      title: title ?? 'Análisis',
      headers: headers,
    );
  }

  static bool isQuestionnaireCompleted(Map<String, dynamic> data) {
    return data['type']?.toString() == 'questionnaire_completed';
  }

  static AppNotificationDto notificationFromPushData(
    Map<String, dynamic> data, {
    String? fallbackTitle,
    String? fallbackBody,
  }) {
    return AppNotificationDto(
      id: data['notification_id']?.toString() ?? '',
      title: data['title']?.toString() ?? fallbackTitle ?? 'Notificación',
      message: data['body']?.toString() ?? fallbackBody ?? '',
      type: data['type']?.toString() ?? 'info',
      read: true,
      payload: Map<String, dynamic>.from(data),
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  static Future<void> openQuestionnaireCompletedDetail(
    BuildContext context, {
    required AppNotificationDto notification,
  }) {
    return showQuestionnaireNotificationDetailSheet(
      context,
      notification: notification,
    );
  }

  /// Cita solicitada por paciente en web, pendiente de acción del doctor.
  static bool isDoctorWebAppointmentPending(AppNotificationDto n) {
    return n.type == 'appointment_pending_approval' ||
        n.appointmentAction == 'doctor_approve' ||
        n.appointmentAction == 'doctor_review' ||
        n.payload['type']?.toString() == 'appointment_pending_approval';
  }

  /// Abre el detalle de cita web pendiente para el doctor.
  static Future<void> openDoctorPendingAppointmentReview(
    BuildContext context, {
    required String appointmentId,
    VoidCallback? onChanged,
  }) {
    return DoctorPendingAppointmentReviewSheet.show(
      context,
      appointmentId: appointmentId,
      onChanged: onChanged,
    );
  }

  /// Navega a la pantalla relevante al abrir una push de cita.
  static void navigateForAppointmentPush(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    if (!context.mounted) return;
    final auth = context.read<AuthProvider>();
    final role = auth.roleName;
    final type = data['type']?.toString() ?? '';
    final action = data['action']?.toString() ?? '';
    final appointmentId = data['appointment_id']?.toString();

    if (role == AppRole.doctor) {
      if (appointmentId != null &&
          appointmentId.isNotEmpty &&
          (type == 'appointment_pending_approval' ||
              action == 'doctor_approve' ||
              action == 'doctor_review')) {
        openDoctorPendingAppointmentReview(
          context,
          appointmentId: appointmentId,
        );
        return;
      }
      if (appointmentId != null && appointmentId.isNotEmpty) {
        context.push(AppPaths.doctorConsultation(appointmentId));
      }
      return;
    }
    if (role == AppRole.patient && type.startsWith('appointment_')) {
      context.go(AppPaths.patientConsultas);
    }
  }
}
