import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/doctor/analysis_document_viewer_screen.dart';
import '../widgets/document_replacement_banner.dart';
import 'api_client.dart';
import 'doctor_service.dart';
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
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnalysisDocumentViewerScreen(
          url: url,
          title: title ?? 'Análisis',
          headers: headers,
        ),
      ),
    );
  }
}
