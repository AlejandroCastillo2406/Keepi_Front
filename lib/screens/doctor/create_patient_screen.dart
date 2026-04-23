import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../models/questionnaire_models.dart';
import '../../services/api_client.dart';
import '../../services/doctor_service.dart';
import '../../services/questionnaire_service.dart';

class CreatePatientScreen extends StatefulWidget {
  const CreatePatientScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<CreatePatientScreen> createState() => _CreatePatientScreenState();
}

class _CreatePatientScreenState extends State<CreatePatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _submitting = false;
  bool _loadingQuestionnaires = true;
  String? _questionnaireError;
  List<TemplateSummary> _templates = [];
  List<Question> _globalQuestions = [];
  final Set<String> _selectedTemplateIds = <String>{};
  final Set<String> _selectedQuestionIds = <String>{};
  int _expiryHours = 72;

  @override
  void initState() {
    super.initState();
    _loadQuestionnaires();
  }

  Future<void> _loadQuestionnaires() async {
    final svc = QuestionnaireService(widget.api);
    setState(() {
      _loadingQuestionnaires = true;
      _questionnaireError = null;
    });
    try {
      final results = await Future.wait([
        svc.fetchTemplates(),
        svc.fetchGlobalQuestions(status: QuestionStatusFilter.active),
      ]);
      if (!mounted) return;
      setState(() {
        _templates = results[0] as List<TemplateSummary>;
        _globalQuestions = results[1] as List<Question>;
        _loadingQuestionnaires = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _questionnaireError = DoctorService.messageFromDio(e);
        _loadingQuestionnaires = false;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final doctorSvc = DoctorService(widget.api);
    final questionnaireSvc = QuestionnaireService(widget.api);
    try {
      final created = await doctorSvc.createPatient(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
      );

      InvitationSendResult? invite;
      if (_selectedTemplateIds.isNotEmpty || _selectedQuestionIds.isNotEmpty) {
        invite = await questionnaireSvc.sendInvitationBatch(
          patientId: created.id,
          templateIds: _selectedTemplateIds.toList(),
          questionIds: _selectedQuestionIds.toList(),
          expiresInHours: _expiryHours,
        );
      }

      if (!mounted) return;
      final String snackMsg;
      if (invite == null) {
        snackMsg = 'Paciente creado: ${created.email}';
      } else if (!invite.emailSent) {
        snackMsg =
            'Paciente creado. El correo del cuestionario no se envió: ${invite.emailError ?? "revisa SES en el servidor"}. '
            'Puedes copiar el link desde la respuesta de la API o reintentar.';
      } else {
        snackMsg = 'Paciente creado y cuestionario enviado por correo.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(snackMsg),
          behavior: SnackBarBehavior.floating,
          backgroundColor: invite != null && !invite.emailSent ? Colors.orange.shade900 : null,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(DoctorService.messageFromDio(e)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: KeepiColors.surfaceBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
        ),
        title: const Text('Nuevo paciente'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                Text(
                  'Datos de contacto',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: KeepiColors.slate,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Opcionalmente puedes enviar cuestionarios iniciales por link público.',
                  style: theme.textTheme.bodySmall?.copyWith(color: KeepiColors.slateLight),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    hintText: 'Como aparecerá en la app',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    hintText: 'ejemplo@correo.com',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Requerido';
                    if (!v.contains('@')) return 'Correo no válido';
                    return null;
                  },
                ),
                const SizedBox(height: 22),
                _QuestionnaireBlock(
                  loading: _loadingQuestionnaires,
                  error: _questionnaireError,
                  templates: _templates,
                  globalQuestions: _globalQuestions,
                  selectedTemplateIds: _selectedTemplateIds,
                  selectedQuestionIds: _selectedQuestionIds,
                  expiryHours: _expiryHours,
                  onRetry: _loadQuestionnaires,
                  onToggleTemplate: (id, value) {
                    setState(() {
                      if (value) {
                        _selectedTemplateIds.add(id);
                      } else {
                        _selectedTemplateIds.remove(id);
                      }
                    });
                  },
                  onToggleQuestion: (id, value) {
                    setState(() {
                      if (value) {
                        _selectedQuestionIds.add(id);
                      } else {
                        _selectedQuestionIds.remove(id);
                      }
                    });
                  },
                  onExpiryChanged: (value) {
                    if (value == null) return;
                    setState(() => _expiryHours = value);
                  },
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Crear paciente y enviar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestionnaireBlock extends StatelessWidget {
  const _QuestionnaireBlock({
    required this.loading,
    required this.error,
    required this.templates,
    required this.globalQuestions,
    required this.selectedTemplateIds,
    required this.selectedQuestionIds,
    required this.expiryHours,
    required this.onRetry,
    required this.onToggleTemplate,
    required this.onToggleQuestion,
    required this.onExpiryChanged,
  });

  final bool loading;
  final String? error;
  final List<TemplateSummary> templates;
  final List<Question> globalQuestions;
  final Set<String> selectedTemplateIds;
  final Set<String> selectedQuestionIds;
  final int expiryHours;
  final VoidCallback onRetry;
  final void Function(String id, bool value) onToggleTemplate;
  final void Function(String id, bool value) onToggleQuestion;
  final ValueChanged<int?> onExpiryChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cuestionarios iniciales',
            style: TextStyle(fontWeight: FontWeight.w700, color: KeepiColors.slate),
          ),
          const SizedBox(height: 6),
          const Text(
            'Selecciona plantillas y/o preguntas globales para enviar por link al paciente.',
            style: TextStyle(fontSize: 12.5, color: KeepiColors.slateLight),
          ),
          const SizedBox(height: 12),
          if (loading)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
          else if (error != null)
            Row(
              children: [
                Expanded(child: Text(error!, style: const TextStyle(color: Colors.red))),
                TextButton(onPressed: onRetry, child: const Text('Reintentar')),
              ],
            )
          else ...[
            const Text('Plantillas', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            for (final t in templates)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(t.name),
                subtitle: Text('${t.totalQuestions} preguntas'),
                value: selectedTemplateIds.contains(t.id),
                onChanged: (v) => onToggleTemplate(t.id, v ?? false),
              ),
            const SizedBox(height: 8),
            const Text('Preguntas adicionales', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            for (final q in globalQuestions)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(q.text, maxLines: 2, overflow: TextOverflow.ellipsis),
                value: selectedQuestionIds.contains(q.id),
                onChanged: (v) => onToggleQuestion(q.id, v ?? false),
              ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: expiryHours,
              decoration: const InputDecoration(labelText: 'Vencimiento del link'),
              items: const [24, 48, 72, 168]
                  .map((h) => DropdownMenuItem<int>(value: h, child: Text('$h horas')))
                  .toList(),
              onChanged: onExpiryChanged,
            ),
          ],
        ],
      ),
    );
  }
}
