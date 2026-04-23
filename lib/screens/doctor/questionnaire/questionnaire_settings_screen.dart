import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_theme.dart';
import '../../../models/questionnaire_models.dart';
import '../../../services/api_client.dart';
import '../../../services/questionnaire_service.dart';
import '_widgets.dart';
import 'question_editor_screen.dart';
import 'specialty_questions_screen.dart';
import 'template_editor_screen.dart';

/// Shell con 3 pestañas: Especialidades / Plantillas personalizadas / Preguntas globales.
class QuestionnaireSettingsScreen extends StatefulWidget {
  const QuestionnaireSettingsScreen({super.key});

  @override
  State<QuestionnaireSettingsScreen> createState() => _QuestionnaireSettingsScreenState();
}

class _QuestionnaireSettingsScreenState extends State<QuestionnaireSettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final QuestionnaireService _service;

  final TextEditingController _search = TextEditingController();
  QuestionStatusFilter _globalsFilter = QuestionStatusFilter.all;

  List<Specialty>? _specialties;
  List<TemplateSummary>? _templates;
  List<Question>? _globals;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this)..addListener(() => setState(() {}));
    _service = QuestionnaireService(context.read<ApiClient>());
    _loadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.fetchSpecialties(),
        _service.fetchTemplates(),
        _service.fetchGlobalQuestions(status: _globalsFilter),
      ]);
      if (!mounted) return;
      setState(() {
        _specialties = results[0] as List<Specialty>;
        _templates = results[1] as List<TemplateSummary>;
        _globals = results[2] as List<Question>;
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

  Future<void> _reloadGlobals() async {
    try {
      final globals = await _service.fetchGlobalQuestions(status: _globalsFilter);
      if (!mounted) return;
      setState(() => _globals = globals);
    } catch (_) {}
  }

  Future<void> _reloadSpecialties() async {
    try {
      final list = await _service.fetchSpecialties();
      if (!mounted) return;
      setState(() => _specialties = list);
    } catch (_) {}
  }

  Future<void> _reloadTemplates() async {
    try {
      final list = await _service.fetchTemplates();
      if (!mounted) return;
      setState(() => _templates = list);
    } catch (_) {}
  }

  Iterable<Specialty> get _filteredSpecialties {
    final q = _search.text.trim().toLowerCase();
    final list = _specialties ?? const <Specialty>[];
    if (q.isEmpty) return list;
    return list.where((s) =>
        s.name.toLowerCase().contains(q) ||
        (s.description ?? '').toLowerCase().contains(q));
  }

  Iterable<Question> get _filteredGlobals {
    final q = _search.text.trim().toLowerCase();
    final list = _globals ?? const <Question>[];
    if (q.isEmpty) return list;
    return list.where((e) => e.text.toLowerCase().contains(q));
  }

  Iterable<TemplateSummary> get _filteredTemplates {
    final q = _search.text.trim().toLowerCase();
    final list = _templates ?? const <TemplateSummary>[];
    if (q.isEmpty) return list;
    return list.where((e) =>
        e.name.toLowerCase().contains(q) ||
        (e.description ?? '').toLowerCase().contains(q) ||
        (e.specialtyName ?? '').toLowerCase().contains(q));
  }

  Future<void> _onPrimaryCtaPressed() async {
    switch (_tabs.index) {
      case 0:
        await _openQuestionEditor();
        break;
      case 1:
        await _openTemplateEditor();
        break;
      case 2:
        await _openQuestionEditor(global: true);
        break;
    }
  }

  Future<void> _openQuestionEditor({
    Question? existing,
    String? presetSpecialtyId,
    bool global = false,
  }) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => QuestionEditorScreen(
          service: _service,
          specialties: _specialties ?? const [],
          initial: existing,
          presetSpecialtyId: presetSpecialtyId,
          presetGlobal: global,
        ),
      ),
    );
    if (changed == true) {
      await Future.wait([_reloadSpecialties(), _reloadGlobals()]);
    }
  }

  Future<void> _openTemplateEditor({TemplateSummary? existing}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TemplateEditorScreen(
          service: _service,
          specialties: _specialties ?? const [],
          existing: existing,
        ),
      ),
    );
    if (changed == true) {
      await _reloadTemplates();
    }
  }

  String get _ctaLabel {
    switch (_tabs.index) {
      case 1:
        return 'Nueva plantilla';
      default:
        return 'Nueva pregunta';
    }
  }

  IconData get _ctaIcon {
    switch (_tabs.index) {
      case 1:
        return Icons.playlist_add_rounded;
      default:
        return Icons.add_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: KeepiColors.surfaceBg,
      appBar: AppBar(
        title: const Text('Cuestionarios de salud'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: KeepiColors.surfaceBg,
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              labelColor: KeepiColors.orange,
              unselectedLabelColor: KeepiColors.slateLight,
              indicatorColor: KeepiColors.orange,
              indicatorWeight: 2.5,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              tabs: const [
                Tab(text: 'Especialidades'),
                Tab(text: 'Plantillas'),
                Tab(text: 'Globales'),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Buscar…',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20, color: KeepiColors.slateLight),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close, size: 18, color: KeepiColors.slateLight),
                                onPressed: () {
                                  _search.clear();
                                  setState(() {});
                                },
                              ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Material(
                    color: KeepiColors.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _onPrimaryCtaPressed,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: const LinearGradient(
                            colors: [KeepiColors.orange, KeepiColors.orangeLight],
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_ctaIcon, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              _ctaLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Container(
                  width: double.infinity,
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
              ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: KeepiColors.orange, strokeWidth: 2.5),
                    )
                  : TabBarView(
                      controller: _tabs,
                      children: [
                        _buildSpecialtiesTab(),
                        _buildTemplatesTab(),
                        _buildGlobalsTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecialtiesTab() {
    final items = _filteredSpecialties.toList();
    if (items.isEmpty) {
      return RefreshIndicator(
        color: KeepiColors.orange,
        onRefresh: _reloadSpecialties,
        child: ListView(
          children: const [
            QEmptyState(
              icon: Icons.medical_services_outlined,
              title: 'Sin especialidades disponibles',
              subtitle: 'Contacta a soporte para habilitar las especialidades base.',
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: KeepiColors.orange,
      onRefresh: _reloadSpecialties,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final spec = items[i];
          return QSpecialtyTile(
            specialty: spec,
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SpecialtyQuestionsScreen(
                    specialty: spec,
                    service: _service,
                    specialties: _specialties ?? const [],
                  ),
                ),
              );
              await _reloadSpecialties();
            },
          );
        },
      ),
    );
  }

  Widget _buildTemplatesTab() {
    final items = _filteredTemplates.toList();
    if (items.isEmpty) {
      return RefreshIndicator(
        color: KeepiColors.orange,
        onRefresh: _reloadTemplates,
        child: ListView(
          children: [
            QEmptyState(
              icon: Icons.auto_awesome_motion_outlined,
              title: 'Aún no tienes plantillas',
              subtitle:
                  'Crea una plantilla personalizada para agrupar las preguntas que usas con más frecuencia.',
              action: FilledButton.icon(
                onPressed: () => _openTemplateEditor(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nueva plantilla'),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: KeepiColors.orange,
      onRefresh: _reloadTemplates,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final t = items[i];
          return _TemplateTile(
            template: t,
            onTap: () => _openTemplateEditor(existing: t),
            onDelete: () async {
              final ok = await _confirmDialog(
                title: 'Eliminar plantilla',
                message: '¿Seguro que deseas eliminar "${t.name}"?',
                confirmLabel: 'Eliminar',
              );
              if (ok != true) return;
              try {
                await _service.deleteTemplate(t.id);
                await _reloadTemplates();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error eliminando: $e')),
                );
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildGlobalsTab() {
    final items = _filteredGlobals.toList();
    return RefreshIndicator(
      color: KeepiColors.orange,
      onRefresh: _reloadGlobals,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
        children: [
          QStatusFilter(
            value: _globalsFilter,
            onChanged: (v) {
              setState(() => _globalsFilter = v);
              _reloadGlobals();
            },
            totalAll: _globals?.length ?? 0,
            totalActive: (_globals ?? []).where((e) => e.isActive).length,
            totalInactive: (_globals ?? []).where((e) => !e.isActive).length,
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            QEmptyState(
              icon: Icons.public_outlined,
              title: 'Sin preguntas globales',
              subtitle: 'Crea una pregunta global para que aplique a cualquier especialidad.',
              action: FilledButton.icon(
                onPressed: () => _openQuestionEditor(global: true),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nueva pregunta global'),
              ),
            )
          else
            ...items.map(
              (q) => QQuestionRow(
                question: q,
                onToggle: (v) => _toggleQuestion(q, v),
                onEdit: q.isMine
                    ? () => _openQuestionEditor(existing: q, global: true)
                    : () {},
                onDuplicate: () => _openQuestionEditor(
                  existing: q,
                  global: q.specialtyId == null,
                  presetSpecialtyId: q.specialtyId,
                ),
                onDelete: () => _deleteQuestion(q),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _toggleQuestion(Question q, bool v) async {
    try {
      await _service.toggleQuestion(q.id, v);
      await Future.wait([_reloadGlobals(), _reloadSpecialties()]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _deleteQuestion(Question q) async {
    if (!q.isMine) return;
    final ok = await _confirmDialog(
      title: 'Eliminar pregunta',
      message: '¿Seguro que quieres eliminar esta pregunta?',
      confirmLabel: 'Eliminar',
    );
    if (ok != true) return;
    try {
      await _service.deleteQuestion(q.id);
      await Future.wait([_reloadGlobals(), _reloadSpecialties()]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<bool?> _confirmDialog({
    required String title,
    required String message,
    String confirmLabel = 'Aceptar',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: KeepiColors.orange,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({
    required this.template,
    required this.onTap,
    required this.onDelete,
  });

  final TemplateSummary template;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: KeepiColors.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: KeepiColors.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: KeepiColors.skyBlueSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome_motion_outlined,
                    color: KeepiColors.skyBlue, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if ((template.description ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        template.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: KeepiColors.slateLight,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: KeepiColors.orangeSoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${template.totalQuestions} preguntas',
                            style: const TextStyle(
                              fontSize: 11,
                              color: KeepiColors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (template.specialtyName != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: KeepiColors.slateSoft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              template.specialtyName!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: KeepiColors.slate,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: KeepiColors.slateLight),
                onPressed: onDelete,
                tooltip: 'Eliminar',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
