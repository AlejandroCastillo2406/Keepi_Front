import 'package:flutter/material.dart';

import '../services/appointment_service.dart';
import '../services/doctor_service.dart';

/// Datos y callbacks del panel médico para construir pantallas desde rutas.
class DoctorSessionBridge {
  const DoctorSessionBridge({
    required this.appointmentById,
    required this.patientById,
    required this.patientStubForAppointment,
    required this.onRefreshAll,
    required this.onLoadAgenda,
    required this.onPop,
    required this.onOpenTimeline,
    required this.onOpenRequestAnalysis,
    required this.onOpenAssignPrescription,
    required this.onScheduleAppointment,
    required this.onOpenSendQuestionnaire,
    required this.onOpenConsultationForPatient,
    required this.onOpenPatientProfile,
  });

  final AppointmentDto? Function(String appointmentId) appointmentById;
  final PatientListItem? Function(String patientId) patientById;
  final PatientListItem Function(
    AppointmentDto appointment, {
    String? name,
    String? email,
  }) patientStubForAppointment;
  final Future<void> Function() onRefreshAll;
  final Future<void> Function() onLoadAgenda;
  final VoidCallback onPop;
  final void Function(PatientListItem patient) onOpenTimeline;
  final void Function(PatientListItem patient) onOpenRequestAnalysis;
  final void Function(PatientListItem patient) onOpenAssignPrescription;
  final void Function(PatientListItem patient) onScheduleAppointment;
  final void Function(PatientListItem patient) onOpenSendQuestionnaire;
  final void Function(PatientListItem patient) onOpenConsultationForPatient;
  final void Function(PatientListItem patient, {int tabIndex})
      onOpenPatientProfile;
}

class DoctorSessionScope extends InheritedWidget {
  const DoctorSessionScope({
    super.key,
    required this.bridge,
    required super.child,
  });

  final DoctorSessionBridge bridge;

  static DoctorSessionBridge of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<DoctorSessionScope>();
    assert(scope != null, 'DoctorSessionScope no encontrado en el árbol.');
    return scope!.bridge;
  }

  static DoctorSessionBridge? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<DoctorSessionScope>()
        ?.bridge;
  }

  @override
  bool updateShouldNotify(DoctorSessionScope oldWidget) =>
      bridge != oldWidget.bridge;
}
