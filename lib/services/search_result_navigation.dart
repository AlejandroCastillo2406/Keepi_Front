import 'package:flutter/material.dart';

import '../services/drive_structure_service.dart';
import '../services/document_file_opener.dart';
import '../services/doctor_service.dart';
import 'search_service.dart';
import 'timeline_event_opener.dart';

/// Abre el elemento correspondiente al pulsar un resultado de búsqueda global.
class SearchResultNavigation {
  static Future<void> open(
    BuildContext context,
    GlobalSearchItem item, {
    List<PatientListItem>? patients,
    VoidCallback? onDoctorOpenAgenda,
  }) async {
    switch (item.type) {
      case 'document':
        await _openDocument(context, item);
        break;
      case 'appointment':
      case 'analysis':
        await TimelineEventOpener.openSearchItem(
          context,
          item,
          patients: patients,
          onDoctorOpenAgenda: onDoctorOpenAgenda,
        );
        break;
      default:
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tipo no soportado: ${item.type}')),
        );
    }
  }

  static Future<void> _openDocument(
    BuildContext context,
    GlobalSearchItem item,
  ) async {
    final subtitle = item.subtitle?.trim();
    await DocumentFileOpener.open(
      context,
      file: DriveFile(
        id: item.id,
        name: item.title,
        keepiDocumentId: item.id,
        mimeType: _guessMimeFromName(item.title),
        category: subtitle,
      ),
    );
  }

  static String? _guessMimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    return null;
  }
}
