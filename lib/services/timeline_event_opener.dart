import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/timeline_event.dart';
import '../router/app_navigation.dart';
import '../router/app_paths.dart';
import '../screens/doctor/questionnaire/doctor_answer_invitation_screen.dart';
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
    final pendingInvitationId = _pendingInvitationIdFromEvent(event);
    if (pendingInvitationId != null) {
      final label = (event.subtitle ?? event.title).trim();
      final answered = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => DoctorAnswerInvitationScreen(
            invitationId: pendingInvitationId,
            invitationLabel: label.isEmpty ? 'Solicitud pendiente' : label,
            patientName: patientName,
          ),
        ),
      );
      if (answered == true) onNoteSaved?.call();
      return;
    }

    if (event.isPriorDocuments) {
      final pid = event.actionPatientId ?? patientId;
      await context.push<void>(AppPaths.doctorPriorDocuments(pid));
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

  static String? _pendingInvitationIdFromEvent(TimelineEvent event) {
    if (!event.isPendingStep) return null;
    if (event.isClinicalIntake && event.id.startsWith('intake_req_')) {
      return event.clinicalIntakeInvitationId;
    }
    if (event.isPriorDocuments && event.id.startsWith('priordocs_req_')) {
      return event.priorDocsInvitationId;
    }
    return null;
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

    await context.push<void>(
      AppPaths.doctorConsultation(
        appointment.id,
        patientId: appointment.patientId,
        name: name,
        email: email,
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
    await AppNavigation.push<void>(
      context,
      AppPaths.doctorConsultation(
        appointmentId,
        patientId: patientId,
        name: patientName,
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

    final patientName = patients
            ?.where((p) => p.id == patientId)
            .map((p) => p.name)
            .firstOrNull ??
        'Paciente';

    if (type == 'appointment') {
      await AppNavigation.push<void>(
        context,
        AppPaths.doctorConsultation(
          item.id,
          patientId: patientId,
          name: patientName,
        ),
      );
      return;
    }

    final doctorSvc = DoctorService(context.read<ApiClient>());

    if (!context.mounted) return;
    AppNavigation.showLoadingOverlay(context);

    TimelineEvent? event;
    try {
      event = await TimelineEventResolver.resolveForSearchItem(
        doctorService: doctorSvc,
        item: item,
      );
    } catch (e) {
      if (context.mounted) AppNavigation.hideLoadingOverlay(context);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DoctorService.messageFromDio(e))),
      );
      return;
    }

    if (context.mounted) AppNavigation.hideLoadingOverlay(context);
    if (!context.mounted || event == null) return;

    await openTimelineEvent(
      context,
      patientId: patientId,
      patientName: patientName,
      event: event,
    );
  }
}
