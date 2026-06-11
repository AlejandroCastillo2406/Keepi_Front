import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/app_theme.dart';
import '../../core/doctor_web_shell_scope.dart';
import '../../core/web_layout.dart';
import '../../models/consultation_context.dart';
import '../../models/timeline_event.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../services/appointment_service.dart';
import '../../services/doctor_service.dart';
import '../../services/speech_dictation_service.dart';
import '../../services/timeline_event_opener.dart';
import '../../utils/consultation_note_codec.dart';
import '../../utils/patient_expediente_export.dart';
import '../../utils/timeline_event_resolver.dart';
import '../../widgets/doctor_patient_web_blocks.dart';
import '../../widgets/profile_settings_widgets.dart';
import 'doctor_patient_profile_screen.dart';
import 'doctor_patient_timeline_screen.dart';
import 'doctor_upload_analysis_for_patient_screen.dart';

class DoctorConsultationScreen extends StatefulWidget {
  const DoctorConsultationScreen({
    super.key,
    required this.appointment,
    required this.patientName,
    this.patientEmail,
    this.embedded = false,
    this.onBack,
    this.onSaved,
    this.onOpenTimeline,
    this.onOpenRequestAnalysis,
    this.onOpenAssignPrescription,
    this.onOpenSchedule,
    this.onOpenQuestionnaire,
    this.onTabSelected,
  });

  final AppointmentDto appointment;
  final String patientName;
  final String? patientEmail;
  final bool embedded;
  final VoidCallback? onBack;
  final VoidCallback? onSaved;
  final VoidCallback? onOpenTimeline;
  final VoidCallback? onOpenRequestAnalysis;
  final VoidCallback? onOpenAssignPrescription;
  final VoidCallback? onOpenSchedule;
  final VoidCallback? onOpenQuestionnaire;
  final ValueChanged<int>? onTabSelected;

  @override
  State<DoctorConsultationScreen> createState() =>
      _DoctorConsultationScreenState();
}

class _DoctorConsultationScreenState extends State<DoctorConsultationScreen> {
  bool _loading = true;
  bool _saving = false;
  bool _exportingExpediente = false;
  String? _error;
  TimelineEvent? _event;
  ConsultationVitals _vitals = const ConsultationVitals();
  List<TimelineEvent> _timeline = [];
  List<AnalysisRequestDto> _analysisRequests = [];
  ConsultationContext? _context;
  late final TextEditingController _notesCtrl;
  int _tabIndex = 4;
  final SpeechDictationService _dictation = SpeechDictationService();
  String _dictationPrefix = '';
  bool _isDictating = false;
  bool _dictationHeardThisSession = false;

  @override
  void initState() {
    super.initState();
    _notesCtrl = TextEditingController();
    _bootstrap();
  }

  @override
  void dispose() {
    _dictation.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _warnNoSpeechDetected() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'No se detectó voz. Verifica el micrófono e inténtalo de nuevo.',
        ),
        backgroundColor: Colors.orange.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _finishDictationSession({bool forceNoSpeechCheck = false}) {
    if (!_isDictating) return;

    final heard = _dictationHeardThisSession ||
        _notesCtrl.text.trim().length > _dictationPrefix.trim().length;
    setState(() => _isDictating = false);
    if (forceNoSpeechCheck && !heard) {
      _warnNoSpeechDetected();
    }
  }

  void _applyDictationText(String text) {
    if (text.trim().isNotEmpty) {
      _dictationHeardThisSession = true;
    }
    final combined = '$_dictationPrefix$text';
    if (_notesCtrl.text == combined) return;
    _notesCtrl.value = TextEditingValue(
      text: combined,
      selection: TextSelection.collapsed(offset: combined.length),
    );
  }

  Future<void> _toggleDictation() async {
    if (_isDictating || _dictation.isListening) {
      await _dictation.stop();
      if (!mounted) return;
      _finishDictationSession(forceNoSpeechCheck: true);
      return;
    }

    _dictationHeardThisSession = false;
    _dictationPrefix = _notesCtrl.text.trimRight();
    if (_dictationPrefix.isNotEmpty) {
      _dictationPrefix = '$_dictationPrefix ';
    }

    final error = await _dictation.start(
      onTranscript: (text, {required isFinal}) {
        if (!mounted) return;
        _applyDictationText(text);
      },
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'doneNoResult') {
          _finishDictationSession(forceNoSpeechCheck: true);
          return;
        }
        if (status == SpeechToText.notListeningStatus ||
            status == SpeechToText.doneStatus) {
          _finishDictationSession(forceNoSpeechCheck: true);
        }
      },
      onError: (message) {
        if (!mounted) return;
        final noMatch = message.toLowerCase().contains('no_match') ||
            message.toLowerCase().contains('no match');
        _finishDictationSession(forceNoSpeechCheck: noMatch);
        if (noMatch) {
          _warnNoSpeechDetected();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      },
    );

    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    setState(() => _isDictating = true);
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiClient>();
      final doctorSvc = DoctorService(api);
      final event = await TimelineEventResolver.resolveForAppointment(
        doctorService: doctorSvc,
        appointment: widget.appointment,
      );
      final timelineFuture = doctorSvc.fetchPatientTimeline(
        widget.appointment.patientId,
      );
      final consultationContextFuture = doctorSvc.fetchConsultationContext(
        widget.appointment.patientId,
      );
      final analysisFuture = doctorSvc.fetchPatientAnalysisRequests(
        widget.appointment.patientId,
      );
      final timeline = await timelineFuture;
      final consultationContext = await consultationContextFuture;
      final analysis = await analysisFuture;
      if (!mounted) return;

      var vitals = const ConsultationVitals();
      try {
        final data = await doctorSvc.fetchTimelineDoctorNote(
          patientId: widget.appointment.patientId,
          eventId: event.id,
        );
        final decoded = ConsultationNoteCodec.decode(
          (data['content'] as String?) ?? '',
        );
        _notesCtrl.text = decoded.clinicalNote;
        vitals = decoded.vitals;
      } on DioException catch (e) {
        if (e.response?.statusCode != 404) rethrow;
      }

      final intakeAllergies = (consultationContext.allergies ?? '').trim();
      if (vitals.allergies.isEmpty && intakeAllergies.isNotEmpty) {
        vitals = vitals.copyWith(allergies: intakeAllergies);
      }

      setState(() {
        _event = event;
        _context = consultationContext;
        _analysisRequests = analysis;
        _vitals = vitals;
        _timeline = timeline
            .where((e) => e.eventType.toLowerCase() != 'analysis_upload')
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

  void _handleBack() {
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }
    Navigator.of(context).maybePop();
  }

  void _openFullTimeline() {
    if (widget.onOpenTimeline != null) {
      widget.onOpenTimeline!();
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DoctorPatientTimelineScreen(
          patientId: widget.appointment.patientId,
          patientName: widget.patientName,
        ),
      ),
    );
  }

  List<AnalysisRequestDto> get _pendingAnalysis => _analysisRequests
      .where((r) => r.status == 'pending' && (r.documentId ?? '').isEmpty)
      .toList();

  Future<void> _openDoctorUploadPending(AnalysisRequestDto item) async {
    final webNav = DoctorWebShellScope.maybeOf(context);
    if (webNav != null && widget.embedded) {
      webNav.push(
        DoctorWebRoute(
          kind: DoctorWebOverlayKind.uploadAnalysis,
          uploadRequestId: item.id,
          uploadDescription: item.description,
          patient: PatientListItem(
            id: widget.appointment.patientId,
            email: widget.patientEmail ?? '',
            name: widget.patientName,
            mustChangePassword: false,
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
    if (ok == true && mounted) await _bootstrap();
  }

  Future<void> _openEditProfileDialog() async {
    final ctx = _context;
    final nameCtrl = TextEditingController(
      text: ctx?.patientName ?? widget.patientName,
    );
    final emailCtrl = TextEditingController(
      text: ctx?.patientEmail ?? widget.patientEmail ?? '',
    );
    final phoneCtrl = TextEditingController(text: ctx?.phone ?? '');
    final ageCtrl = TextEditingController(text: ctx?.ageYears?.toString() ?? '');
    final bloodCtrl = TextEditingController(text: ctx?.bloodType ?? '');
    final weightCtrl = TextEditingController(text: ctx?.weightKg?.toString() ?? '');
    final allergiesCtrl = TextEditingController(text: ctx?.allergies ?? '');
    var selectedSex = (ctx?.sex ?? '').trim();
    if (selectedSex.isEmpty) selectedSex = 'Masculino';

    const sexOptions = [
      'Femenino',
      'Masculino',
      'Otro',
      'Prefiero no decir',
    ];

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Editar perfil',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: sexOptions.contains(selectedSex) ? selectedSex : 'Masculino',
                    decoration: const InputDecoration(
                      labelText: 'Sexo',
                      border: OutlineInputBorder(),
                    ),
                    items: sexOptions
                        .map(
                          (option) => DropdownMenuItem(
                            value: option,
                            child: Text(option),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selectedSex = value);
                    },
                  ),
                  const SizedBox(height: 18),
                  const Divider(),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ageCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Edad (años)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bloodCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de sangre',
                      hintText: 'Ej. O+',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: weightCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Peso (kg)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: allergiesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Alergias',
                      hintText: 'Ej. Penicilina',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              style: FilledButton.styleFrom(backgroundColor: KeepiColors.skyBlue),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) {
      nameCtrl.dispose();
      emailCtrl.dispose();
      phoneCtrl.dispose();
      ageCtrl.dispose();
      bloodCtrl.dispose();
      weightCtrl.dispose();
      allergiesCtrl.dispose();
      return;
    }

    final name = nameCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    final ageRaw = ageCtrl.text.trim();
    final weightRaw = weightCtrl.text.trim();
    final bloodType = bloodCtrl.text.trim();
    final allergiesText = allergiesCtrl.text.trim();
    nameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    ageCtrl.dispose();
    bloodCtrl.dispose();
    weightCtrl.dispose();
    allergiesCtrl.dispose();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre es obligatorio')),
      );
      return;
    }
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El correo es obligatorio')),
      );
      return;
    }

    int? ageYears;
    double? weightKg;
    if (ageRaw.isNotEmpty) {
      ageYears = int.tryParse(ageRaw.replaceAll(RegExp(r'[^0-9]'), ''));
      if (ageYears == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Edad inválida')),
        );
        return;
      }
    }
    if (weightRaw.isNotEmpty) {
      weightKg = double.tryParse(
        weightRaw.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), ''),
      );
      if (weightKg == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Peso inválido')),
        );
        return;
      }
    }

    try {
      final doctorSvc = DoctorService(context.read<ApiClient>());
      final updated = await doctorSvc.upsertClinicalProfile(
        patientId: widget.appointment.patientId,
        name: name,
        email: email,
        phone: phone.isEmpty ? null : phone,
        sex: selectedSex,
        ageYears: ageYears,
        bloodType: bloodType.isEmpty ? null : bloodType,
        weightKg: weightKg,
        allergies: allergiesText.isEmpty ? null : allergiesText,
      );
      if (!mounted) return;
      final allergies = (updated.allergies ?? '').trim();
      setState(() {
        _context = updated;
        if (allergies.isNotEmpty && _vitals.allergies.isEmpty) {
          _vitals = _vitals.copyWith(allergies: allergies);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil actualizado'),
          backgroundColor: KeepiColors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(DoctorService.messageFromDio(e)),
          backgroundColor: Colors.red,
        ),
      );
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
        patientId: widget.appointment.patientId,
        patientName: widget.patientName,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } finally {
      if (mounted) setState(() => _exportingExpediente = false);
    }
  }

  Widget _buildPatientSummaryHeader({
    required ConsultationContext? ctx,
    required ConsultationStats stats,
    required bool wide,
  }) {
    final header = ConsultationPatientHeader(
      name: ctx?.patientName ?? widget.patientName,
      email: ctx?.patientEmail ?? widget.patientEmail ?? '',
      sex: ctx?.sex,
      subtitle: _whenLabel(),
      ageYears: ctx?.ageYears,
      bloodType: ctx?.bloodType,
      weightKg: ctx?.weightKg,
      onEditProfile: _openEditProfileDialog,
      onExport: _exportExpediente,
      exporting: _exportingExpediente,
    );
    final statsGrid = DoctorPatientStatsGrid(
      totalAnalysis: stats.analysisRequested,
      uploadedAnalysis: stats.analysisUploaded,
      pendingAnalysis: stats.analysisPending,
      timelineEvents: stats.timelineEvents,
    );

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 5, child: header),
          const SizedBox(width: 18),
          Expanded(flex: 4, child: statsGrid),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        const SizedBox(height: 14),
        statsGrid,
      ],
    );
  }

  Future<String?> _editVital({
    required String title,
    required String label,
    required String initial,
    required String hint,
    required ValueChanged<String> onSave,
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
    if (result == null || !mounted) return null;
    setState(() => onSave(result));
    return result;
  }

  Future<void> _finishConsultation() async {
    final clinical = _notesCtrl.text.trim();
    if (clinical.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escribe las notas clínicas de la consulta.'),
        ),
      );
      return;
    }
    final event = _event;
    if (event == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final payload = ConsultationNoteCodec.encode(
        clinicalNote: clinical,
        vitals: _vitals,
      );
      await DoctorService(context.read<ApiClient>()).upsertTimelineDoctorNote(
        patientId: widget.appointment.patientId,
        eventId: event.id,
        eventType: event.eventType,
        doctorNote: payload,
      );
      if (!mounted) return;
      widget.onSaved?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Consulta guardada'),
          backgroundColor: KeepiColors.green,
        ),
      );
      _handleBack();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = DoctorService.messageFromDio(e);
      });
    }
  }

  String _whenLabel() {
    final dt = widget.appointment.appointmentDate?.toLocal();
    if (dt == null) return 'Sin fecha';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} · $h:$m';
  }

  Widget _vitalCell({
    required String label,
    required String value,
    required String unit,
    required String hint,
    required bool alertStyle,
    required bool showDivider,
    required VoidCallback onEdit,
  }) {
    final empty = value.isEmpty;
    final display = empty ? '—' : (unit.isEmpty ? value : '$value $unit');

    return Expanded(
      child: InkWell(
        onTap: onEdit,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            border: showDivider
                ? const Border(
                    left: BorderSide(color: KeepiColors.cardBorder),
                  )
                : null,
            color: alertStyle && !empty
                ? Colors.red.shade50.withValues(alpha: 0.65)
                : Colors.transparent,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: alertStyle && !empty
                      ? Colors.red.shade700
                      : KeepiColors.slateLight,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      empty ? '—' : display,
                      style: TextStyle(
                        fontSize: empty ? 22 : 18,
                        fontWeight: FontWeight.w800,
                        color: empty
                            ? KeepiColors.slateLight
                            : (alertStyle
                                ? Colors.red.shade800
                                : KeepiColors.skyBlue),
                        height: 1.1,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.edit_outlined,
                    size: 15,
                    color: empty ? KeepiColors.orange : KeepiColors.slateLight,
                  ),
                ],
              ),
              if (empty) ...[
                const SizedBox(height: 4),
                Text(
                  hint,
                  style: const TextStyle(
                    fontSize: 10,
                    color: KeepiColors.slateLight,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVitalsBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _vitalCell(
              label: 'PRESIÓN',
              value: _vitals.bloodPressure,
              unit: 'mmHg',
              hint: '120/80',
              alertStyle: false,
              showDivider: false,
              onEdit: () => _editVital(
                title: 'Presión arterial',
                label: 'Presión',
                initial: _vitals.bloodPressure,
                hint: 'Ej. 120/80',
                onSave: (v) => _vitals = _vitals.copyWith(bloodPressure: v),
              ),
            ),
            _vitalCell(
              label: 'F. CARDÍACA',
              value: _vitals.heartRate,
              unit: 'bpm',
              hint: '72',
              alertStyle: false,
              showDivider: true,
              onEdit: () => _editVital(
                title: 'Frecuencia cardíaca',
                label: 'Pulsaciones',
                initial: _vitals.heartRate,
                hint: 'Ej. 72',
                onSave: (v) => _vitals = _vitals.copyWith(heartRate: v),
              ),
            ),
            _vitalCell(
              label: 'TEMP',
              value: _vitals.temperature,
              unit: '°C',
              hint: '36.5',
              alertStyle: false,
              showDivider: true,
              onEdit: () => _editVital(
                title: 'Temperatura',
                label: 'Temperatura',
                initial: _vitals.temperature,
                hint: 'Ej. 36.5',
                onSave: (v) => _vitals = _vitals.copyWith(temperature: v),
              ),
            ),
            _vitalCell(
              label: 'ALERGIAS',
              value: _vitals.allergies,
              unit: '',
              hint: 'Registrar',
              alertStyle: true,
              showDivider: true,
              onEdit: () => _editVital(
                title: 'Alergias',
                label: 'Alergias conocidas',
                initial: _vitals.allergies,
                hint: 'Ej. Penicilina',
                onSave: (v) => _vitals = _vitals.copyWith(allergies: v),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClinicalNotesCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: KeepiColors.orangeSoft.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: KeepiColors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Notas Clínicas',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: KeepiColors.slate,
                  ),
                ),
              ),
              IconButton(
                onPressed: _saving ? null : _toggleDictation,
                icon: Icon(
                  _isDictating ? Icons.mic_rounded : Icons.mic_none_rounded,
                  color: _isDictating ? KeepiColors.orange : KeepiColors.slateLight,
                  size: 20,
                ),
                tooltip: _isDictating
                    ? 'Detener dictado'
                    : 'Dictado por voz (español o inglés)',
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 120,
            child: TextField(
            controller: _notesCtrl,
            expands: true,
            maxLines: null,
            enabled: !_saving,
            textCapitalization: TextCapitalization.sentences,
            textAlignVertical: TextAlignVertical.top,
            decoration: InputDecoration(
              hintText: 'Seguimiento',
              filled: true,
              fillColor: KeepiColors.surfaceBg,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _isDictating
                      ? KeepiColors.orange
                      : KeepiColors.cardBorder,
                  width: _isDictating ? 1.6 : 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _isDictating
                      ? KeepiColors.orange
                      : KeepiColors.cardBorder,
                  width: _isDictating ? 1.6 : 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _isDictating
                      ? KeepiColors.orange
                      : KeepiColors.orange.withValues(alpha: 0.7),
                  width: 1.6,
                ),
              ),
            ),
          ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _saving ? null : _finishConsultation,
              style: FilledButton.styleFrom(
                backgroundColor: KeepiColors.orange,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 18),
              label: const Text(
                'Finalizar consulta',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSidebar({required bool wide}) {
    final recent = _timeline.take(5).toList();

    final panel = Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProfileSectionDivider(
            tag: 'LÍNEA DE TIEMPO',
            count: _timeline.length,
          ),
          const SizedBox(height: 16),
          if (recent.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Sin eventos en el historial.',
                textAlign: TextAlign.center,
                style: TextStyle(color: KeepiColors.slateLight, fontSize: 13),
              ),
            )
          else
            ...recent.asMap().entries.map((entry) {
              final i = entry.key;
              final e = entry.value;
              final isLast = i == recent.length - 1;
              return _ConsultationTimelineEntry(
                event: e,
                isLast: isLast,
                onTap: () => TimelineEventOpener.openTimelineEvent(
                  context,
                  patientId: widget.appointment.patientId,
                  patientName: widget.patientName,
                  event: e,
                  onNoteSaved: _bootstrap,
                ),
              );
            }),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _openFullTimeline,
            style: TextButton.styleFrom(
              foregroundColor: KeepiColors.skyBlue,
              textStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                fontSize: 11,
              ),
            ),
            child: const Text('VER HISTORIAL COMPLETO'),
          ),
        ],
      ),
    );

    if (wide) {
      return SizedBox(width: 300, child: panel);
    }
    return panel;
  }

  Widget _buildMainColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildVitalsBar(),
        const SizedBox(height: 16),
        _buildClinicalNotesCard(),
      ],
    );
  }

  Widget _buildProfileTabPanels() {
    final ctx = _context;
    return DoctorPatientProfileScreen(
      key: const ValueKey('consultation-profile-tabs'),
      embeddedTabPanelsOnly: true,
      externalTabIndex: _tabIndex.clamp(0, 3),
      embedded: true,
      patientId: widget.appointment.patientId,
      patientName: ctx?.patientName ?? widget.patientName,
      patientEmail: ctx?.patientEmail ?? widget.patientEmail ?? '',
      mustChangePassword: false,
      onOpenTimeline: widget.onOpenTimeline ?? _openFullTimeline,
      onOpenRequestAnalysis: widget.onOpenRequestAnalysis ?? () {},
      onOpenAssignPrescription: widget.onOpenAssignPrescription ?? () {},
      onOpenSchedule: widget.onOpenSchedule ?? () {},
      onOpenQuestionnaire: widget.onOpenQuestionnaire ?? () {},
    );
  }

  Widget _buildConsultationTabPanel(bool wide) {
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildMainColumn()),
          const SizedBox(width: 20),
          _buildTimelineSidebar(wide: true),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMainColumn(),
        const SizedBox(height: 20),
        _buildTimelineSidebar(wide: false),
      ],
    );
  }

  Widget _buildShell() {
    final ctx = _context;
    final pending = _pendingAnalysis;
    final stats = ctx?.stats ?? const ConsultationStats();

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;

        return WebContentFrame(
          maxWidth: kWebContentMaxWidth,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: _handleBack,
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
              _buildPatientSummaryHeader(ctx: ctx, stats: stats, wide: wide),
              const SizedBox(height: 22),
              const DoctorSectionTitle(tag: 'ACCIONES RÁPIDAS', count: 6),
              const SizedBox(height: 12),
              DoctorWebQuickActionsRow(
                hasPendingUpload: pending.isNotEmpty,
                onOpenTimeline: _openFullTimeline,
                onOpenRequestAnalysis: widget.onOpenRequestAnalysis ?? () {},
                onOpenUpload: pending.isNotEmpty
                    ? () => _openDoctorUploadPending(pending.first)
                    : null,
                onOpenAssignPrescription:
                    widget.onOpenAssignPrescription ?? () {},
                onOpenSchedule: widget.onOpenSchedule ?? () {},
                onOpenQuestionnaire: widget.onOpenQuestionnaire ?? () {},
              ),
              const SizedBox(height: 26),
              DoctorPatientTabBar(
                selectedIndex: _tabIndex,
                includeConsultationTab: true,
                onSelected: (index) {
                  if (index == _tabIndex) return;
                  setState(() => _tabIndex = index);
                },
              ),
              const SizedBox(height: 22),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: IndexedStack(
                  index: _tabIndex == 4 ? 1 : 0,
                  children: [
                    SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 32),
                      child: _buildProfileTabPanels(),
                    ),
                    SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 32),
                      child: _buildConsultationTabPanel(wide),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: CircularProgressIndicator(color: KeepiColors.orange),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = widget.embedded || isWebWide(context) ? 28.0 : 18.0;

    if (_loading) {
      if (widget.embedded) {
        return ColoredBox(
          color: KeepiColors.surfaceBg,
          child: _buildLoadingView(),
        );
      }
      return Scaffold(
        backgroundColor: KeepiColors.surfaceBg,
        body: SafeArea(child: _buildLoadingView()),
      );
    }

    if (widget.embedded) {
      return ColoredBox(
        color: KeepiColors.surfaceBg,
        child: Padding(
          padding: EdgeInsets.fromLTRB(pad, 8, pad, 0),
          child: _buildShell(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: KeepiColors.surfaceBg,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(pad, 12, pad, 0),
          child: _buildShell(),
        ),
      ),
    );
  }
}

class _ConsultationTimelineEntry extends StatelessWidget {
  const _ConsultationTimelineEntry({
    required this.event,
    required this.isLast,
    required this.onTap,
  });

  final TimelineEvent event;
  final bool isLast;
  final VoidCallback onTap;

  static const _months = [
    'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
    'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC',
  ];

  Color _iconColor(String type) {
    switch (type) {
      case 'prescription':
        return KeepiColors.skyBlue;
      case 'appointment':
        return KeepiColors.orange;
      case 'analysis':
      case 'analysis_request':
        return const Color(0xFF2563EB);
      default:
        return KeepiColors.slate;
    }
  }

  IconData _icon(String type) {
    switch (type) {
      case 'prescription':
        return Icons.medication_outlined;
      case 'appointment':
        return Icons.event_available_outlined;
      case 'analysis':
      case 'analysis_request':
        return Icons.biotech_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.tryParse(event.occurredAt)?.toLocal();
    final day = dt?.day ?? 0;
    final month = dt != null ? _months[dt.month - 1] : event.date;
    final accent = _iconColor(event.eventType);
    final subtitle = (event.subtitle ?? event.description).trim();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 52,
                child: Column(
                  children: [
                    Text(
                      day > 0 ? '$day' : '—',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: KeepiColors.slate,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      month,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: KeepiColors.slateLight,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Container(
                        width: 2,
                        color: isLast
                            ? Colors.transparent
                            : KeepiColors.cardBorder,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: accent.withValues(alpha: 0.35)),
                  ),
                  child: Icon(_icon(event.eventType), size: 17, color: accent),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: KeepiColors.slate,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
        ),
      ),
    );
  }
}
