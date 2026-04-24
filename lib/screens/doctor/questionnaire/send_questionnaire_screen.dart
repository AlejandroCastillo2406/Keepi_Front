import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../models/questionnaire_models.dart';
import '../../../services/api_client.dart';
import '../../../services/doctor_service.dart';
import '../../../services/questionnaire_service.dart';
import 'questionnaire_invite_picker_block.dart';

/// Envía un cuestionario de salud por link al paciente en cualquier momento.
class SendQuestionnaireScreen extends StatefulWidget {
  const SendQuestionnaireScreen({
    super.key,
    required this.api,
    required this.patientId,
    required this.patientName,
    this.patientEmail,
  });

  final ApiClient api;
  final String patientId;
  final String patientName;
  final String? patientEmail;

  @override
  State<SendQuestionnaireScreen> createState() => _SendQuestionnaireScreenState();
}

class _SendQuestionnaireScreenState extends State<SendQuestionnaireScreen> {
  bool _loadingQuestionnaires = true;
  String? _questionnaireError;
  List<TemplateSummary> _templates = [];
  List<Question> _globalQuestions = [];
  final Set<String> _selectedTemplateIds = <String>{};
  final Set<String> _selectedQuestionIds = <String>{};
  bool _submitting = false;

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

  bool get _hasSelection =>
      _selectedTemplateIds.isNotEmpty || _selectedQuestionIds.isNotEmpty;

  Future<void> _submit() async {
    if (!_hasSelection || _submitting) return;
    setState(() => _submitting = true);
    final questionnaireSvc = QuestionnaireService(widget.api);
    try {
      final invite = await questionnaireSvc.sendInvitationBatch(
        patientId: widget.patientId,
        templateIds: _selectedTemplateIds.toList(),
        questionIds: _selectedQuestionIds.toList(),
      );
      if (!mounted) return;
      final String snackMsg;
      if (!invite.emailSent) {
        snackMsg =
            'El correo no se envió: ${invite.emailError ?? "revisa SES en el servidor"}. '
            'El cuestionario quedó registrado; revisa logs o reintenta.';
      } else {
        snackMsg = 'Cuestionario enviado por correo a ${widget.patientEmail ?? "el paciente"}.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(snackMsg),
          behavior: SnackBarBehavior.floating,
          backgroundColor: !invite.emailSent ? Colors.orange.shade900 : null,
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
        title: const Text('Enviar cuestionario'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: ListView(
            children: [
              Text(
                widget.patientName,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: KeepiColors.slate,
                  letterSpacing: -0.3,
                ),
              ),
              if ((widget.patientEmail ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  widget.patientEmail!.trim(),
                  style: theme.textTheme.bodyMedium?.copyWith(color: KeepiColors.slateLight),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                'El paciente recibirá un enlace seguro para responder. Puedes reenviar otro cuestionario cuando lo necesites.',
                style: theme.textTheme.bodySmall?.copyWith(color: KeepiColors.slateLight, height: 1.4),
              ),
              const SizedBox(height: 20),
              QuestionnaireInvitePickerBlock(
                title: 'Contenido del cuestionario',
                description:
                    'Marca al menos una plantilla o una pregunta global. Se generará un solo link con todo el lote.',
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
                onPressed: (_submitting || !_hasSelection) ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Enviar por correo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
