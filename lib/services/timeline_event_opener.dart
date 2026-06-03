import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../models/timeline_event.dart';
import '../services/api_client.dart';
import '../services/appointment_service.dart';
import '../services/doctor_service.dart';
import '../services/search_service.dart';
import '../utils/timeline_event_resolver.dart';
import '../widgets/timeline_event_detail_sheet.dart';
import 'search_result_navigation.dart';

/// Abre el detalle de timeline (misma UI en inicio, búsqueda e historial).
class TimelineEventOpener {
  static Future<void> openAppointment(
    BuildContext context, {
    required AppointmentDto appointment,
    VoidCallback? onNoteSaved,
  }) async {
    final api = context.read<ApiClient>();
    final doctorSvc = DoctorService(api);
    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: KeepiColors.orange),
      ),
    );

    TimelineEvent event;
    try {
      event = await TimelineEventResolver.resolveForAppointment(
        doctorService: doctorSvc,
        appointment: appointment,
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
    if (!context.mounted) return;

    await TimelineEventDetailSheet.show(
      context,
      patientId: appointment.patientId,
      event: event,
      onNoteSaved: onNoteSaved,
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

    await TimelineEventDetailSheet.show(
      context,
      patientId: patientId,
      event: event,
    );
  }
}
