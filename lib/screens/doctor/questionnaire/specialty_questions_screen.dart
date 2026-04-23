import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../models/questionnaire_models.dart';
import '../../../services/questionnaire_service.dart';
import '_widgets.dart';
import 'question_editor_screen.dart';

class SpecialtyQuestionsScreen extends StatefulWidget {
  const SpecialtyQuestionsScreen({
    super.key,
    required this.specialty,
    required this.service,
    required this.specialties,
  });

  final Specialty specialty;
  final QuestionnaireService service;
  final List<Specialty> specialties;

  @override
  State<SpecialtyQuestionsScreen> createState() => _SpecialtyQuestionsScreenState();
}

class _SpecialtyQuestionsScreenState extends State<SpecialtyQuestionsScreen> {
  QuestionStatusFilter _filter = QuestionStatusFilter.all;
  List<Question>? _all;
  String? _error;
  bool _loading = true;
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final qs = await widget.service.fetchSpecialtyQuestions(widget.specialty.id);
      if (!mounted) return;
      setState(() {
        _all = qs;
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

  List<Question> get _filtered {
    final base = _all ?? const [];
    final q = _search.text.trim().toLowerCase();
    return base.where((qq) {
      if (_filter == QuestionStatusFilter.active && !qq.isActive) return false;
      if (_filter == QuestionStatusFilter.inactive && qq.isActive) return false;
      if (q.isEmpty) return true;
      return qq.text.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _toggle(Question q, bool v) async {
    try {
      final updated = await widget.service.toggleQuestion(q.id, v);
      if (!mounted) return;
      setState(() {
        final list = _all ?? [];
        final idx = list.indexWhere((e) => e.id == q.id);
        if (idx >= 0) list[idx] = updated;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _edit(Question q) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => QuestionEditorScreen(
          service: widget.service,
          specialties: widget.specialties,
          initial: q,
          presetSpecialtyId: widget.specialty.id,
        ),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _duplicate(Question q) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => QuestionEditorScreen(
          service: widget.service,
          specialties: widget.specialties,
          initial: q,
          presetSpecialtyId: widget.specialty.id,
          forceDuplicate: true,
        ),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _delete(Question q) async {
    if (!q.isMine) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar pregunta'),
        content: const Text('¿Seguro que deseas eliminar esta pregunta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: KeepiColors.orange),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.service.deleteQuestion(q.id);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _newQuestion() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => QuestionEditorScreen(
          service: widget.service,
          specialties: widget.specialties,
          presetSpecialtyId: widget.specialty.id,
        ),
      ),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: KeepiColors.surfaceBg,
      appBar: AppBar(
        title: Text(widget.specialty.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: KeepiColors.orangeSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          iconForSpecialty(widget.specialty.icon ?? widget.specialty.slug),
                          color: KeepiColors.orange,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.specialty.description ??
                              'Preguntas base y propias de esta especialidad.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: KeepiColors.slateLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Buscar preguntas…',
                      prefixIcon: const Icon(Icons.search_rounded,
                          size: 20, color: KeepiColors.slateLight),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close,
                                  size: 18, color: KeepiColors.slateLight),
                              onPressed: () {
                                _search.clear();
                                setState(() {});
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  QStatusFilter(
                    value: _filter,
                    onChanged: (v) => setState(() => _filter = v),
                    totalAll: _all?.length ?? 0,
                    totalActive: (_all ?? []).where((e) => e.isActive).length,
                    totalInactive: (_all ?? []).where((e) => !e.isActive).length,
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
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(_error!),
                          ),
                        )
                      : RefreshIndicator(
                          color: KeepiColors.orange,
                          onRefresh: _load,
                          child: _filtered.isEmpty
                              ? ListView(
                                  children: [
                                    QEmptyState(
                                      icon: Icons.question_mark_rounded,
                                      title: 'Sin resultados',
                                      subtitle:
                                          'Prueba cambiando los filtros o crea una pregunta nueva para esta especialidad.',
                                      action: FilledButton.icon(
                                        onPressed: _newQuestion,
                                        icon: const Icon(Icons.add_rounded),
                                        label: const Text('Añadir pregunta'),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                                  itemCount: _filtered.length,
                                  itemBuilder: (_, i) {
                                    final q = _filtered[i];
                                    return QQuestionRow(
                                      question: q,
                                      onToggle: (v) => _toggle(q, v),
                                      onEdit: () => _edit(q),
                                      onDuplicate: () => _duplicate(q),
                                      onDelete: () => _delete(q),
                                    );
                                  },
                                ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newQuestion,
        backgroundColor: KeepiColors.orange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Añadir nueva pregunta'),
      ),
    );
  }
}
