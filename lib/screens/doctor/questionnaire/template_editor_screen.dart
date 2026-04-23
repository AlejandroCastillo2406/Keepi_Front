import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../models/questionnaire_models.dart';
import '../../../services/questionnaire_service.dart';
import '_widgets.dart';

class TemplateEditorScreen extends StatefulWidget {
  const TemplateEditorScreen({
    super.key,
    required this.service,
    required this.specialties,
    this.existing,
  });

  final QuestionnaireService service;
  final List<Specialty> specialties;
  final TemplateSummary? existing;

  @override
  State<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends State<TemplateEditorScreen> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  String? _specialtyId;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  String? _templateId;
  List<Question> _selected = [];

  bool get _isEditing => _templateId != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _description = TextEditingController(text: widget.existing?.description ?? '');
    _specialtyId = widget.existing?.specialtyId;
    _templateId = widget.existing?.id;
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!_isEditing) {
      setState(() => _loading = false);
      return;
    }
    try {
      final detail = await widget.service.fetchTemplate(_templateId!);
      if (!mounted) return;
      setState(() {
        _selected = detail.questions;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'El nombre debe tener al menos 2 caracteres.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (!_isEditing) {
        final created = await widget.service.createTemplate(
          name: name,
          description: _description.text,
          specialtyId: _specialtyId,
        );
        _templateId = created.id;
      } else {
        await widget.service.updateTemplate(
          _templateId!,
          name: name,
          description: _description.text,
          specialtyId: _specialtyId,
        );
      }
      await widget.service.upsertTemplateQuestions(
        _templateId!,
        _selected.map((q) => q.id).toList(),
      );
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

  Future<void> _openPicker() async {
    final selectedIds = _selected.map((e) => e.id).toSet();
    final result = await Navigator.of(context).push<List<Question>>(
      MaterialPageRoute(
        builder: (_) => _QuestionPickerScreen(
          service: widget.service,
          specialties: widget.specialties,
          initiallySelected: selectedIds,
          initialSpecialtyId: _specialtyId,
        ),
      ),
    );
    if (result == null) return;
    // mantener orden existente; agregar nuevos al final
    final existingIds = _selected.map((e) => e.id).toSet();
    final merged = <Question>[..._selected];
    for (final q in result) {
      if (!existingIds.contains(q.id)) merged.add(q);
    }
    // quitar los desmarcados
    final resultIds = result.map((e) => e.id).toSet();
    merged.removeWhere((q) => !resultIds.contains(q.id));
    setState(() => _selected = merged);
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _selected.removeAt(oldIndex);
      _selected.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: KeepiColors.surfaceBg,
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar plantilla' : 'Nueva plantilla'),
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
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: KeepiColors.orange, strokeWidth: 2.5),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                        TextField(
                          controller: _name,
                          maxLength: 120,
                          decoration: const InputDecoration(
                            labelText: 'Nombre de la plantilla',
                            hintText: 'Ej. Primera consulta cardio',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _description,
                          maxLength: 200,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Descripción (opcional)',
                          ),
                        ),
                        const SizedBox(height: 12),
                        _SpecialtyPickerInline(
                          value: _specialtyId,
                          specialties: widget.specialties,
                          onChanged: (v) => setState(() => _specialtyId = v),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Preguntas (${_selected.length})',
                              style: theme.textTheme.titleSmall,
                            ),
                            TextButton.icon(
                              onPressed: _openPicker,
                              icon: const Icon(Icons.playlist_add_rounded, size: 18),
                              label: const Text('Añadir preguntas'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _selected.isEmpty
                        ? QEmptyState(
                            icon: Icons.list_alt_rounded,
                            title: 'Sin preguntas aún',
                            subtitle:
                                'Agrega preguntas base o tuyas para construir esta plantilla. Puedes reordenarlas después.',
                            action: FilledButton.icon(
                              onPressed: _openPicker,
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Añadir preguntas'),
                            ),
                          )
                        : ReorderableListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _selected.length,
                            onReorder: _reorder,
                            itemBuilder: (_, i) {
                              final q = _selected[i];
                              return _TemplateQuestionTile(
                                key: ValueKey(q.id),
                                index: i + 1,
                                question: q,
                                onRemove: () {
                                  setState(() => _selected.removeAt(i));
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SpecialtyPickerInline extends StatelessWidget {
  const _SpecialtyPickerInline({
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
          hint: const Text('Sin especialidad (opcional)'),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Sin especialidad'),
            ),
            ...specialties.map(
              (s) => DropdownMenuItem<String?>(
                value: s.id,
                child: Text(s.name),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _TemplateQuestionTile extends StatelessWidget {
  const _TemplateQuestionTile({
    super.key,
    required this.index,
    required this.question,
    required this.onRemove,
  });

  final int index;
  final Question question;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KeepiColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.drag_indicator_rounded, color: KeepiColors.slateLight),
          const SizedBox(width: 6),
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: KeepiColors.orangeSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: KeepiColors.orange,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question.text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${question.responseType.label} · '
                  '${question.specialtyName ?? 'Global'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: KeepiColors.slateLight,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, color: KeepiColors.slateLight),
          ),
        ],
      ),
    );
  }
}

class _QuestionPickerScreen extends StatefulWidget {
  const _QuestionPickerScreen({
    required this.service,
    required this.specialties,
    required this.initiallySelected,
    this.initialSpecialtyId,
  });

  final QuestionnaireService service;
  final List<Specialty> specialties;
  final Set<String> initiallySelected;
  final String? initialSpecialtyId;

  @override
  State<_QuestionPickerScreen> createState() => _QuestionPickerScreenState();
}

class _QuestionPickerScreenState extends State<_QuestionPickerScreen> {
  final TextEditingController _search = TextEditingController();
  late Set<String> _selected;
  String? _scopeSpecialtyId;
  bool _showGlobals = true;

  List<Question> _items = [];
  Map<String, Question> _byId = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initiallySelected};
    _scopeSpecialtyId = widget.initialSpecialtyId;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final futures = <Future<List<Question>>>[];
      if (_showGlobals) futures.add(widget.service.fetchGlobalQuestions());
      if (_scopeSpecialtyId != null) {
        futures.add(widget.service.fetchSpecialtyQuestions(_scopeSpecialtyId!));
      } else {
        // Si no hay scope, cargar todas las especialidades
        for (final s in widget.specialties) {
          futures.add(widget.service.fetchSpecialtyQuestions(s.id));
        }
      }
      final results = await Future.wait(futures);
      final combined = <String, Question>{};
      for (final list in results) {
        for (final q in list) {
          combined[q.id] = q;
        }
      }
      if (!mounted) return;
      setState(() {
        _byId = combined;
        _items = combined.values.toList()
          ..sort((a, b) => a.text.toLowerCase().compareTo(b.text.toLowerCase()));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  List<Question> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return _items.where((qq) {
      if (q.isEmpty) return true;
      return qq.text.toLowerCase().contains(q) ||
          (qq.specialtyName ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KeepiColors.surfaceBg,
      appBar: AppBar(
        title: const Text(
          'Añadir preguntas',
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
              onPressed: () {
                final result = _selected
                    .map((id) => _byId[id])
                    .whereType<Question>()
                    .toList();
                Navigator.of(context).pop(result);
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text('Usar (${_selected.length})'),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Column(
                children: [
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Buscar preguntas…',
                      prefixIcon: Icon(Icons.search_rounded,
                          size: 20, color: KeepiColors.slateLight),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 46,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.only(right: 4),
                      child: Row(
                        children: [
                          _ScopeChip(
                            label: 'Globales',
                            selected: _showGlobals,
                            onTap: () {
                              setState(() => _showGlobals = !_showGlobals);
                              _load();
                            },
                          ),
                          const SizedBox(width: 8),
                          _ScopeChip(
                            label: 'Todas las especialidades',
                            selected: _scopeSpecialtyId == null,
                            onTap: () {
                              setState(() => _scopeSpecialtyId = null);
                              _load();
                            },
                          ),
                          const SizedBox(width: 8),
                          ...widget.specialties.map(
                            (s) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _ScopeChip(
                                label: s.name,
                                selected: _scopeSpecialtyId == s.id,
                                onTap: () {
                                  setState(() => _scopeSpecialtyId = s.id);
                                  _load();
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: KeepiColors.orange, strokeWidth: 2.5),
                    )
                  : _error != null
                      ? Center(child: Text(_error!))
                      : _filtered.isEmpty
                          ? const QEmptyState(
                              icon: Icons.search_off_rounded,
                              title: 'Sin resultados',
                              subtitle: 'Ajusta los filtros o cambia la búsqueda.',
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              itemCount: _filtered.length,
                              itemBuilder: (_, i) {
                                final q = _filtered[i];
                                final checked = _selected.contains(q.id);
                                return InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () {
                                    setState(() {
                                      if (checked) {
                                        _selected.remove(q.id);
                                      } else {
                                        _selected.add(q.id);
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: KeepiColors.cardBg,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: checked
                                            ? KeepiColors.orange
                                            : KeepiColors.cardBorder,
                                        width: checked ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: checked,
                                          activeColor: KeepiColors.orange,
                                          onChanged: (v) {
                                            setState(() {
                                              if (v == true) {
                                                _selected.add(q.id);
                                              } else {
                                                _selected.remove(q.id);
                                              }
                                            });
                                          },
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                q.text,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: KeepiColors.slate,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${q.responseType.label} · '
                                                '${q.specialtyName ?? 'Global'}'
                                                '${q.isMine ? ' · Propia' : ''}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: KeepiColors.slateLight,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScopeChip extends StatelessWidget {
  const _ScopeChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? KeepiColors.orangeSoft : KeepiColors.cardBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? KeepiColors.orange : KeepiColors.cardBorder,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? KeepiColors.orange : KeepiColors.slate,
          ),
        ),
      ),
    );
  }
}
