import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/app_theme.dart';
import '../../../core/web_layout.dart';
import '../../../models/questionnaire_models.dart';
import '../../../providers/patients_cache_provider.dart';
import '../../../services/api_client.dart';
import '../../../services/doctor_service.dart';
import '../../../services/questionnaire_service.dart';

/// Reenvía el enlace web al paciente (ficha, documentos y/o cuestionario).
class SendQuestionnaireScreen extends StatefulWidget {
  const SendQuestionnaireScreen({
    super.key,
    required this.api,
    required this.patientId,
    required this.patientName,
    this.patientEmail,
    this.embedded = false,
    this.onBack,
  });

  final ApiClient api;
  final String patientId;
  final String patientName;
  final String? patientEmail;
  final bool embedded;
  final VoidCallback? onBack;

  @override
  State<SendQuestionnaireScreen> createState() => _SendQuestionnaireScreenState();
}

class _SendQuestionnaireScreenState extends State<SendQuestionnaireScreen> {
  bool _submitting = false;
  bool _loadingTemplates = true;
  bool _enableClinicalIntake = true;
  bool _collectPriorDocuments = false;
  bool _enableQuestionnaire = false;
  List<TemplateSummary> _templates = const [];
  String? _selectedTemplateId;

  List<TemplateSummary> get _usableTemplates =>
      _templates.where((t) => t.totalQuestions > 0).toList();

  bool get _willSendInvite =>
      _enableClinicalIntake || _collectPriorDocuments || _enableQuestionnaire;

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

  String? _validateOptions() {
    if (!_willSendInvite) {
      return 'Activa al menos una opción para enviar el enlace.';
    }
    if (_enableQuestionnaire) {
      if (_usableTemplates.isEmpty) {
        return 'No tienes plantillas con preguntas.';
      }
      if (_selectedTemplateId == null) {
        return 'Selecciona una plantilla de cuestionario.';
      }
    }
    return null;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final err = _validateOptions();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _submitting = true);
    final questionnaireSvc = QuestionnaireService(widget.api);
    try {
      final templateIds = _enableQuestionnaire && _selectedTemplateId != null
          ? [_selectedTemplateId!]
          : <String>[];
      final invite = await questionnaireSvc.sendClinicalInvitation(
        patientId: widget.patientId,
        enableClinicalIntake: _enableClinicalIntake,
        templateIds: templateIds,
        collectPriorDocuments: _collectPriorDocuments,
      );
      if (!mounted) return;
      context.read<PatientsCacheProvider>().invalidateProfile(widget.patientId);
      final snackMsg = invite.emailSent
          ? 'Enlace enviado por correo.'
          : 'El correo no se envió: ${invite.emailError ?? "revisa SES"}.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(snackMsg),
          behavior: SnackBarBehavior.floating,
          backgroundColor: !invite.emailSent ? Colors.orange.shade900 : null,
        ),
      );
      _closeAfterSuccess();
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

  void _closeAfterSuccess() {
    if (widget.onBack != null) {
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

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Color color,
    required ValueChanged<bool>? onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12.5, height: 1.4)),
      value: value,
      activeColor: color,
      onChanged: onChanged,
    );
  }

  Widget _buildForm(ThemeData theme) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.embedded ? 28 : 20,
        widget.embedded ? 8 : 16,
        widget.embedded ? 28 : 20,
        20,
      ),
      child: ListView(
        children: [
          Text(
            widget.patientName,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: KeepiColors.slate,
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
            'Activa solo lo que necesites. Todo va en un solo enlace.',
            style: theme.textTheme.bodySmall?.copyWith(color: KeepiColors.slateLight),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: KeepiColors.cardBorder),
            ),
            child: Column(
              children: [
                _switchTile(
                  title: 'Ficha clínica previa',
                  subtitle: 'Datos, antecedentes, alergias y medicamentos.',
                  value: _enableClinicalIntake,
                  color: KeepiColors.green,
                  onChanged: _submitting ? null : (v) => setState(() => _enableClinicalIntake = v),
                ),
                const Divider(height: 1),
                _switchTile(
                  title: 'Documentos médicos previos',
                  subtitle: 'Subida opcional de estudios o informes.',
                  value: _collectPriorDocuments,
                  color: KeepiColors.skyBlue,
                  onChanged: _submitting ? null : (v) => setState(() => _collectPriorDocuments = v),
                ),
                const Divider(height: 1),
                _switchTile(
                  title: 'Cuestionario',
                  subtitle: 'Una plantilla de preguntas preparada por ti.',
                  value: _enableQuestionnaire,
                  color: KeepiColors.orange,
                  onChanged: _submitting
                      ? null
                      : (v) => setState(() {
                            _enableQuestionnaire = v;
                            if (!v) {
                              _selectedTemplateId = null;
                            } else if (_selectedTemplateId == null &&
                                _usableTemplates.length == 1) {
                              _selectedTemplateId = _usableTemplates.first.id;
                            }
                          }),
                ),
                if (_enableQuestionnaire && !_loadingTemplates && _usableTemplates.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedTemplateId,
                    decoration: const InputDecoration(
                      labelText: 'Plantilla',
                      helperText: 'Solo una plantilla por envío.',
                      border: OutlineInputBorder(),
                    ),
                    isExpanded: true,
                    items: _usableTemplates
                        .map(
                          (t) => DropdownMenuItem(
                            value: t.id,
                            child: Text('${t.name} (${t.totalQuestions} preguntas)'),
                          ),
                        )
                        .toList(),
                    onChanged: _submitting ? null : (v) => setState(() => _selectedTemplateId = v),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(_submitting ? 'Enviando…' : 'Enviar enlace por correo'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.embedded) {
      return EmbeddedWebPage(
        title: 'Enviar ficha clínica',
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
        title: const Text('Enviar ficha clínica'),
      ),
      body: SafeArea(child: _buildForm(theme)),
    );
  }
}
