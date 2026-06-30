import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/keepi_timezone.dart';
import '../../core/web_layout.dart';
import '../../providers/auth_provider.dart';
import '../../providers/patients_cache_provider.dart';
import '../../router/app_auth_actions.dart';
import '../../router/app_navigation.dart';
import '../../router/app_paths.dart';
import '../../router/doctor_session_scope.dart';
import '../../services/api_client.dart';
import '../../services/appointment_service.dart';
import '../../services/config_service.dart' as config_dto;
import '../../services/doctor_service.dart';
import '../../services/scheduling_service.dart';
import '../../utils/attendance_kpi.dart';
import '../../widgets/doctor_appointment_slot_picker.dart';
import '../../widgets/doctor_patient_picker_sheet.dart';
import '../../widgets/keepi_web_dialog.dart';
import '../../widgets/doctor_pending_appointment_review_sheet.dart';
import '../../widgets/home_added_search_section.dart';
import '../../widgets/web_app_shell.dart';
import '../common/storage_choice_flow.dart';
import 'home/doctor_agenda_tab.dart';
import 'home/doctor_home_bottom_nav.dart';
import 'home/doctor_dashboard_tab.dart';
import 'home/doctor_expedientes_tab.dart';
import 'home/doctor_home_helpers.dart';
import 'home/doctor_patients_tab.dart';
import 'home/doctor_home_patients_widgets.dart';

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
  AttendanceStatsData? _attendanceStats;
  bool _loadingAttendanceStats = false;

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
      _loadAttendanceStats(),
    ]);
  }

  Future<void> _loadAttendanceStats() async {
    if (!mounted) return;
    setState(() => _loadingAttendanceStats = true);
    try {
      final stats =
          await DoctorService(context.read<ApiClient>()).fetchDoctorAttendanceStats();
      if (!mounted) return;
      setState(() {
        _attendanceStats = stats;
        _loadingAttendanceStats = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingAttendanceStats = false);
    }
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
      final tomorrow = from.add(const Duration(days: 1));
      // Fin del día de mañana — solo hoy y mañana en agenda del home.
      final to = DateTime(
        tomorrow.year,
        tomorrow.month,
        tomorrow.day,
        23,
        59,
        59,
        999,
      );
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
    final today = KeepiTimezone.startOfTodayInSavedZone();
    return _agenda
        .where((a) =>
            doctorHomeIsConfirmedAppointment(a) &&
            a.appointmentDate != null &&
            KeepiTimezone.isSameScheduleDay(a.appointmentDate!, today))
        .toList()
      ..sort((a, b) => a.appointmentDate!.compareTo(b.appointmentDate!));
  }

  /// Todas las citas confirmadas de hoy y mañana, ordenadas por hora.
  List<AppointmentDto> get _todayAndTomorrowAppointments {
    final startOfToday = KeepiTimezone.startOfTodayInSavedZone();
    final endOfTomorrow = startOfToday.add(const Duration(days: 2));
    return _agenda
        .where((a) {
          if (!doctorHomeIsConfirmedAppointment(a) || a.appointmentDate == null) {
            return false;
          }
          final d = a.appointmentDate!.asScheduleLocal;
          return !d.isBefore(startOfToday) && d.isBefore(endOfTomorrow);
        })
        .toList()
      ..sort((a, b) => a.appointmentDate!.compareTo(b.appointmentDate!));
  }

  List<AppointmentDto> get _upcomingAppointments {
    final nowUtc = DateTime.now().toUtc();
    return _agenda.where((a) {
      if (!doctorHomeIsConfirmedAppointment(a)) return false;
      final d = a.appointmentDate;
      return d != null && d.isAfter(nowUtc);
    }).toList()
      ..sort((a, b) => a.appointmentDate!.compareTo(b.appointmentDate!));
  }

  int get _pendingConfirmCount => _agenda
      .where((a) =>
          a.status == 'pending_patient_approval' ||
          a.status == 'pending_doctor_proposal' ||
          a.status == 'pending_doctor_approval')
      .length;

  /// Próxima cita confirmada de hoy o mañana cuyo horario aún no termina.
  AppointmentDto? get _featuredNextAppointmentInRange {
    final nowUtc = DateTime.now().toUtc();
    for (final a in _todayAndTomorrowAppointments) {
      final end = a.endDate ?? doctorHomeAppointmentSlotEnd(a, _slotDurationMinutes);
      if (end != null && end.isAfter(nowUtc)) return a;
    }
    return null;
  }

  AppointmentDto? get _featuredNextAppointment {
    final nowUtc = DateTime.now().toUtc();
    final candidates = _agenda
        .where((a) => doctorHomeIsConfirmedAppointment(a) && a.appointmentDate != null)
        .toList()
      ..sort((a, b) => a.appointmentDate!.compareTo(b.appointmentDate!));
    for (final a in candidates) {
      final end = a.endDate ?? doctorHomeAppointmentSlotEnd(a, _slotDurationMinutes);
      if (end != null && end.isAfter(nowUtc)) return a;
    }
    return null;
  }

  AppointmentDto? get _nextAppointment => _featuredNextAppointment;

  List<AppointmentDto> get _dashboardUpcoming {
    final featured = _featuredNextAppointment;
    final nowUtc = DateTime.now().toUtc();
    return _agenda
        .where((a) {
          if (!doctorHomeIsConfirmedAppointment(a) || a.appointmentDate == null) {
            return false;
          }
          if (featured != null && a.id == featured.id) return false;
          final end = a.endDate ?? doctorHomeAppointmentSlotEnd(a, _slotDurationMinutes);
          return end != null && end.isAfter(nowUtc);
        })
        .toList()
        ..sort((a, b) => a.appointmentDate!.compareTo(b.appointmentDate!));
  }

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

    final confirm = await showDoctorAppointmentConfirmDialog(
      context,
      patientName: p.name,
      dateTime: finalDateTime,
    );
    if (confirm == null || !mounted) return;

    try {
      final svc = DoctorService(context.read<ApiClient>());
      await svc.scheduleAppointment(
        patientId: p.id,
        date: finalDateTime,
        reason: confirm.reason,
        doctorNote: confirm.doctorNote,
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
    final selectedPatient = await openDoctorPatientPicker(
      context,
      patients: patients,
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
      await _loadAttendanceStats();
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
    final ok = await KeepiConfirmDialog.show(
      context,
      title: 'Desactivar paciente',
      message:
          '¿Desactivar a ${p.name}? Dejará de aparecer en tu lista, pero su historial se conserva.',
      confirmLabel: 'Desactivar',
      icon: Icons.person_off_outlined,
      accent: const Color(0xFFDC2626),
      destructive: true,
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

  Future<void> _sendSchedulingLinkEmail(PatientListItem p) async {
    if (p.email.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El paciente no tiene correo registrado.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: KeepiColors.orange),
      ),
    );

    try {
      final result = await SchedulingService(context.read<ApiClient>())
          .emailPatientSchedulingLink(p.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.emailSent
                ? 'Link de agenda enviado a ${p.email}'
                : (result.emailError ?? result.message).isNotEmpty
                    ? (result.emailError ?? result.message)
                    : 'No se pudo enviar el correo.',
          ),
          backgroundColor:
              result.emailSent ? KeepiColors.green : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(SchedulingService.messageFromDio(e)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openPatientActions(PatientListItem p) async {
    await openDoctorPatientActionsSheet(
      context: context,
      patient: p,
      onTimeline: () => _openTimeline(p),
      onSchedule: () => _scheduleAppointment(p),
      onPrescription: () => _openAssignPrescription(p),
      onAnalysis: () => _openRequestAnalysis(p),
      onQuestionnaire: () => _openSendQuestionnaire(p),
      onSendSchedulingLink: () => _sendSchedulingLinkEmail(p),
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
      bottomNavigationBar: DoctorHomeBottomNav(
        currentIndex: tabIndex,
        onTap: _onDoctorNavTap,
      ),
    );
  }

  Widget _buildHomeTab(AuthProvider auth) {
    return DoctorDashboardTab(
      auth: auth,
      patients: _patients,
      agenda: _agenda,
      loadingAgenda: _loadingAgenda,
      agendaError: _agendaError,
      patientsError: _patientsError,
      slotDurationMinutes: _slotDurationMinutes,
      markingAttendanceIds: _markingAttendanceIds,
      attendanceStats: _attendanceStats,
      loadingAttendanceStats: _loadingAttendanceStats,
      nextAppointment: _nextAppointment,
      dashboardUpcoming: _dashboardUpcoming,
      featuredNextAppointmentInRange: _featuredNextAppointmentInRange,
      todayAndTomorrowAppointments: _todayAndTomorrowAppointments,
      todaysAppointments: _todaysAppointments,
      pendingConfirmCount: _pendingConfirmCount,
      onRefresh: () => _refreshAll(force: true),
      onRetryAgenda: _loadAgenda,
      onRetryPatients: _loadPatients,
      onNotifications: _openNotifications,
      onLogout: _handleLogout,
      onCreatePatient: _openCreatePatient,
      onScheduleAppointment: _openGlobalScheduleAppointment,
      onOpenProfile: (a) {
        final p = _patientForAppointment(a);
        if (p != null) _openPatientProfileDialog(p);
      },
      onOpenConsultation: _openConsultation,
      onMarkAttendance: _markAttendance,
      onOpenAgendaAppointment: _openAgendaAppointment,
      onOpenExpedientes: _openExpedientes,
      onOpenQuestionnaires: _openQuestionnaireSettings,
      patientForAppointment: _patientForAppointment,
    );
  }

  Widget _buildPatientsTab(AuthProvider auth) {
    return DoctorPatientsTab(
      patients: _patients,
      filteredPatients: _filteredPatients,
      loadingPatients: _loadingPatients,
      patientsError: _patientsError,
      searchController: _searchCtrl,
      onSearchChanged: (v) => setState(() => _patientQuery = v),
      onRefresh: () => _loadPatients(force: true),
      onRetry: _loadPatients,
      onNotifications: _openNotifications,
      onLogout: _handleLogout,
      onOpenProfile: _openPatientProfileDialog,
      onDeletePatient: _deletePatient,
      onOpenActions: _openPatientActions,
    );
  }

  Widget _buildAgendaTab(AuthProvider auth) {
    return DoctorHomeAgendaTab(
      onNotifications: _openNotifications,
      onLogout: _handleLogout,
      onOpenConsultation: _openConsultation,
    );
  }

  Widget _buildExpedientesTab(AuthProvider auth) {
    return DoctorHomeExpedientesTab(
      onNotifications: _openNotifications,
      onLogout: _handleLogout,
    );
  }
}
