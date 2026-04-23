import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../models/timeline_event.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../services/appointment_service.dart';
import '../../services/config_service.dart' as config_dto;
import '../../services/doctor_service.dart';
import '../../services/prescription_service.dart';
import '../../widgets/patient_care_timeline.dart';
import '../common/notifications_screen.dart';
import '../common/storage_choice_flow.dart';
import 'patient_upload_analysis_screen.dart';

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

// ────────────────────────────────────────────────────────────────
//   PANTALLA
// ────────────────────────────────────────────────────────────────

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  int _currentIndex = 0;

  final FirstRunStorageGate _storageGate = FirstRunStorageGate();
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri?>? _linkSubscription;

  List<AnalysisRequestDto> _pendingAnalysisRequests = [];
  List<AppointmentDto> _myAppointments = [];
  bool _loadingConsultas = false;
  String? _consultasError;

  bool _loadingTimeline = false;
  String? _timelineError;
  List<TimelineEvent> _timelineEvents = [];

  bool _loadingRecetas = false;
  String? _recetasError;
  List<PrescriptionDto> _recetas = [];

  @override
  void initState() {
    super.initState();
    _listenForStorageDeepLinks();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserConfigForStorage();
      _loadPendingAnalysisRequests();
      _loadCareTimeline();
      _loadRecetas();
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  // ── Data loading ─────────────────────────────────────────────
  Future<void> _loadCareTimeline() async {
    setState(() {
      _loadingTimeline = true;
      _timelineError = null;
    });
    try {
      final api = context.read<ApiClient>();
      final list = await DoctorService(api).fetchMyCareTimeline();
      if (!mounted) return;
      setState(() {
        _timelineEvents = list;
        _loadingTimeline = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _timelineError = DoctorService.messageFromDio(e);
        _loadingTimeline = false;
      });
    }
  }

  Future<void> _loadPendingAnalysisRequests() async {
    setState(() {
      _loadingConsultas = true;
      _consultasError = null;
    });
    try {
      final api = context.read<ApiClient>();
      final list = await DoctorService(api).fetchMyPendingRequests();
      final appointments = await AppointmentService(api).fetchMine();
      if (!mounted) return;
      setState(() {
        _pendingAnalysisRequests = list;
        _myAppointments = appointments;
        _loadingConsultas = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _consultasError = DoctorService.messageFromDio(e);
        _loadingConsultas = false;
      });
    }
  }

  Future<void> _loadRecetas() async {
    setState(() {
      _loadingRecetas = true;
      _recetasError = null;
    });
    try {
      final api = context.read<ApiClient>();
      final rows = await PrescriptionService(api).fetchMine();
      if (!mounted) return;
      setState(() {
        _recetas = rows;
        _loadingRecetas = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _recetasError = PrescriptionService.messageFromDio(e);
        _loadingRecetas = false;
      });
    }
  }

  Future<void> _openPrescriptionScan(PrescriptionDto p) async {
    final api = context.read<ApiClient>();
    try {
      final url = await PrescriptionService(api).getScanUrl(p.id);
      if (url.isEmpty) return;
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(PrescriptionService.messageFromDio(e))),
      );
    }
  }

  Future<void> _togglePrescriptionReminder(PrescriptionDto p, bool enabled) async {
    final api = context.read<ApiClient>();
    try {
      await PrescriptionService(api).setReminderOptIn(p.id, enabled);
      await _loadRecetas();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(enabled ? 'Recordatorios activados' : 'Recordatorios desactivados'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(PrescriptionService.messageFromDio(e))),
      );
    }
  }

  // ── Helpers de cita ──────────────────────────────────────────
  AppointmentDto? get _nextUpcomingAppointment {
    final now = DateTime.now();
    final future = _myAppointments
        .where((a) => a.currentStartAt.toLocal().isAfter(now))
        .toList()
      ..sort((a, b) => a.currentStartAt.compareTo(b.currentStartAt));
    return future.isEmpty ? null : future.first;
  }

  Future<void> _confirmAppointment(AppointmentDto a) async {
    final api = context.read<ApiClient>();
    try {
      await AppointmentService(api).patientConfirm(a.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cita confirmada')),
      );
      await _loadPendingAnalysisRequests();
      await _loadCareTimeline();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppointmentService.messageFromDio(e))),
      );
    }
  }

  Future<void> _requestAppointmentChange(AppointmentDto a) async {
    final api = context.read<ApiClient>();
    try {
      await AppointmentService(api).patientRequestChange(
        appointmentId: a.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avisamos al doctor que no puedes en ese horario')),
      );
      await _loadPendingAnalysisRequests();
      await _loadCareTimeline();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppointmentService.messageFromDio(e))),
      );
    }
  }

  Future<void> _openUploadForRequest(AnalysisRequestDto req) async {
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PatientUploadAnalysisScreen(
          requestId: req.id,
          description: req.description,
        ),
      ),
    );
    if (done == true && mounted) {
      await _loadPendingAnalysisRequests();
      await _loadCareTimeline();
  }
  }

  // ── Deep links (storage onboarding) ──────────────────────────
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

  // ── Build ────────────────────────────────────────────────────
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
            _buildHomeTab(context, auth),
            _buildRecetasTab(auth),
            _buildConsultasTab(auth),
            _buildProfilePlaceholder(auth),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() => _currentIndex = i);
          if (i == 0) _loadCareTimeline();
          if (i == 1) _loadRecetas();
          if (i == 2) _loadPendingAnalysisRequests();
        },
      ),
    );
  }

  // ── Home (Dashboard) ─────────────────────────────────────────
  Future<void> _refreshAll() async {
    await _loadCareTimeline();
    await _loadPendingAnalysisRequests();
    await _loadRecetas();
  }

  Widget _buildHomeTab(BuildContext context, AuthProvider auth) {
    final nextAppt = _nextUpcomingAppointment;
    final pending = _pendingAnalysisRequests;

    return RefreshIndicator(
      color: KeepiColors.orange,
      onRefresh: _refreshAll,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _TopBar(
              onNotifs: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ),
              onLogout: auth.logout,
            ),
          ),
          SliverToBoxAdapter(
            child: _HomeHero(
              greeting: _greetingForNow(),
              name: auth.name ?? 'Paciente',
              eventCount: _timelineEvents.length,
              pendingCount: pending.length,
              appointmentCount: _myAppointments.length,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate.fixed([
                if (nextAppt != null) ...[
                  _SectionDivider(tag: 'TU PRÓXIMA CITA', count: 1),
                  const SizedBox(height: 14),
                  _NextAppointmentCard(
                    appointment: nextAppt,
                    onConfirm: () => _confirmAppointment(nextAppt),
                    onRequestChange: () => _requestAppointmentChange(nextAppt),
                  ),
                  const SizedBox(height: 28),
                ],
                if (pending.isNotEmpty) ...[
                  _SectionDivider(tag: 'TE TOCA A TI', count: pending.length),
                  const SizedBox(height: 14),
                  for (final r in pending)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PendingCompactCard(
                        request: r,
                        onTap: () => _openUploadForRequest(r),
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
                _SectionDivider(tag: 'ATAJOS', count: 3),
                const SizedBox(height: 14),
                _ShortcutsStrip(
                  recetas: _recetas.length,
                  citas: _myAppointments.length,
                  pendientes: pending.length,
                  onTapRecetas: () {
                    setState(() => _currentIndex = 1);
                    _loadRecetas();
                  },
                  onTapConsultas: () {
                    setState(() => _currentIndex = 2);
                    _loadPendingAnalysisRequests();
                  },
                  onTapPerfil: () => setState(() => _currentIndex = 3),
                ),
                const SizedBox(height: 28),
                _homeTimelineBlock(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _homeTimelineBlock() {
    if (_loadingTimeline) return const _LoadingBox();
    if (_timelineError != null) {
      return _ErrorBox(message: _timelineError!, onRetry: _loadCareTimeline);
    }
    if (_timelineEvents.isEmpty) {
      return const _EmptyStateCard(
        tag: 'HISTORIAL',
        title: 'Todavía no hay movimiento',
        message:
            'Cuando tu médico registre tu alta o solicite estudios, verás el paso a paso exactamente aquí.',
        icon: Icons.timeline_outlined,
      );
    }
    return PatientCareTimeline(events: _timelineEvents);
  }

  // ── Recetas tab ──────────────────────────────────────────────
  Widget _buildRecetasTab(AuthProvider auth) {
    final total = _recetas.length;
    final withReminders = _recetas.where((r) => r.remindersEnabled).length;

    return RefreshIndicator(
      color: KeepiColors.orange,
      onRefresh: _loadRecetas,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _TopBar(
              onNotifs: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ),
              onLogout: auth.logout,
            ),
          ),
          SliverToBoxAdapter(
            child: _RecetasHero(total: total, withReminders: withReminders),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 120),
            sliver: SliverToBoxAdapter(child: _recetasBlock()),
          ),
        ],
      ),
    );
  }

  Widget _recetasBlock() {
    if (_loadingRecetas) return const _LoadingBox();
    if (_recetasError != null) {
      return _ErrorBox(message: _recetasError!, onRetry: _loadRecetas);
    }
    if (_recetas.isEmpty) {
      return const _EmptyStateCard(
        tag: 'RECETAS',
        title: 'Aún no hay recetas',
        message:
            'Cuando tu médico emita una receta en Keepi, la verás aquí con su PDF original y recordatorios.',
        icon: Icons.receipt_long_outlined,
      );
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        _SectionDivider(tag: 'LISTADO', count: _recetas.length),
        const SizedBox(height: 14),
        for (final p in _recetas)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PrescriptionCard(
              data: p,
              onOpen: () => _openPrescriptionScan(p),
              onToggleReminder: (v) => _togglePrescriptionReminder(p, v),
            ),
          ),
      ],
    );
  }

  // ── Consultas tab ────────────────────────────────────────────
  Widget _buildConsultasTab(AuthProvider auth) {
    final appts = _myAppointments;
    final reqs = _pendingAnalysisRequests;

    return RefreshIndicator(
      color: KeepiColors.orange,
      onRefresh: _loadPendingAnalysisRequests,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _TopBar(
              onNotifs: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ),
              onLogout: auth.logout,
            ),
          ),
          SliverToBoxAdapter(
            child: _ConsultasHero(
              appts: appts.length,
              reqs: reqs.length,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate.fixed([
                _SectionDivider(tag: 'CITAS AGENDADAS', count: appts.length),
                const SizedBox(height: 14),
                if (_loadingConsultas && _consultasError == null)
                  const _LoadingBox()
                else if (_consultasError != null)
                  _ErrorBox(message: _consultasError!, onRetry: _loadPendingAnalysisRequests)
                else if (appts.isEmpty)
                  const _InlineEmpty(
                    icon: Icons.event_busy_outlined,
                    message: 'Aún no tienes citas agendadas.',
                  )
                else
                  ...appts.map(_buildAppointmentCard),
                const SizedBox(height: 34),
                _SectionDivider(tag: 'DOCUMENTOS PENDIENTES', count: reqs.length),
                const SizedBox(height: 14),
                if (_loadingConsultas && _consultasError == null)
                  const SizedBox.shrink()
                else if (_consultasError != null)
                  const SizedBox.shrink()
                else if (reqs.isEmpty)
                  const _InlineEmpty(
                    icon: Icons.check_circle_outline_rounded,
                    message: 'Tu médico no tiene estudios pendientes para ti.',
                  )
                else
                  ...reqs.map(_buildPendingRequestCard),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePlaceholder(AuthProvider auth) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _TopBar(
            onNotifs: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
            onLogout: auth.logout,
          ),
        ),
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: _EmptyStateCard(
                tag: 'PERFIL',
                title: 'En construcción',
                message: 'Aquí podrás administrar tus datos, preferencias y almacenamiento en la nube.',
                icon: Icons.person_outline_rounded,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Cards ────────────────────────────────────────────────────
  Widget _buildAppointmentCard(AppointmentDto a) {
    final start = a.currentStartAt.toLocal();
    final end = a.currentEndAt.toLocal();
    final timeLabel =
        '${_two(start.hour)}:${_two(start.minute)} — ${_two(end.hour)}:${_two(end.minute)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _DossierCard(
        day: start.day,
        monthAbbr: _monthsEsUpper[start.month - 1],
        tagLabel: 'CITA',
        statusLabel: a.status.toUpperCase(),
        tagColor: KeepiColors.skyBlue,
        metaLine: timeLabel,
        title: 'Consulta médica',
        detail: a.reason.isEmpty ? 'Consulta' : a.reason,
        icon: Icons.event_available_outlined,
      ),
    );
  }

  Widget _buildPendingRequestCard(AnalysisRequestDto req) {
    final dt = DateTime.tryParse(req.createdAt)?.toLocal();
    final day = dt?.day ?? 0;
    final monthAbbr = dt != null ? _monthsEsUpper[dt.month - 1] : '—';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _DossierCard(
        day: day,
        monthAbbr: monthAbbr,
        tagLabel: 'ANÁLISIS',
        statusLabel: 'PENDIENTE',
        tagColor: KeepiColors.orange,
        metaLine: 'Solicitado por tu médico',
        title: 'Estudio por entregar',
        detail: req.description.trim().isEmpty ? 'Estudio solicitado' : req.description.trim(),
        icon: Icons.biotech_outlined,
        actionLabel: 'Subir estudio',
        onAction: () => _openUploadForRequest(req),
      ),
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
//   HERO SECTIONS
// ────────────────────────────────────────────────────────────────

class _HomeHero extends StatelessWidget {
  const _HomeHero({
    required this.greeting,
    required this.name,
    required this.eventCount,
    required this.pendingCount,
    required this.appointmentCount,
  });

  final String greeting;
  final String name;
  final int eventCount;
  final int pendingCount;
  final int appointmentCount;

  @override
  Widget build(BuildContext context) {
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
                TextSpan(text: '$greeting,\n'),
                TextSpan(
                  text: name,
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
            'Un resumen intencionalmente breve de tu expediente.',
            style: TextStyle(
              fontSize: 13.5,
              color: KeepiColors.slateLight,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          _StatsStrip(
            items: [
              _StatItem(value: eventCount, label: 'EN HISTORIAL'),
              _StatItem(value: appointmentCount, label: 'CITAS'),
              _StatItem(value: pendingCount, label: 'PENDIENTES', accent: pendingCount > 0),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConsultasHero extends StatelessWidget {
  const _ConsultasHero({required this.appts, required this.reqs});

  final int appts;
  final int reqs;

  @override
  Widget build(BuildContext context) {
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
                'AGENDA Y ESTUDIOS',
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
            'Tus consultas.',
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
            'Citas médicas y los estudios que tu doctor te ha solicitado.',
            style: TextStyle(fontSize: 13.5, color: KeepiColors.slateLight, height: 1.4),
          ),
          const SizedBox(height: 18),
          _StatsStrip(
            items: [
              _StatItem(value: appts, label: 'CITAS'),
              _StatItem(value: reqs, label: 'PENDIENTES', accent: reqs > 0),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecetasHero extends StatelessWidget {
  const _RecetasHero({required this.total, required this.withReminders});
  final int total;
  final int withReminders;

  @override
  Widget build(BuildContext context) {
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
                'FARMACOLOGÍA',
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
            'Tus recetas.',
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
            'Tratamientos vigentes, archivos originales y recordatorios de toma.',
            style: TextStyle(fontSize: 13.5, color: KeepiColors.slateLight, height: 1.4),
          ),
          const SizedBox(height: 18),
          _StatsStrip(
            items: [
              _StatItem(value: total, label: 'RECETAS'),
              _StatItem(value: withReminders, label: 'CON AVISO', accent: withReminders > 0),
            ],
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
//   PRESCRIPTION CARD
// ────────────────────────────────────────────────────────────────

class _PrescriptionCard extends StatelessWidget {
  const _PrescriptionCard({
    required this.data,
    required this.onOpen,
    required this.onToggleReminder,
  });

  final PrescriptionDto data;
  final VoidCallback onOpen;
  final ValueChanged<bool> onToggleReminder;

  String get _statusLabel {
    switch (data.status) {
      case 'confirmed':
      case 'active':
      case 'completed':
        return 'ACTIVA';
      case 'draft_ocr':
      case 'draft':
        return 'BORRADOR';
      case 'archived':
        return 'ARCHIVADA';
      default:
        return data.status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final meds = data.items;
    final doctor = (data.doctorName ?? '').trim();
    final file = (data.sourceFileName ?? '').trim();

    return Container(
                decoration: BoxDecoration(
        color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KeepiColors.cardBorder),
                ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF7C3AED), width: 1.6),
                  ),
                  child: const Icon(Icons.medication_outlined, size: 19, color: Color(0xFF7C3AED)),
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
                              color: Color(0xFF7C3AED),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          const Text(
                            'RECETA',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                              color: Color(0xFF7C3AED),
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
                              _statusLabel,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: KeepiColors.slateLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 2,
                        width: 20,
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        doctor.isEmpty ? 'Receta emitida' : doctor,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: KeepiColors.slate,
                          height: 1.25,
                          letterSpacing: -0.25,
                        ),
                      ),
                      if (file.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(
                              Icons.description_outlined,
                              size: 13,
                              color: KeepiColors.slateLight,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                file,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: KeepiColors.slateLight,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(width: 12, height: 1, color: KeepiColors.slate.withValues(alpha: 0.45)),
                const SizedBox(width: 8),
                Text(
                  '${_two(meds.length)} ${meds.length == 1 ? "MEDICAMENTO" : "MEDICAMENTOS"}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    color: KeepiColors.slateLight,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(height: 1, color: KeepiColors.slate.withValues(alpha: 0.12)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (meds.isEmpty)
              const Text(
                'Sin medicamentos detectados.',
                style: TextStyle(
                  fontSize: 13,
                  color: KeepiColors.slateLight,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              ...meds.map(_buildMedRow),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onOpen,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      decoration: BoxDecoration(
                        color: KeepiColors.slate,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.picture_as_pdf_outlined, color: Colors.white, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'VER PDF',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _ReminderToggle(
                  enabled: data.remindersEnabled,
                  onChanged: onToggleReminder,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedRow(PrescriptionItemDto i) {
    final frags = <String>[];
    if (i.everyHours != null) frags.add('cada ${i.everyHours}h');
    if (i.durationDays != null) frags.add('${i.durationDays} días');
    if ((i.route ?? '').trim().isNotEmpty) frags.add(i.route!.trim());
    final detail = frags.join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 10),
      child: Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: Color(0xFF7C3AED),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  i.medication.isEmpty ? 'Medicamento sin nombre' : i.medication,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: KeepiColors.slate,
                    height: 1.25,
                  ),
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    detail,
                    style: const TextStyle(
                      fontSize: 12,
                      color: KeepiColors.slateLight,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderToggle extends StatelessWidget {
  const _ReminderToggle({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? KeepiColors.orange : KeepiColors.slateLight;
    return InkWell(
      onTap: () => onChanged(!enabled),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: color.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              enabled
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 8),
            Text(
              enabled ? 'AVISO ON' : 'AVISO OFF',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: color,
              ),
            ),
          ],
        ),
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
//   DOSSIER CARD (Cita / Solicitud)
// ────────────────────────────────────────────────────────────────

class _DossierCard extends StatelessWidget {
  const _DossierCard({
    required this.day,
    required this.monthAbbr,
    required this.tagLabel,
    required this.statusLabel,
    required this.tagColor,
    required this.metaLine,
    required this.title,
    required this.detail,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  final int day;
  final String monthAbbr;
  final String tagLabel;
  final String statusLabel;
  final Color tagColor;
  final String metaLine;
  final String title;
  final String detail;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date stamp
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
                // Body
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(color: tagColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            tagLabel,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                              color: tagColor,
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
                              statusLabel,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: KeepiColors.slateLight,
                              ),
                  ),
                ),
              ],
            ),
                      const SizedBox(height: 6),
                      Container(
                        height: 2,
                        width: 20,
                        decoration: BoxDecoration(
                          color: tagColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 8),
            Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: KeepiColors.slate,
                          height: 1.25,
                          letterSpacing: -0.25,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        detail,
                        style: const TextStyle(
                          fontSize: 13,
                          color: KeepiColors.slateLight,
                          height: 1.4,
                        ),
                      ),
                      if (metaLine.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 1,
                              color: KeepiColors.slate.withValues(alpha: 0.55),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                metaLine,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: KeepiColors.slate.withValues(alpha: 0.85),
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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
                      border: Border.all(color: tagColor, width: 1.6),
                    ),
                    child: Icon(icon, size: 17, color: tagColor),
                  ),
                ),
              ],
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              _DossierAction(label: actionLabel!, onTap: onAction!),
            ],
          ],
        ),
      ),
    );
  }
}

class _DossierAction extends StatelessWidget {
  const _DossierAction({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
              width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
        decoration: BoxDecoration(
          color: KeepiColors.slate,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
//   NEXT APPOINTMENT CARD (dashboard)
// ────────────────────────────────────────────────────────────────

class _NextAppointmentCard extends StatelessWidget {
  const _NextAppointmentCard({
    required this.appointment,
    required this.onConfirm,
    required this.onRequestChange,
  });

  final AppointmentDto appointment;
  final VoidCallback onConfirm;
  final VoidCallback onRequestChange;

  bool get _needsConfirm => appointment.status == 'pending_patient_confirmation';

  String _statusLabel() {
    switch (appointment.status) {
      case 'pending_patient_confirmation':
        return 'POR CONFIRMAR';
      case 'confirmed':
        return 'CONFIRMADA';
      case 'reschedule_requested':
        return 'CAMBIO SOLICITADO';
      case 'cancelled':
        return 'CANCELADA';
      default:
        return appointment.status.toUpperCase();
    }
  }

  String _relativeLabel(DateTime start) {
    final now = DateTime.now();
    final delta = start.difference(now);
    if (delta.inDays > 1) return 'En ${delta.inDays} días';
    if (delta.inDays == 1) return 'Mañana';
    if (delta.inHours >= 1) return 'En ${delta.inHours} h';
    if (delta.inMinutes >= 1) return 'En ${delta.inMinutes} min';
    return 'Ahora';
  }

  @override
  Widget build(BuildContext context) {
    final start = appointment.currentStartAt.toLocal();
    final end = appointment.currentEndAt.toLocal();
    final timeLabel =
        '${_two(start.hour)}:${_two(start.minute)} — ${_two(end.hour)}:${_two(end.minute)}';

    return Container(
        decoration: BoxDecoration(
          color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _needsConfirm
              ? KeepiColors.orange.withValues(alpha: 0.55)
              : KeepiColors.cardBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 68,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _two(start.day),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: KeepiColors.slate,
                          height: 1,
                          letterSpacing: -1.4,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _monthsEsUpper[start.month - 1],
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: KeepiColors.slateLight,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _weekdaysEsUpper[start.weekday - 1],
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: KeepiColors.slateLight,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
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
                                color: _needsConfirm
                                    ? KeepiColors.orange
                                    : KeepiColors.slateLight,
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
                      const SizedBox(height: 10),
                      Text(
                        _relativeLabel(start),
                        style: const TextStyle(
                          fontSize: 17.5,
                          fontWeight: FontWeight.w800,
                          color: KeepiColors.slate,
                          height: 1.2,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          color: KeepiColors.slateLight,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        appointment.reason.isEmpty ? 'Consulta médica' : appointment.reason,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: KeepiColors.slate,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_needsConfirm) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: onConfirm,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
                        decoration: BoxDecoration(
                          color: KeepiColors.slate,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_rounded, color: Colors.white, size: 17),
                            SizedBox(width: 8),
                            Text(
                              'CONFIRMAR',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: onRequestChange,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: KeepiColors.slate),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.edit_calendar_outlined, color: KeepiColors.slate, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'NO PUEDO',
                              style: TextStyle(
                                color: KeepiColors.slate,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
//   PENDING COMPACT CARD (dashboard)
// ────────────────────────────────────────────────────────────────

class _PendingCompactCard extends StatelessWidget {
  const _PendingCompactCard({required this.request, required this.onTap});
  final AnalysisRequestDto request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final detail =
        request.description.trim().isEmpty ? 'Estudio solicitado' : request.description.trim();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: KeepiColors.orange.withValues(alpha: 0.45)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: KeepiColors.orange, width: 1.6),
              ),
              child: const Icon(Icons.biotech_outlined, size: 17, color: KeepiColors.orange),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                    'ANÁLISIS · POR SUBIR',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      color: KeepiColors.orange,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: KeepiColors.slate,
                      height: 1.3,
                      letterSpacing: -0.15,
                    ),
                  ),
                    ],
                  ),
                ),
            const SizedBox(width: 10),
            const Icon(Icons.arrow_forward_rounded, color: KeepiColors.slate, size: 18),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
//   SHORTCUTS STRIP (dashboard)
// ────────────────────────────────────────────────────────────────

class _ShortcutsStrip extends StatelessWidget {
  const _ShortcutsStrip({
    required this.recetas,
    required this.citas,
    required this.pendientes,
    required this.onTapRecetas,
    required this.onTapConsultas,
    required this.onTapPerfil,
  });

  final int recetas;
  final int citas;
  final int pendientes;
  final VoidCallback onTapRecetas;
  final VoidCallback onTapConsultas;
  final VoidCallback onTapPerfil;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ShortcutTile(
            icon: Icons.receipt_long_outlined,
            label: 'Recetas',
            count: recetas,
            accent: const Color(0xFF7C3AED),
            onTap: onTapRecetas,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ShortcutTile(
            icon: Icons.event_note_outlined,
            label: 'Consultas',
            count: citas + pendientes,
            accent: KeepiColors.skyBlue,
            onTap: onTapConsultas,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ShortcutTile(
            icon: Icons.person_outline_rounded,
            label: 'Perfil',
            count: null,
            accent: KeepiColors.slate,
            onTap: onTapPerfil,
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
    required this.count,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int? count;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: KeepiColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: accent, width: 1.6),
                  ),
                  child: Icon(icon, color: accent, size: 17),
                ),
                if (count != null)
                  Text(
                    _two(count!),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: accent,
                      height: 1,
                      letterSpacing: -0.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
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
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: KeepiColors.slateLight,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, size: 12, color: KeepiColors.slateLight),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
//   STATE WIDGETS (loading / error / empty)
// ────────────────────────────────────────────────────────────────

class _LoadingBox extends StatelessWidget {
  const _LoadingBox();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: SizedBox(
          width: 22, height: 22,
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
          Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: KeepiColors.orange, size: 18),
              const SizedBox(width: 8),
              const Text(
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
    _NavItemData(icon: Icons.receipt_long_outlined, label: 'Recetas'),
    _NavItemData(icon: Icons.event_note_outlined, label: 'Consultas'),
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
