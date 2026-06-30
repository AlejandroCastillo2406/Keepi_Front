import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../screens/common/notifications_screen.dart';
import '../screens/common/prior_documents_screen.dart';
import '../screens/doctor/create_patient_screen.dart';
import '../screens/doctor/doctor_assign_prescription_screen.dart';
import '../screens/doctor/doctor_consultation_screen.dart';
import '../screens/doctor/doctor_patient_profile_screen.dart';
import '../screens/doctor/doctor_patient_timeline_screen.dart';
import '../screens/doctor/doctor_request_analysis_screen.dart';
import '../screens/doctor/doctor_upload_analysis_for_patient_screen.dart';
import '../screens/doctor/questionnaire/send_questionnaire_screen.dart';
import '../screens/user/settings_screen.dart';
import '../screens/doctor/doctor_attendance_detail_screen.dart';
import '../providers/patients_cache_provider.dart';
import '../services/api_client.dart';
import '../services/appointment_service.dart';
import '../services/doctor_service.dart';
import 'doctor_session_scope.dart';

/// Marcador vacío: el shell muestra el IndexedStack de tabs.
class DoctorTabPlaceholder extends StatelessWidget {
  const DoctorTabPlaceholder({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Widget buildDoctorOverlayPage(BuildContext context, GoRouterState state) {
  final bridge = DoctorSessionScope.of(context);
  final api = context.read<ApiClient>();
  final path = state.uri.path;

  if (path.endsWith('/configuracion')) {
    return const SettingsScreen(embedded: true);
  }
  if (path.endsWith('/notificaciones')) {
    return NotificationsScreen(embedded: true, onBack: bridge.onPop);
  }
  if (path.endsWith('/nuevo-paciente')) {
    return CreatePatientScreen(
      api: api,
      embedded: true,
      onBack: bridge.onPop,
      onCreated: () async {
        bridge.onPop();
        await bridge.onRefreshAll();
      },
    );
    
  }
  if (path.endsWith('/asistencia-detalle')) {
      return DoctorAttendanceDetailScreen(
        embedded: true,
        status: state.uri.queryParameters['status'] ?? 'pending',
        onBack: bridge.onPop,
      );
    }

  final consultaMatch = RegExp(r'/consulta/([^/]+)$').firstMatch(path);
  if (consultaMatch != null) {
    final appointmentId = consultaMatch.group(1)!;
    final name = state.uri.queryParameters['name'];
    final email = state.uri.queryParameters['email'];
    final patientId = state.uri.queryParameters['patientId'];
    return _ConsultationRouteLoader(
      appointmentId: appointmentId,
      patientId: patientId,
      patientName: name,
      patientEmail: email,
      bridge: bridge,
    );
  }

  final patientMatch = RegExp(r'/paciente/([^/]+)').firstMatch(path);
  if (patientMatch == null) {
    return _MissingRouteData(
      message: 'Ruta no reconocida.',
      onBack: bridge.onPop,
    );
  }

  return _PatientRouteLoader(
    patientId: patientMatch.group(1)!,
    path: path,
    state: state,
    bridge: bridge,
    api: api,
  );
}

Widget _buildPatientRouteContent({
  required PatientListItem patient,
  required String path,
  required GoRouterState state,
  required DoctorSessionBridge bridge,
  required ApiClient api,
}) {
  if (path.endsWith('/historial')) {
    return DoctorPatientTimelineScreen(
      embedded: true,
      patientId: patient.id,
      patientName: patient.name,
      onBack: bridge.onPop,
    );
  }
  if (path.endsWith('/solicitar-analisis')) {
    return DoctorRequestAnalysisScreen(
      embedded: true,
      patientId: patient.id,
      patientName: patient.name,
      onBack: bridge.onPop,
    );
  }
  if (path.endsWith('/receta')) {
    return DoctorAssignPrescriptionScreen(
      embedded: true,
      patientId: patient.id,
      patientName: patient.name,
      onBack: bridge.onPop,
    );
  }
  if (path.endsWith('/cuestionario')) {
    return SendQuestionnaireScreen(
      embedded: true,
      api: api,
      patientId: patient.id,
      patientName: patient.name,
      patientEmail: patient.email,
      onBack: bridge.onPop,
    );
  }
  if (path.endsWith('/documentos-previos')) {
    return PriorDocumentsScreen(
      embedded: true,
      patientId: patient.id,
      patientName: patient.name,
      onBack: bridge.onPop,
    );
  }
  final uploadMatch = RegExp(r'/subir-analisis/([^/]+)$').firstMatch(path);
  if (uploadMatch != null) {
    return DoctorUploadAnalysisForPatientScreen(
      embedded: true,
      requestId: uploadMatch.group(1)!,
      description: state.uri.queryParameters['desc'] ?? '',
      patientName: patient.name,
      onBack: bridge.onPop,
    );
  }

  final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '0') ?? 0;
  return DoctorPatientProfileScreen(
    embedded: true,
    patientId: patient.id,
    patientName: patient.name,
    patientEmail: patient.email,
    mustChangePassword: patient.mustChangePassword,
    initialTabIndex: tab,
    onBack: bridge.onPop,
    onOpenTimeline: () => bridge.onOpenTimeline(patient),
    onOpenRequestAnalysis: () => bridge.onOpenRequestAnalysis(patient),
    onOpenAssignPrescription: () => bridge.onOpenAssignPrescription(patient),
    onOpenSchedule: () => bridge.onScheduleAppointment(patient),
    onOpenQuestionnaire: () => bridge.onOpenSendQuestionnaire(patient),
    onOpenConsultation: () => bridge.onOpenConsultationForPatient(patient),
  );
}

class _PatientRouteLoader extends StatefulWidget {
  const _PatientRouteLoader({
    required this.patientId,
    required this.path,
    required this.state,
    required this.bridge,
    required this.api,
  });

  final String patientId;
  final String path;
  final GoRouterState state;
  final DoctorSessionBridge bridge;
  final ApiClient api;

  @override
  State<_PatientRouteLoader> createState() => _PatientRouteLoaderState();
}

class _PatientRouteLoaderState extends State<_PatientRouteLoader> {
  PatientListItem? _patient;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final cache = context.read<PatientsCacheProvider>();
    var patient = widget.bridge.patientById(widget.patientId) ??
        cache.peekPatient(widget.patientId);
    if (patient == null) {
      try {
        final list = await cache.fetchAndCachePatients(
          DoctorService(context.read<ApiClient>()),
        );
        for (final p in list) {
          if (p.id == widget.patientId) {
            patient = p;
            break;
          }
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = DoctorService.messageFromDio(e);
          _loading = false;
        });
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _patient = patient;
      _loading = false;
      if (patient == null) _error = 'Paciente no encontrado.';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: KeepiColors.orange),
      );
    }
    if (_error != null || _patient == null) {
      return _MissingRouteData(
        message: _error ?? 'Paciente no encontrado.',
        onBack: widget.bridge.onPop,
      );
    }

    return _buildPatientRouteContent(
      patient: _patient!,
      path: widget.path,
      state: widget.state,
      bridge: widget.bridge,
      api: widget.api,
    );
  }
}

class _ConsultationRouteLoader extends StatefulWidget {
  const _ConsultationRouteLoader({
    required this.appointmentId,
    required this.bridge,
    this.patientId,
    this.patientName,
    this.patientEmail,
  });

  final String appointmentId;
  final DoctorSessionBridge bridge;
  final String? patientId;
  final String? patientName;
  final String? patientEmail;

  @override
  State<_ConsultationRouteLoader> createState() =>
      _ConsultationRouteLoaderState();
}

class _ConsultationRouteLoaderState extends State<_ConsultationRouteLoader> {
  AppointmentDto? _appointment;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    var appt = widget.bridge.appointmentById(widget.appointmentId);
    if (appt == null) {
      try {
        appt = await AppointmentService(context.read<ApiClient>())
            .fetchById(widget.appointmentId);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = AppointmentService.messageFromDio(e);
          _loading = false;
        });
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _appointment = appt;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return ColoredBox(
        color: KeepiColors.surfaceBg,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: widget.bridge.onPop,
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: KeepiColors.slate,
                  ),
                  const Expanded(
                    child: Text(
                      'Consulta',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: KeepiColors.slate,
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.patientName != null &&
                  widget.patientName!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  widget.patientName!.trim(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: KeepiColors.slate,
                  ),
                ),
              ],
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: KeepiColors.orange),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_error != null || _appointment == null) {
      return _MissingRouteData(
        message: _error ?? 'Cita no encontrada.',
        onBack: widget.bridge.onPop,
      );
    }

    final appt = _appointment!;
    final p = widget.bridge.patientStubForAppointment(
      appt,
      name: widget.patientName,
      email: widget.patientEmail,
    );
    return DoctorConsultationScreen(
      key: ValueKey('consultation-${appt.id}'),
      embedded: true,
      appointment: appt,
      patientId: widget.patientId ?? appt.patientId,
      patientName: widget.patientName ?? p.name,
      patientEmail: widget.patientEmail ?? p.email,
      onBack: widget.bridge.onPop,
      onSaved: widget.bridge.onLoadAgenda,
      onOpenTimeline: () => widget.bridge.onOpenTimeline(p),
      onOpenRequestAnalysis: () => widget.bridge.onOpenRequestAnalysis(p),
      onOpenAssignPrescription: () => widget.bridge.onOpenAssignPrescription(p),
      onOpenSchedule: () => widget.bridge.onScheduleAppointment(p),
      onOpenQuestionnaire: () => widget.bridge.onOpenSendQuestionnaire(p),
      onTabSelected: (index) =>
          widget.bridge.onOpenPatientProfile(p, tabIndex: index),
    );
  }
}

class _MissingRouteData extends StatelessWidget {
  const _MissingRouteData({
    required this.message,
    required this.onBack,
  });

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onBack, child: const Text('Volver')),
        ],
      ),
    );
  }
}
