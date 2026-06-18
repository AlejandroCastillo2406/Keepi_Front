import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/web_layout.dart';
import '../../models/consultation_context.dart';
import '../../models/timeline_event.dart';
import '../../providers/auth_provider.dart';
import '../../providers/patients_cache_provider.dart';
import '../../services/api_client.dart';
import '../../services/appointment_service.dart';
import '../../services/doctor_service.dart';
import '../../services/timeline_event_opener.dart';
import 'questionnaire/doctor_answer_questionnaire_screen.dart';
import '../../utils/patient_expediente_export.dart';
import '../../widgets/doctor_clinical_profile_editor.dart';
import '../../widgets/doctor_patient_web_blocks.dart';
import '../../widgets/patient_care_timeline.dart';
import '../../widgets/patient_scheduling_link_dialog.dart';
import '../../router/app_navigation.dart';
import '../../router/app_paths.dart';

class DoctorPatientProfileScreen extends StatefulWidget {
  const DoctorPatientProfileScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.patientEmail,
    required this.mustChangePassword,
    required this.onOpenTimeline,
    required this.onOpenRequestAnalysis,
    required this.onOpenAssignPrescription,
    required this.onOpenSchedule,
    required this.onOpenQuestionnaire,
    this.initialTabIndex = 0,
    this.onOpenConsultation,
    this.embedded = false,
    this.onBack,
    this.embeddedTabPanelsOnly = false,
    this.externalTabIndex = 0,
  });

  final String patientId;
  final String patientName;
  final String patientEmail;
  final bool mustChangePassword;

  final VoidCallback onOpenTimeline;
  final VoidCallback onOpenRequestAnalysis;
  final VoidCallback onOpenAssignPrescription;
  final VoidCallback onOpenSchedule;
  final VoidCallback onOpenQuestionnaire;
  final int initialTabIndex;
  final VoidCallback? onOpenConsultation;
  final bool embedded;
  final VoidCallback? onBack;
  /// Solo el cuerpo de pestañas (Resumen/Análisis/Cuestionarios/Historial), sin cabecera.
  final bool embeddedTabPanelsOnly;
  final int externalTabIndex;

  @override
  State<DoctorPatientProfileScreen> createState() =>
      _DoctorPatientProfileScreenState();
}

class _DoctorPatientProfileScreenState
    extends State<DoctorPatientProfileScreen> with AutomaticKeepAliveClientMixin {
  bool _loading = true;
  bool _bootstrapping = false;
  String? _error;

  List<AnalysisRequestDto> _analysisRequests = [];
  List<TimelineEvent> _timeline = [];
  List<Map<String, dynamic>> _questionnaireResponses = [];
  List<Map<String, dynamic>> _questionnairePending = [];
  ConsultationContext? _clinicalContext;
  bool _exportingExpediente = false;
  bool _editingProfile = false;
  String? _openingDocumentId;
  late int _webTabIndex;
  List<AppointmentDto> _patientAppointments = const [];
  bool _loadingConsultations = false;

  int get _maxTabIndex => widget.embeddedTabPanelsOnly ? 3 : 4;

  @override
  bool get wantKeepAlive => widget.embeddedTabPanelsOnly;

  int get _activeTabIndex => widget.embeddedTabPanelsOnly
      ? widget.externalTabIndex.clamp(0, 3)
      : _webTabIndex;

  List<_QuestionnaireGroup> _buildQuestionnaireGroups(
      List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return const [];

    final parsed = rows.map((r) {
      final rawDate = (r['answered_at'] ?? '').toString();
      final dt = DateTime.tryParse(rawDate)?.toLocal();
      return _ResponseRow(data: r, answeredAt: dt);
    }).toList()
      ..sort((a, b) {
        final ad = a.answeredAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = b.answeredAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });

    final groups = <_QuestionnaireGroup>[];
    for (final row in parsed) {
      final invId = (row.data['invitation_id'] ?? '').toString().trim();

      _QuestionnaireGroup? match;
      if (invId.isNotEmpty) {
        for (final g in groups) {
          if (g.invitationId == invId) {
            match = g;
            break;
          }
        }
      } else {
        final current = groups.isEmpty ? null : groups.last;
        if (current != null &&
            row.answeredAt != null &&
            current.anchor != null &&
            current.anchor!.difference(row.answeredAt!).abs() <=
                const Duration(minutes: 12)) {
          match = current;
        }
      }

      if (match != null) {
        match.items.add(row.data);
        final t = row.answeredAt;
        if (t != null && (match.anchor == null || t.isAfter(match.anchor!))) {
          match.anchor = t;
        }
      } else {
        groups.add(
          _QuestionnaireGroup(
            invitationId: invId.isEmpty ? null : invId,
            anchor: row.answeredAt,
            answeredBy: (row.data['answered_by'] ?? '').toString(),
            items: [row.data],
          ),
        );
      }
    }
    return groups;
  }

  @override
  void initState() {
    super.initState();
    if (!widget.embeddedTabPanelsOnly) {
      _webTabIndex = widget.initialTabIndex.clamp(0, _maxTabIndex);
    }
    final cached =
        context.read<PatientsCacheProvider>().peekProfile(widget.patientId);
    if (cached != null) {
      _applyProfileSnapshot(cached);
      _loading = false;
      _bootstrapping = false;
    } else {
      _loading = false;
      _bootstrapping = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData(force: cached == null);
      if (!widget.embeddedTabPanelsOnly &&
          widget.initialTabIndex.clamp(0, _maxTabIndex) == 4) {
        _handleConsultaTabSelected();
      }
    });
  }

  Future<List<AppointmentDto>> _loadPatientAppointments() async {
    final api = context.read<ApiClient>();
    return AppointmentService(api).fetchDoctorPatientAppointments(
      widget.patientId,
    );
  }

  Future<void> _openConsultationForAppointment(AppointmentDto appt) async {
    await context.push(
      AppPaths.doctorConsultation(
        appt.id,
        patientId: widget.patientId,
        name: widget.patientName,
        email: widget.patientEmail.isNotEmpty ? widget.patientEmail : null,
      ),
    );
  }

  Future<void> _handleConsultaTabSelected() async {
    if (widget.embeddedTabPanelsOnly) return;

    setState(() => _loadingConsultations = true);
    try {
      final rows = await _loadPatientAppointments();
      if (!mounted) return;

      if (rows.length == 1) {
        setState(() => _loadingConsultations = false);
        await _openConsultationForAppointment(rows.first);
        return;
      }

      setState(() {
        _patientAppointments = rows;
        _webTabIndex = 4;
        _loadingConsultations = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingConsultations = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppointmentService.messageFromDio(e)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onWebTabSelected(int index) {
    if (index == 4) {
      _handleConsultaTabSelected();
      return;
    }
    setState(() => _webTabIndex = index);
  }

  String _appointmentStatusLabel(String status) {
    switch (status) {
      case 'scheduled':
        return 'Confirmada';
      case 'pending_patient_approval':
        return 'Pendiente del paciente';
      case 'pending_doctor_approval':
        return 'Pendiente del médico';
      case 'pending_doctor_proposal':
        return 'Propuesta pendiente';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  String _formatAppointmentWhen(AppointmentDto appt) {
    final dt = appt.appointmentDate?.toLocal();
    if (dt == null) return 'Sin fecha programada';
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${dt.year} · $hh:$min';
  }

  void _applyProfileSnapshot(PatientProfileSnapshot snap) {
    _analysisRequests = snap.analysisRequests;
    _timeline = snap.timeline;
    _questionnaireResponses = snap.questionnaireResponses;
    _questionnairePending = snap.questionnairePending;
    if (snap.clinicalContext != null) {
      _clinicalContext = snap.clinicalContext;
    }
  }

  Future<void> _reloadProfile({bool force = true}) async {
    if (force) {
      context.read<PatientsCacheProvider>().invalidateProfile(widget.patientId);
    }
    await _loadData(force: force);
  }

  Future<void> _loadData({bool force = false}) async {
    if (!mounted) return;

    final cache = context.read<PatientsCacheProvider>();
    if (!force) {
      final cached = cache.peekProfile(widget.patientId);
      if (cached != null) {
        setState(() {
          _applyProfileSnapshot(cached);
          _loading = false;
          _bootstrapping = false;
          _error = null;
        });
        return;
      }
    }

    setState(() {
      _bootstrapping = true;
      _error = null;
      if (_analysisRequests.isEmpty &&
          _timeline.isEmpty &&
          _clinicalContext == null) {
        _loading = false;
      }
    });
    try {
      final api = context.read<ApiClient>();
      final svc = DoctorService(api);
      final snap = await cache.fetchAndCacheProfile(
        patientId: widget.patientId,
        doctorSvc: svc,
        apiClient: api,
        force: force,
      );
      if (!mounted) return;
      setState(() {
        _applyProfileSnapshot(snap);
        _loading = false;
        _bootstrapping = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = DoctorService.messageFromDio(e);
        _loading = false;
        _bootstrapping = false;
      });
    }
  }

  void _handleTimelineEventTap(TimelineEvent event) {
    TimelineEventOpener.openTimelineEvent(
      context,
      patientId: widget.patientId,
      patientName: widget.patientName,
      event: event,
      onNoteSaved: () => _reloadProfile(),
    );
  }

  Future<void> _openSchedulingLink() async {
    await PatientSchedulingLinkDialog.show(
      context,
      patientId: widget.patientId,
      patientName: widget.patientName,
    );
  }

  Widget _buildSummaryHeader({
    required int pendingCount,
    required int completedCount,
    required bool wide,
  }) {
    final ctx = _clinicalContext;
    return DoctorPatientSummaryHeaderRow(
      name: ctx?.patientName ?? widget.patientName,
      email: ctx?.patientEmail ?? widget.patientEmail,
      sex: ctx?.sex,
      ageYears: ctx?.ageYears,
      bloodType: ctx?.bloodType,
      weightKg: ctx?.weightKg,
      totalAnalysis: _analysisRequests.length,
      uploadedAnalysis: completedCount,
      pendingAnalysis: pendingCount,
      timelineEvents: _timeline.length,
      onEditAge: () => _editClinicalAge(),
      onEditBloodType: () => _editClinicalBloodType(),
      onEditWeight: () => _editClinicalWeight(),
      onEditProfile: _openEditProfileDialog,
      onExport: _exportExpediente,
      exporting: _exportingExpediente,
      editingProfile: _editingProfile,
      wide: wide,
    );
  }

  Future<void> _persistClinicalProfile({
    int? ageYears,
    String? bloodType,
    double? weightKg,
  }) async {
    try {
      final updated = await DoctorService(context.read<ApiClient>())
          .upsertClinicalProfile(
        patientId: widget.patientId,
        ageYears: ageYears,
        bloodType: bloodType,
        weightKg: weightKg,
      );
      if (!mounted) return;
      setState(() => _clinicalContext = updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DoctorService.messageFromDio(e))),
      );
    }
  }

  Future<String?> _promptClinicalField({
    required String title,
    required String label,
    required String initial,
    required String hint,
  }) async {
    final ctrl = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: KeepiColors.orange),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  Future<void> _editClinicalAge() async {
    final raw = await _promptClinicalField(
      title: 'Edad',
      label: 'Años',
      initial: _clinicalContext?.ageYears?.toString() ?? '',
      hint: 'Ej. 35',
    );
    if (raw == null || !mounted) return;
    if (raw.isEmpty) {
      await _persistClinicalProfile(ageYears: null);
      return;
    }
    final age = int.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), ''));
    if (age == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Edad inválida')),
      );
      return;
    }
    await _persistClinicalProfile(ageYears: age);
  }

  Future<void> _editClinicalBloodType() async {
    final raw = await _promptClinicalField(
      title: 'Tipo de sangre',
      label: 'Grupo',
      initial: _clinicalContext?.bloodType ?? '',
      hint: 'Ej. O+',
    );
    if (raw == null || !mounted) return;
    await _persistClinicalProfile(bloodType: raw.isEmpty ? null : raw);
  }

  Future<void> _editClinicalWeight() async {
    final raw = await _promptClinicalField(
      title: 'Peso',
      label: 'Kilogramos',
      initial: _clinicalContext?.weightKg?.toString() ?? '',
      hint: 'Ej. 72.5',
    );
    if (raw == null || !mounted) return;
    if (raw.isEmpty) {
      await _persistClinicalProfile(weightKg: null);
      return;
    }
    final weight = double.tryParse(
      raw.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), ''),
    );
    if (weight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Peso inválido')),
      );
      return;
    }
    await _persistClinicalProfile(weightKg: weight);
  }

  Future<void> _openEditProfileDialog() async {
    if (_editingProfile || _exportingExpediente) return;

    final form = await showDoctorClinicalProfileEditor(
      context,
      initial: _clinicalContext,
      fallbackName: widget.patientName,
      fallbackEmail: widget.patientEmail,
    );
    if (form == null || !mounted) return;

    setState(() => _editingProfile = true);
    try {
      final updated = await saveClinicalProfileForm(
        api: context.read<ApiClient>(),
        patientId: widget.patientId,
        form: form,
      );
      if (updated == null || !mounted) return;
      setState(() => _clinicalContext = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil actualizado'),
          backgroundColor: KeepiColors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DoctorService.messageFromDio(e))),
      );
    } finally {
      if (mounted) setState(() => _editingProfile = false);
    }
  }

  Future<void> _exportExpediente() async {
    final doctorId = context.read<AuthProvider>().userId;
    if (doctorId == null || doctorId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesión no válida.')),
      );
      return;
    }

    setState(() => _exportingExpediente = true);
    try {
      await exportPatientExpedienteZip(
        context: context,
        api: context.read<ApiClient>(),
        doctorId: doctorId,
        patientId: widget.patientId,
        patientName: _clinicalContext?.patientName ?? widget.patientName,
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is DioException
          ? DoctorService.messageFromDio(e)
          : e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } finally {
      if (mounted) setState(() => _exportingExpediente = false);
    }
  }

  Widget _buildWebLayout({
    required List<AnalysisRequestDto> pendingList,
    required List<AnalysisRequestDto> completed,
    required List<_QuestionnaireGroup> questionnaireGroups,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 36),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSummaryHeader(
                  pendingCount: pendingList.length,
                  completedCount: completed.length,
                  wide: constraints.maxWidth >= 900,
                ),
                const SizedBox(height: 24),
                const _SectionTitle(tag: 'ACCIONES RÁPIDAS', count: 7),
                const SizedBox(height: 12),
                DoctorWebQuickActionsRow(
                  hasPendingUpload: pendingList.isNotEmpty,
                  onOpenTimeline: widget.onOpenTimeline,
                  onOpenRequestAnalysis: widget.onOpenRequestAnalysis,
                  onOpenUpload: pendingList.isNotEmpty
                      ? () => _openDoctorUploadPending(pendingList.first)
                      : null,
                  onOpenAssignPrescription: widget.onOpenAssignPrescription,
                  onOpenSchedule: widget.onOpenSchedule,
                  onOpenQuestionnaire: widget.onOpenQuestionnaire,
                  onGenerateSchedulingLink: _openSchedulingLink,
                ),
                const SizedBox(height: 26),
                DoctorPatientTabBar(
                  selectedIndex: _webTabIndex,
                  includeConsultationTab: !widget.embeddedTabPanelsOnly,
                  onSelected: _onWebTabSelected,
                ),
                const SizedBox(height: 22),
                _buildWebTabBody(
                  pendingList: pendingList,
                  completed: completed,
                  questionnaireGroups: questionnaireGroups,
                  tabIndex: _activeTabIndex,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWebTabBody({
    required List<AnalysisRequestDto> pendingList,
    required List<AnalysisRequestDto> completed,
    required List<_QuestionnaireGroup> questionnaireGroups,
    required int tabIndex,
  }) {
    if (_bootstrapping &&
        _analysisRequests.isEmpty &&
        _timeline.isEmpty &&
        _questionnaireResponses.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: CircularProgressIndicator(color: KeepiColors.orange),
        ),
      );
    }
    switch (tabIndex) {
      case 1:
        return _buildAnalysisPanel(
          pendingList: pendingList,
          completed: completed,
          sectionTag: 'ANÁLISIS',
        );
      case 2:
        return _buildQuestionnairePanel(questionnaireGroups);
      case 3:
        return _buildHistorialPanel();
      case 4:
        return _buildConsultaPanel();
      case 0:
      default:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildAnalysisPanel(
                pendingList: pendingList,
                completed: completed,
                sectionTag: 'TAREAS PENDIENTES',
                compact: true,
              ),
            ),
            const SizedBox(width: 22),
            Expanded(
              child: _buildTimelinePanel(compact: true),
            ),
          ],
        );
    }
  }

  Widget _buildAnalysisPanel({
    required List<AnalysisRequestDto> pendingList,
    required List<AnalysisRequestDto> completed,
    required String sectionTag,
    bool compact = false,
  }) {
    final limit = compact ? 6 : 12;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          tag: sectionTag,
          count: pendingList.length + completed.length,
        ),
        const SizedBox(height: 12),
        if (pendingList.isEmpty && completed.isEmpty)
          const _InlineEmpty(
            icon: Icons.biotech_outlined,
            message: 'Aún no hay análisis solicitados para este paciente.',
          )
        else ...[
          if (pendingList.isNotEmpty) ...[
            const _AnalysisSubsectionLabel(
              label: 'PENDIENTES DE SUBIR',
              hint:
                  'El paciente puede traer el reporte en físico; tú puedes subirlo aquí.',
            ),
            const SizedBox(height: 8),
            ...pendingList.take(limit).map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AnalysisCard(
                      item: r,
                      isPending: true,
                      onTap: () => _openDoctorUploadPending(r),
                    ),
                  ),
                ),
            if (pendingList.length > limit)
              _AnalysisListFootnote(
                text: 'Mostrando $limit de ${pendingList.length} pendientes.',
              ),
            const SizedBox(height: 14),
          ],
          if (completed.isNotEmpty) ...[
            if (pendingList.isNotEmpty)
              const _AnalysisSubsectionLabel(label: 'SUBIDOS / COMPLETADOS'),
            if (pendingList.isNotEmpty) const SizedBox(height: 8),
            ...completed.take(limit).map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AnalysisCard(
                      item: r,
                      isPending: false,
                      isOpening: _openingDocumentId == r.id,
                      onTap: () => _openAnalysisDocument(r),
                    ),
                  ),
                ),
            if (completed.length > limit)
              const _AnalysisListFootnote(
                text: 'Mostrando los completados más recientes.',
              ),
          ],
        ],
      ],
    );
  }

  Widget _buildTimelinePanel({bool compact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          tag: compact ? 'LÍNEA DE TIEMPO' : 'TIMELINE CLÍNICO',
          count: _timeline.length,
        ),
        const SizedBox(height: 12),
        if (_timeline.isEmpty)
          const _InlineEmpty(
            icon: Icons.timeline_rounded,
            message: 'Todavía no hay eventos clínicos en la línea de tiempo.',
          )
        else
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: KeepiColors.cardBorder),
            ),
            child: PatientCareTimeline(
              events: _timeline.take(compact ? 5 : 10).toList(),
              showSectionHeader: false,
              compact: compact,
              titleOnly: compact,
              onEventTap: _handleTimelineEventTap,
            ),
          ),
        if (compact) ...[
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: widget.onOpenTimeline,
            style: OutlinedButton.styleFrom(
              foregroundColor: KeepiColors.slate,
              side: const BorderSide(color: KeepiColors.cardBorder),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Ver historial completo',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _openAnswerQuestionnaire(Map<String, dynamic> pending) async {
    final invitationId = (pending['id'] ?? '').toString();
    if (invitationId.isEmpty) return;
    final name =
        (pending['questionnaire_name'] ?? 'Cuestionario').toString().trim();
    final answered = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DoctorAnswerQuestionnaireScreen(
          invitationId: invitationId,
          questionnaireName: name,
          patientName: widget.patientName,
        ),
      ),
    );
    if (answered == true && mounted) {
      await _reloadProfile(force: true);
    }
  }

  Widget _buildQuestionnairePanel(List<_QuestionnaireGroup> questionnaireGroups) {
    final hasPending = _questionnairePending.isNotEmpty;
    final hasResponses = _questionnaireResponses.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasPending) ...[
          _SectionTitle(
            tag: 'CUESTIONARIOS PENDIENTES',
            count: _questionnairePending.length,
          ),
          const SizedBox(height: 12),
          ..._questionnairePending.map(
            (pending) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PendingQuestionnaireCard(
                data: pending,
                onAnswer: () => _openAnswerQuestionnaire(pending),
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],
        _SectionTitle(
          tag: 'RESPUESTAS CUESTIONARIO',
          count: _questionnaireResponses.length,
        ),
        const SizedBox(height: 12),
        if (!hasResponses && !hasPending)
          const _InlineEmpty(
            icon: Icons.quiz_outlined,
            message:
                'Este paciente todavía no tiene respuestas de cuestionarios.',
          )
        else if (!hasResponses)
          const _InlineEmpty(
            icon: Icons.quiz_outlined,
            message: 'Aún no hay respuestas registradas.',
          )
        else ...[
          ...questionnaireGroups.take(8).toList().asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _QuestionnaireGroupCard(
                    index: entry.key,
                    group: entry.value,
                  ),
                ),
              ),
          if (questionnaireGroups.length > 8)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 6),
              child: Text(
                'Mostrando los 8 cuestionarios más recientes.',
                style: TextStyle(
                  color: KeepiColors.slateLight.withValues(alpha: 0.9),
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildHistorialPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTimelinePanel(compact: false),
        const SizedBox(height: 16),
        _ActionButton(
          icon: Icons.timeline_rounded,
          accent: KeepiColors.slate,
          title: 'Ver historial completo',
          subtitle: 'Abrir toda la línea de tiempo del paciente.',
          onTap: widget.onOpenTimeline,
        ),
      ],
    );
  }

  Widget _buildConsultaPanel() {
    if (_loadingConsultations) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: CircularProgressIndicator(color: KeepiColors.orange),
        ),
      );
    }

    if (_patientAppointments.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionTitle(tag: 'CONSULTAS', count: 0),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: KeepiColors.cardBorder),
            ),
            child: const Text(
              'Este paciente aún no tiene consultas registradas.',
              style: TextStyle(color: KeepiColors.slateLight, height: 1.45),
            ),
          ),
          const SizedBox(height: 16),
          _ActionButton(
            icon: Icons.event_available_rounded,
            accent: KeepiColors.orange,
            title: 'Programar cita',
            subtitle: 'Agenda una nueva consulta con este paciente.',
            onTap: widget.onOpenSchedule,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(tag: 'CONSULTAS', count: _patientAppointments.length),
        const SizedBox(height: 12),
        Text(
          'Elige la consulta que quieres abrir.',
          style: TextStyle(
            color: KeepiColors.slateLight.withValues(alpha: 0.95),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 14),
        ..._patientAppointments.map((appt) {
          final reason = appt.reason.trim().isEmpty ? 'Consulta médica' : appt.reason.trim();
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ActionButton(
              icon: Icons.medical_services_outlined,
              accent: KeepiColors.orange,
              title: _formatAppointmentWhen(appt),
              subtitle: '$reason · ${_appointmentStatusLabel(appt.status)}',
              onTap: () => _openConsultationForAppointment(appt),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildEmbeddedTabPanelsOnly() {
    if (_bootstrapping &&
        _analysisRequests.isEmpty &&
        _timeline.isEmpty &&
        _questionnaireResponses.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: CircularProgressIndicator(color: KeepiColors.orange),
        ),
      );
    }
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: CircularProgressIndicator(color: KeepiColors.orange),
        ),
      );
    }
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: () => _reloadProfile());
    }

    final completed = _analysisRequests
        .where((r) => r.status.toLowerCase() == 'completed')
        .toList()
      ..sort((a, b) => (b.completedAt ?? b.createdAt)
          .compareTo(a.completedAt ?? a.createdAt));
    final pendingList = _analysisRequests
        .where((r) => r.status.toLowerCase() != 'completed')
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final questionnaireGroups =
        _buildQuestionnaireGroups(_questionnaireResponses);

    return _buildWebTabBody(
      pendingList: pendingList,
      completed: completed,
      questionnaireGroups: questionnaireGroups,
      tabIndex: _activeTabIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.embeddedTabPanelsOnly) {
      return _buildEmbeddedTabPanelsOnly();
    }

    final completed = _analysisRequests
        .where((r) => r.status.toLowerCase() == 'completed')
        .toList()
      ..sort((a, b) => (b.completedAt ?? b.createdAt)
          .compareTo(a.completedAt ?? a.createdAt));
    final pendingList = _analysisRequests
        .where((r) => r.status.toLowerCase() != 'completed')
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final pendingCount = pendingList.length;
    final questionnaireGroups =
        _buildQuestionnaireGroups(_questionnaireResponses);

    final body = RefreshIndicator(
      color: KeepiColors.orange,
      onRefresh: () => _reloadProfile(),
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(color: KeepiColors.orange),
            )
          : _error != null &&
                  _analysisRequests.isEmpty &&
                  _timeline.isEmpty &&
                  _clinicalContext == null
              ? _ErrorState(message: _error!, onRetry: () => _reloadProfile())
              : isWebWide(context) || widget.embedded
                  ? _buildWebLayout(
                      pendingList: pendingList,
                      completed: completed,
                      questionnaireGroups: questionnaireGroups,
                    )
                  : ListView(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
                    children: [
                      _buildSummaryHeader(
                        pendingCount: pendingCount,
                        completedCount: completed.length,
                        wide: false,
                      ),
                      const SizedBox(height: 22),
                      _SectionTitle(
                        tag: 'ANÁLISIS',
                        count: pendingCount + completed.length,
                      ),
                      const SizedBox(height: 12),
                      if (pendingList.isEmpty && completed.isEmpty)
                        const _InlineEmpty(
                          icon: Icons.biotech_outlined,
                          message:
                              'Aún no hay análisis solicitados para este paciente.',
                        )
                      else ...[
                        if (pendingList.isNotEmpty) ...[
                          const _AnalysisSubsectionLabel(
                            label: 'PENDIENTES DE SUBIR',
                            hint:
                                'El paciente puede traer el reporte en físico; tú puedes subirlo aquí.',
                          ),
                          const SizedBox(height: 8),
                          ...pendingList.take(8).map(
                                (r) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _AnalysisCard(
                                    item: r,
                                    isPending: true,
                                    onTap: () => _openDoctorUploadPending(r),
                                  ),
                                ),
                              ),
                          if (pendingList.length > 8)
                            _AnalysisListFootnote(
                              text:
                                  'Mostrando 8 de ${pendingList.length} pendientes.',
                            ),
                          const SizedBox(height: 14),
                        ],
                        if (completed.isNotEmpty) ...[
                          if (pendingList.isNotEmpty)
                            const _AnalysisSubsectionLabel(
                              label: 'SUBIDOS / COMPLETADOS',
                            ),
                          if (pendingList.isNotEmpty) const SizedBox(height: 8),
                          ...completed.take(8).map(
                                (r) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _AnalysisCard(
                                    item: r,
                                    isPending: false,
                                    isOpening: _openingDocumentId == r.id,
                                    onTap: () => _openAnalysisDocument(r),
                                  ),
                                ),
                              ),
                          if (completed.length > 8)
                            _AnalysisListFootnote(
                              text:
                                  'Mostrando los 8 completados más recientes.',
                            ),
                        ],
                      ],
                      const SizedBox(height: 16),
                      _SectionTitle(
                        tag: 'TIMELINE CLÍNICO',
                        count: _timeline.length,
                      ),
                      const SizedBox(height: 12),
                      if (_timeline.isEmpty)
                        const _InlineEmpty(
                          icon: Icons.timeline_rounded,
                          message:
                              'Todavía no hay eventos clínicos en la línea de tiempo.',
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: KeepiColors.cardBorder),
                          ),
                          child: PatientCareTimeline(
                            events: _timeline.take(5).toList(),
                            showSectionHeader: false,
                            compact: true,
                            titleOnly: true,
                            onEventTap: _handleTimelineEventTap,
                          ),
                        ),
                      const SizedBox(height: 18),
                      if (_questionnairePending.isNotEmpty) ...[
                        _SectionTitle(
                          tag: 'CUESTIONARIOS PENDIENTES',
                          count: _questionnairePending.length,
                        ),
                        const SizedBox(height: 12),
                        ..._questionnairePending.map(
                          (pending) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _PendingQuestionnaireCard(
                              data: pending,
                              onAnswer: () => _openAnswerQuestionnaire(pending),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                      _SectionTitle(
                        tag: 'RESPUESTAS CUESTIONARIO',
                        count: _questionnaireResponses.length,
                      ),
                      const SizedBox(height: 12),
                      if (_questionnaireResponses.isEmpty &&
                          _questionnairePending.isEmpty)
                        const _InlineEmpty(
                          icon: Icons.quiz_outlined,
                          message:
                              'Este paciente todavía no tiene respuestas de cuestionarios.',
                        )
                      else if (_questionnaireResponses.isEmpty)
                        const _InlineEmpty(
                          icon: Icons.quiz_outlined,
                          message: 'Aún no hay respuestas registradas.',
                        )
                      else
                        ...questionnaireGroups
                            .take(6)
                            .toList()
                            .asMap()
                            .entries
                            .map(
                              (entry) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _QuestionnaireGroupCard(
                                  index: entry.key,
                                  group: entry.value,
                                ),
                              ),
                            ),
                      if (questionnaireGroups.length > 6)
                        Padding(
                          padding: const EdgeInsets.only(top: 2, bottom: 6),
                          child: Text(
                            'Mostrando los 6 cuestionarios más recientes.',
                            style: TextStyle(
                              color:
                                  KeepiColors.slateLight.withValues(alpha: 0.9),
                              fontSize: 12.5,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      const SizedBox(height: 18),
                      const _SectionTitle(tag: 'ACCIONES RÁPIDAS', count: 6),
                      const SizedBox(height: 12),
                      _ActionButton(
                        icon: Icons.timeline_rounded,
                        accent: KeepiColors.slate,
                        title: 'Ver historial completo',
                        subtitle: 'Abrir toda la línea de tiempo del paciente.',
                        onTap: widget.onOpenTimeline,
                      ),
                      const SizedBox(height: 10),
                      _ActionButton(
                        icon: Icons.biotech_outlined,
                        accent: KeepiColors.orange,
                        title: 'Solicitar análisis',
                        subtitle: 'Enviar nueva solicitud y link de subida.',
                        onTap: widget.onOpenRequestAnalysis,
                      ),
                      if (pendingList.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _ActionButton(
                          icon: Icons.upload_file_rounded,
                          accent: KeepiColors.orange,
                          title: 'Subir reporte en consultorio',
                          subtitle: pendingList.length == 1
                              ? 'Sube el análisis físico del paciente.'
                              : '${pendingList.length} solicitudes pendientes; abre la más reciente.',
                          onTap: () => _openDoctorUploadPending(pendingList.first),
                        ),
                      ],
                      const SizedBox(height: 10),
                      _ActionButton(
                        icon: Icons.medication_outlined,
                        accent: const Color(0xFF7C3AED),
                        title: 'Asignar receta',
                        subtitle: 'Emitir una prescripción nueva.',
                        onTap: widget.onOpenAssignPrescription,
                      ),
                      const SizedBox(height: 10),
                      _ActionButton(
                        icon: Icons.event_available_outlined,
                        accent: KeepiColors.skyBlue,
                        title: 'Programar cita',
                        subtitle: 'Definir fecha y hora de consulta.',
                        onTap: widget.onOpenSchedule,
                      ),
                      const SizedBox(height: 10),
                      _ActionButton(
                        icon: Icons.link_rounded,
                        accent: const Color(0xFF0284C7),
                        title: 'Link agenda web',
                        subtitle: 'Generar enlace para que el paciente agende en línea.',
                        onTap: _openSchedulingLink,
                      ),
                      const SizedBox(height: 10),
                      _ActionButton(
                        icon: Icons.outgoing_mail,
                        accent: KeepiColors.skyBlue,
                        title: 'Enviar ficha clínica',
                        subtitle: 'Compartir preguntas de seguimiento.',
                        onTap: widget.onOpenQuestionnaire,
                      ),
                    ],
                  ),
    );

    if (widget.embedded) {
      return EmbeddedWebPage(
        title: 'Perfil del paciente',
        onBack: widget.onBack,
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: KeepiColors.surfaceBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Perfil del paciente',
          style: TextStyle(
            color: KeepiColors.slate,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: body,
    );
  }

  Future<void> _openDoctorUploadPending(AnalysisRequestDto item) async {
    final ok = await context.push<bool>(
      AppPaths.doctorUploadAnalysis(
        widget.patientId,
        item.id,
        description: item.description,
      ),
    );
    if (ok == true && mounted) await _reloadProfile();
  }

  Future<void> _openAnalysisDocument(AnalysisRequestDto item) async {
    final documentId = item.documentId?.trim();
    if (documentId == null || documentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este análisis no tiene documento vinculado aún.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _openingDocumentId = item.id);
    try {
      final api = context.read<ApiClient>();
      final svc = DoctorService(api);
      final url = svc.getMobileDocumentUrl(documentId);
      final token = api.accessToken;
      final headers = <String, String>{
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        'Accept': '*/*',
      };
      if (!mounted) return;
      await AppNavigation.pushDocumentViewer(
        context,
        url: url,
        title: 'Archivo de análisis',
        headers: headers,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'No se pudo abrir el archivo: ${DoctorService.messageFromDio(e)}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _openingDocumentId = null);
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.tag, required this.count});

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
        const SizedBox(width: 8),
        Text(
          tag,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.7,
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
            count.toString().padLeft(2, '0'),
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: KeepiColors.slate,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            color: KeepiColors.slate.withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }
}

class _AnalysisSubsectionLabel extends StatelessWidget {
  const _AnalysisSubsectionLabel({
    required this.label,
    this.hint,
  });

  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: KeepiColors.slateLight,
          ),
        ),
        if (hint != null && hint!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            hint!,
            style: TextStyle(
              fontSize: 12,
              color: KeepiColors.slateLight.withValues(alpha: 0.95),
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

class _AnalysisListFootnote extends StatelessWidget {
  const _AnalysisListFootnote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          color: KeepiColors.slateLight.withValues(alpha: 0.9),
          fontSize: 12.5,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  const _AnalysisCard({
    required this.item,
    required this.onTap,
    this.isPending = false,
    this.isOpening = false,
  });

  final AnalysisRequestDto item;
  final VoidCallback onTap;
  final bool isPending;
  final bool isOpening;

  @override
  Widget build(BuildContext context) {
    final completedAt = item.completedAt?.trim();
    final accent = isPending ? KeepiColors.orange : KeepiColors.skyBlue;
    final accentSoft =
        isPending ? KeepiColors.orangeSoft : KeepiColors.skyBlueSoft;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPending
                ? KeepiColors.orange.withValues(alpha: 0.35)
                : KeepiColors.cardBorder,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accentSoft,
                shape: BoxShape.circle,
                border: Border.all(color: accent, width: 1.4),
              ),
              child: Icon(
                isPending
                    ? Icons.upload_file_rounded
                    : Icons.biotech_outlined,
                size: 18,
                color: accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPending ? 'PENDIENTE DE SUBIR' : 'ANÁLISIS COMPLETADO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.3,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: KeepiColors.slate,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    isPending
                        ? 'Solicitado: ${item.createdAt.isNotEmpty ? item.createdAt : '—'} · Toca para subir el reporte físico'
                        : completedAt == null || completedAt.isEmpty
                            ? 'Fecha de cierre no disponible'
                            : 'Completado: $completedAt',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: KeepiColors.slateLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            isOpening
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: KeepiColors.orange,
                    ),
                  )
                : Icon(
                    isPending
                        ? Icons.chevron_right_rounded
                        : Icons.open_in_new_rounded,
                    size: 18,
                    color: KeepiColors.slateLight,
                  ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
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
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: accent, width: 1.5),
              ),
              child: Icon(icon, color: accent, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14.3,
                      fontWeight: FontWeight.w800,
                      color: KeepiColors.slate,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12.4,
                      color: KeepiColors.slateLight,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded,
                size: 18, color: KeepiColors.slate),
          ],
        ),
      ),
    );
  }
}

class _QuestionnaireGroupCard extends StatelessWidget {
  const _QuestionnaireGroupCard({
    required this.index,
    required this.group,
  });

  final int index;
  final _QuestionnaireGroup group;

  String get _title => group.displayName(index);

  bool get _answeredByDoctor => group.answeredBy == 'doctor';

  Color get _accentColor =>
      _answeredByDoctor ? KeepiColors.skyBlue : KeepiColors.orange;

  String get _answeredLabel {
    final at = _formatAnchor(group.anchor);
    if (_answeredByDoctor) {
      return at.isEmpty ? 'Contestado por ti' : 'Contestado por ti: $at';
    }
    return at.isEmpty ? 'Respondido por el paciente' : 'Respondido: $at';
  }

  void _openResponsesModal(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          _title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: KeepiColors.slate,
            fontSize: 17,
          ),
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_formatAnchor(group.anchor).isNotEmpty ||
                    group.answeredBy.isNotEmpty) ...[
                  Text(
                    _answeredLabel,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: _answeredByDoctor
                          ? KeepiColors.skyBlue
                          : KeepiColors.slateLight,
                      fontWeight: _answeredByDoctor
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                ...group.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _QuestionAnswerRow(data: item),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _answeredByDoctor
              ? KeepiColors.skyBlue.withValues(alpha: 0.45)
              : KeepiColors.cardBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: _accentColor, width: 1.4),
            ),
            child: Icon(
              _answeredByDoctor
                  ? Icons.medical_services_outlined
                  : Icons.quiz_outlined,
              size: 18,
              color: _accentColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: KeepiColors.slate,
                    height: 1.25,
                  ),
                ),
                if (group.anchor != null || group.answeredBy.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _answeredLabel,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: _answeredByDoctor
                          ? KeepiColors.skyBlue
                          : KeepiColors.slateLight,
                      fontWeight: _answeredByDoctor
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: () => _openResponsesModal(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: _accentColor,
              side: BorderSide(color: _accentColor),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Ver respuestas',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatAnchor(DateTime? date) {
    if (date == null) return '';
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year;
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $h:$min';
  }
}

class _QuestionAnswerRow extends StatelessWidget {
  const _QuestionAnswerRow({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final question = (data['question_text'] ?? 'Pregunta').toString();
    
    String answer = (data['answer_value'] ?? 'Sin respuesta').toString();
    if (answer.contains('value:')) {
      answer = answer.replaceAll(RegExp(r'[{}]'), '').replaceAll('value:', '').trim();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: KeepiColors.surfaceBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: KeepiColors.slate,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            answer,
            style: const TextStyle(
              fontSize: 12.5,
              color: KeepiColors.slateLight,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingQuestionnaireCard extends StatelessWidget {
  const _PendingQuestionnaireCard({
    required this.data,
    required this.onAnswer,
  });

  final Map<String, dynamic> data;
  final VoidCallback onAnswer;

  @override
  Widget build(BuildContext context) {
    final name = (data['questionnaire_name'] ?? 'Cuestionario').toString();
    final total = data['total_questions'] as int? ?? 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: KeepiColors.orangeSoft.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: KeepiColors.orange.withValues(alpha: 0.55),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: KeepiColors.orange, width: 1.4),
            ),
            child: const Icon(
              Icons.pending_actions_rounded,
              size: 18,
              color: KeepiColors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: KeepiColors.slate,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  total > 0
                      ? 'Pendiente · $total preguntas'
                      : 'Pendiente de contestar',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: KeepiColors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onAnswer,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            child: const Text(
              'Contestar',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionnaireGroup {
  _QuestionnaireGroup({
    this.invitationId,
    required this.anchor,
    required this.items,
    this.answeredBy = '',
  });

  final String? invitationId;
  DateTime? anchor;
  final List<Map<String, dynamic>> items;
  final String answeredBy;

  String displayName(int fallbackIndex) {
    for (final item in items) {
      final name = (item['questionnaire_name'] ?? '').toString().trim();
      if (name.isNotEmpty) return name;
    }
    return 'Cuestionario ${fallbackIndex + 1}';
  }
}

class _ResponseRow {
  _ResponseRow({
    required this.data,
    required this.answeredAt,
  });

  final Map<String, dynamic> data;
  final DateTime? answeredAt;
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: KeepiColors.slateLight),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13.3,
                color: KeepiColors.slateLight,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 140),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: KeepiColors.orange.withValues(alpha: 0.35)),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: KeepiColors.orange,
                  size: 32,
                ),
                const SizedBox(height: 10),
                const Text(
                  'NO PUDIMOS CARGAR EL PERFIL',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: KeepiColors.orange,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: KeepiColors.slate,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KeepiColors.orange,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
