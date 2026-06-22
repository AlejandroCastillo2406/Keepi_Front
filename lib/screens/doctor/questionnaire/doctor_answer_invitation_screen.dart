import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_theme.dart';
import '../../../services/api_client.dart';
import '../../../services/doctor_service.dart';
import '../../../services/questionnaire_service.dart';

/// Flujo unificado para que el médico conteste en nombre del paciente:
/// ficha clínica → documentos previos → cuestionario.
class DoctorAnswerInvitationScreen extends StatefulWidget {
  const DoctorAnswerInvitationScreen({
    super.key,
    required this.invitationId,
    required this.invitationLabel,
    required this.patientName,
  });

  final String invitationId;
  final String invitationLabel;
  final String patientName;

  @override
  State<DoctorAnswerInvitationScreen> createState() =>
      _DoctorAnswerInvitationScreenState();
}

enum _InvitationPhase { intake, priorDocs, questions, done }

class _DoctorAnswerInvitationScreenState
    extends State<DoctorAnswerInvitationScreen> {
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  Map<String, dynamic>? _workflow;
  _InvitationPhase _phase = _InvitationPhase.intake;
  bool _priorDocsSkipped = false;

  List<Map<String, dynamic>> _questions = const [];
  final Map<String, dynamic> _answers = {};

  int _intakeStep = 0;
  final Map<String, Map<String, dynamic>> _intakeValues = {};
  List<Map<String, dynamic>> _intakeSections = const [];

  final List<String> _uploadedDocs = [];

  QuestionnaireService get _svc =>
      QuestionnaireService(context.read<ApiClient>());

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data =
          await _svc.fetchInvitationWorkflowForDoctor(widget.invitationId);
      if (!mounted) return;
      _applyWorkflow(data);
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = DoctorService.messageFromDio(e);
        _loading = false;
      });
    }
  }

  void _applyWorkflow(Map<String, dynamic> data) {
    _workflow = data;
    _intakeSections = _parseSections(data['intake_sections']);
    _initIntakeValues();
    _questions = _parseQuestions(data['questions']);
    _phase = _resolvePhase(data);
  }

  List<Map<String, dynamic>> _parseSections(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  List<Map<String, dynamic>> _parseQuestions(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  void _initIntakeValues() {
    for (final section in _intakeSections) {
      final id = (section['id'] ?? '').toString();
      if (id.isEmpty) continue;
      final fields = section['fields'];
      final map = <String, dynamic>{};
      if (fields is List) {
        for (final f in fields.whereType<Map>()) {
          final key = (f['key'] ?? '').toString();
          if (key.isEmpty) continue;
          map[key] = f['value'];
        }
      }
      _intakeValues[id] = map;
    }
  }

  _InvitationPhase _resolvePhase(Map<String, dynamic> data) {
    if (data['status']?.toString() == 'completed') {
      return _InvitationPhase.done;
    }
    if (data['enable_clinical_intake'] == true &&
        data['intake_completed'] != true) {
      return _InvitationPhase.intake;
    }
    if (data['collect_prior_documents'] == true && !_priorDocsSkipped) {
      return _InvitationPhase.priorDocs;
    }
    if (_hasQuestionnaire(data)) {
      return _InvitationPhase.questions;
    }
    return _InvitationPhase.done;
  }

  bool _hasQuestionnaire(Map<String, dynamic> data) {
    if (data['questionnaire_completed'] == true) return false;
    if (_questions.isNotEmpty) return true;
    return data['has_questionnaire'] == true;
  }

  Future<void> _finishIfNeeded() async {
    final wf = _workflow;
    if (wf == null) return;
    if (wf['status']?.toString() == 'completed') return;
    await _svc.finishDoctorInvitation(widget.invitationId);
  }

  Future<void> _advanceAfterStep() async {
    try {
      final data =
          await _svc.fetchInvitationWorkflowForDoctor(widget.invitationId);
      if (!mounted) return;
      setState(() => _applyWorkflow(data));
      if (_phase == _InvitationPhase.done) {
        await _finishIfNeeded();
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DoctorService.messageFromDio(e))),
      );
    }
  }

  Future<void> _submitIntakeSection() async {
    final section = _intakeSections[_intakeStep];
    final sectionId = (section['id'] ?? '').toString();
    if (sectionId.isEmpty) return;
    if (!_validateIntakeSection(section)) return;

    setState(() => _submitting = true);
    try {
      final answers = _sanitizeSectionAnswers(
        sectionId,
        Map<String, dynamic>.from(_intakeValues[sectionId] ?? {}),
      );
      final result = await _svc.submitDoctorIntakeSection(
        invitationId: widget.invitationId,
        sectionId: sectionId,
        answers: answers,
      );
      if (!mounted) return;

      if (result['intake_completed'] == true) {
        await _advanceAfterStep();
      } else if (_intakeStep < _intakeSections.length - 1) {
        setState(() => _intakeStep++);
      } else {
        await _advanceAfterStep();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DoctorService.messageFromDio(e))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _skipPriorDocs() async {
    setState(() => _priorDocsSkipped = true);
    await _advanceAfterStep();
  }

  Future<void> _pickAndUploadPriorDoc() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      setState(() => _submitting = true);

      final formData = FormData.fromMap({
        'file': kIsWeb
            ? MultipartFile.fromBytes(file.bytes!, filename: file.name)
            : await MultipartFile.fromFile(file.path!, filename: file.name),
      });
      final res = await _svc.uploadDoctorPriorDocument(
        invitationId: widget.invitationId,
        formData: formData,
      );
      if (!mounted) return;
      final name = (res['file_name'] ?? file.name).toString();
      setState(() => _uploadedDocs.add(name));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Documento subido: $name')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DoctorService.messageFromDio(e))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _finishPriorDocs() async {
    setState(() => _priorDocsSkipped = true);
    await _advanceAfterStep();
  }

  Future<void> _submitQuestionnaire() async {
    for (final q in _questions) {
      final itemId = (q['item_id'] ?? '').toString();
      final required = q['is_required'] == true;
      final value = _answers[itemId];
      if (!required) continue;
      if (value == null ||
          (value is String && value.trim().isEmpty) ||
          value == <String>[]) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Completa todas las preguntas obligatorias'),
          ),
        );
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      final payload = _answers.entries
          .map((e) => {'item_id': e.key, 'answer': e.value})
          .toList();
      await _svc.submitDoctorInvitation(
        invitationId: widget.invitationId,
        answers: payload,
      );
      if (!mounted) return;
      await _advanceAfterStep();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DoctorService.messageFromDio(e))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KeepiColors.surfaceBg,
      appBar: AppBar(
        backgroundColor: KeepiColors.surfaceBg,
        elevation: 0,
        title: Text(
          _phaseTitle(),
          style: const TextStyle(
            color: KeepiColors.slate,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        iconTheme: const IconThemeData(color: KeepiColors.slate),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: KeepiColors.orange),
            )
          : _error != null
              ? _buildError()
              : _buildBody(),
    );
  }

  String _phaseTitle() {
    switch (_phase) {
      case _InvitationPhase.intake:
        return 'Ficha clínica';
      case _InvitationPhase.priorDocs:
        return 'Documentos previos';
      case _InvitationPhase.questions:
        return 'Cuestionario';
      case _InvitationPhase.done:
        return 'Completado';
    }
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        _buildHeaderBanner(),
        if (_workflow != null) _buildProgress(),
        Expanded(
          child: switch (_phase) {
            _InvitationPhase.intake => _buildIntakeStep(),
            _InvitationPhase.priorDocs => _buildPriorDocsStep(),
            _InvitationPhase.questions => _buildQuestionsStep(),
            _InvitationPhase.done => _buildDoneStep(),
          },
        ),
      ],
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KeepiColors.orangeSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: KeepiColors.orange.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.invitationLabel,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: KeepiColors.slate,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Paciente: ${widget.patientName}',
            style: const TextStyle(fontSize: 13, color: KeepiColors.slateLight),
          ),
          const SizedBox(height: 8),
          const Text(
            'Las respuestas quedarán registradas como contestadas por el médico.',
            style: TextStyle(
              fontSize: 12.5,
              color: KeepiColors.slate,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    final wf = _workflow!;
    final steps = <String>[];
    if (wf['enable_clinical_intake'] == true) steps.add('Ficha');
    if (wf['collect_prior_documents'] == true) steps.add('Documentos');
    if (wf['has_questionnaire'] == true) steps.add('Cuestionario');
    if (steps.length <= 1) return const SizedBox.shrink();

    final currentLabel = switch (_phase) {
      _InvitationPhase.intake => 'Ficha',
      _InvitationPhase.priorDocs => 'Documentos',
      _InvitationPhase.questions => 'Cuestionario',
      _InvitationPhase.done => steps.last,
    };
    final currentIndex = steps.indexOf(currentLabel).clamp(0, steps.length - 1);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  color: i <= currentIndex
                      ? KeepiColors.orange
                      : KeepiColors.cardBorder,
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: i <= currentIndex
                    ? KeepiColors.orangeSoft
                    : KeepiColors.slateSoft,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: i <= currentIndex
                      ? KeepiColors.orange
                      : KeepiColors.cardBorder,
                ),
              ),
              child: Text(
                steps[i],
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: i <= currentIndex
                      ? KeepiColors.orange
                      : KeepiColors.slateLight,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIntakeStep() {
    if (_intakeSections.isEmpty) {
      return const Center(child: Text('No hay secciones de ficha clínica.'));
    }
    final section = _intakeSections[_intakeStep];
    final sectionId = (section['id'] ?? '').toString();
    final fields = (section['fields'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Text(
                (section['title'] ?? 'Sección').toString(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: KeepiColors.slate,
                ),
              ),
              if ((section['subtitle'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  section['subtitle'].toString(),
                  style: const TextStyle(
                    fontSize: 13,
                    color: KeepiColors.slateLight,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ...fields.map(
                (f) => _IntakeFieldEditor(
                  field: f,
                  value: _intakeValues[sectionId]?[f['key']],
                  onChanged: (v) {
                    setState(() {
                      _intakeValues[sectionId] ??= {};
                      _intakeValues[sectionId]![f['key'].toString()] = v;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        _bottomButton(
          label: _intakeStep < _intakeSections.length - 1
              ? 'Siguiente sección'
              : 'Guardar ficha',
          onPressed: _submitIntakeSection,
        ),
      ],
    );
  }

  Widget _buildPriorDocsStep() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              const Text(
                'Sube estudios o documentos previos del paciente (opcional).',
                style: TextStyle(
                  fontSize: 14.5,
                  color: KeepiColors.slate,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _submitting ? null : _pickAndUploadPriorDoc,
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('Seleccionar archivo'),
              ),
              if (_uploadedDocs.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Archivos subidos',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: KeepiColors.slate,
                  ),
                ),
                const SizedBox(height: 8),
                ..._uploadedDocs.map(
                  (name) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.check_circle_rounded,
                      color: KeepiColors.green,
                    ),
                    title: Text(name),
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting ? null : _skipPriorDocs,
                  child: const Text('Omitir'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _submitting ? null : _finishPriorDocs,
                  child: const Text('Continuar'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionsStep() {
    if (_questions.isEmpty) {
      return Center(
        child: FilledButton(
          onPressed: _advanceAfterStep,
          child: const Text('Continuar'),
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: _questions.map(_buildQuestionCard).toList(),
          ),
        ),
        _bottomButton(
          label: 'Guardar respuestas',
          onPressed: _submitQuestionnaire,
        ),
      ],
    );
  }

  Widget _buildDoneStep() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 56, color: KeepiColors.green),
          const SizedBox(height: 16),
          const Text(
            'Invitación completada',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: KeepiColors.slate,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _bottomButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _submitting ? null : onPressed,
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(label),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> q) {
    final itemId = (q['item_id'] ?? '').toString();
    final text = (q['question_text'] ?? '').toString();
    final help = (q['help_text'] ?? '').toString();
    final required = q['is_required'] == true;
    final type = (q['response_type'] ?? 'long_text').toString().toLowerCase();
    final options = (q['options'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            required ? '$text *' : text,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: KeepiColors.slate,
              height: 1.3,
            ),
          ),
          if (help.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              help,
              style: const TextStyle(
                fontSize: 12.5,
                color: KeepiColors.slateLight,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _QuestionField(
            itemId: itemId,
            type: type,
            options: options,
            value: _answers[itemId],
            onChanged: (v) => setState(() => _answers[itemId] = v),
          ),
        ],
      ),
    );
  }

  bool _validateIntakeSection(Map<String, dynamic> section) {
    final sectionId = (section['id'] ?? '').toString();
    final answers = _intakeValues[sectionId] ?? {};
    final fields = (section['fields'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e));

    for (final field in fields) {
      if (field['required'] != true) continue;
      final key = (field['key'] ?? '').toString();
      final type = (field['type'] ?? '').toString().toLowerCase();
      final v = answers[key];
      if (!_fieldHasValue(type, v)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Completa: ${field['label'] ?? key}')),
        );
        return false;
      }
    }
    return true;
  }

  bool _fieldHasValue(String type, dynamic v) {
    if (type == 'allergy_list') {
      final items = _normalizeAllergyItems(v);
      return items.any((s) => s.trim().isNotEmpty);
    }
    if (type == 'medication_list') {
      return _normalizeMedicationItems(v).any((m) => m['name']!.trim().isNotEmpty);
    }
    if (type == 'family_history_list') {
      return _normalizeFamilyItems(v).any(
        (row) =>
            row['condition']!.trim().isNotEmpty &&
            row['relative']!.trim().isNotEmpty,
      );
    }
    if (type == 'surgery_list') {
      return _normalizeSurgeryItems(v).any(
        (row) =>
            row['procedure']!.trim().isNotEmpty &&
            row['date']!.trim().isNotEmpty,
      );
    }
    if (type == 'phone' || type.contains('phone')) {
      final digits = v?.toString().replaceAll(RegExp(r'\D'), '') ?? '';
      return digits.length == 10;
    }
    return v != null && v.toString().trim().isNotEmpty;
  }

  Map<String, dynamic> _sanitizeSectionAnswers(
    String sectionId,
    Map<String, dynamic> answers,
  ) {
    if (sectionId == 'allergies') {
      final items = _normalizeAllergyItems(answers['allergy_items'])
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      return {'allergy_items': items};
    }
    if (sectionId == 'medications') {
      final items = _normalizeMedicationItems(answers['medication_items'])
          .where((m) => m['name']!.trim().isNotEmpty)
          .toList();
      return {'medication_items': items};
    }
    if (sectionId == 'family_history') {
      final items = _normalizeFamilyItems(answers['family_history_items'])
          .where(
            (row) =>
                row['condition']!.trim().isNotEmpty &&
                row['relative']!.trim().isNotEmpty,
          )
          .toList();
      return {'family_history_items': items};
    }
    if (sectionId == 'surgeries') {
      final items = _normalizeSurgeryItems(answers['surgery_items'])
          .where(
            (row) =>
                row['procedure']!.trim().isNotEmpty &&
                row['date']!.trim().isNotEmpty,
          )
          .toList();
      return {'surgery_items': items};
    }
    if (sectionId == 'personal_data') {
      final out = Map<String, dynamic>.from(answers);
      if (out['phone'] != null) {
        final digits = out['phone'].toString().replaceAll(RegExp(r'\D'), '');
        out['phone'] = digits.length > 10 ? digits.substring(0, 10) : digits;
      }
      return out;
    }
    return answers;
  }

  List<String> _normalizeAllergyItems(dynamic val) {
    if (val is List) {
      final items = val.map((v) => v.toString()).toList();
      return items.isEmpty ? [''] : items;
    }
    if (val is String && val.trim().isNotEmpty) return [val.trim()];
    return [''];
  }

  List<Map<String, String>> _normalizeMedicationItems(dynamic val) {
    if (val is List) {
      return val.map((m) {
        if (m is Map) {
          return {
            'name': (m['name'] ?? '').toString(),
            'mg': (m['mg'] ?? '').toString(),
          };
        }
        return {'name': m.toString(), 'mg': ''};
      }).toList();
    }
    return [{'name': '', 'mg': ''}];
  }

  List<Map<String, String>> _normalizeFamilyItems(dynamic val) {
    if (val is List) {
      return val.map((item) {
        if (item is Map) {
          return {
            'condition': (item['condition'] ?? item['name'] ?? '').toString(),
            'relative': (item['relative'] ?? '').toString(),
          };
        }
        return {'condition': item.toString(), 'relative': ''};
      }).toList();
    }
    return [{'condition': '', 'relative': ''}];
  }

  List<Map<String, String>> _normalizeSurgeryItems(dynamic val) {
    if (val is List) {
      return val.map((item) {
        if (item is Map) {
          return {
            'procedure': (item['procedure'] ?? item['name'] ?? '').toString(),
            'date': (item['date'] ?? '').toString(),
          };
        }
        return {'procedure': item.toString(), 'date': ''};
      }).toList();
    }
    return [{'procedure': '', 'date': ''}];
  }
}

class _IntakeFieldEditor extends StatelessWidget {
  const _IntakeFieldEditor({
    required this.field,
    required this.value,
    required this.onChanged,
  });

  final Map<String, dynamic> field;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = (field['label'] ?? '').toString();
    final type = (field['type'] ?? 'long_text').toString().toLowerCase();
    final required = field['required'] == true;
    final placeholder = (field['placeholder'] ?? '').toString();
    final options = (field['options'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            required ? '$label *' : label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: KeepiColors.slate,
            ),
          ),
          const SizedBox(height: 8),
          _buildInput(type, placeholder, options),
        ],
      ),
    );
  }

  Widget _buildInput(String type, String placeholder, List<String> options) {
    switch (type) {
      case 'phone':
        return TextField(
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: placeholder.isNotEmpty ? placeholder : '10 dígitos',
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          controller: TextEditingController(text: value?.toString() ?? ''),
          onChanged: onChanged,
        );
      case 'date':
        return TextField(
          decoration: const InputDecoration(
            hintText: 'AAAA-MM-DD',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          controller: TextEditingController(text: value?.toString() ?? ''),
          onChanged: onChanged,
        );
      case 'single_choice':
        return DropdownButtonFormField<String>(
          decoration: const InputDecoration(border: OutlineInputBorder()),
          value: value?.toString().isNotEmpty == true ? value.toString() : null,
          items: options
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: onChanged,
        );
      case 'allergy_list':
        return _AllergyListInput(value: value, onChanged: onChanged);
      case 'medication_list':
        return _MedicationListInput(value: value, onChanged: onChanged);
      case 'family_history_list':
        return _FamilyHistoryListInput(value: value, onChanged: onChanged);
      case 'surgery_list':
        return _SurgeryListInput(value: value, onChanged: onChanged);
      case 'short_text':
        return TextField(
          decoration: InputDecoration(
            hintText: placeholder,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          controller: TextEditingController(text: value?.toString() ?? ''),
          onChanged: onChanged,
        );
      default:
        return TextField(
          minLines: 2,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: placeholder.isNotEmpty ? placeholder : 'Escribe aquí',
            border: const OutlineInputBorder(),
          ),
          controller: TextEditingController(text: value?.toString() ?? ''),
          onChanged: onChanged,
        );
    }
  }
}

class _AllergyListInput extends StatefulWidget {
  const _AllergyListInput({required this.value, required this.onChanged});
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  @override
  State<_AllergyListInput> createState() => _AllergyListInputState();
}

class _AllergyListInputState extends State<_AllergyListInput> {
  late List<String> _items;

  @override
  void initState() {
    super.initState();
    _items = _parse(widget.value);
  }

  List<String> _parse(dynamic val) {
    if (val is List && val.isNotEmpty) {
      return val.map((e) => e.toString()).toList();
    }
    return [''];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < _items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    controller: TextEditingController(text: _items[i]),
                    onChanged: (v) {
                      _items[i] = v;
                      widget.onChanged(List<String>.from(_items));
                    },
                  ),
                ),
                if (_items.length > 1)
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _items.removeAt(i);
                        widget.onChanged(List<String>.from(_items));
                      });
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
          ),
        TextButton.icon(
          onPressed: () {
            setState(() {
              _items.add('');
              widget.onChanged(List<String>.from(_items));
            });
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Agregar alergia'),
        ),
      ],
    );
  }
}

class _MedicationListInput extends StatefulWidget {
  const _MedicationListInput({required this.value, required this.onChanged});
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  @override
  State<_MedicationListInput> createState() => _MedicationListInputState();
}

class _MedicationListInputState extends State<_MedicationListInput> {
  late List<Map<String, String>> _items;

  @override
  void initState() {
    super.initState();
    _items = _parse(widget.value);
  }

  List<Map<String, String>> _parse(dynamic val) {
    if (val is List && val.isNotEmpty) {
      return val.map((m) {
        if (m is Map) {
          return {
            'name': (m['name'] ?? '').toString(),
            'mg': (m['mg'] ?? '').toString(),
          };
        }
        return {'name': m.toString(), 'mg': ''};
      }).toList();
    }
    return [{'name': '', 'mg': ''}];
  }

  void _notify() => widget.onChanged(_items);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < _items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Medicamento',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    controller:
                        TextEditingController(text: _items[i]['name']),
                    onChanged: (v) {
                      _items[i]['name'] = v;
                      _notify();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Dosis',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    controller: TextEditingController(text: _items[i]['mg']),
                    onChanged: (v) {
                      _items[i]['mg'] = v;
                      _notify();
                    },
                  ),
                ),
              ],
            ),
          ),
        TextButton.icon(
          onPressed: () {
            setState(() {
              _items.add({'name': '', 'mg': ''});
              _notify();
            });
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Agregar medicamento'),
        ),
      ],
    );
  }
}

class _FamilyHistoryListInput extends StatefulWidget {
  const _FamilyHistoryListInput({required this.value, required this.onChanged});
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  @override
  State<_FamilyHistoryListInput> createState() =>
      _FamilyHistoryListInputState();
}

class _FamilyHistoryListInputState extends State<_FamilyHistoryListInput> {
  late List<Map<String, String>> _items;

  @override
  void initState() {
    super.initState();
    _items = _parse(widget.value);
  }

  List<Map<String, String>> _parse(dynamic val) {
    if (val is List && val.isNotEmpty) {
      return val.map((item) {
        if (item is Map) {
          return {
            'condition': (item['condition'] ?? item['name'] ?? '').toString(),
            'relative': (item['relative'] ?? '').toString(),
          };
        }
        return {'condition': item.toString(), 'relative': ''};
      }).toList();
    }
    return [{'condition': '', 'relative': ''}];
  }

  void _notify() => widget.onChanged(_items);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < _items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Condición',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    controller:
                        TextEditingController(text: _items[i]['condition']),
                    onChanged: (v) {
                      _items[i]['condition'] = v;
                      _notify();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Familiar',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    controller:
                        TextEditingController(text: _items[i]['relative']),
                    onChanged: (v) {
                      _items[i]['relative'] = v;
                      _notify();
                    },
                  ),
                ),
              ],
            ),
          ),
        TextButton.icon(
          onPressed: () {
            setState(() {
              _items.add({'condition': '', 'relative': ''});
              _notify();
            });
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Agregar antecedente'),
        ),
      ],
    );
  }
}

class _SurgeryListInput extends StatefulWidget {
  const _SurgeryListInput({required this.value, required this.onChanged});
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  @override
  State<_SurgeryListInput> createState() => _SurgeryListInputState();
}

class _SurgeryListInputState extends State<_SurgeryListInput> {
  late List<Map<String, String>> _items;

  @override
  void initState() {
    super.initState();
    _items = _parse(widget.value);
  }

  List<Map<String, String>> _parse(dynamic val) {
    if (val is List && val.isNotEmpty) {
      return val.map((item) {
        if (item is Map) {
          return {
            'procedure': (item['procedure'] ?? item['name'] ?? '').toString(),
            'date': (item['date'] ?? '').toString(),
          };
        }
        return {'procedure': item.toString(), 'date': ''};
      }).toList();
    }
    return [{'procedure': '', 'date': ''}];
  }

  void _notify() => widget.onChanged(_items);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < _items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Procedimiento',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    controller:
                        TextEditingController(text: _items[i]['procedure']),
                    onChanged: (v) {
                      _items[i]['procedure'] = v;
                      _notify();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Fecha',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    controller:
                        TextEditingController(text: _items[i]['date']),
                    onChanged: (v) {
                      _items[i]['date'] = v;
                      _notify();
                    },
                  ),
                ),
              ],
            ),
          ),
        TextButton.icon(
          onPressed: () {
            setState(() {
              _items.add({'procedure': '', 'date': ''});
              _notify();
            });
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Agregar cirugía'),
        ),
      ],
    );
  }
}

class _QuestionField extends StatelessWidget {
  const _QuestionField({
    required this.itemId,
    required this.type,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String itemId;
  final String type;
  final List<String> options;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case 'numeric':
        return TextField(
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            hintText: 'Número',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => onChanged(v.trim()),
        );
      case 'short_text':
        return TextField(
          decoration: const InputDecoration(
            hintText: 'Respuesta corta',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: onChanged,
        );
      case 'yes_no':
        final opts = options.isNotEmpty ? options : const ['Sí', 'No'];
        return Wrap(
          spacing: 8,
          children: opts
              .map(
                (opt) => ChoiceChip(
                  label: Text(opt),
                  selected: value == opt,
                  onSelected: (_) => onChanged(opt),
                ),
              )
              .toList(),
        );
      case 'single_choice':
        if (options.isEmpty) {
          return TextField(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: onChanged,
          );
        }
        return DropdownButtonFormField<String>(
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: options
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: onChanged,
        );
      case 'multi_choice':
        final selected = (value as List<String>?) ?? <String>[];
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options
              .map(
                (opt) => FilterChip(
                  label: Text(opt),
                  selected: selected.contains(opt),
                  onSelected: (on) {
                    final next = List<String>.from(selected);
                    if (on) {
                      next.add(opt);
                    } else {
                      next.remove(opt);
                    }
                    onChanged(next);
                  },
                ),
              )
              .toList(),
        );
      default:
        return TextField(
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Escribe tu respuesta',
            border: OutlineInputBorder(),
          ),
          onChanged: onChanged,
        );
    }
  }
}
