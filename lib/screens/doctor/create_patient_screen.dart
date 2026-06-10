import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/web_layout.dart';
import '../../models/questionnaire_models.dart';
import '../../services/api_client.dart';
import '../../services/doctor_service.dart';
import '../../services/questionnaire_service.dart';
import 'questionnaire/questionnaire_invite_picker_block.dart';

class CreatePatientScreen extends StatefulWidget {
  const CreatePatientScreen({
    super.key,
    required this.api,
    this.embedded = false,
    this.onBack,
    this.onCreated,
  });

  final ApiClient api;
  final bool embedded;
  final VoidCallback? onBack;
  final VoidCallback? onCreated;

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
  bool _useDynamicQuestionnaire = false;
  bool _enableClinicalIntake = false;
  bool _collectPriorDocuments = false;

  bool get _willSendQuestionnaire =>
      _useDynamicQuestionnaire ||
      _selectedTemplateIds.isNotEmpty ||
      _selectedQuestionIds.isNotEmpty;

  bool get _willSendIntakeOnly =>
      _enableClinicalIntake && !_willSendQuestionnaire;

  bool get _willSendLink => _enableClinicalIntake || _willSendQuestionnaire;

  String get _submitButtonLabel {
    if (!_willSendLink) return 'Crear paciente';
    if (_willSendIntakeOnly) return 'Crear paciente y enviar ficha';
    if (_enableClinicalIntake && _willSendQuestionnaire) {
      return 'Crear paciente y enviar ficha + cuestionario';
    }
    return 'Crear paciente y enviar cuestionario';
  }

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

  void _setDynamicQuestionnaire(bool value) {
    setState(() {
      _useDynamicQuestionnaire = value;
      if (value) {
        _selectedTemplateIds.clear();
        _selectedQuestionIds.clear();
      }
    });
  }

  void _setEnableClinicalIntake(bool value) {
    setState(() {
      _enableClinicalIntake = value;
      if (!value) {
        _collectPriorDocuments = false;
      }
    });
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
      final collectPrior =
          _enableClinicalIntake && _collectPriorDocuments;

      if (_willSendIntakeOnly) {
        invite = await questionnaireSvc.sendIntakeOnlyInvitation(
          patientId: created.id,
          collectPriorDocuments: collectPrior,
        );
      } else if (_useDynamicQuestionnaire) {
        invite = await questionnaireSvc.sendInvitationBatch(
          patientId: created.id,
          useDynamicQuestionnaire: true,
          collectPriorDocuments: collectPrior,
          enableClinicalIntake: _enableClinicalIntake,
        );
      } else if (_selectedTemplateIds.isNotEmpty ||
          _selectedQuestionIds.isNotEmpty) {
        invite = await questionnaireSvc.sendInvitationBatch(
          patientId: created.id,
          templateIds: _selectedTemplateIds.toList(),
          questionIds: _selectedQuestionIds.toList(),
          collectPriorDocuments: collectPrior,
          enableClinicalIntake: _enableClinicalIntake,
        );
      }

      if (!mounted) return;
      String snackMsg;
      if (invite == null) {
        snackMsg = 'Paciente creado: ${created.email}';
      } else if (!invite.emailSent) {
        snackMsg =
            'Paciente creado. El correo no se envió: ${invite.emailError ?? "revisa SES en el servidor"}. '
            'Puedes copiar el link desde la respuesta de la API o reintentar.';
        if (invite.publicLink.isNotEmpty) {
          snackMsg += ' Link: ${invite.publicLink}';
        }
      } else if (_willSendIntakeOnly) {
        snackMsg =
            'Paciente creado. Se envió por correo el enlace para completar la ficha clínica.';
      } else if (_useDynamicQuestionnaire) {
        snackMsg = _enableClinicalIntake
            ? 'Paciente creado. Se envió el enlace con ficha clínica y cuestionario IA.'
            : 'Paciente creado. Se envió el enlace del cuestionario dinámico (IA).';
      } else {
        snackMsg = _enableClinicalIntake
            ? 'Paciente creado. Se envió el enlace con ficha clínica y cuestionario.'
            : 'Paciente creado. Se envió el enlace del cuestionario.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(snackMsg),
          behavior: SnackBarBehavior.floating,
          backgroundColor: invite != null && !invite.emailSent
              ? Colors.orange.shade900
              : null,
        ),
      );
      _finishAfterCreate();
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

  void _finishAfterCreate() {
    if (widget.onCreated != null) {
      widget.onCreated!();
    } else if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.of(context).pop(true);
    }
  }

  void _handleClose() {
    if (_submitting) return;
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.of(context).pop(false);
    }
  }

  Widget _buildForm(ThemeData theme, bool showPriorDocsHint) {
    return WebContentFrame(
          maxWidth: 720,
          padding: EdgeInsets.fromLTRB(
            widget.embedded ? 28 : 20,
            widget.embedded ? 8 : 16,
            widget.embedded ? 28 : 20,
            20,
          ),
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
                  'Solo nombre y correo aquí. Teléfono, antecedentes y el resto '
                  'los completa el paciente en el enlace temporal.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: KeepiColors.slateLight,
                  ),
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
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requerido' : null,
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
                Text(
                  'Invitación web',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: KeepiColors.slate,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Activa ficha clínica, cuestionario o las dos. Si solo activas la ficha, '
                  'el paciente no verá preguntas de cuestionario.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: KeepiColors.slateLight,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _enableClinicalIntake
                          ? KeepiColors.green.withValues(alpha: 0.45)
                          : KeepiColors.cardBorder,
                    ),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Ficha clínica previa',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: KeepiColors.slate,
                          ),
                        ),
                        subtitle: const Text(
                          'Datos, antecedentes, alergias y medicamentos en el enlace. '
                          'Opcionalmente puedes pedir documentos previos y combinar con cuestionario.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: KeepiColors.slateLight,
                            height: 1.4,
                          ),
                        ),
                        value: _enableClinicalIntake,
                        activeColor: KeepiColors.green,
                        onChanged:
                            _submitting ? null : _setEnableClinicalIntake,
                      ),
                      if (_enableClinicalIntake) ...[
                        const Divider(height: 1),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Documentos médicos previos',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: KeepiColors.slate,
                            ),
                          ),
                          subtitle: const Text(
                            'Tras completar la ficha, el paciente podrá subir análisis, '
                            'laboratorios o informes anteriores (opcional).',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: KeepiColors.slateLight,
                              height: 1.4,
                            ),
                          ),
                          value: _collectPriorDocuments,
                          activeColor: KeepiColors.skyBlue,
                          onChanged: _submitting
                              ? null
                              : (v) =>
                                  setState(() => _collectPriorDocuments = v),
                        ),
                      ],
                    ],
                  ),
                ),
                if (showPriorDocsHint) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: KeepiColors.skyBlueSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: KeepiColors.skyBlue.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.upload_file_rounded,
                          color: KeepiColors.skyBlue,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Los documentos se piden justo después de la ficha clínica, '
                            'antes del cuestionario (si lo envías).',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: KeepiColors.slate,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  'Cuestionario (opcional)',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: KeepiColors.slate,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _useDynamicQuestionnaire
                          ? KeepiColors.orange.withValues(alpha: 0.45)
                          : KeepiColors.cardBorder,
                    ),
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Cuestionario dinámico con IA',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: KeepiColors.slate,
                      ),
                    ),
                    subtitle: const Text(
                      'AWS Bedrock adapta cada pregunta según la respuesta anterior. '
                      'Máximo 10 preguntas. Al activarlo, las plantillas quedan deshabilitadas.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: KeepiColors.slateLight,
                        height: 1.4,
                      ),
                    ),
                    value: _useDynamicQuestionnaire,
                    activeColor: KeepiColors.orange,
                    onChanged: _submitting ? null : _setDynamicQuestionnaire,
                  ),
                ),
                const SizedBox(height: 14),
                QuestionnaireInvitePickerBlock(
                  title: 'Plantillas y preguntas',
                  description:
                      'Selecciona plantillas y/o preguntas globales. '
                      'No disponible si activas el cuestionario dinámico.',
                  loading: _loadingQuestionnaires,
                  error: _questionnaireError,
                  templates: _templates,
                  globalQuestions: _globalQuestions,
                  selectedTemplateIds: _selectedTemplateIds,
                  selectedQuestionIds: _selectedQuestionIds,
                  enabled: !_useDynamicQuestionnaire,
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
                      : Text(_submitButtonLabel),
                ),
              ],
            ),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showPriorDocsHint =
        _enableClinicalIntake && _collectPriorDocuments;

    if (widget.embedded) {
      return EmbeddedWebPage(
        title: 'Nuevo paciente',
        onBack: _submitting ? null : _handleClose,
        child: SafeArea(child: _buildForm(theme, showPriorDocsHint)),
      );
    }

    return Scaffold(
      backgroundColor: KeepiColors.surfaceBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _submitting ? null : _handleClose,
        ),
        title: const Text('Nuevo paciente'),
      ),
      body: SafeArea(child: _buildForm(theme, showPriorDocsHint)),
    );
  }
}
