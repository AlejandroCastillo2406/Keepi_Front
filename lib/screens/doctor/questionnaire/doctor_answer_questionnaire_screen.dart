import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_theme.dart';
import '../../../services/api_client.dart';
import '../../../services/doctor_service.dart';
import '../../../services/questionnaire_service.dart';

class DoctorAnswerQuestionnaireScreen extends StatefulWidget {
  const DoctorAnswerQuestionnaireScreen({
    super.key,
    required this.invitationId,
    required this.questionnaireName,
    required this.patientName,
  });

  final String invitationId;
  final String questionnaireName;
  final String patientName;

  @override
  State<DoctorAnswerQuestionnaireScreen> createState() =>
      _DoctorAnswerQuestionnaireScreenState();
}

class _DoctorAnswerQuestionnaireScreenState
    extends State<DoctorAnswerQuestionnaireScreen> {
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  List<Map<String, dynamic>> _questions = const [];
  final Map<String, dynamic> _answers = {};

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
      final data = await QuestionnaireService(context.read<ApiClient>())
          .fetchInvitationQuestionsForDoctor(widget.invitationId);
      if (!mounted) return;
      final raw = data['questions'];
      final list = raw is List
          ? raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];
      setState(() {
        _questions = list;
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

  Future<void> _submit() async {
    for (final q in _questions) {
      final itemId = (q['item_id'] ?? '').toString();
      final required = q['is_required'] == true;
      final value = _answers[itemId];
      if (!required) continue;
      if (value == null || (value is String && value.trim().isEmpty) || value == <String>[]) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Completa todas las preguntas obligatorias')),
        );
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      final payload = _answers.entries
          .map((e) => {'item_id': e.key, 'answer': e.value})
          .toList();
      await QuestionnaireService(context.read<ApiClient>()).submitDoctorInvitation(
        invitationId: widget.invitationId,
        answers: payload,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
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
        title: const Text(
          'Contestar cuestionario',
          style: TextStyle(
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
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        children: [
                          Container(
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
                                  widget.questionnaireName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: KeepiColors.slate,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Paciente: ${widget.patientName}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: KeepiColors.slateLight,
                                  ),
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
                          ),
                          const SizedBox(height: 18),
                          ..._questions.map(_buildQuestionCard),
                        ],
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _submitting ? null : _submit,
                            child: _submitting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Guardar respuestas'),
                          ),
                        ),
                      ),
                    ),
                  ],
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
              style: const TextStyle(fontSize: 12.5, color: KeepiColors.slateLight),
            ),
          ],
          const SizedBox(height: 12),
          _buildField(itemId, type, options),
        ],
      ),
    );
  }

  Widget _buildField(String itemId, String type, List<String> options) {
    switch (type) {
      case 'numeric':
        return TextField(
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            hintText: 'Número',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => _answers[itemId] = v.trim(),
        );
      case 'short_text':
        return TextField(
          decoration: const InputDecoration(
            hintText: 'Respuesta corta',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => _answers[itemId] = v,
        );
      case 'yes_no':
        final opts = options.isNotEmpty ? options : const ['Sí', 'No'];
        return Wrap(
          spacing: 8,
          children: opts
              .map(
                (opt) => ChoiceChip(
                  label: Text(opt),
                  selected: _answers[itemId] == opt,
                  onSelected: (_) => setState(() => _answers[itemId] = opt),
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
            onChanged: (v) => _answers[itemId] = v,
          );
        }
        return DropdownButtonFormField<String>(
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: options
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: (v) => setState(() => _answers[itemId] = v),
        );
      case 'multi_choice':
        final selected = (_answers[itemId] as List<String>?) ?? <String>[];
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options
              .map(
                (opt) => FilterChip(
                  label: Text(opt),
                  selected: selected.contains(opt),
                  onSelected: (on) {
                    setState(() {
                      final next = List<String>.from(selected);
                      if (on) {
                        next.add(opt);
                      } else {
                        next.remove(opt);
                      }
                      _answers[itemId] = next;
                    });
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
          onChanged: (v) => _answers[itemId] = v,
        );
    }
  }
}
