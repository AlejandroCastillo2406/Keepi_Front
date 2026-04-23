import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../models/questionnaire_models.dart';
import '../../../services/questionnaire_service.dart';
import '_widgets.dart';

class QuestionEditorScreen extends StatefulWidget {
  const QuestionEditorScreen({
    super.key,
    required this.service,
    required this.specialties,
    this.initial,
    this.presetSpecialtyId,
    this.presetGlobal = false,
    this.forceDuplicate = false,
  });

  final QuestionnaireService service;
  final List<Specialty> specialties;
  final Question? initial;
  final String? presetSpecialtyId;
  final bool presetGlobal;
  final bool forceDuplicate;

  @override
  State<QuestionEditorScreen> createState() => _QuestionEditorScreenState();
}

class _QuestionEditorScreenState extends State<QuestionEditorScreen> {
  late final TextEditingController _text;
  late final TextEditingController _help;
  late final List<TextEditingController> _optionCtrls;

  QuestionResponseType _type = QuestionResponseType.shortText;
  String? _specialtyId;
  bool _isRequired = false;
  bool _showInHistory = true;
  bool _addHelp = false;
  bool _saving = false;
  String? _error;

  bool get _isEditingOwn =>
      widget.initial != null && widget.initial!.isMine && !widget.forceDuplicate;

  @override
  void initState() {
    super.initState();
    final q = widget.initial;
    _text = TextEditingController(text: q?.text ?? '');
    _help = TextEditingController(text: q?.helpText ?? '');
    _addHelp = (q?.helpText ?? '').trim().isNotEmpty;
    _type = q?.responseType ?? QuestionResponseType.shortText;
    _isRequired = q?.isRequired ?? false;
    _showInHistory = q?.showInHistory ?? true;

    // Specialty inicial
    if (widget.presetGlobal) {
      _specialtyId = null;
    } else if (widget.presetSpecialtyId != null) {
      _specialtyId = widget.presetSpecialtyId;
    } else {
      _specialtyId = q?.specialtyId;
    }

    final opts = q?.options ?? const <String>[];
    _optionCtrls = [
      for (final o in opts) TextEditingController(text: o),
    ];
    if (_type.needsOptions && _optionCtrls.length < 2) {
      while (_optionCtrls.length < 2) {
        _optionCtrls.add(TextEditingController());
      }
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _help.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _currentOptions => _optionCtrls
      .map((c) => c.text.trim())
      .where((s) => s.isNotEmpty)
      .toList(growable: false);

  bool get _isValid {
    if (_text.text.trim().length < 3) return false;
    if (_type.needsOptions && _currentOptions.length < 2) return false;
    return true;
  }

  Future<void> _save() async {
    if (!_isValid) {
      setState(() => _error = 'Completa la pregunta y al menos 2 opciones si aplica.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final options = _type.needsOptions ? _currentOptions : null;
      final helpText = _addHelp ? _help.text.trim() : '';
      if (_isEditingOwn) {
        await widget.service.updateQuestion(
          widget.initial!.id,
          specialtyId: _specialtyId,
          text: _text.text,
          responseType: _type,
          options: options,
          helpText: helpText,
          isRequired: _isRequired,
          showInHistory: _showInHistory,
        );
      } else {
        await widget.service.createQuestion(
          specialtyId: _specialtyId,
          text: _text.text,
          responseType: _type,
          options: options,
          helpText: helpText,
          isRequired: _isRequired,
          showInHistory: _showInHistory,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  void _addOption() {
    setState(() => _optionCtrls.add(TextEditingController()));
  }

  void _removeOption(int i) {
    setState(() {
      _optionCtrls[i].dispose();
      _optionCtrls.removeAt(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _isEditingOwn ? 'Editar pregunta' : 'Nueva pregunta';

    return Scaffold(
      backgroundColor: KeepiColors.surfaceBg,
      appBar: AppBar(
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 6, 10, 6),
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_saving)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.2,
                      ),
                    )
                  else
                    const Icon(Icons.check_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(_saving ? 'Guardando…' : 'Guardar'),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: KeepiColors.orangeSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: KeepiColors.orange.withOpacity(0.3)),
                ),
                child: Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(color: KeepiColors.slate),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text('Pregunta', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
              controller: _text,
              minLines: 2,
              maxLines: 4,
              maxLength: 200,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Escribe la pregunta que quieres realizar…',
              ),
            ),
            const SizedBox(height: 16),
            Text('Especialidad', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _SpecialtyPicker(
              value: _specialtyId,
              specialties: widget.specialties,
              onChanged: (v) => setState(() => _specialtyId = v),
            ),
            const SizedBox(height: 20),
            Text('Tipo de respuesta', style: theme.textTheme.titleSmall),
            const SizedBox(height: 10),
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                // Altura fija: evita overflow del contenido (icono + título + 2 líneas).
                mainAxisExtent: 132,
              ),
              children: QuestionResponseType.values
                  .map(
                    (t) => QResponseTypeCard(
                      type: t,
                      selected: _type == t,
                      onTap: () {
                        setState(() {
                          _type = t;
                          if (t.needsOptions && _optionCtrls.length < 2) {
                            while (_optionCtrls.length < 2) {
                              _optionCtrls.add(TextEditingController());
                            }
                          }
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
            if (_type.needsOptions) ...[
              const SizedBox(height: 20),
              Text('Opciones', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              ..._optionCtrls.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: KeepiColors.slateSoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${e.key + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: KeepiColors.slate,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: e.value,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Opción ${e.key + 1}',
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: KeepiColors.slateLight),
                        onPressed: _optionCtrls.length <= 2
                            ? null
                            : () => _removeOption(e.key),
                      ),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addOption,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Añadir opción'),
                ),
              ),
            ],
            const SizedBox(height: 20),
            _SwitchCard(
              title: 'Pregunta obligatoria',
              subtitle: 'El paciente deberá responderla antes de enviar el cuestionario.',
              value: _isRequired,
              onChanged: (v) => setState(() => _isRequired = v),
            ),
            const SizedBox(height: 8),
            _SwitchCard(
              title: 'Mostrar en historial',
              subtitle: 'La respuesta aparecerá en el expediente del paciente.',
              value: _showInHistory,
              onChanged: (v) => setState(() => _showInHistory = v),
            ),
            const SizedBox(height: 8),
            _SwitchCard(
              title: 'Agregar ayuda (opcional)',
              subtitle: 'Texto breve que se muestra bajo la pregunta.',
              value: _addHelp,
              onChanged: (v) => setState(() => _addHelp = v),
            ),
            if (_addHelp) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _help,
                maxLength: 200,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Ej. Indica si has tomado medicamento en las últimas 24h.',
                ),
              ),
            ],
            const SizedBox(height: 20),
            QAnswerPreview(
              type: _type,
              questionText: _text.text,
              options: _currentOptions,
            ),
          ],
        ),
      ),
    );
  }
}

class _SpecialtyPicker extends StatelessWidget {
  const _SpecialtyPicker({
    required this.value,
    required this.specialties,
    required this.onChanged,
  });

  final String? value;
  final List<Specialty> specialties;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KeepiColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          value: value,
          hint: const Text('Global (sin especialidad)'),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Row(
                children: [
                  Icon(Icons.public_outlined, size: 18, color: KeepiColors.slate),
                  SizedBox(width: 8),
                  Text('Global (sin especialidad)'),
                ],
              ),
            ),
            ...specialties.map(
              (s) => DropdownMenuItem<String?>(
                value: s.id,
                child: Row(
                  children: [
                    Icon(iconForSpecialty(s.icon ?? s.slug),
                        size: 18, color: KeepiColors.orange),
                    const SizedBox(width: 8),
                    Expanded(child: Text(s.name, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _SwitchCard extends StatelessWidget {
  const _SwitchCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KeepiColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: KeepiColors.slate,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: KeepiColors.slateLight,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: KeepiColors.orange,
            activeTrackColor: KeepiColors.orangeLight,
          ),
        ],
      ),
    );
  }
}
