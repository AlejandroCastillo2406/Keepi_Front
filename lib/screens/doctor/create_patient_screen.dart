import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../models/questionnaire_models.dart';
import '../../services/api_client.dart';
import '../../services/doctor_service.dart';
import '../../services/questionnaire_service.dart';
import 'questionnaire/questionnaire_invite_picker_block.dart';

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
                QuestionnaireInvitePickerBlock(
                  title: 'Cuestionarios iniciales',
                  description:
                      'Selecciona plantillas y/o preguntas globales para enviar por link al paciente.',
                  loading: _loadingQuestionnaires,
                  error: _questionnaireError,
                  templates: _templates,
                  globalQuestions: _globalQuestions,
                  selectedTemplateIds: _selectedTemplateIds,
                  selectedQuestionIds: _selectedQuestionIds,
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
