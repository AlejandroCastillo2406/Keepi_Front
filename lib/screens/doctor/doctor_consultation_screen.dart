import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/app_theme.dart';
import '../../core/web_layout.dart';
import '../../models/consultation_context.dart';
import '../../models/timeline_event.dart';
import '../../providers/auth_provider.dart';
import '../../providers/consultation_bootstrap_provider.dart';
import '../../services/api_client.dart';
import '../../services/appointment_service.dart';
import '../../services/doctor_service.dart';
import '../../services/speech_dictation_service.dart';
import '../../services/timeline_event_opener.dart';
import '../../utils/consultation_note_codec.dart';
import '../../utils/patient_expediente_export.dart';
import '../../widgets/doctor_clinical_profile_editor.dart';
import '../../widgets/doctor_patient_web_blocks.dart';
import '../../widgets/patient_care_timeline.dart';
import '../../widgets/patient_scheduling_link_dialog.dart';
import '../../router/app_paths.dart';
import '../../widgets/profile_settings_widgets.dart';
import 'doctor_patient_profile_screen.dart';

class DoctorConsultationScreen extends StatefulWidget {
  const DoctorConsultationScreen({
    super.key,
    required this.appointment,
    required this.patientName,
    this.patientId,
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
  final String? patientId;
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
  bool _bootstrapping = false;
  bool _saving = false;
  bool _exportingExpediente = false;
  bool _editingProfile = false;
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

  AppointmentDto? _resolvedAppointment;
  String? _resolvedPatientId;

  AppointmentDto get _effectiveAppointment =>
      _resolvedAppointment ?? widget.appointment;

  String get _patientId {
    final resolved = _resolvedPatientId?.trim();
    if (resolved != null && resolved.isNotEmpty) return resolved;
    return _effectiveAppointment.patientId.trim();
  }

  @override
  void initState() {
    super.initState();
    _notesCtrl = TextEditingController();
    _resolvedPatientId = _initialPatientId();

    final initialPatientId = _initialPatientId();
    if (initialPatientId != null && initialPatientId.isNotEmpty) {
      final cached = context.read<ConsultationBootstrapProvider>().peek(
            initialPatientId,
            widget.appointment.id,
          );
      if (cached != null) {
        _applyBootstrapFields(cached);
        _bootstrapping = false;
      } else {
        _bootstrapping = true;
      }
    } else {
      _bootstrapping = true;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startBootstrap();
    });
  }

  String? _initialPatientId() {
    final fromRoute = widget.patientId?.trim();
    if (fromRoute != null && fromRoute.isNotEmpty) return fromRoute;
    final fromAppt = widget.appointment.patientId.trim();
    if (fromAppt.isNotEmpty) return fromAppt;
    return null;
  }

  @override
  void didUpdateWidget(covariant DoctorConsultationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appointment.id != widget.appointment.id ||
        oldWidget.patientId != widget.patientId) {
      _resolvedAppointment = null;
      _resolvedPatientId = _initialPatientId();
      _startBootstrap(forceRefresh: true);
    }
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
    if (text.trim().isEmpty) return;
    _dictationHeardThisSession = true;
    final combined = '$_dictationPrefix$text';
    if (_notesCtrl.text == combined) return;
    _notesCtrl.value = TextEditingValue(
      text: combined,
      selection: TextSelection.collapsed(offset: combined.length),
    );
  }

  Future<void> _endDictationFromEngine() async {
    if (!_isDictating) return;
    await _dictation.stop();
    if (!mounted) return;
    final heard = _dictationHeardThisSession ||
        _notesCtrl.text.trim().length > _dictationPrefix.trim().length;
    _finishDictationSession(forceNoSpeechCheck: !heard);
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

    setState(() => _isDictating = true);

    final error = await _dictation.start(
      onTranscript: (text, {required isFinal}) {
        if (!mounted) return;
        setState(() => _applyDictationText(text));
      },
      onStatus: (status) {
        if (!mounted) return;
        if (status == SpeechToText.listeningStatus) {
          setState(() => _isDictating = true);
          return;
        }
        if (status == 'notListening') {
          unawaited(_dictation.stop());
          _finishDictationSession(
            forceNoSpeechCheck: !_dictationHeardThisSession,
          );
          return;
        }
        if (status == 'doneNoResult') {
          _endDictationFromEngine();
          return;
        }
        if (status == SpeechToText.doneStatus) {
          _endDictationFromEngine();
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
      setState(() => _isDictating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }
  }

  Future<void> _startBootstrap({bool forceRefresh = false}) async {
    if (!mounted) return;

    final patientId = await _resolvePatientId();
    if (!mounted) return;
    if (patientId == null || patientId.isEmpty) {
      setState(() {
        _error = 'No se pudo identificar al paciente de esta cita.';
        _bootstrapping = false;
      });
      return;
    }

    await _bootstrap(patientId: patientId, forceRefresh: forceRefresh);
  }

  Future<String?> _resolvePatientId() async {
    final cached = _resolvedPatientId?.trim();
    if (cached != null && cached.isNotEmpty) return cached;

    final fromAppt = _effectiveAppointment.patientId.trim();
    if (fromAppt.isNotEmpty) {
      _resolvedPatientId = fromAppt;
      return fromAppt;
    }

    try {
      final appt = await AppointmentService(context.read<ApiClient>())
          .fetchById(_effectiveAppointment.id);
      if (!mounted) return null;
      _resolvedAppointment = appt;
      final resolved = appt.patientId.trim();
      if (resolved.isNotEmpty) {
        _resolvedPatientId = resolved;
        return resolved;
      }
    } catch (_) {}

    return null;
  }

  Future<void> _bootstrap({
    required String patientId,
    bool forceRefresh = false,
  }) async {
    final appointmentId = _effectiveAppointment.id;
    final cache = context.read<ConsultationBootstrapProvider>();

    if (!forceRefresh) {
      final cached = cache.peek(patientId, appointmentId);
      if (cached != null) {
        _applyBootstrap(cached);
        return;
      }
    }

    setState(() {
      _bootstrapping = true;
      _error = null;
    });
    try {
      final data = await DoctorService(context.read<ApiClient>())
          .fetchConsultationBootstrap(
        patientId: patientId,
        appointmentId: appointmentId,
      );
      if (!mounted) return;
      cache.put(patientId, appointmentId, data);
      _applyBootstrap(data);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _humanizeBootstrapError(e);
        _bootstrapping = false;
      });
    }
  }

  String _humanizeBootstrapError(Object e) {
    final msg = DoctorService.messageFromDio(e);
    if (msg == 'not_found') {
      return 'No se pudo cargar la consulta. Verifica la cita e intenta de nuevo.';
    }
    return msg;
  }

  void _applyBootstrapFields(ConsultationBootstrapData data) {
    var vitals = const ConsultationVitals();
    final noteRaw = data.doctorNoteContent.trim();
    if (noteRaw.isNotEmpty) {
      final decoded = ConsultationNoteCodec.decode(noteRaw);
      _notesCtrl.text = decoded.clinicalNote;
      vitals = decoded.vitals;
    } else {
      _notesCtrl.text = '';
    }

    final intakeAllergies = (data.context.allergies ?? '').trim();
    if (vitals.allergies.isEmpty && intakeAllergies.isNotEmpty) {
      vitals = vitals.copyWith(allergies: intakeAllergies);
    }

    _event = data.event;
    _context = data.context;
    _analysisRequests = data.analysisRequests;
    _vitals = vitals;
    _timeline = data.timeline
        .where((e) => e.eventType.toLowerCase() != 'analysis_upload')
        .toList();
  }

  void _applyBootstrap(ConsultationBootstrapData data) {
    _applyBootstrapFields(data);
    if (!mounted) return;
    setState(() {
      _bootstrapping = false;
      _error = null;
    });
  }

  void _handleBack() {
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }
    if (context.canPop()) {
      context.pop();
    }
  }

  void _openFullTimeline() {
    if (widget.onOpenTimeline != null) {
      widget.onOpenTimeline!();
      return;
    }
    context.push<void>(
      AppPaths.doctorPatientTimeline(_patientId),
    );
  }

  Future<void> _openSchedulingLink() async {
    await PatientSchedulingLinkDialog.show(
      context,
      patientId: _patientId,
      patientName: _context?.patientName ?? widget.patientName,
    );
  }

  List<AnalysisRequestDto> get _pendingAnalysis => _analysisRequests
      .where((r) => r.status == 'pending' && (r.documentId ?? '').isEmpty)
      .toList();

  Future<void> _openDoctorUploadPending(AnalysisRequestDto item) async {
    final ok = await context.push<bool>(
      AppPaths.doctorUploadAnalysis(
        _patientId,
        item.id,
        description: item.description,
      ),
    );
    if (ok == true && mounted) {
      context.read<ConsultationBootstrapProvider>().invalidate(
            _patientId,
            _effectiveAppointment.id,
          );
      await _startBootstrap(forceRefresh: true);
    }
  }

  Widget _buildPatientSummaryHeader({
    required ConsultationContext? ctx,
    required ConsultationStats stats,
    required bool wide,
  }) {
    return DoctorPatientSummaryHeaderRow(
      name: ctx?.patientName ?? widget.patientName,
      email: ctx?.patientEmail ?? widget.patientEmail ?? '',
      sex: ctx?.sex,
      subtitle: _whenLabel(),
      ageYears: ctx?.ageYears,
      bloodType: ctx?.bloodType,
      weightKg: ctx?.weightKg,
      totalAnalysis: stats.analysisRequested,
      uploadedAnalysis: stats.analysisUploaded,
      pendingAnalysis: stats.analysisPending,
      attendanceRatePercent: stats.attendanceRatePercent,
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

  Future<void> _openEditProfileDialog() async {
    if (_editingProfile || _exportingExpediente) return;

    final form = await showDoctorClinicalProfileEditor(
      context,
      initial: _context,
      fallbackName: widget.patientName,
      fallbackEmail: widget.patientEmail ?? '',
    );
    if (form == null || !mounted) return;

    setState(() => _editingProfile = true);
    try {
      final updated = await saveClinicalProfileForm(
        api: context.read<ApiClient>(),
        patientId: _patientId,
        form: form,
      );
      if (updated == null || !mounted) return;
      context.read<ConsultationBootstrapProvider>().invalidate(
            _patientId,
            _effectiveAppointment.id,
          );
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
        patientId: _patientId,
        patientName: _context?.patientName ?? widget.patientName,
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

  String _whenLabel() {
    final parts = _consultationDateTimeParts();
    if (parts.date.isEmpty && parts.time.isEmpty) return '';
    if (parts.time.isEmpty) return parts.date;
    if (parts.date.isEmpty) return parts.time;
    return '${parts.date} · ${parts.time}';
  }

  ({String date, String time}) _consultationDateTimeParts() {
    final dt = _effectiveAppointment.appointmentDate?.toLocal();
    if (dt == null) {
      final ev = _event;
      if (ev != null && ev.date.trim().isNotEmpty) {
        return (date: ev.date.trim(), time: ev.time.trim());
      }
      return (date: '', time: '');
    }
    final date =
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    var time = '$h:$m';
    final end = _effectiveAppointment.endDate?.toLocal();
    if (end != null) {
      final eh = end.hour.toString().padLeft(2, '0');
      final em = end.minute.toString().padLeft(2, '0');
      time = '$time – $eh:$em';
    }
    return (date: date, time: time);
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'scheduled':
        return Icons.check_circle_outline;
      case 'canceled':
        return Icons.cancel_outlined;
      case 'pending_patient_approval':
      case 'pending_doctor_approval':
      case 'pending_doctor_proposal':
        return Icons.hourglass_top_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'scheduled':
        return KeepiColors.green;
      case 'canceled':
        return Colors.red.shade700;
      case 'pending_patient_approval':
      case 'pending_doctor_approval':
      case 'pending_doctor_proposal':
        return KeepiColors.orange;
      default:
        return KeepiColors.slateLight;
    }
  }

  Widget _referenceSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(
        width: 2,
        height: 2,
        decoration: BoxDecoration(
          color: KeepiColors.slateLight.withValues(alpha: 0.55),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _referenceDatum({
    required IconData icon,
    required String text,
    Color? iconColor,
    Color? textColor,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 15,
          color: iconColor ?? KeepiColors.orange,
        ),
        const SizedBox(width: 5),
        Text(
          text,
          maxLines: maxLines ?? 1,
          overflow: overflow ?? TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor ?? KeepiColors.slate,
          ),
        ),
      ],
    );
  }

  String _consultationReason() {
    final fromAppt = _effectiveAppointment.reason.trim();
    if (fromAppt.isNotEmpty) return fromAppt;
    final ev = _event;
    if (ev != null) {
      final sub = (ev.subtitle ?? '').trim();
      if (sub.isNotEmpty) return sub;
      final desc = ev.description.trim();
      if (desc.isNotEmpty) return desc;
    }
    return 'Consulta médica';
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

  Widget _buildConsultationReferenceCard() {
    final dateTime = _consultationDateTimeParts();
    final reason = _consultationReason();
    final status = _appointmentStatusLabel(_effectiveAppointment.status);
    final statusColor = _statusColor(_effectiveAppointment.status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dateTime.date.isNotEmpty) ...[
                _referenceDatum(
                  icon: Icons.calendar_today_outlined,
                  text: dateTime.date,
                ),
                if (dateTime.time.isNotEmpty) _referenceSeparator(),
              ],
              if (dateTime.time.isNotEmpty) ...[
                _referenceDatum(
                  icon: Icons.schedule_rounded,
                  text: dateTime.time,
                ),
                _referenceSeparator(),
              ],
              _referenceDatum(
                icon: _statusIcon(_effectiveAppointment.status),
                text: status,
                iconColor: statusColor,
                textColor: statusColor,
              ),
            ],
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(width: 14),
            Expanded(
              child: _ConsultationReferenceReason(text: reason),
            ),
          ],
        ],
      ),
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
        patientId: _patientId,
        ageYears: ageYears,
        bloodType: bloodType,
        weightKg: weightKg,
      );
      if (!mounted) return;
      context.read<ConsultationBootstrapProvider>().invalidate(
            _patientId,
            _effectiveAppointment.id,
          );
      setState(() => _context = updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DoctorService.messageFromDio(e))),
      );
    }
  }

  Future<void> _editClinicalAge() async {
    final raw = await _editVital(
      title: 'Edad',
      label: 'Años',
      initial: _context?.ageYears?.toString() ?? '',
      hint: 'Ej. 35',
      onSave: (_) {},
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
    final raw = await _editVital(
      title: 'Tipo de sangre',
      label: 'Grupo',
      initial: _context?.bloodType ?? '',
      hint: 'Ej. O+',
      onSave: (_) {},
    );
    if (raw == null || !mounted) return;
    await _persistClinicalProfile(
      bloodType: raw.isEmpty ? null : raw,
    );
  }

  Future<void> _editClinicalWeight() async {
    final raw = await _editVital(
      title: 'Peso',
      label: 'Kilogramos',
      initial: _context?.weightKg?.toString() ?? '',
      hint: 'Ej. 72.5',
      onSave: (_) {},
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
        patientId: _patientId,
        eventId: event.id,
        eventType: event.eventType,
        doctorNote: payload,
      );
      context.read<ConsultationBootstrapProvider>().invalidate(
            _patientId,
            _effectiveAppointment.id,
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
                style: IconButton.styleFrom(
                  backgroundColor: _isDictating
                      ? KeepiColors.orangeSoft
                      : Colors.transparent,
                ),
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
          if (_isDictating) ...[
            const SizedBox(height: 10),
            _DictationListeningBanner(
              heardSpeech: _dictationHeardThisSession,
            ),
          ],
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
            PatientCareTimeline(
              events: recent,
              showSectionHeader: false,
              compact: true,
              titleOnly: true,
              onEventTap: (e) => TimelineEventOpener.openTimelineEvent(
                context,
                patientId: _patientId,
                patientName: widget.patientName,
                event: e,
                onNoteSaved: () => _startBootstrap(forceRefresh: true),
              ),
            ),
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
      return SizedBox(width: 340, child: panel);
    }
    return panel;
  }

  Widget _buildMainColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildConsultationReferenceCard(),
        const SizedBox(height: 16),
        _buildVitalsBar(),
        const SizedBox(height: 16),
        _buildClinicalNotesCard(),
      ],
    );
  }

  Widget _buildProfileTabPanels() {
    final ctx = _context;
    return DoctorPatientProfileScreen(
      key: ValueKey('consultation-profile-tabs-$_patientId'),
      embeddedTabPanelsOnly: true,
      externalTabIndex: _tabIndex.clamp(0, 3),
      embedded: true,
      patientId: _patientId,
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
    if (_bootstrapping && _context == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: CircularProgressIndicator(color: KeepiColors.orange),
        ),
      );
    }
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
              const DoctorSectionTitle(tag: 'ACCIONES RÁPIDAS', count: 7),
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
                onGenerateSchedulingLink: _openSchedulingLink,
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
              if (_error != null &&
                  _context == null &&
                  !_bootstrapping) ...[
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => _startBootstrap(forceRefresh: true),
                    child: const Text('Reintentar'),
                  ),
                ),
                const SizedBox(height: 12),
              ] else if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: _error != null &&
                        _context == null &&
                        !_bootstrapping
                    ? const SizedBox.shrink()
                    : IndexedStack(
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

  @override
  Widget build(BuildContext context) {
    final pad = widget.embedded || isWebWide(context) ? 28.0 : 18.0;

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

class _ConsultationReferenceReason extends StatefulWidget {
  const _ConsultationReferenceReason({required this.text});

  final String text;

  @override
  State<_ConsultationReferenceReason> createState() =>
      _ConsultationReferenceReasonState();
}

class _ConsultationReferenceReasonState
    extends State<_ConsultationReferenceReason> {
  bool _expanded = false;
  bool _overflows = false;
  final GlobalKey _textKey = GlobalKey();

  static const _textStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: KeepiColors.slate,
  );

  @override
  void didUpdateWidget(covariant _ConsultationReferenceReason oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _expanded = false;
      _overflows = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
  }

  void _checkOverflow() {
    if (!mounted || _expanded) return;
    final renderBox = _textKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: _textStyle),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout(maxWidth: renderBox.size.width);

    final next = painter.didExceedMaxLines;
    if (next != _overflows && mounted) {
      setState(() => _overflows = next);
    }
  }

  void _toggleExpanded() {
    if (!_overflows && !_expanded) return;
    setState(() => _expanded = !_expanded);
    if (!_expanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: (_overflows || _expanded) ? _toggleExpanded : null,
      borderRadius: BorderRadius.circular(6),
      child: Row(
        crossAxisAlignment:
            _expanded ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.subject_rounded,
            size: 15,
            color: KeepiColors.orange,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              widget.text,
              key: _textKey,
              maxLines: _expanded ? null : 1,
              overflow:
                  _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: _textStyle,
            ),
          ),
          if (_overflows || _expanded) ...[
            const SizedBox(width: 2),
            Icon(
              _expanded
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              size: 18,
              color: KeepiColors.slateLight,
            ),
          ],
        ],
      ),
    );
  }
}

class _DictationListeningBanner extends StatefulWidget {
  const _DictationListeningBanner({required this.heardSpeech});

  final bool heardSpeech;

  @override
  State<_DictationListeningBanner> createState() =>
      _DictationListeningBannerState();
}

class _DictationListeningBannerState extends State<_DictationListeningBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: KeepiColors.orangeSoft.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: KeepiColors.orange.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.12).animate(
              CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
            ),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: KeepiColors.orange,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: KeepiColors.orange.withValues(alpha: 0.35),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(Icons.mic_rounded, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.heardSpeech
                      ? 'Escuchando lo que dices…'
                      : 'Escuchando… habla ahora',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: KeepiColors.slate,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Se detiene tras 3 segundos de silencio',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: KeepiColors.slateLight,
                  ),
                ),
              ],
            ),
          ),
          if (widget.heardSpeech)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: KeepiColors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: KeepiColors.green.withValues(alpha: 0.4),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.graphic_eq_rounded, size: 14, color: KeepiColors.green),
                  SizedBox(width: 4),
                  Text(
                    'Voz',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: KeepiColors.green,
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
