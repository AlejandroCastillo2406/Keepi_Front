import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../core/decorative_background.dart';
import '../../core/web_layout.dart';
import '../../router/app_auth_actions.dart';
import '../../router/app_navigation.dart';
import '../../router/app_paths.dart';
import '../../router/doctor_session_scope.dart';
import '../../widgets/web_app_shell.dart';
import '../../providers/auth_provider.dart';
import '../../providers/patients_cache_provider.dart';
import '../../services/api_client.dart';
import '../../services/appointment_service.dart';
import '../../services/config_service.dart' as config_dto;
import '../../services/doctor_service.dart';
import '../../services/scheduling_service.dart';
import '../common/storage_choice_flow.dart';
import '../../widgets/doctor_note_field.dart';
import '../../widgets/doctor_appointment_slot_picker.dart';
import '../../widgets/doctor_pending_appointment_review_sheet.dart';
import 'doctor_calendar_tab.dart';
import 'documentos_screen.dart';
import '../../widgets/home_added_search_section.dart';

//   CONSTANTES / HELPERS

const _monthsEsUpper = <String>[
  'ENE',
  'FEB',
  'MAR',
  'ABR',
  'MAY',
  'JUN',
  'JUL',
  'AGO',
  'SEP',
  'OCT',
  'NOV',
  'DIC',
];
const _weekdaysEsUpper = <String>[
  'LUN',
  'MAR',
  'MIÉ',
  'JUE',
  'VIE',
  'SÁB',
  'DOM'
];

String _greetingForNow() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Buenos días';
  if (h < 19) return 'Buenas tardes';
  return 'Buenas noches';
}

String _todayStamp() {
  final now = DateTime.now();
  return '${_weekdaysEsUpper[now.weekday - 1]} · ${now.day.toString().padLeft(2, '0')} ${_monthsEsUpper[now.month - 1]} ${now.year}';
}

String _two(int v) => v.toString().padLeft(2, '0');

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime? _appointmentSlotEnd(AppointmentDto a, int slotMinutes) {
  if (a.endDate != null) return a.endDate!.toLocal();
  final start = a.appointmentDate?.toLocal();
  if (start == null) return null;
  return start.add(Duration(minutes: slotMinutes));
}

bool _canConfirmAttendance(AppointmentDto a, int slotMinutes) {
  if (a.status != 'scheduled') return false;
  if (a.attendanceStatus != null && a.attendanceStatus!.isNotEmpty) {
    return false;
  }
  final end = _appointmentSlotEnd(a, slotMinutes);
  if (end == null) return false;
  return DateTime.now().isAfter(end);
}

bool _isConfirmedAppointment(AppointmentDto a) => a.status == 'scheduled';

//   PANTALLA

class DoctorHomeScreen extends StatefulWidget {
  const DoctorHomeScreen({super.key, this.shellChild});

  /// Contenido de rutas hijas (overlays) en web vía go_router.
  final Widget? shellChild;

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  int _currentIndex = 0;

  // Patients state
  List<PatientListItem> _patients = [];
  bool _loadingPatients = true;
  String? _patientsError;
  String _patientQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  // Calendar state (for dashboard stats)
  List<AppointmentDto> _agenda = [];
  bool _loadingAgenda = true;
  String? _agendaError;
  int _slotDurationMinutes = 30;
  final Set<String> _markingAttendanceIds = {};

  // Storage onboarding
  final FirstRunStorageGate _storageGate = FirstRunStorageGate();
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri?>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    final cached = context.read<PatientsCacheProvider>().patientsList;
    if (cached != null) {
      _patients = cached;
      _loadingPatients = false;
    }
    _listenForStorageDeepLinks();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserConfigForStorage();
      _refreshAll();
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshAll({bool force = false}) async {
    await Future.wait([
      _loadPatients(force: force),
      _loadAgenda(),
    ]);
  }

  Future<void> _loadPatients({bool force = false}) async {
    if (!mounted) return;

    final cache = context.read<PatientsCacheProvider>();
    if (!force) {
      final cached = cache.patientsList;
      if (cached != null) {
        setState(() {
          _patients = cached;
          _loadingPatients = false;
          _patientsError = null;
        });
        return;
      }
    }

    setState(() {
      _loadingPatients = true;
      _patientsError = null;
    });
    try {
      final svc = DoctorService(context.read<ApiClient>());
      final list = await cache.fetchAndCachePatients(svc, force: force);
      if (!mounted) return;
      setState(() {
        _patients = list;
        _loadingPatients = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _patientsError = DoctorService.messageFromDio(e);
        _loadingPatients = false;
      });
    }
  }

  Future<void> _loadAgenda() async {
    if (!mounted) return;
    setState(() {
      _loadingAgenda = true;
      _agendaError = null;
    });
    try {
      final api = context.read<ApiClient>();
      final apptSvc = AppointmentService(api);
      final schedSvc = SchedulingService(api);
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day);
      final to = from.add(const Duration(days: 14));
      final results = await Future.wait([
        apptSvc.fetchDoctorCalendar(from: from, to: to),
        schedSvc.fetchSettings(),
      ]);
      if (!mounted) return;
      final calendar = results[0] as DoctorCalendarDto;
      setState(() {
        _agenda = calendar.appointments;
        _slotDurationMinutes =
            (results[1] as SchedulingSettingsDto).slotDurationMinutes;
        _loadingAgenda = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _agendaError = AppointmentService.messageFromDio(e);
        _loadingAgenda = false;
      });
    }
  }

  void _listenForStorageDeepLinks() {
    _appLinks.getInitialLink().then(_onStorageDeepLink);
    _linkSubscription = _appLinks.uriLinkStream.listen(_onStorageDeepLink);
  }

  void _onStorageDeepLink(Uri? uri) {
    if (uri == null) return;
    final s = uri.toString();
    if (s.contains('oauth2redirect') &&
        uri.queryParameters['success'] == '1' &&
        mounted) {
      _loadUserConfigForStorage();
      return;
    }
    if (s.contains('stripe-success') && mounted) {
      _loadUserConfigForStorage();
    }
  }

  Future<void> _loadUserConfigForStorage() async {
    try {
      final api = context.read<ApiClient>();
      final config = await config_dto.ConfigService(api).getUserConfig();
      if (!mounted) return;
      await maybeShowFirstRunStorageDialog(
        context,
        config: config,
        gate: _storageGate,
        onReloadAfterChoice: _loadUserConfigForStorage,
      );
    } catch (_) {}
  }

  List<AppointmentDto> get _todaysAppointments {
    final now = DateTime.now();
    return _agenda
        .where((a) =>
            _isConfirmedAppointment(a) &&
            a.appointmentDate != null &&
            _sameDay(a.appointmentDate!.toLocal(), now))
        .toList()
      ..sort((a, b) => a.appointmentDate!.compareTo(b.appointmentDate!));
  }

  List<AppointmentDto> get _upcomingAppointments {
    final now = DateTime.now();
    return _agenda.where((a) {
      if (!_isConfirmedAppointment(a)) return false;
      final d = a.appointmentDate?.toLocal();
      return d != null && d.isAfter(now);
    }).toList()
      ..sort((a, b) => a.appointmentDate!.compareTo(b.appointmentDate!));
  }

  int get _pendingConfirmCount => _agenda
      .where((a) =>
          a.status == 'pending_patient_approval' ||
          a.status == 'pending_doctor_proposal' ||
          a.status == 'pending_doctor_approval')
      .length;

  AppointmentDto? get _featuredNextAppointment {
    final now = DateTime.now();
    final candidates = _agenda
        .where((a) => _isConfirmedAppointment(a) && a.appointmentDate != null)
        .toList()
      ..sort((a, b) => a.appointmentDate!.compareTo(b.appointmentDate!));
    for (final a in candidates) {
      final end = _appointmentSlotEnd(a, _slotDurationMinutes);
      if (end != null && end.isAfter(now)) return a;
    }
    return null;
  }

  AppointmentDto? get _nextAppointment => _featuredNextAppointment;

  List<AppointmentDto> get _dashboardUpcoming {
    final featured = _featuredNextAppointment;
    final now = DateTime.now();
    return _agenda
        .where((a) {
          if (!_isConfirmedAppointment(a) || a.appointmentDate == null) {
            return false;
          }
          if (featured != null && a.id == featured.id) return false;
          final end = _appointmentSlotEnd(a, _slotDurationMinutes);
          return end != null && end.isAfter(now);
        })
        .toList()
      ..sort((a, b) => a.appointmentDate!.compareTo(b.appointmentDate!));
  }

  static const _noScheduledAppointmentsMessage = 'No hay citas agendadas.';

  List<PatientListItem> get _filteredPatients {
    final q = _patientQuery.trim().toLowerCase();
    if (q.isEmpty) return _patients;
    return _patients
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.email.toLowerCase().contains(q))
        .toList();
  }

  void _openNotifications() => context.push(AppPaths.doctorNotifications);

  Future<void> _handleLogout() => AppAuthActions.logout(context);

  void _openQuestionnaireSettings() =>
      context.push(AppPaths.doctorQuestionnaires);

  void _openExpedientes() => context.go(AppPaths.doctorExpedientes);

  void _popWebRoute() => AppNavigation.pop(context);

  Future<void> _openCreatePatient() async {
    final created = await context.push<bool>(AppPaths.doctorCreatePatient);
    if (created == true && mounted) await _refreshAll(force: true);
  }

  Future<void> _openRequestAnalysis(PatientListItem p) async {
    await context.push(AppPaths.doctorRequestAnalysis(p.id));
  }

  Future<void> _openAssignPrescription(PatientListItem p) async {
    await context.push(AppPaths.doctorAssignPrescription(p.id));
  }

  Future<void> _openTimeline(PatientListItem p) async {
    await context.push(AppPaths.doctorPatientTimeline(p.id));
  }

  Future<void> _scheduleAppointment(PatientListItem p) async {
    final finalDateTime = await pickDoctorAppointmentSlot(context);
    if (finalDateTime == null || !mounted) return;

    final noteCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final dateStr =
        '${_two(finalDateTime.day)}/${_two(finalDateTime.month)}/${finalDateTime.year}';
    final timeStr = formatSlotTimeLocal(finalDateTime);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: KeepiColors.cardBorder),
          ),
          backgroundColor: Colors.white,
          title: const Text(
            'Confirmar cita',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: KeepiColors.slate,
              letterSpacing: -0.3,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 14.5,
                      color: KeepiColors.slate,
                      height: 1.4,
                    ),
                    children: [
                      const TextSpan(text: '¿Asignar la cita a '),
                      TextSpan(
                        text: p.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: KeepiColors.skyBlue,
                        ),
                      ),
                      const TextSpan(text: ' el '),
                      TextSpan(
                        text: dateStr,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: ' a las '),
                      TextSpan(
                        text: timeStr,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: '?'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ConsultationReasonField(controller: reasonCtrl),
                const SizedBox(height: 16),
                DoctorNoteField(controller: noteCtrl),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                'Cancelar',
                style: TextStyle(
                  color: KeepiColors.slateLight,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: KeepiColors.orange,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                'Confirmar',
                style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
              ),
            ),
          ],
        );
      },
    );

    final doctorNote = noteCtrl.text.trim();
    final reason = reasonCtrl.text.trim();
    noteCtrl.dispose();
    reasonCtrl.dispose();

    if (confirm != true || !mounted) return;
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indica el motivo de la consulta.')),
      );
      return;
    }

    try {
      final svc = DoctorService(context.read<ApiClient>());
      await svc.scheduleAppointment(
        patientId: p.id,
        date: finalDateTime,
        reason: reason,
        doctorNote: doctorNote.isEmpty ? null : doctorNote,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cita agendada correctamente'),
          backgroundColor: KeepiColors.green,
        ),
      );
      await _loadAgenda();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${DoctorService.messageFromDio(e)}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openGlobalScheduleAppointment() async {
    var patients = _patients;
    if (patients.isEmpty) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: KeepiColors.orange),
        ),
      );
      try {
        patients =
            await DoctorService(context.read<ApiClient>()).fetchMyPatients();
        if (mounted) Navigator.pop(context);
      } catch (_) {
        if (mounted) Navigator.pop(context);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al cargar la lista de pacientes')),
          );
        }
        return;
      }
    }

    if (patients.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aún no tienes pacientes registrados para agendar.'),
        ),
      );
      return;
    }

    if (!mounted) return;
    final selectedPatient = await showModalBottomSheet<PatientListItem>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            children: [
              const Text(
                'Selecciona un paciente',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: KeepiColors.slate,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: patients.length,
                  itemBuilder: (context, index) {
                    final p = patients[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: KeepiColors.skyBlueSoft,
                        child: Text(
                          p.name.isNotEmpty
                              ? p.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: KeepiColors.skyBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        p.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(p.email),
                      onTap: () => Navigator.pop(ctx, p),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selectedPatient == null || !mounted) return;
    await _scheduleAppointment(selectedPatient);
  }

  PatientListItem? _patientForAppointment(AppointmentDto a) {
    final match =
        _patients.where((p) => p.id == a.patientId).toList(growable: false);
    if (match.isEmpty) return null;
    return match.first;
  }

  PatientListItem _patientStubForAppointment(
    AppointmentDto a, {
    String? name,
    String? email,
  }) {
    return _patientForAppointment(a) ??
        PatientListItem(
          id: a.patientId,
          email: email ?? '',
          name: name ?? 'Paciente',
          mustChangePassword: false,
        );
  }

  Future<void> _openConsultation(AppointmentDto a) async {
    final patient = _patientForAppointment(a);
    final name = patient?.name ?? 'Paciente';
    final email = patient?.email;
    await context.push(
      AppPaths.doctorConsultation(
        a.id,
        patientId: a.patientId,
        name: name,
        email: email,
      ),
    );
  }

  Future<void> _openAgendaAppointment(AppointmentDto a) async {
    if (a.status == 'pending_doctor_approval' ||
        a.status == 'pending_patient_approval' ||
        a.status == 'pending_doctor_proposal') {
      await DoctorPendingAppointmentReviewSheet.show(
        context,
        appointmentId: a.id,
        onChanged: _loadAgenda,
      );
      return;
    }
    await _openConsultation(a);
  }

  Future<void> _markAttendance(AppointmentDto a, String status) async {
    if (_markingAttendanceIds.contains(a.id)) return;
    setState(() => _markingAttendanceIds.add(a.id));
    try {
      final svc = AppointmentService(context.read<ApiClient>());
      final updated = await svc.recordAttendance(
        appointmentId: a.id,
        status: status,
      );
      if (!mounted) return;
      setState(() {
        _agenda = _agenda
            .map((x) => x.id == updated.id ? updated : x)
            .toList(growable: false);
      });
      final label = status == 'attended' ? 'Asistencia confirmada' : 'Marcado como no asistió';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(label),
          backgroundColor: status == 'attended' ? KeepiColors.green : null,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppointmentService.messageFromDio(e)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _markingAttendanceIds.remove(a.id));
      }
    }
  }

  Future<void> _openSendQuestionnaire(PatientListItem p) async {
    await context.push(AppPaths.doctorSendQuestionnaire(p.id));
    if (!mounted) return;
    context.read<PatientsCacheProvider>().invalidateProfile(p.id);
  }

  Future<void> _deletePatient(PatientListItem p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desactivar paciente'),
        content: Text(
          '¿Desactivar a ${p.name}? Dejará de aparecer en tu lista, pero su historial se conserva.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: KeepiColors.orange),
      ),
    );

    try {
      await DoctorService(context.read<ApiClient>()).deletePatient(p.id);
      if (!mounted) return;
      Navigator.pop(context);
      context.read<PatientsCacheProvider>().removePatient(p.id);
      setState(() {
        _patients = _patients.where((x) => x.id != p.id).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${p.name} desactivado'),
          backgroundColor: KeepiColors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(DoctorService.messageFromDio(e)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openPatientActions(PatientListItem p) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PatientActionsSheet(
        patient: p,
        onTimeline: () {
          Navigator.of(ctx).pop();
          _openTimeline(p);
        },
        onSchedule: () {
          Navigator.of(ctx).pop();
          _scheduleAppointment(p);
        },
        onPrescription: () {
          Navigator.of(ctx).pop();
          _openAssignPrescription(p);
        },
        onAnalysis: () {
          Navigator.of(ctx).pop();
          _openRequestAnalysis(p);
        },
        onQuestionnaire: () {
          Navigator.of(ctx).pop();
          _openSendQuestionnaire(p);
        },
      ),
    );
  }

  AppointmentDto? _appointmentForConsultation(PatientListItem p) {
    final forPatient =
        _agenda.where((a) => a.patientId == p.id).toList(growable: false);
    if (forPatient.isEmpty) return null;
    final today = _todaysAppointments
        .where((a) => a.patientId == p.id)
        .toList(growable: false);
    if (today.isNotEmpty) return today.first;
    final upcoming = _upcomingAppointments
        .where((a) => a.patientId == p.id)
        .toList(growable: false);
    if (upcoming.isNotEmpty) return upcoming.first;
    return forPatient.last;
  }

  Future<void> _openConsultationForPatient(PatientListItem p) async {
    final appt = _appointmentForConsultation(p);
    if (appt == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay citas agendadas para abrir la consulta.'),
        ),
      );
      return;
    }
    if (context.canPop()) context.pop();
    await context.push(
      AppPaths.doctorConsultation(
        appt.id,
        patientId: p.id,
        name: p.name,
        email: p.email.isNotEmpty ? p.email : null,
      ),
    );
  }

  Future<void> _openPatientProfileDialog(
    PatientListItem p, {
    int initialTabIndex = 0,
  }) async {
    await context.push(AppPaths.doctorPatient(p.id, tab: initialTabIndex));
  }

  AppointmentDto? _appointmentById(String id) {
    for (final a in _agenda) {
      if (a.id == id) return a;
    }
    return null;
  }

  PatientListItem? _patientById(String id) {
    for (final p in _patients) {
      if (p.id == id) return p;
    }
    return null;
  }

  DoctorSessionBridge get _sessionBridge => DoctorSessionBridge(
        appointmentById: _appointmentById,
        patientById: _patientById,
        patientStubForAppointment: _patientStubForAppointment,
        onRefreshAll: () => _refreshAll(force: true),
        onLoadAgenda: _loadAgenda,
        onPop: _popWebRoute,
        onOpenTimeline: _openTimeline,
        onOpenRequestAnalysis: _openRequestAnalysis,
        onOpenAssignPrescription: _openAssignPrescription,
        onScheduleAppointment: _scheduleAppointment,
        onOpenSendQuestionnaire: _openSendQuestionnaire,
        onOpenConsultationForPatient: _openConsultationForPatient,
        onOpenPatientProfile: (p, {tabIndex = 0}) =>
            _openPatientProfileDialog(p, initialTabIndex: tabIndex),
      );

  void _onDoctorNavTap(int i) {
    context.go(AppPaths.doctorHomeForTab(i));
    if (i == 0 || i == 1) _loadPatients(force: false);
    if (i == 0 || i == 2) _loadAgenda();
  }

  void _openSettings() => context.push(AppPaths.doctorSettings);

  static const _doctorWebNav = <WebNavItem>[
    WebNavItem(icon: Icons.space_dashboard_outlined, label: 'Inicio'),
    WebNavItem(icon: Icons.people_alt_outlined, label: 'Pacientes'),
    WebNavItem(icon: Icons.calendar_month_outlined, label: 'Agenda'),
    WebNavItem(icon: Icons.folder_copy_outlined, label: 'Expedientes'),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final routePath = GoRouterState.of(context).uri.path;
    final onOverlay = AppPaths.isDoctorOverlayPath(routePath);
    var tabIndex = _currentIndex;
    if (!onOverlay) {
      tabIndex = AppPaths.doctorTabIndexFromPath(routePath);
      if (tabIndex != _currentIndex) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _currentIndex = tabIndex);
        });
      }
    }

    final mainBody = IndexedStack(
      index: tabIndex,
      children: [
        _buildHomeTab(auth),
        _buildPatientsTab(auth),
        _buildAgendaTab(auth),
        _buildExpedientesTab(auth),
      ],
    );

    if (onOverlay && widget.shellChild != null && !isWebWide(context)) {
      return DoctorSessionScope(
        bridge: _sessionBridge,
        child: widget.shellChild!,
      );
    }

    final body = onOverlay && widget.shellChild != null
        ? widget.shellChild!
        : mainBody;

    if (isWebWide(context)) {
      return DoctorSessionScope(
        bridge: _sessionBridge,
        child: WebAppShell(
          brandTitle: auth.name ?? 'Doctor',
          navItems: _doctorWebNav,
          currentIndex: tabIndex,
          onNavTap: _onDoctorNavTap,
          onNotifications: _openNotifications,
          onSettings: _openSettings,
          onLogout: _handleLogout,
          userLabel: auth.name ?? 'Doctor',
          userSubtitle: 'MÉDICO',
          primaryAction: (tabIndex == 0 || tabIndex == 1)
              ? WebSidebarButton(
                  label: 'Nuevo paciente',
                  icon: Icons.person_add_alt_1_rounded,
                  onPressed: _openCreatePatient,
                )
              : null,
          headerCenter: !onOverlay
              ? HomeAddedSearchSection(
                  compact: true,
                  patients: _patients,
                  onDoctorOpenAgenda: () => context.go(AppPaths.doctorAgenda),
                )
              : null,
          body: body,
        ),
      );
    }

    return Scaffold(
      backgroundColor: KeepiColors.surfaceBg,
      body: SafeArea(
        bottom: false,
        child: body,
      ),
      floatingActionButton: (tabIndex == 0 || tabIndex == 1)
          ? FloatingActionButton.extended(
              onPressed: _openCreatePatient,
              backgroundColor: KeepiColors.orange,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text(
                'NUEVO PACIENTE',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            )
          : null,
      bottomNavigationBar: _BottomNav(
        currentIndex: tabIndex,
        onTap: _onDoctorNavTap,
      ),
    );
  }

  Widget _buildHomeTab(AuthProvider auth) {
    if (isWebWide(context)) return _buildWebHomeTab(auth);

    final nextAppt = _nextAppointment;
    final upcomingList = _dashboardUpcoming;
    final pending = _pendingConfirmCount;

    final dashboard = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HomeGreeting(
          greeting: _greetingForNow(),
          name: auth.name ?? 'Doctor',
        ),
        const SizedBox(height: 12),
        HomeAddedSearchSection(
          patients: _patients,
          onDoctorOpenAgenda: () => context.go(AppPaths.doctorAgenda),
        ),
        const SizedBox(height: 20),
        if (_loadingAgenda && _agenda.isEmpty)
          const _LoadingBox()
        else if (_agendaError != null)
          _ErrorBox(message: _agendaError!, onRetry: _loadAgenda)
        else if (nextAppt != null)
          _NextAppointmentHero(
            appointment: nextAppt,
            patient: _patientForAppointment(nextAppt),
            onOpenProfile: () {
              final p = _patientForAppointment(nextAppt);
              if (p != null) _openPatientProfileDialog(p);
            },
            onOpenConsultation: () => _openConsultation(nextAppt),
          )
        else
          _EmptyNextAppointmentCard(
            message: _noScheduledAppointmentsMessage,
          ),
        const SizedBox(height: 18),
        _HomeTopActionsStrip(
          onNewPatient: _openCreatePatient,
          onScheduleAppointment: _openGlobalScheduleAppointment,
        ),
        const SizedBox(height: 22),
        if (_patientsError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _ErrorBox(
              message: _patientsError!,
              onRetry: _loadPatients,
            ),
          ),
        if (upcomingList.isNotEmpty) ...[
          _SectionDivider(tag: 'PRÓXIMAS CITAS', count: upcomingList.length),
          const SizedBox(height: 14),
          for (final a in upcomingList.take(6))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AgendaCard(
                appointment: a,
                patients: _patients,
                slotDurationMinutes: _slotDurationMinutes,
                markingAttendance: _markingAttendanceIds.contains(a.id),
                onMarkAttendance: _markAttendance,
                onTap: () => _openAgendaAppointment(a),
              ),
            ),
        ],
        const SizedBox(height: 20),
        const _SectionDivider(tag: 'ATAJOS', count: 4),
        const SizedBox(height: 14),
        _ShortcutsStrip(
          onPatients: () => context.go(AppPaths.doctorPacientes),
          onDocuments: _openExpedientes,
          onQuestionnaires: _openQuestionnaireSettings,
          onAgenda: () => context.go(AppPaths.doctorAgenda),
        ),
        const SizedBox(height: 120),
      ],
    );

    return RefreshIndicator(
      color: KeepiColors.orange,
      onRefresh: () => _refreshAll(force: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _TopBar(
              onNotifs: _openNotifications,
              onLogout: _handleLogout,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: dashboard,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebHomeTab(AuthProvider auth) {
    final today = _todaysAppointments;
    final featured = _featuredNextAppointment;
    final restOfToday = featured == null
        ? today
        : today.where((a) => a.id != featured.id).toList();
    final upcoming = _dashboardUpcoming
        .where((a) {
          final d = a.appointmentDate?.toLocal();
          return d == null || !_sameDay(d, DateTime.now());
        })
        .take(5)
        .toList();
    final pendingList = _agenda
        .where((a) =>
            a.status == 'pending_patient_approval' ||
            a.status == 'pending_doctor_proposal' ||
            a.status == 'pending_doctor_approval')
        .toList()
      ..sort((a, b) {
        final da = a.appointmentDate;
        final db = b.appointmentDate;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });
    final loadingFirst = _loadingAgenda && _agenda.isEmpty;
    final pending = _pendingConfirmCount;

    return RefreshIndicator(
      color: KeepiColors.orange,
      onRefresh: () => _refreshAll(force: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: SubtleDecorativeBackground(
              child: WebContentFrame(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HomeGreeting(
                      greeting: _greetingForNow(),
                      name: auth.name ?? 'Doctor',
                    ),
                    const SizedBox(height: 20),
                    _HomeTopActionsStrip(
                      onNewPatient: _openCreatePatient,
                      onScheduleAppointment: _openGlobalScheduleAppointment,
                    ),
                    const SizedBox(height: 28),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _SectionDivider(
                                      tag: 'AGENDA DE HOY',
                                      count: today.length,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        context.go(AppPaths.doctorAgenda),
                                    child: const Text('Ver agenda'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              if (loadingFirst)
                                const _LoadingBox()
                              else if (_agendaError != null)
                                _ErrorBox(
                                  message: _agendaError!,
                                  onRetry: _loadAgenda,
                                )
                              else if (featured == null &&
                                  today.isEmpty &&
                                  upcoming.isEmpty)
                                const _InlineEmpty(
                                  icon: Icons.event_available_outlined,
                                  message:
                                      'No hay citas agendadas. Revisa la agenda o crea una nueva.',
                                )
                              else ...[
                                if (featured != null)
                                  _NextAppointmentHero(
                                    compact: true,
                                    featured: true,
                                    appointment: featured,
                                    patient: _patientForAppointment(featured),
                                    slotDurationMinutes: _slotDurationMinutes,
                                    markingAttendance: _markingAttendanceIds
                                        .contains(featured.id),
                                    onMarkAttendance: _markAttendance,
                                    onOpenProfile: () {
                                      final p =
                                          _patientForAppointment(featured);
                                      if (p != null) {
                                        _openPatientProfileDialog(p);
                                      }
                                    },
                                    onOpenConsultation: () =>
                                        _openConsultation(featured),
                                  )
                                else
                                  _EmptyNextAppointmentCard(
                                    message:
                                        _noScheduledAppointmentsMessage,
                                    featured: true,
                                  ),
                                if (restOfToday.isNotEmpty) ...[
                                  if (featured != null || today.isNotEmpty)
                                    const SizedBox(height: 16),
                                  _SectionDivider(
                                    tag: 'MÁS HOY',
                                    count: restOfToday.length,
                                  ),
                                  const SizedBox(height: 14),
                                ],
                                for (final a in restOfToday)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _AgendaCard(
                                      appointment: a,
                                      patients: _patients,
                                      slotDurationMinutes: _slotDurationMinutes,
                                      markingAttendance:
                                          _markingAttendanceIds.contains(a.id),
                                      onMarkAttendance: _markAttendance,
                                      onTap: () => _openAgendaAppointment(a),
                                    ),
                                  ),
                                if (upcoming.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  _SectionDivider(
                                    tag: 'PRÓXIMOS DÍAS',
                                    count: upcoming.length,
                                  ),
                                  const SizedBox(height: 14),
                                  for (final a in upcoming)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: _AgendaCard(
                                        appointment: a,
                                        patients: _patients,
                                        slotDurationMinutes: _slotDurationMinutes,
                                        markingAttendance:
                                            _markingAttendanceIds.contains(a.id),
                                        onMarkAttendance: _markAttendance,
                                        onTap: () => _openAgendaAppointment(a),
                                      ),
                                    ),
                                ],
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 28),
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _SectionDivider(
                                tag: 'RESUMEN DE ACTIVIDAD',
                                count: 0,
                              ),
                              const SizedBox(height: 14),
                              if (loadingFirst)
                                const _LoadingBox()
                              else if (_agendaError != null)
                                const SizedBox.shrink()
                              else
                                _StatsStrip(
                                  items: [
                                    _StatItem(
                                      value: _todaysAppointments.length,
                                      label: 'CITAS HOY',
                                    ),
                                    _StatItem(
                                      value: pending,
                                      label: 'POR CONFIRMAR',
                                      accent: pending > 0,
                                    ),
                                    _StatItem(
                                      value: _patients.length,
                                      label: 'PACIENTES',
                                    ),
                                  ],
                                ),
                              if (pendingList.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                _WebPendingCard(
                                  pending: pendingList,
                                  patients: _patients,
                                  onOpen: _openAgendaAppointment,
                                  onViewAll: () =>
                                      context.go(AppPaths.doctorAgenda),
                                ),
                              ],
                              const SizedBox(height: 24),
                              const _SectionDivider(tag: 'ATAJOS', count: 4),
                              const SizedBox(height: 14),
                              _ShortcutsStrip(
                                onPatients: () =>
                                    context.go(AppPaths.doctorPacientes),
                                onDocuments: _openExpedientes,
                                onQuestionnaires: _openQuestionnaireSettings,
                                onAgenda: () => context.go(AppPaths.doctorAgenda),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientsTab(AuthProvider auth) {
    final list = _filteredPatients;
    return RefreshIndicator(
      color: KeepiColors.orange,
      onRefresh: () => _loadPatients(force: true),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _TopBar(
              onNotifs: _openNotifications,
              onLogout: _handleLogout,
            ),
          ),
          SliverToBoxAdapter(
            child: _PatientsHero(
              total: _patients.length,
              filtered: list.length,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 10),
            sliver: SliverToBoxAdapter(
              child: _SearchField(
                controller: _searchCtrl,
                hint: 'Buscar por nombre o correo...',
                onChanged: (v) => setState(() => _patientQuery = v),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate.fixed([
                if (_patientsError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _ErrorBox(
                      message: _patientsError!,
                      onRetry: _loadPatients,
                    ),
                  ),
                _SectionDivider(tag: 'PACIENTES', count: list.length),
                const SizedBox(height: 14),
                if (_loadingPatients && _patients.isEmpty)
                  const _LoadingBox()
                else if (list.isEmpty && _patients.isEmpty)
                  const _EmptyStateCard(
                    tag: 'PACIENTES',
                    title: 'Aún no hay pacientes',
                    message:
                        'Crea tu primer paciente con el botón “Nuevo paciente”. Vincularás su expediente, recetas y análisis.',
                    icon: Icons.people_alt_outlined,
                  )
                else if (list.isEmpty)
                  const _InlineEmpty(
                    icon: Icons.search_off_rounded,
                    message: 'No encontramos pacientes con esa búsqueda.',
                  )
                else
                  for (final p in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PatientTile(
                        patient: p,
                        onProfileTap: () => _openPatientProfileDialog(p),
                        onDeleteTap: () => _deletePatient(p),
                        onArrowTap: () => _openPatientActions(p),
                      ),
                    ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgendaTab(AuthProvider auth) {
    return Column(
      children: [
        _TopBar(onNotifs: _openNotifications, onLogout: _handleLogout),
        Expanded(
          child: DoctorCalendarTab(onOpenConsultation: _openConsultation),
        ),
      ],
    );
  }

  Widget _buildExpedientesTab(AuthProvider auth) {
    return Column(
      children: [
        _TopBar(onNotifs: _openNotifications, onLogout: _handleLogout),
        const Expanded(
          child: DocumentosScreen(embedded: true),
        ),
      ],
    );
  }
}

//   TOP BAR

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onNotifs, required this.onLogout});

  final VoidCallback onNotifs;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    if (isWebWide(context)) {
      return const SizedBox(height: 8);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 14, 6),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/logo.png',
              width: 34,
              height: 34,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.folder_rounded,
                size: 28,
                color: KeepiColors.orange,
              ),
            ),
          ),
          const Spacer(),
          _IconPill(icon: Icons.notifications_none_rounded, onTap: onNotifs),
          const SizedBox(width: 8),
          _IconPill(icon: Icons.logout_rounded, onTap: onLogout),
        ],
      ),
    );
  }
}

class _IconPill extends StatelessWidget {
  const _IconPill({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: KeepiColors.cardBorder),
        ),
        child: Icon(icon, size: 19, color: KeepiColors.slate),
      ),
    );
  }
}

//   HEROS

class _HomeGreeting extends StatelessWidget {
  const _HomeGreeting({
    required this.greeting,
    required this.name,
  });

  final String greeting;
  final String name;

  @override
  Widget build(BuildContext context) {
    final firstName = name.split(' ').first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 22, height: 2, color: KeepiColors.slate),
            const SizedBox(width: 8),
            Text(
              _todayStamp(),
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8,
                color: KeepiColors.slate,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: isWebWide(context) ? 30 : 26,
              fontWeight: FontWeight.w800,
              color: KeepiColors.slate,
              height: 1.1,
              letterSpacing: -0.7,
            ),
            children: [
              TextSpan(text: '$greeting, Dr. '),
              TextSpan(
                text: firstName,
                style: const TextStyle(color: KeepiColors.orange),
              ),
              const TextSpan(
                text: '.',
                style: TextStyle(color: KeepiColors.slate),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Tu consultorio digital, en un vistazo.',
          style: TextStyle(
            fontSize: 13.5,
            color: KeepiColors.slateLight,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _NextAppointmentHero extends StatelessWidget {
  const _NextAppointmentHero({
    required this.appointment,
    required this.patient,
    required this.onOpenProfile,
    required this.onOpenConsultation,
    this.compact = false,
    this.featured = false,
    this.slotDurationMinutes = 30,
    this.onMarkAttendance,
    this.markingAttendance = false,
  });

  final AppointmentDto appointment;
  final PatientListItem? patient;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenConsultation;
  final bool compact;
  final bool featured;
  final int slotDurationMinutes;
  final Future<void> Function(AppointmentDto, String status)? onMarkAttendance;
  final bool markingAttendance;

  String get _patientName =>
      patient?.name ?? appointment.patientName ?? 'Paciente';

  String _statusLabel() {
    switch (appointment.status) {
      case 'pending_patient_approval':
        return 'POR CONFIRMAR';
      case 'scheduled':
        return 'CONFIRMADA';
      case 'pending_doctor_proposal':
        return 'ESPERANDO FECHA';
      case 'pending_doctor_approval':
        return 'POR CONFIRMAR';
      default:
        return appointment.status.toUpperCase();
    }
  }

  Color _statusColor() {
    switch (appointment.status) {
      case 'scheduled':
        return KeepiColors.green;
      case 'pending_patient_approval':
      case 'pending_doctor_proposal':
      case 'pending_doctor_approval':
        return KeepiColors.orange;
      default:
        return KeepiColors.slateLight;
    }
  }

  String get _badgeLabel {
    switch (appointment.attendanceStatus) {
      case 'attended':
        return 'ASISTIÓ';
      case 'no_show':
        return 'NO ASISTIÓ';
      default:
        return _statusLabel();
    }
  }

  Color get _badgeColor {
    switch (appointment.attendanceStatus) {
      case 'attended':
        return KeepiColors.green;
      case 'no_show':
        return KeepiColors.slate;
      default:
        return _statusColor();
    }
  }

  Widget _buildHeaderRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Text(
            'PRÓXIMA CITA',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
              color: KeepiColors.orange,
            ),
          ),
        ),
        _StatusBadge(label: _badgeLabel, color: _badgeColor),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = appointment.appointmentDate?.toLocal();
    final timeLabel =
        date != null ? '${_two(date.hour)}:${_two(date.minute)}' : 'Sin hora';
    final reason = appointment.reason.isEmpty
        ? 'Consulta médica'
        : appointment.reason;
    final initial =
        _patientName.isEmpty ? '?' : _patientName[0].toUpperCase();
    final wideLayout = isWebWide(context) && !compact;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: featured
              ? KeepiColors.orange.withValues(alpha: 0.35)
              : KeepiColors.cardBorder,
          width: featured ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: KeepiColors.slate.withValues(alpha: featured ? 0.1 : 0.06),
            blurRadius: featured ? 28 : 24,
            offset: Offset(0, featured ? 10 : 8),
          ),
        ],
      ),
      padding: EdgeInsets.all(wideLayout ? 28 : (featured ? 24 : 20)),
      child: wideLayout
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderRow(),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: _buildContentBody(timeLabel, reason)),
                    const SizedBox(width: 24),
                    _PatientAvatarLarge(initial: initial, size: 140),
                  ],
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderRow(),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildContentBody(timeLabel, reason)),
                    const SizedBox(width: 12),
                    _PatientAvatarLarge(
                      initial: initial,
                      size: featured ? 80 : 72,
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildContentBody(String timeLabel, String reason) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _patientName,
          style: TextStyle(
            fontSize: featured ? 30 : 28,
            fontWeight: FontWeight.w800,
            color: KeepiColors.slate,
            letterSpacing: -0.8,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 20,
          runSpacing: 10,
          children: [
            _HeroInfoChip(
              icon: Icons.schedule_rounded,
              iconColor: KeepiColors.orange,
              label: 'Hora',
              value: timeLabel,
            ),
            _HeroInfoChip(
              icon: Icons.event_note_outlined,
              iconColor: KeepiColors.skyBlue,
              label: 'Motivo',
              value: reason,
            ),
          ],
        ),
        if (onMarkAttendance != null &&
            _canConfirmAttendance(appointment, slotDurationMinutes)) ...[
          const SizedBox(height: 14),
          if (markingAttendance)
            const SizedBox(
              height: 28,
              width: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _AttendanceActionButton(
                  icon: Icons.check_rounded,
                  label: 'Confirmar asistencia',
                  color: KeepiColors.green,
                  onTap: () => onMarkAttendance!(appointment, 'attended'),
                ),
                _AttendanceActionButton(
                  icon: Icons.close_rounded,
                  label: 'No asistió',
                  color: KeepiColors.slate,
                  onTap: () => onMarkAttendance!(appointment, 'no_show'),
                ),
              ],
            ),
        ],
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: onOpenConsultation,
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Iniciar consulta'),
            ),
            OutlinedButton.icon(
              onPressed: onOpenProfile,
              style: OutlinedButton.styleFrom(
                foregroundColor: KeepiColors.slate,
                side: const BorderSide(color: KeepiColors.cardBorder),
              ),
              icon: const Icon(Icons.folder_copy_outlined, size: 18),
              label: const Text('Abrir expediente'),
            ),
          ],
        ),
      ],
    );
  }
}

class _EmptyNextAppointmentCard extends StatelessWidget {
  const _EmptyNextAppointmentCard({
    this.message,
    this.featured = false,
  });

  final String? message;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: featured
              ? KeepiColors.orange.withValues(alpha: 0.35)
              : KeepiColors.cardBorder,
          width: featured ? 1.5 : 1,
        ),
      ),
      child: _InlineEmpty(
        icon: Icons.event_available_outlined,
        message: message ??
            'No hay citas próximas. Revisa la agenda o crea una nueva.',
      ),
    );
  }
}

class _HeroInfoChip extends StatelessWidget {
  const _HeroInfoChip({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: KeepiColors.slateLight,
                letterSpacing: 0.4,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: KeepiColors.slate,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientAvatarLarge extends StatelessWidget {
  const _PatientAvatarLarge({required this.initial, required this.size});

  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: KeepiColors.skyBlueSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KeepiColors.cardBorder, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.34,
          fontWeight: FontWeight.w800,
          color: KeepiColors.skyBlue,
        ),
      ),
    );
  }
}

class _WebPendingCard extends StatelessWidget {
  const _WebPendingCard({
    required this.pending,
    required this.patients,
    required this.onOpen,
    required this.onViewAll,
  });

  final List<AppointmentDto> pending;
  final List<PatientListItem> patients;
  final ValueChanged<AppointmentDto> onOpen;
  final VoidCallback onViewAll;

  String _patientName(AppointmentDto a) {
    final match = patients.where((p) => p.id == a.patientId);
    if (match.isEmpty) return a.patientName ?? 'Paciente';
    return match.first.name;
  }

  String _statusHint(String status) {
    switch (status) {
      case 'pending_patient_approval':
        return 'Espera confirmación del paciente';
      case 'pending_doctor_proposal':
        return 'Propón una fecha';
      case 'pending_doctor_approval':
        return 'Confirma la cita';
      default:
        return status;
    }
  }

  String _statusTag(String status) {
    switch (status) {
      case 'pending_patient_approval':
        return 'POR CONFIRMAR';
      case 'pending_doctor_proposal':
        return 'SIN FECHA';
      case 'pending_doctor_approval':
        return 'POR CONFIRMAR';
      default:
        return 'PENDIENTE';
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending_patient_approval':
        return Icons.hourglass_top_rounded;
      case 'pending_doctor_proposal':
        return Icons.edit_calendar_outlined;
      case 'pending_doctor_approval':
      default:
        return Icons.event_available_outlined;
    }
  }

  Color _statusColor(String status) => KeepiColors.orange;

  String _appointmentTime(AppointmentDto a) {
    final dt = a.appointmentDate?.toLocal();
    if (dt == null) return 'Sin hora';
    return '${_weekdaysEsUpper[dt.weekday - 1]} · ${_two(dt.hour)}:${_two(dt.minute)}';
  }

  Widget _buildDateStamp(AppointmentDto a) {
    final date = a.appointmentDate?.toLocal();
    final day = date?.day ?? 0;
    final monthAbbr = date != null ? _monthsEsUpper[date.month - 1] : '—';
    return SizedBox(
      width: 44,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            day > 0 ? _two(day) : '—',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: KeepiColors.slate,
              height: 1,
              letterSpacing: -0.8,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            monthAbbr,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: KeepiColors.slateLight,
              letterSpacing: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(AppointmentDto a) {
    final color = _statusColor(a.status);
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1.8),
      ),
      child: Icon(_statusIcon(a.status), size: 16, color: color),
    );
  }

  Widget _buildPendingBody(AppointmentDto a) {
    final color = _statusColor(a.status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            const Text(
              'CITA',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: KeepiColors.orange,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 2,
              height: 2,
              decoration: BoxDecoration(
                color: KeepiColors.slateLight.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _statusTag(a.status),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _patientName(a),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: KeepiColors.slate,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _statusHint(a.status),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            color: KeepiColors.slateLight,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Container(
              width: 10,
              height: 1,
              color: KeepiColors.slate.withValues(alpha: 0.55),
            ),
            const SizedBox(width: 6),
            Text(
              _appointmentTime(a),
              style: const TextStyle(
                fontSize: 12,
                color: KeepiColors.slate,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown = pending.take(3).toList();
    final single = pending.length == 1 ? pending.first : null;

    Widget cardContent = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: KeepiColors.orange.withValues(alpha: 0.45),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'POR CONFIRMAR',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                  color: KeepiColors.orange,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: KeepiColors.orangeSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _two(pending.length),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: KeepiColors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final a in shown)
            InkWell(
              onTap: () => onOpen(a),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDateStamp(a),
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: _buildStatusIcon(a),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _buildPendingBody(a)),
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: KeepiColors.slateLight,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (pending.length > shown.length)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onViewAll,
                child: Text('Ver  más'),
              ),
            ),
        ],
      ),
    );

    if (single != null) {
      cardContent = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onOpen(single),
          borderRadius: BorderRadius.circular(16),
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}


class _PatientsHero extends StatelessWidget {
  const _PatientsHero({required this.total, required this.filtered});
  final int total;
  final int filtered;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 22, height: 2, color: KeepiColors.slate),
              const SizedBox(width: 8),
              const Text(
                'DIRECTORIO',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                  color: KeepiColors.slate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Tus pacientes.',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: KeepiColors.slate,
              height: 1.1,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Toca una tarjeta para ver su historial, agendar citas, recetas o análisis.',
            style: TextStyle(
              fontSize: 13.5,
              color: KeepiColors.slateLight,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          _StatsStrip(
            items: [
              _StatItem(value: total, label: 'TOTAL'),
              _StatItem(
                  value: filtered,
                  label: 'MOSTRANDO',
                  accent: filtered != total && total > 0),
            ],
          ),
        ],
      ),
    );
  }
}

//   STATS STRIP

class _StatItem {
  const _StatItem(
      {required this.value, required this.label, this.accent = false});
  final int value;
  final String label;
  final bool accent;
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.items});
  final List<_StatItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              Expanded(child: _StatCell(item: items[i])),
              if (i < items.length - 1)
                Container(width: 1, color: KeepiColors.cardBorder),
            ],
          ],
        ),
      ),
    );
  }
}

class _HomeTopActionsStrip extends StatelessWidget {
  const _HomeTopActionsStrip({
    required this.onNewPatient,
    required this.onScheduleAppointment,
  });

  final VoidCallback onNewPatient;
  final VoidCallback onScheduleAppointment;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _HomeTopActionCell(
            icon: Icons.person_add_alt_1_rounded,
            label: 'NUEVO PACIENTE',
            onPressed: onNewPatient,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _HomeTopActionCell(
            icon: Icons.event_available_rounded,
            label: 'AGENDAR CITA',
            onPressed: onScheduleAppointment,
            accent: true,
          ),
        ),
      ],
    );
  }
}

class _HomeTopActionCell extends StatelessWidget {
  const _HomeTopActionCell({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ? KeepiColors.orange : KeepiColors.slate;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: KeepiColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: color,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.item});
  final _StatItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.accent ? KeepiColors.orange : KeepiColors.slate;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            _two(item.value),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1,
              letterSpacing: -1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              item.label,
              maxLines: 2,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: KeepiColors.slateLight,
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//   SECTION DIVIDER

class _SectionDivider extends StatelessWidget {
  const _SectionDivider({required this.tag, required this.count});
  final String tag;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 18,
            height: 1,
            color: KeepiColors.slate.withValues(alpha: 0.45)),
        const SizedBox(width: 10),
        Text(
          tag,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
            color: KeepiColors.slate,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: KeepiColors.slateSoft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _two(count),
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: KeepiColors.slate,
              letterSpacing: 0.3,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
              height: 1, color: KeepiColors.slate.withValues(alpha: 0.12)),
        ),
      ],
    );
  }
}

//   PATIENT TILE

class _PatientTile extends StatelessWidget {
  const _PatientTile({
    required this.patient,
    required this.onProfileTap,
    required this.onDeleteTap,
    required this.onArrowTap,
  });

  final PatientListItem patient;
  final VoidCallback onProfileTap;
  final VoidCallback onDeleteTap;
  final VoidCallback onArrowTap;

  @override
  Widget build(BuildContext context) {
    final initial = patient.name.isEmpty ? '?' : patient.name[0].toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      // Usamos Material transparente para que los InkWell hijos muestren el efecto ripple
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ÁREA 1: Todo el perfil del paciente (abre la ventanita)
            Expanded(
              child: InkWell(
                onTap: onProfileTap,
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: KeepiColors.skyBlueSoft,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: KeepiColors.skyBlue, width: 1.6),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: KeepiColors.skyBlue,
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: KeepiColors.skyBlue,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                const Text(
                                  'PACIENTE',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.4,
                                    color: KeepiColors.skyBlue,
                                  ),
                                ),
                                if (patient.mustChangePassword) ...[
                                  // ... (manteniendo tu lógica de primer acceso)
                                  const SizedBox(width: 7),
                                  Container(
                                    width: 2,
                                    height: 2,
                                    decoration: BoxDecoration(
                                      color: KeepiColors.slateLight
                                          .withValues(alpha: 0.6),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  const Text(
                                    'PRIMER ACCESO',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                      color: KeepiColors.orange,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              patient.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: KeepiColors.slate,
                                letterSpacing: -0.25,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              patient.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: KeepiColors.slateLight,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: onDeleteTap,
              tooltip: 'Desactivar paciente',
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.red,
                size: 22,
              ),
            ),
            // ÁREA 2: La flecha (Abre el menú de acciones que ya tenías)
            InkWell(
              onTap: onArrowTap,
              borderRadius:
                  const BorderRadius.horizontal(right: Radius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 14, 14, 14),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: KeepiColors.slateSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    size: 17,
                    color: KeepiColors.slate,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//   PATIENT ACTIONS SHEET

class _PatientActionsSheet extends StatelessWidget {
  const _PatientActionsSheet({
    required this.patient,
    required this.onTimeline,
    required this.onSchedule,
    required this.onPrescription,
    required this.onAnalysis,
    required this.onQuestionnaire,
  });

  final PatientListItem patient;
  final VoidCallback onTimeline;
  final VoidCallback onSchedule;
  final VoidCallback onPrescription;
  final VoidCallback onAnalysis;
  final VoidCallback onQuestionnaire;

  @override
  Widget build(BuildContext context) {
    final initial = patient.name.isEmpty ? '?' : patient.name[0].toUpperCase();
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: KeepiColors.slateSoft,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: KeepiColors.skyBlueSoft,
                    shape: BoxShape.circle,
                    border: Border.all(color: KeepiColors.skyBlue, width: 1.6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: KeepiColors.skyBlue,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: KeepiColors.slate,
                          letterSpacing: -0.25,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        patient.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: KeepiColors.slateLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const _SectionDivider(tag: 'ACCIONES', count: 5),
            const SizedBox(height: 14),
            _ActionRow(
              icon: Icons.timeline_rounded,
              accent: KeepiColors.slate,
              title: 'Ver historial',
              subtitle: 'Expediente clínico y movimientos recientes.',
              onTap: onTimeline,
            ),
            const SizedBox(height: 10),
            _ActionRow(
              icon: Icons.event_available_outlined,
              accent: KeepiColors.skyBlue,
              title: 'Asignar cita',
              subtitle: 'Propón fecha y hora para la próxima consulta.',
              onTap: onSchedule,
            ),
            const SizedBox(height: 10),
            _ActionRow(
              icon: Icons.medication_outlined,
              accent: const Color(0xFF7C3AED),
              title: 'Asignar receta',
              subtitle: 'Emite una nueva prescripción con recordatorios.',
              onTap: onPrescription,
            ),
            const SizedBox(height: 10),
            _ActionRow(
              icon: Icons.biotech_outlined,
              accent: KeepiColors.orange,
              title: 'Solicitar análisis',
              subtitle: 'Pide estudios de laboratorio o imagen.',
              onTap: onAnalysis,
            ),
            const SizedBox(height: 10),
            _ActionRow(
              icon: Icons.outgoing_mail,
              accent: KeepiColors.skyBlue,
              title: 'Enviar ficha clínica',
              subtitle:
                  'Link por correo con plantillas o preguntas que elijas.',
              onTap: onQuestionnaire,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: KeepiColors.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: accent, width: 1.6),
              ),
              child: Icon(icon, color: accent, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: KeepiColors.slate,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: KeepiColors.slateLight,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.arrow_forward_rounded,
              color: KeepiColors.slate,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

//   AGENDA CARD

class _AttendanceActionButton extends StatelessWidget {
  const _AttendanceActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgendaCard extends StatelessWidget {
  const _AgendaCard({
    required this.appointment,
    required this.patients,
    required this.slotDurationMinutes,
    required this.onMarkAttendance,
    this.markingAttendance = false,
    this.onTap,
  });
  final AppointmentDto appointment;
  final List<PatientListItem> patients;
  final int slotDurationMinutes;
  final Future<void> Function(AppointmentDto, String status) onMarkAttendance;
  final bool markingAttendance;
  final VoidCallback? onTap;

  String _statusLabel() {
    switch (appointment.status) {
      case 'pending_patient_approval':
        return 'POR CONFIRMAR';
      case 'scheduled':
        return 'CONFIRMADA';
      case 'pending_doctor_proposal':
        return 'ESPERANDO FECHA';
      case 'canceled':
        return 'CANCELADA';
      default:
        return appointment.status.toUpperCase();
    }
  }

  Color _statusColor() {
    switch (appointment.status) {
      case 'pending_patient_approval':
      case 'pending_doctor_proposal':
        return KeepiColors.orange;
      case 'scheduled':
        return KeepiColors.green;
      case 'canceled':
        return Colors.red;
      default:
        return KeepiColors.slateLight;
    }
  }

  String _patientName() {
    final match = patients.where((p) => p.id == appointment.patientId).toList();
    if (match.isEmpty) return 'Paciente';
    return match.first.name;
  }

  Widget _buildTrailingAction() {
    final status = appointment.attendanceStatus;
    if (status == 'attended') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: KeepiColors.green.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: KeepiColors.green.withValues(alpha: 0.45)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 14, color: KeepiColors.green),
            SizedBox(width: 4),
            Text(
              'Asistió',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: KeepiColors.green,
              ),
            ),
          ],
        ),
      );
    }
    if (status == 'no_show') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: KeepiColors.slate.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: KeepiColors.slate.withValues(alpha: 0.25)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off_outlined, size: 14, color: KeepiColors.slate),
            SizedBox(width: 4),
            Text(
              'No asistió',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: KeepiColors.slate,
              ),
            ),
          ],
        ),
      );
    }
    if (!_canConfirmAttendance(appointment, slotDurationMinutes)) {
      return Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: KeepiColors.skyBlue, width: 1.6),
        ),
        child: const Icon(
          Icons.event_available_outlined,
          size: 17,
          color: KeepiColors.skyBlue,
        ),
      );
    }
    if (markingAttendance) {
      return const SizedBox(
        width: 34,
        height: 34,
        child: Padding(
          padding: EdgeInsets.all(6),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AttendanceActionButton(
          icon: Icons.check_rounded,
          label: 'Asistió',
          color: KeepiColors.green,
          onTap: () => onMarkAttendance(appointment, 'attended'),
        ),
        const SizedBox(height: 6),
        _AttendanceActionButton(
          icon: Icons.close_rounded,
          label: 'No asistió',
          color: KeepiColors.slate,
          onTap: () => onMarkAttendance(appointment, 'no_show'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = appointment.appointmentDate?.toLocal();
    final day = date?.day ?? 0;
    final monthAbbr = date != null ? _monthsEsUpper[date.month - 1] : '—';
    final timeLabel =
        date != null ? '${_two(date.hour)}:${_two(date.minute)}' : 'Sin hora';
    final statusColor = _statusColor();
    final needsAttention = appointment.status == 'pending_patient_approval' ||
        appointment.status == 'pending_doctor_proposal';

    final card = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: needsAttention
              ? KeepiColors.orange.withValues(alpha: 0.55)
              : KeepiColors.cardBorder,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day > 0 ? _two(day) : '—',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: KeepiColors.slate,
                    height: 1,
                    letterSpacing: -1,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  monthAbbr,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: KeepiColors.slateLight,
                    letterSpacing: 1.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: KeepiColors.skyBlue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    const Text(
                      'CITA',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        color: KeepiColors.skyBlue,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Container(
                      width: 2,
                      height: 2,
                      decoration: BoxDecoration(
                        color: KeepiColors.slateLight.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        _statusLabel(),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  height: 2,
                  width: 22,
                  decoration: BoxDecoration(
                    color: KeepiColors.skyBlue,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _patientName(),
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: KeepiColors.slate,
                    letterSpacing: -0.25,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  appointment.reason.isEmpty
                      ? 'Consulta médica'
                      : appointment.reason,
                  style: const TextStyle(
                    fontSize: 13,
                    color: KeepiColors.slateLight,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 1,
                      color: KeepiColors.slate.withValues(alpha: 0.55),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timeLabel,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: KeepiColors.slate,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 2),
            child: _buildTrailingAction(),
          ),
        ],
      ),
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: card,
      ),
    );
  }
}

//   SHORTCUTS STRIP

class _ShortcutsStrip extends StatelessWidget {
  const _ShortcutsStrip({
    required this.onPatients,
    required this.onDocuments,
    required this.onQuestionnaires,
    required this.onAgenda,
  });

  final VoidCallback onPatients;
  final VoidCallback onDocuments;
  final VoidCallback onQuestionnaires;
  final VoidCallback onAgenda;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ShortcutTile(
            icon: Icons.people_alt_outlined,
            label: 'Pacientes',
            accent: KeepiColors.skyBlue,
            onTap: onPatients,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ShortcutTile(
            icon: Icons.folder_copy_outlined,
            label: 'Expedientes',
            accent: const Color(0xFF7C3AED),
            onTap: onDocuments,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ShortcutTile(
            icon: Icons.quiz_outlined,
            label: 'Cuestionarios',
            accent: KeepiColors.orange,
            onTap: onQuestionnaires,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ShortcutTile(
            icon: Icons.calendar_month_outlined,
            label: 'Agenda',
            accent: KeepiColors.slate,
            onTap: onAgenda,
          ),
        ),
      ],
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 10, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: KeepiColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: accent, width: 1.6),
              ),
              child: Icon(icon, color: accent, size: 16),
            ),
            const SizedBox(height: 14),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: KeepiColors.slate,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(height: 2),
            const Row(
              children: [
                Text(
                  'ABRIR',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: KeepiColors.slateLight,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded,
                    size: 11, color: KeepiColors.slateLight),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

//   SEARCH FIELD

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14, color: KeepiColors.slate),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              const TextStyle(color: KeepiColors.slateLight, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded,
              color: KeepiColors.slateLight, size: 20),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: KeepiColors.slateLight),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          filled: false,
        ),
      ),
    );
  }
}

//   STATE WIDGETS

class _LoadingBox extends StatelessWidget {
  const _LoadingBox();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
              color: KeepiColors.orange, strokeWidth: 2.4),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KeepiColors.orange.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline_rounded,
                  color: KeepiColors.orange, size: 18),
              SizedBox(width: 8),
              Text(
                'NO PUDIMOS CARGAR',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: KeepiColors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
                fontSize: 13.5, color: KeepiColors.slate, height: 1.4),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: onRetry,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: KeepiColors.slate),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded,
                      size: 16, color: KeepiColors.slate),
                  SizedBox(width: 6),
                  Text(
                    'REINTENTAR',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: KeepiColors.slate,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.tag,
    required this.title,
    required this.message,
    required this.icon,
  });

  final String tag;
  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  width: 18,
                  height: 1,
                  color: KeepiColors.slate.withValues(alpha: 0.45)),
              const SizedBox(width: 8),
              Text(
                tag,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                  color: KeepiColors.slate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: KeepiColors.slateLight, width: 1.4),
            ),
            child: Icon(icon, size: 26, color: KeepiColors.slateLight),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: KeepiColors.slate,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13.5,
              color: KeepiColors.slateLight,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: KeepiColors.slateLight, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: KeepiColors.slateLight,
                fontSize: 13.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//   BOTTOM NAV

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.currentIndex, required this.onTap});
  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = <_NavItemData>[
    _NavItemData(icon: Icons.space_dashboard_outlined, label: 'Inicio'),
    _NavItemData(icon: Icons.people_alt_outlined, label: 'Pacientes'),
    _NavItemData(icon: Icons.calendar_month_outlined, label: 'Agenda'),
    _NavItemData(icon: Icons.folder_copy_outlined, label: 'Expedientes'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: KeepiColors.cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: _NavItem(
                    data: _items[i],
                    active: currentIndex == i,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

class _NavItem extends StatelessWidget {
  const _NavItem(
      {required this.data, required this.active, required this.onTap});
  final _NavItemData data;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? KeepiColors.orange : KeepiColors.slateLight;
    return InkResponse(
      onTap: onTap,
      radius: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(data.icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(
              data.label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 5),
            Container(
              width: active ? 18 : 0,
              height: 2,
              decoration: BoxDecoration(
                color: KeepiColors.orange,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
