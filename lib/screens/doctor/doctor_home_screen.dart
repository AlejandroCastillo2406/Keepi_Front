import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/questionnaire_service.dart';
import '../../core/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../services/appointment_service.dart';
import '../../services/config_service.dart' as config_dto;
import '../../services/doctor_service.dart';
import '../common/notifications_screen.dart';
import '../common/storage_choice_flow.dart';
import '../user/settings_screen.dart';
import 'create_patient_screen.dart';
import 'doctor_assign_prescription_screen.dart';
import 'doctor_calendar_tab.dart';
import 'doctor_patient_timeline_screen.dart';
import 'doctor_request_analysis_screen.dart'; 
import 'documentos_screen.dart';
import 'questionnaire/questionnaire_settings_screen.dart';
import 'questionnaire/send_questionnaire_screen.dart';

// ────────────────────────────────────────────────────────────────
//   CONSTANTES / HELPERS
// ────────────────────────────────────────────────────────────────

const _monthsEsUpper = <String>[
  'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
  'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC',
];
const _weekdaysEsUpper = <String>['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];

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

// ────────────────────────────────────────────────────────────────
//   PANTALLA
// ────────────────────────────────────────────────────────────────

class DoctorHomeScreen extends StatefulWidget {
  const DoctorHomeScreen({super.key});

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

  // Storage onboarding
  final FirstRunStorageGate _storageGate = FirstRunStorageGate();
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri?>? _linkSubscription;

  @override
  void initState() {
    super.initState();
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

  // ── Data loading ────────────────────────────────────────────
  Future<void> _refreshAll() async {
    await Future.wait([_loadPatients(), _loadAgenda()]);
  }

  Future<void> _loadPatients() async {
    if (!mounted) return;
    setState(() {
      _loadingPatients = true;
      _patientsError = null;
    });
    try {
      final svc = DoctorService(context.read<ApiClient>());
      final list = await svc.fetchMyPatients();
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
      final svc = AppointmentService(context.read<ApiClient>());
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day);
      final to = from.add(const Duration(days: 14));
      final rows = await svc.fetchDoctorCalendar(from: from, to: to);
      if (!mounted) return;
      setState(() {
        _agenda = rows;
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

  // ── Storage deep links ──────────────────────────────────────
  void _listenForStorageDeepLinks() {
    _appLinks.getInitialLink().then(_onStorageDeepLink);
    _linkSubscription = _appLinks.uriLinkStream.listen(_onStorageDeepLink);
  }

  void _onStorageDeepLink(Uri? uri) {
    if (uri == null) return;
    final s = uri.toString();
    if (s.contains('oauth2redirect') && uri.queryParameters['success'] == '1' && mounted) {
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

  // ── Derived stats ───────────────────────────────────────────
  List<AppointmentDto> get _todaysAppointments {
    final now = DateTime.now();
    return _agenda
        .where((a) => a.appointmentDate != null && _sameDay(a.appointmentDate!.toLocal(), now))
        .toList()
      ..sort((a, b) => a.appointmentDate!.compareTo(b.appointmentDate!));
  }

  List<AppointmentDto> get _upcomingAppointments {
    final now = DateTime.now();
    return _agenda.where((a) {
      final d = a.appointmentDate?.toLocal();
      return d != null && d.isAfter(now);
    }).toList()
      ..sort((a, b) => a.appointmentDate!.compareTo(b.appointmentDate!));
  }

  int get _pendingConfirmCount => _agenda
      .where((a) =>
          a.status == 'pending_patient_approval' ||
          a.status == 'pending_doctor_proposal')
      .length;

  List<PatientListItem> get _filteredPatients {
    final q = _patientQuery.trim().toLowerCase();
    if (q.isEmpty) return _patients;
    return _patients
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.email.toLowerCase().contains(q))
        .toList();
  }

  // ── Actions ─────────────────────────────────────────────────
  void _navigateToSettings() {
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  void _openQuestionnaireSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QuestionnaireSettingsScreen()),
    );
  }

  void _openDocumentos() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DocumentosScreen()),
    );
  }

  Future<void> _openCreatePatient() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreatePatientScreen(api: context.read<ApiClient>()),
      ),
    );
    if (created == true && mounted) await _refreshAll();
  }

  Future<void> _openRequestAnalysis(PatientListItem p) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DoctorRequestAnalysisScreen(
          patientId: p.id,
          patientName: p.name,
        ),
      ),
    );
  }

  Future<void> _openAssignPrescription(PatientListItem p) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DoctorAssignPrescriptionScreen(
          patientId: p.id,
          patientName: p.name,
        ),
      ),
    );
  }

  Future<void> _openTimeline(PatientListItem p) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DoctorPatientTimelineScreen(
          patientId: p.id,
          patientName: p.name,
        ),
      ),
    );
  }

  Future<void> _scheduleAppointment(PatientListItem p) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: KeepiColors.orange),
          ),
          child: child!,
      ),
        );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pickedTime == null || !mounted) return;

    final finalDateTime = DateTime(
      pickedDate.year, pickedDate.month, pickedDate.day,
      pickedTime.hour, pickedTime.minute,
    );

    try {
      final svc = DoctorService(context.read<ApiClient>());
      await svc.scheduleAppointment(
        patientId: p.id,
        date: finalDateTime,
        reason: 'Consulta médica',
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

  Future<void> _openSendQuestionnaire(PatientListItem p) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SendQuestionnaireScreen(
          api: context.read<ApiClient>(),
          patientId: p.id,
          patientName: p.name,
          patientEmail: p.email,
        ),
      ),
    );
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

  Future<void> _openPatientProfileDialog(PatientListItem p) async {
    final initial = p.name.isEmpty ? '?' : p.name[0].toUpperCase();
    
    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Cabecera con Avatar
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: KeepiColors.skyBlueSoft,
                  shape: BoxShape.circle,
                  border: Border.all(color: KeepiColors.skyBlue, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: KeepiColors.skyBlue,
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // 2. Datos del paciente
              Text(
                p.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: KeepiColors.slate,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                p.email,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: KeepiColors.slateLight,
                ),
              ),
              const SizedBox(height: 24),
              
              // 3. Sección de Cuestionarios (DATOS REALES)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'RESPUESTAS DE CUESTIONARIOS',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                    color: KeepiColors.slate,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // Contenedor flexible para la lista
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250), // Evita que se salga de la pantalla
                child: FutureBuilder<List<dynamic>>(
                  // AQUÍ LLAMAMOS A LA API REAL
                  future: QuestionnaireService(context.read<ApiClient>()).fetchPatientResponses(p.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(color: KeepiColors.orange),
                        ),
                      );
                    }
                    
                    if (snapshot.hasError) {
                      return const Text(
                        'Error al cargar las respuestas.',
                        style: TextStyle(color: Colors.red, fontSize: 13),
                      );
                    }

                    final respuestas = snapshot.data ?? [];

                    if (respuestas.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: KeepiColors.surfaceBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: KeepiColors.cardBorder),
                        ),
                        child: const Text(
                          'Este paciente aún no ha respondido cuestionarios.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: KeepiColors.slateLight),
                        ),
                      );
                    }

                    // Lista de respuestas
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: respuestas.length,
                      separatorBuilder: (_, __) => const Divider(color: KeepiColors.cardBorder),
                      itemBuilder: (context, index) {
                        final respuesta = respuestas[index];
                        final pregunta = respuesta['question_text'] ?? 'Pregunta';
                        final valor = respuesta['answer_value'] ?? 'Sin respuesta';

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pregunta,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: KeepiColors.slate,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                valor.toString(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: KeepiColors.orange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 24),
              // 4. Botón de cerrar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KeepiColors.slateSoft,
                    foregroundColor: KeepiColors.slate,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text(
                    'CERRAR',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: KeepiColors.surfaceBg,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _currentIndex,
          children: [
            _buildHomeTab(auth),
            _buildPatientsTab(auth),
            _buildAgendaTab(auth),
            _buildProfileTab(auth),
          ],
        ),
      ),
      floatingActionButton: (_currentIndex == 0 || _currentIndex == 1)
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
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() => _currentIndex = i);
          if (i == 0 || i == 1) _loadPatients();
          if (i == 0 || i == 2) _loadAgenda();
        },
      ),
    );
  }

  // ── Home tab (dashboard) ────────────────────────────────────
  Widget _buildHomeTab(AuthProvider auth) {
    final today = _todaysAppointments;
    final upcoming = _upcomingAppointments.where((a) => !_sameDay(a.appointmentDate!.toLocal(), DateTime.now())).take(3).toList();

    return RefreshIndicator(
      color: KeepiColors.orange,
      onRefresh: _refreshAll,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _TopBar(
              onNotifs: _openNotifications,
              onLogout: auth.logout,
            ),
          ),
          SliverToBoxAdapter(
            child: _HomeHero(
              greeting: _greetingForNow(),
              name: auth.name ?? 'Doctor',
              patients: _patients.length,
              todayAppts: today.length,
              pending: _pendingConfirmCount,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate.fixed([
                if (_patientsError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _ErrorBox(
                      message: _patientsError!,
                      onRetry: _loadPatients,
                    ),
                  ),
                _SectionDivider(tag: 'HOY', count: today.length),
                const SizedBox(height: 14),
                if (_loadingAgenda && _agenda.isEmpty)
                  const _LoadingBox()
                else if (_agendaError != null)
                  _ErrorBox(message: _agendaError!, onRetry: _loadAgenda)
                else if (today.isEmpty)
                  const _InlineEmpty(
                    icon: Icons.coffee_outlined,
                    message: 'Sin citas agendadas para hoy.',
                  )
                else
                  for (final a in today)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AgendaCard(appointment: a, patients: _patients),
                    ),
                const SizedBox(height: 28),
                const _SectionDivider(tag: 'ATAJOS', count: 4),
                const SizedBox(height: 14),
                _ShortcutsStrip(
                  onPatients: () => setState(() => _currentIndex = 1),
                  onDocuments: _openDocumentos,
                  onQuestionnaires: _openQuestionnaireSettings,
                  onAgenda: () => setState(() => _currentIndex = 2),
                ),
                const SizedBox(height: 28),
                if (upcoming.isNotEmpty) ...[
                  _SectionDivider(tag: 'PRÓXIMAS CITAS', count: upcoming.length),
                  const SizedBox(height: 14),
                  for (final a in upcoming)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AgendaCard(appointment: a, patients: _patients),
                    ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Patients tab ────────────────────────────────────────────
  Widget _buildPatientsTab(AuthProvider auth) {
    final list = _filteredPatients;
    return RefreshIndicator(
      color: KeepiColors.orange,
      onRefresh: _loadPatients,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _TopBar(
              onNotifs: _openNotifications,
              onLogout: auth.logout,
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
              // AQUÍ ESTÁN LOS CAMBIOS:
              onProfileTap: () => _openPatientProfileDialog(p), 
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

  // ── Agenda tab ──────────────────────────────────────────────
  Widget _buildAgendaTab(AuthProvider auth) {
    return Column(
      children: [
        _TopBar(onNotifs: _openNotifications, onLogout: auth.logout),
        const Expanded(child: DoctorCalendarTab()),
      ],
    );
  }

  // ── Profile tab ─────────────────────────────────────────────
  Widget _buildProfileTab(AuthProvider auth) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _TopBar(
            onNotifs: _openNotifications,
            onLogout: auth.logout,
          ),
        ),
        SliverToBoxAdapter(
          child: _ProfileHero(
            name: auth.name ?? 'Doctor',
            email: auth.email ?? '',
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 120),
          sliver: SliverList(
            delegate: SliverChildListDelegate.fixed([
              const _SectionDivider(tag: 'CONFIGURACIÓN', count: 3),
              const SizedBox(height: 14),
              _ProfileRow(
                icon: Icons.quiz_outlined,
                accent: KeepiColors.skyBlue,
                title: 'Cuestionarios de salud',
                subtitle: 'Gestiona plantillas y preguntas por especialidad.',
                onTap: _openQuestionnaireSettings,
              ),
              const SizedBox(height: 10),
              _ProfileRow(
                icon: Icons.description_outlined,
                accent: const Color(0xFF7C3AED),
                title: 'Documentos',
                subtitle: 'Todos los archivos subidos por tus pacientes.',
                onTap: _openDocumentos,
              ),
              const SizedBox(height: 10),
              _ProfileRow(
                icon: Icons.settings_outlined,
                accent: KeepiColors.slate,
                title: 'Ajustes de la cuenta',
                subtitle: 'Almacenamiento, suscripción y preferencias.',
                onTap: _navigateToSettings,
              ),
              const SizedBox(height: 26),
              const _SectionDivider(tag: 'SESIÓN', count: 1),
              const SizedBox(height: 14),
              _ProfileRow(
                icon: Icons.logout_rounded,
                accent: Colors.red,
                title: 'Cerrar sesión',
                subtitle: 'Salir de Keepi en este dispositivo.',
                onTap: auth.logout,
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────
//   TOP BAR
// ────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onNotifs, required this.onLogout});

  final VoidCallback onNotifs;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
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

// ────────────────────────────────────────────────────────────────
//   HEROS
// ────────────────────────────────────────────────────────────────

class _HomeHero extends StatelessWidget {
  const _HomeHero({
    required this.greeting,
    required this.name,
    required this.patients,
    required this.todayAppts,
    required this.pending,
  });

  final String greeting;
  final String name;
  final int patients;
  final int todayAppts;
  final int pending;

  @override
  Widget build(BuildContext context) {
    final firstName = name.split(' ').first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
      child: Column(
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
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: KeepiColors.slate,
                height: 1.1,
                letterSpacing: -0.7,
              ),
              children: [
                TextSpan(text: '$greeting,\nDr. '),
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
          const SizedBox(height: 18),
          _StatsStrip(
            items: [
              _StatItem(value: patients, label: 'PACIENTES'),
              _StatItem(value: todayAppts, label: 'CITAS HOY'),
              _StatItem(value: pending, label: 'POR CONFIRMAR', accent: pending > 0),
            ],
          ),
        ],
      ),
    );
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
              _StatItem(value: filtered, label: 'MOSTRANDO', accent: filtered != total && total > 0),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.name, required this.email});
  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 22, height: 2, color: KeepiColors.slate),
        const SizedBox(width: 8),
              const Text(
                'CUENTA',
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
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: KeepiColors.cardBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: KeepiColors.orangeSoft,
                    shape: BoxShape.circle,
                    border: Border.all(color: KeepiColors.orange, width: 1.6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: KeepiColors.orange,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dr. $name',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: KeepiColors.slate,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email.isEmpty ? 'Correo no disponible' : email,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
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
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
//   STATS STRIP
// ────────────────────────────────────────────────────────────────

class _StatItem {
  const _StatItem({required this.value, required this.label, this.accent = false});
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

// ────────────────────────────────────────────────────────────────
//   SECTION DIVIDER
// ────────────────────────────────────────────────────────────────

class _SectionDivider extends StatelessWidget {
  const _SectionDivider({required this.tag, required this.count});
  final String tag;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 18, height: 1, color: KeepiColors.slate.withValues(alpha: 0.45)),
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
          child: Container(height: 1, color: KeepiColors.slate.withValues(alpha: 0.12)),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────
//   PATIENT TILE
// ────────────────────────────────────────────────────────────────

class _PatientTile extends StatelessWidget {
  const _PatientTile({
    required this.patient, 
    required this.onProfileTap, 
    required this.onArrowTap,
  });

  final PatientListItem patient;
  final VoidCallback onProfileTap;
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
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
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
                                      color: KeepiColors.slateLight.withValues(alpha: 0.6),
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
            // ÁREA 2: La flecha (Abre el menú de acciones que ya tenías)
            InkWell(
              onTap: onArrowTap,
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
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

// ────────────────────────────────────────────────────────────────
//   PATIENT ACTIONS SHEET
// ────────────────────────────────────────────────────────────────

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
              title: 'Enviar cuestionario',
              subtitle: 'Link por correo con plantillas o preguntas que elijas.',
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

// ────────────────────────────────────────────────────────────────
//   AGENDA CARD
// ────────────────────────────────────────────────────────────────

class _AgendaCard extends StatelessWidget {
  const _AgendaCard({required this.appointment, required this.patients});
  final AppointmentDto appointment;
  final List<PatientListItem> patients;

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

  @override
  Widget build(BuildContext context) {
    final date = appointment.appointmentDate?.toLocal();
    final day = date?.day ?? 0;
    final monthAbbr = date != null ? _monthsEsUpper[date.month - 1] : '—';
    final timeLabel = date != null
        ? '${_two(date.hour)}:${_two(date.minute)}'
        : 'Sin hora';
    final statusColor = _statusColor();
    final needsAttention = appointment.status == 'pending_patient_approval' ||
        appointment.status == 'pending_doctor_proposal';

    return Container(
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
                  appointment.reason.isEmpty ? 'Consulta médica' : appointment.reason,
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
            child: Container(
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
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
//   SHORTCUTS STRIP
// ────────────────────────────────────────────────────────────────

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
            icon: Icons.description_outlined,
            label: 'Documentos',
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
                Icon(Icons.arrow_forward_rounded, size: 11, color: KeepiColors.slateLight),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
//   PROFILE ROW
// ────────────────────────────────────────────────────────────────

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
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

// ────────────────────────────────────────────────────────────────
//   SEARCH FIELD
// ────────────────────────────────────────────────────────────────

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
          hintStyle: const TextStyle(color: KeepiColors.slateLight, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, color: KeepiColors.slateLight, size: 20),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: KeepiColors.slateLight),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          filled: false,
            ),
          ),
        );
      }
    }

// ────────────────────────────────────────────────────────────────
//   STATE WIDGETS
// ────────────────────────────────────────────────────────────────

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
          child: CircularProgressIndicator(color: KeepiColors.orange, strokeWidth: 2.4),
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
              Icon(Icons.error_outline_rounded, color: KeepiColors.orange, size: 18),
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
            style: const TextStyle(fontSize: 13.5, color: KeepiColors.slate, height: 1.4),
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
                  Icon(Icons.refresh_rounded, size: 16, color: KeepiColors.slate),
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
              Container(width: 18, height: 1, color: KeepiColors.slate.withValues(alpha: 0.45)),
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

// ────────────────────────────────────────────────────────────────
//   BOTTOM NAV
// ────────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.currentIndex, required this.onTap});
  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = <_NavItemData>[
    _NavItemData(icon: Icons.space_dashboard_outlined, label: 'Inicio'),
    _NavItemData(icon: Icons.people_alt_outlined, label: 'Pacientes'),
    _NavItemData(icon: Icons.calendar_month_outlined, label: 'Agenda'),
    _NavItemData(icon: Icons.person_outline_rounded, label: 'Perfil'),
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
  const _NavItem({required this.data, required this.active, required this.onTap});
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
