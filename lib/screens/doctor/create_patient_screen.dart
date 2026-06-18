import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/web_layout.dart';
import '../../models/questionnaire_models.dart';
import '../../services/api_client.dart';
import '../../services/doctor_service.dart';
import '../../services/questionnaire_service.dart';

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
  bool _loadingTemplates = true;
  bool _enableClinicalIntake = true;
  bool _collectPriorDocuments = false;
  bool _enableQuestionnaire = false;
  List<TemplateSummary> _templates = const [];
  String? _selectedTemplateId;

  bool get _willSendInvite =>
      _enableClinicalIntake || _collectPriorDocuments || _enableQuestionnaire;

  String get _submitButtonLabel {
    if (!_willSendInvite) return 'Crear paciente';
    return 'Crear paciente y enviar enlace';
  }

  List<TemplateSummary> get _usableTemplates =>
      _templates.where((t) => t.totalQuestions > 0).toList();

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    try {
      final list = await QuestionnaireService(widget.api).fetchTemplates();
      if (!mounted) return;
      setState(() {
        _templates = list;
        _loadingTemplates = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingTemplates = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  String? _validateInvitationOptions() {
    if (!_willSendInvite) return null;
    if (!_enableClinicalIntake &&
        !_collectPriorDocuments &&
        !_enableQuestionnaire) {
      return 'Activa al menos una opción en la invitación web.';
    }
    if (_enableQuestionnaire) {
      if (_usableTemplates.isEmpty) {
        return 'No tienes plantillas con preguntas. Créalas en Ajustes → Cuestionarios.';
      }
      if (_selectedTemplateId == null || _selectedTemplateId!.isEmpty) {
        return 'Selecciona una plantilla de cuestionario.';
      }
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final inviteError = _validateInvitationOptions();
    if (inviteError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(inviteError),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.orange.shade900,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    final doctorSvc = DoctorService(widget.api);
    final questionnaireSvc = QuestionnaireService(widget.api);
    try {
      final created = await doctorSvc.createPatient(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
      );

      InvitationSendResult? invite;
      if (_willSendInvite) {
        final templateIds = _enableQuestionnaire && _selectedTemplateId != null
            ? [_selectedTemplateId!]
            : <String>[];
        invite = await questionnaireSvc.sendClinicalInvitation(
          patientId: created.id,
          enableClinicalIntake: _enableClinicalIntake,
          templateIds: templateIds,
          collectPriorDocuments: _collectPriorDocuments,
        );
      }

      if (!mounted) return;
      String snackMsg;
      if (invite == null) {
        snackMsg = 'Paciente creado: ${created.email}';
      } else if (!invite.emailSent) {
        snackMsg =
            'Paciente creado. El correo no se envió: ${invite.emailError ?? "revisa SES en el servidor"}.';
        if (invite.publicLink.isNotEmpty) {
          snackMsg += ' Link: ${invite.publicLink}';
        }
      } else {
        snackMsg = 'Paciente creado. Se envió el enlace por correo.';
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
      context.pop(true);
    }
  }

  void _handleClose() {
    if (_submitting) return;
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      context.pop(false);
    }
  }

  Widget _invitationSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required Color activeColor,
    required ValueChanged<bool>? onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: KeepiColors.slate,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12.5,
          color: KeepiColors.slateLight,
          height: 1.4,
        ),
      ),
      value: value,
      activeColor: activeColor,
      onChanged: onChanged,
    );
  }

  Widget _buildForm(ThemeData theme) {
    final anyInviteOn = _willSendInvite;

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
              'los completa el paciente en el enlace web.',
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
              'Activa solo lo que necesites. El paciente recibe un enlace con '
              'ficha clínica, documentos y/o cuestionario, según elijas.',
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
                  color: anyInviteOn
                      ? KeepiColors.green.withValues(alpha: 0.45)
                      : KeepiColors.cardBorder,
                ),
              ),
              child: Column(
                children: [
                  _invitationSwitch(
                    title: 'Ficha clínica previa',
                    subtitle:
                        'Datos, antecedentes, alergias y medicamentos.',
                    value: _enableClinicalIntake,
                    activeColor: KeepiColors.green,
                    onChanged: _submitting
                        ? null
                        : (v) => setState(() => _enableClinicalIntake = v),
                  ),
                  const Divider(height: 1),
                  _invitationSwitch(
                    title: 'Documentos médicos previos',
                    subtitle:
                        'El paciente podrá subir análisis, laboratorios o informes (opcional).',
                    value: _collectPriorDocuments,
                    activeColor: KeepiColors.skyBlue,
                    onChanged: _submitting
                        ? null
                        : (v) => setState(() => _collectPriorDocuments = v),
                  ),
                  const Divider(height: 1),
                  _invitationSwitch(
                    title: 'Cuestionario',
                    subtitle:
                        'El paciente responderá una plantilla que elijas.',
                    value: _enableQuestionnaire,
                    activeColor: KeepiColors.orange,
                    onChanged: _submitting
                        ? null
                        : (v) => setState(() {
                              _enableQuestionnaire = v;
                              if (!v) _selectedTemplateId = null;
                              else if (_selectedTemplateId == null &&
                                  _usableTemplates.length == 1) {
                                _selectedTemplateId = _usableTemplates.first.id;
                              }
                            }),
                  ),
                  if (_enableQuestionnaire) ...[
                    const SizedBox(height: 8),
                    if (_loadingTemplates)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    else if (_usableTemplates.isEmpty)
                      Text(
                        'No tienes plantillas con preguntas. Créalas en Ajustes → Cuestionarios.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: KeepiColors.slateLight,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: _selectedTemplateId,
                        decoration: const InputDecoration(
                          labelText: 'Plantilla',
                          helperText: 'Solo puedes elegir una plantilla.',
                          border: OutlineInputBorder(),
                        ),
                        isExpanded: true,
                        items: _usableTemplates
                            .map(
                              (t) => DropdownMenuItem(
                                value: t.id,
                                child: Text(
                                  '${t.name} (${t.totalQuestions} preguntas)',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _submitting
                            ? null
                            : (v) => setState(() => _selectedTemplateId = v),
                        validator: (_) => null,
                      ),
                  ],
                ],
              ),
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

    if (widget.embedded) {
      return EmbeddedWebPage(
        title: 'Nuevo paciente',
        onBack: _submitting ? null : _handleClose,
        child: SafeArea(child: _buildForm(theme)),
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
      body: SafeArea(child: _buildForm(theme)),
    );
  }
}
