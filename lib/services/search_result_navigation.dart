import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/roles.dart';
import '../providers/auth_provider.dart';
import '../screens/doctor/analysis_document_viewer_screen.dart';
import '../screens/doctor/doctor_request_analysis_screen.dart';
import '../screens/doctor/doctor_upload_analysis_for_patient_screen.dart';
import '../services/api_client.dart';
import '../services/appointment_service.dart';
import '../services/doctor_service.dart';
import '../services/drive_structure_service.dart';
import '../services/document_file_opener.dart';
import 'search_service.dart';

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
        await _openAppointment(context, item, patients: patients);
        break;
      case 'analysis':
        await _openAnalysis(context, item, patients: patients);
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

  static Future<void> _openAppointment(
    BuildContext context,
    GlobalSearchItem item, {
    List<PatientListItem>? patients,
  }) async {
    final api = context.read<ApiClient>();
    final svc = AppointmentService(api);
    AppointmentDto? appt;
    try {
      appt = await svc.fetchById(item.id);
    } catch (_) {
      appt = null;
    }
    if (!context.mounted) return;

    final auth = context.read<AuthProvider>();
    final isDoctor = auth.roleName == AppRole.doctor;
    String patientName = 'Paciente';
    if (patients != null && appt != null) {
      final match =
          patients.where((p) => p.id == appt!.patientId).toList();
      if (match.isNotEmpty) patientName = match.first.name;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AppointmentDetailSheet(
        item: item,
        appointment: appt,
        patientName: patientName,
        isDoctor: isDoctor,
        appointmentService: svc,
      ),
    );
  }

  static Future<void> _openAnalysis(
    BuildContext context,
    GlobalSearchItem item, {
    List<PatientListItem>? patients,
  }) async {
    final api = context.read<ApiClient>();
    final svc = DoctorService(api);
    final auth = context.read<AuthProvider>();
    final isDoctor = auth.roleName == AppRole.doctor;

    AnalysisRequestDto? request;
    if (item.patientId != null && item.patientId!.isNotEmpty) {
      try {
        final list = await svc.fetchPatientAnalysisRequests(item.patientId!);
        for (final r in list) {
          if (r.id == item.id) {
            request = r;
            break;
          }
        }
      } catch (_) {}
    }
    if (request == null) {
      try {
        final pending = await svc.fetchMyPendingRequests();
        for (final r in pending) {
          if (r.id == item.id) {
            request = r;
            break;
          }
        }
      } catch (_) {}
    }

    if (!context.mounted) return;

    String patientName = 'Paciente';
    if (patients != null && item.patientId != null) {
      final match =
          patients.where((p) => p.id == item.patientId).toList();
      if (match.isNotEmpty) patientName = match.first.name;
    }

    final docId = request?.documentId?.trim();
    if (docId != null && docId.isNotEmpty) {
      final url = svc.getMobileDocumentUrl(docId);
      final token = api.accessToken;
      final headers = <String, String>{
        if (token != null && token.isNotEmpty)
          'Authorization': 'Bearer $token',
        'Accept': '*/*',
      };
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AnalysisDocumentViewerScreen(
            url: url,
            title: item.title,
            headers: headers,
          ),
        ),
      );
      return;
    }

    if (isDoctor && item.patientId != null && item.patientId!.isNotEmpty) {
      final status = (request?.status ?? item.status ?? '').toLowerCase();
      if (status == 'pending' || status == 'pendiente') {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DoctorUploadAnalysisForPatientScreen(
              requestId: item.id,
              description: item.title,
              patientName: patientName,
            ),
          ),
        );
      } else {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DoctorRequestAnalysisScreen(
              patientId: item.patientId!,
              patientName: patientName,
            ),
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AnalysisDetailSheet(item: item, request: request),
    );
  }
}

class _AppointmentDetailSheet extends StatelessWidget {
  const _AppointmentDetailSheet({
    required this.item,
    required this.appointment,
    required this.patientName,
    required this.isDoctor,
    required this.appointmentService,
  });

  final GlobalSearchItem item;
  final AppointmentDto? appointment;
  final String patientName;
  final bool isDoctor;
  final AppointmentService appointmentService;

  String _statusLabel(String status) {
    switch (status) {
      case 'pending_patient_approval':
        return 'Pendiente de confirmación del paciente';
      case 'scheduled':
        return 'Confirmada';
      case 'pending_doctor_proposal':
        return 'Esperando fecha del doctor';
      case 'canceled':
        return 'Cancelada';
      default:
        return status;
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return 'Sin fecha asignada';
    final local = d.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year} · '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final appt = appointment;
    final status = appt?.status ?? item.status ?? '';
    final date = appt?.appointmentDate ?? item.date;
    final reason = appt?.reason.isNotEmpty == true ? appt!.reason : item.title;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: KeepiColors.slate.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: KeepiColors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.event_rounded,
                  color: KeepiColors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Cita médica',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: KeepiColors.slate,
                      ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DetailRow(label: 'Motivo', value: reason),
          _DetailRow(label: 'Paciente', value: patientName),
          _DetailRow(label: 'Fecha', value: _formatDate(date)),
          _DetailRow(label: 'Estado', value: _statusLabel(status)),
          if (item.subtitle != null && item.subtitle!.isNotEmpty)
            _DetailRow(label: 'Detalle', value: item.subtitle!),
        ],
      ),
    );
  }
}

class _AnalysisDetailSheet extends StatelessWidget {
  const _AnalysisDetailSheet({required this.item, this.request});

  final GlobalSearchItem item;
  final AnalysisRequestDto? request;

  @override
  Widget build(BuildContext context) {
    final status = request?.status ?? item.status ?? '';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.biotech_outlined, color: KeepiColors.skyBlue),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DetailRow(label: 'Estado', value: status),
          if (item.subtitle != null)
            _DetailRow(label: 'Info', value: item.subtitle!),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: KeepiColors.slateLight,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: KeepiColors.slate,
                  height: 1.35,
                ),
          ),
        ],
      ),
    );
  }
}
