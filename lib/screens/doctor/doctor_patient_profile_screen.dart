import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../core/doctor_web_shell_scope.dart';
import '../../core/web_layout.dart';
import '../../models/timeline_event.dart';
import '../../services/api_client.dart';
import '../../services/doctor_service.dart';
import '../../services/timeline_event_opener.dart';
import '../../services/questionnaire_service.dart';
import '../../widgets/doctor_patient_web_blocks.dart';
import '../../widgets/timeline_event_detail_sheet.dart';
import '../../widgets/patient_care_timeline.dart';
import 'analysis_document_viewer_screen.dart';
import 'doctor_upload_analysis_for_patient_screen.dart';

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
  String? _error;

  List<AnalysisRequestDto> _analysisRequests = [];
  List<TimelineEvent> _timeline = [];
  List<Map<String, dynamic>> _questionnaireResponses = [];
  String? _openingDocumentId;
  late int _webTabIndex;

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
      final current = groups.isEmpty ? null : groups.last;
      if (current == null ||
          row.answeredAt == null ||
          current.anchor == null ||
          current.anchor!.difference(row.answeredAt!).abs() >
              const Duration(minutes: 12)) {
        groups.add(
          _QuestionnaireGroup(
            anchor: row.answeredAt,
            items: [row.data],
          ),
        );
      } else {
        current.items.add(row.data);
      }
    }
    return groups;
  }

  @override
  void initState() {
    super.initState();
    if (!widget.embeddedTabPanelsOnly) {
      _webTabIndex = widget.initialTabIndex.clamp(0, 3);
    }
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = DoctorService(context.read<ApiClient>());
      final questionnaireSvc = QuestionnaireService(context.read<ApiClient>());
      final analysisFuture = svc.fetchPatientAnalysisRequests(widget.patientId);
      final timelineFuture = svc.fetchPatientTimeline(widget.patientId);
      final responsesFuture =
          questionnaireSvc.fetchPatientResponses(widget.patientId);
      final analysis = await analysisFuture;
      final timeline = await timelineFuture;
      final responsesRaw = await responsesFuture;
      if (!mounted) return;
      setState(() {
        _analysisRequests = analysis;
        _timeline = timeline;
        _questionnaireResponses = responsesRaw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = DoctorService.messageFromDio(e);
        _loading = false;
      });
    }
  }

  void _handleTimelineEventTap(TimelineEvent event) {
    TimelineEventOpener.openTimelineEvent(
      context,
      patientId: widget.patientId,
      patientName: widget.patientName,
      event: event,
      onNoteSaved: _loadData,
    );
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: _PatientHeaderCard(
                        name: widget.patientName,
                        email: widget.patientEmail,
                        mustChangePassword: widget.mustChangePassword,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      flex: 6,
                      child: _PatientStats(
                        totalAnalysis: _analysisRequests.length,
                        uploadedAnalysis: completed.length,
                        pendingAnalysis: pendingList.length,
                        timelineEvents: _timeline.length,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const _SectionTitle(tag: 'ACCIONES RÁPIDAS', count: 6),
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
                ),
                const SizedBox(height: 26),
                DoctorPatientTabBar(
                  selectedIndex: _webTabIndex,
                  onSelected: (index) =>
                      setState(() => _webTabIndex = index),
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
              events: _timeline.take(compact ? 6 : 10).toList(),
              showSectionHeader: false,
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

  Widget _buildQuestionnairePanel(List<_QuestionnaireGroup> questionnaireGroups) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          tag: 'RESPUESTAS CUESTIONARIO',
          count: _questionnaireResponses.length,
        ),
        const SizedBox(height: 12),
        if (_questionnaireResponses.isEmpty)
          const _InlineEmpty(
            icon: Icons.quiz_outlined,
            message:
                'Este paciente todavía no tiene respuestas de cuestionarios.',
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

  Widget _buildEmbeddedTabPanelsOnly() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: CircularProgressIndicator(color: KeepiColors.orange),
        ),
      );
    }
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _loadData);
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
      onRefresh: _loadData,
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(color: KeepiColors.orange),
            )
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _loadData)
              : isWebWide(context) || widget.embedded
                  ? _buildWebLayout(
                      pendingList: pendingList,
                      completed: completed,
                      questionnaireGroups: questionnaireGroups,
                    )
                  : ListView(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
                    children: [
                      _PatientHeaderCard(
                        name: widget.patientName,
                        email: widget.patientEmail,
                        mustChangePassword: widget.mustChangePassword,
                      ),
                      const SizedBox(height: 14),
                      _PatientStats(
                        totalAnalysis: _analysisRequests.length,
                        uploadedAnalysis: completed.length,
                        pendingAnalysis: pendingCount,
                        timelineEvents: _timeline.length,
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
                            events: _timeline.take(6).toList(),
                            showSectionHeader: false,
                            onEventTap: _handleTimelineEventTap,
                          ),
                        ),
                      const SizedBox(height: 18),
                      _SectionTitle(
                        tag: 'RESPUESTAS CUESTIONARIO',
                        count: _questionnaireResponses.length,
                      ),
                      const SizedBox(height: 12),
                      if (_questionnaireResponses.isEmpty)
                        const _InlineEmpty(
                          icon: Icons.quiz_outlined,
                          message:
                              'Este paciente todavía no tiene respuestas de cuestionarios.',
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
                      const _SectionTitle(tag: 'ACCIONES RÁPIDAS', count: 5),
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
                        icon: Icons.outgoing_mail,
                        accent: KeepiColors.skyBlue,
                        title: 'Enviar cuestionario',
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

  void _showEventDetail(BuildContext context, TimelineEvent event) {
    TimelineEventDetailSheet.show(
      context,
      patientId: widget.patientId,
      event: event,
      onNoteSaved: _loadData,
    );
  }


  Future<void> _openDoctorUploadPending(AnalysisRequestDto item) async {
    final webNav = DoctorWebShellScope.maybeOf(context);
    if (webNav != null && (widget.embedded || isWebWide(context))) {
      webNav.push(
        DoctorWebRoute(
          kind: DoctorWebOverlayKind.uploadAnalysis,
          uploadRequestId: item.id,
          uploadDescription: item.description,
          patient: PatientListItem(
            id: widget.patientId,
            email: widget.patientEmail,
            name: widget.patientName,
            mustChangePassword: widget.mustChangePassword,
          ),
        ),
      );
      return;
    }

    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DoctorUploadAnalysisForPatientScreen(
          requestId: item.id,
          description: item.description,
          patientName: widget.patientName,
        ),
      ),
    );
    if (ok == true && mounted) await _loadData();
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
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AnalysisDocumentViewerScreen(
            url: url,
            title: 'Archivo de análisis',
            headers: headers,
          ),
        ),
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

class _PatientHeaderCard extends StatelessWidget {
  const _PatientHeaderCard({
    required this.name,
    required this.email,
    required this.mustChangePassword,
  });

  final String name;
  final String email;
  final bool mustChangePassword;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: KeepiColors.skyBlueSoft,
              shape: BoxShape.circle,
              border: Border.all(color: KeepiColors.skyBlue, width: 1.8),
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                color: KeepiColors.skyBlue,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PACIENTE',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: KeepiColors.skyBlue,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: KeepiColors.slate,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.8,
                    color: KeepiColors.slateLight,
                  ),
                ),
              ],
            ),
          ),
          if (mustChangePassword)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: KeepiColors.orangeSoft,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: KeepiColors.orange.withValues(alpha: 0.5)),
              ),
              child: const Text(
                'PRIMER ACCESO',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: KeepiColors.orange,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PatientStats extends StatelessWidget {
  const _PatientStats({
    required this.totalAnalysis,
    required this.uploadedAnalysis,
    required this.pendingAnalysis,
    required this.timelineEvents,
  });

  final int totalAnalysis;
  final int uploadedAnalysis;
  final int pendingAnalysis;
  final int timelineEvents;

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
            _StatCell(value: totalAnalysis, label: 'SOLICITADOS'),
            const _VLine(),
            _StatCell(value: uploadedAnalysis, label: 'SUBIDOS', accent: true),
            const _VLine(),
            _StatCell(value: pendingAnalysis, label: 'PENDIENTES'),
            const _VLine(),
            _StatCell(value: timelineEvents, label: 'EVENTOS'),
          ],
        ),
      ),
    );
  }
}

class _VLine extends StatelessWidget {
  const _VLine();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, color: KeepiColors.cardBorder);
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.value,
    required this.label,
    this.accent = false,
  });

  final int value;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ? KeepiColors.orange : KeepiColors.slate;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(
              value.toString().padLeft(2, '0'),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1,
                letterSpacing: -0.8,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 9.2,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: KeepiColors.slateLight,
              ),
            ),
          ],
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final answeredAt = _formatAnchor(group.anchor);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: KeepiColors.orangeSoft,
              shape: BoxShape.circle,
              border: Border.all(color: KeepiColors.orange, width: 1.4),
            ),
            child: const Icon(
              Icons.quiz_outlined,
              size: 18,
              color: KeepiColors.orange,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CUESTIONARIO ${index + 1}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                    color: KeepiColors.orange,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${group.items.length} respuestas registradas',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: KeepiColors.slate,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 5),
                if (answeredAt.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    'Respondido: $answeredAt',
                    style: const TextStyle(
                      fontSize: 12.2,
                      color: KeepiColors.slateLight,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                ...group.items.take(4).toList().asMap().entries.map(
                      (entry) => Padding(
                        padding: EdgeInsets.only(
                          bottom: entry.key == group.items.take(4).length - 1
                              ? 0
                              : 8,
                        ),
                        child: _QuestionAnswerRow(data: entry.value),
                      ),
                    ),
                if (group.items.length > 4) ...[
                  const SizedBox(height: 8),
                  Text(
                    '+ ${group.items.length - 4} respuestas más',
                    style: const TextStyle(
                      fontSize: 12,
                      color: KeepiColors.slateLight,
                      fontStyle: FontStyle.italic,
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
    
    // --- LÓGICA DE LIMPIEZA AGREGADA AQUÍ ---
    String answer = (data['answer_value'] ?? 'Sin respuesta').toString();
    if (answer.contains('value:')) {
      answer = answer.replaceAll(RegExp(r'[{}]'), '').replaceAll('value:', '').trim();
    }
    // ----------------------------------------

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

class _QuestionnaireGroup {
  _QuestionnaireGroup({
    required this.anchor,
    required this.items,
  });

  final DateTime? anchor;
  final List<Map<String, dynamic>> items;
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
