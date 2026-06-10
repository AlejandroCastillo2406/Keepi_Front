import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/doctor_web_shell_scope.dart';
import '../core/web_layout.dart';
import '../models/timeline_event.dart';
import '../screens/common/prior_documents_screen.dart';
import '../screens/doctor/doctor_consultation_screen.dart';
import '../services/api_client.dart';
import '../services/appointment_service.dart';
import '../services/doctor_service.dart';
import '../services/search_service.dart';
import '../utils/timeline_event_resolver.dart';
import '../widgets/timeline_event_detail_sheet.dart';
import 'search_result_navigation.dart';

/// Abre el detalle de timeline (misma UI en inicio, búsqueda e historial).
class TimelineEventOpener {
  static Future<void> openTimelineEvent(
    BuildContext context, {
    required String patientId,
    required String patientName,
    required TimelineEvent event,
    VoidCallback? onNoteSaved,
  }) async {
    if (event.isPriorDocuments) {
      final pid = event.actionPatientId ?? patientId;
      final webNav = DoctorWebShellScope.maybeOf(context);
      if (webNav != null && isWebWide(context)) {
        webNav.push(
          DoctorWebRoute(
            kind: DoctorWebOverlayKind.priorDocuments,
            priorDocumentsPatientId: pid,
            priorDocumentsPatientName: patientName,
          ),
        );
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => PriorDocumentsScreen(
            patientId: pid,
            patientName: patientName,
          ),
        ),
      );
      return;
    }

    if (event.eventType.toLowerCase() == 'appointment') {
      final apptId = event.id.replaceAll(RegExp(r'^appt_'), '');
      if (apptId.isNotEmpty) {
        await _openConsultationByAppointmentId(
          context,
          appointmentId: apptId,
          patientId: patientId,
          patientName: patientName,
          onSaved: onNoteSaved,
        );
        return;
      }
    }

    await TimelineEventDetailSheet.show(
      context,
      patientId: patientId,
      event: event,
      onNoteSaved: onNoteSaved,
    );
  }

  static Future<void> openAppointment(
    BuildContext context, {
    required AppointmentDto appointment,
    VoidCallback? onNoteSaved,
  }) async {
    final api = context.read<ApiClient>();
    final doctorSvc = DoctorService(api);
    if (!context.mounted) return;

    String name = 'Paciente';
    String? email;
    try {
      final patients = await doctorSvc.fetchMyPatients();
      final match =
          patients.where((p) => p.id == appointment.patientId).toList();
      if (match.isNotEmpty) {
        name = match.first.name;
        email = match.first.email;
      }
    } catch (_) {}

    if (!context.mounted) return;

    final webNav = DoctorWebShellScope.maybeOf(context);
    if (webNav != null && isWebWide(context)) {
      webNav.openConsultation(
        appointment,
        patientName: name,
        patientEmail: email,
      );
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DoctorConsultationScreen(
          appointment: appointment,
          patientName: name,
          patientEmail: email,
          onSaved: onNoteSaved,
        ),
      ),
    );
  }

  static Future<void> _openConsultationByAppointmentId(
    BuildContext context, {
    required String appointmentId,
    required String patientId,
    required String patientName,
    VoidCallback? onSaved,
  }) async {
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: KeepiColors.orange),
      ),
    );

    AppointmentDto appointment;
    try {
      appointment =
          await AppointmentService(context.read<ApiClient>()).fetchById(
        appointmentId,
      );
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppointmentService.messageFromDio(e))),
      );
      return;
    }

    if (context.mounted) Navigator.of(context).pop();
    if (!context.mounted) return;

    final webNav = DoctorWebShellScope.maybeOf(context);
    if (webNav != null && isWebWide(context)) {
      webNav.openConsultation(
        appointment,
        patientName: patientName,
      );
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DoctorConsultationScreen(
          appointment: appointment,
          patientName: patientName,
          onSaved: onSaved,
        ),
      ),
    );
  }

  static Future<void> openSearchItem(
    BuildContext context,
    GlobalSearchItem item, {
    List<PatientListItem>? patients,
    VoidCallback? onDoctorOpenAgenda,
  }) async {
    final type = item.type.toLowerCase();
    if (type == 'document') {
      await SearchResultNavigation.open(
        context,
        item,
        patients: patients,
        onDoctorOpenAgenda: onDoctorOpenAgenda,
      );
      return;
    }

    final patientId = item.patientId?.trim();
    if (patientId == null || patientId.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se encontró el paciente del resultado.'),
        ),
      );
      return;
    }

    final doctorSvc = DoctorService(context.read<ApiClient>());

    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: KeepiColors.orange),
      ),
    );

    TimelineEvent? event;
    try {
      event = await TimelineEventResolver.resolveForSearchItem(
        doctorService: doctorSvc,
        item: item,
      );
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DoctorService.messageFromDio(e))),
      );
      return;
    }

    if (context.mounted) Navigator.of(context).pop();
    if (!context.mounted || event == null) return;

    final patientName = patients
            ?.where((p) => p.id == patientId)
            .map((p) => p.name)
            .firstOrNull ??
        'Paciente';

    await openTimelineEvent(
      context,
      patientId: patientId,
      patientName: patientName,
      event: event,
    );
  }
}
