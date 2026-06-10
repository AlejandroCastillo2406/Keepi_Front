import 'package:flutter/material.dart';

import '../services/appointment_service.dart';
import '../services/doctor_service.dart';

/// Rutas internas del panel derecho en web (la sidebar izquierda permanece fija).
enum DoctorWebOverlayKind {
  settings,
  consultation,
  patientProfile,
  timeline,
  requestAnalysis,
  assignPrescription,
  sendQuestionnaire,
  notifications,
  createPatient,
  priorDocuments,
  uploadAnalysis,
}

class DoctorWebRoute {
  const DoctorWebRoute({
    required this.kind,
    this.appointment,
    this.patient,
    this.profileTabIndex = 0,
    this.priorDocumentsPatientId,
    this.priorDocumentsPatientName,
    this.uploadRequestId,
    this.uploadDescription,
    this.consultationPatientName,
    this.consultationPatientEmail,
  });

  final DoctorWebOverlayKind kind;
  final AppointmentDto? appointment;
  final PatientListItem? patient;
  final int profileTabIndex;
  final String? priorDocumentsPatientId;
  final String? priorDocumentsPatientName;
  final String? uploadRequestId;
  final String? uploadDescription;
  final String? consultationPatientName;
  final String? consultationPatientEmail;
}

/// API de navegación embebida para pantallas hijas en web.
abstract class DoctorWebNavigator {
  void push(DoctorWebRoute route);
  void pop();
  void clear();
  void openConsultation(
    AppointmentDto appointment, {
    String? patientName,
    String? patientEmail,
  });
  void openPatientProfile(PatientListItem patient, {int tabIndex = 0});
}

class DoctorWebShellScope extends InheritedWidget {
  const DoctorWebShellScope({
    super.key,
    required this.navigator,
    required super.child,
  });

  final DoctorWebNavigator navigator;

  static DoctorWebNavigator? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<DoctorWebShellScope>()
        ?.navigator;
  }

  @override
  bool updateShouldNotify(DoctorWebShellScope oldWidget) =>
      navigator != oldWidget.navigator;
}
