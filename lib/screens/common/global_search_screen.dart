import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/decorative_background.dart';
import '../../services/api_client.dart';
import '../../services/doctor_service.dart';
import '../../services/search_result_navigation.dart';
import '../../services/search_service.dart';

enum _SearchSection { all, appointment, document, analysis }

/// Pantalla dedicada de búsqueda global (citas, documentos, análisis).
class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({
    super.key,
    this.patients,
    this.onDoctorOpenAgenda,
  });

  final List<PatientListItem>? patients;
  final VoidCallback? onDoctorOpenAgenda;

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  List<GlobalSearchItem> _results = [];
  bool _loading = true;
  String? _error;
  _SearchSection _section = _SearchSection.all;

  static const _sectionOrder = [
    _SearchSection.appointment,
    _SearchSection.document,
    _SearchSection.analysis,
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _runSearch(query: null);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String? _apiItemType(_SearchSection section) {
    switch (section) {
      case _SearchSection.all:
        return null;
      case _SearchSection.appointment:
        return 'appointment';
      case _SearchSection.document:
        return 'document';
      case _SearchSection.analysis:
        return 'analysis';
    }
  }

  Future<void> _runSearch({String? query}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = SearchService(context.read<ApiClient>());
      final rows = await svc.search(
        query: query,
        itemType: _apiItemType(_section),
      );
      if (!mounted) return;
      setState(() {
        _results = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = SearchService.messageFromDio(e);
        _loading = false;
        _results = [];
      });
    }
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _runSearch(query: value.trim().isEmpty ? null : value);
    });
  }

  void _onSectionChanged(_SearchSection section) {
    if (_section == section) return;
    setState(() => _section = section);
    _runSearch(query: _controller.text.trim().isEmpty ? null : _controller.text);
  }

  IconData _iconFor(_SearchSection section) {
    switch (section) {
      case _SearchSection.appointment:
        return Icons.event_rounded;
      case _SearchSection.document:
        return Icons.description_outlined;
      case _SearchSection.analysis:
        return Icons.biotech_outlined;
      case _SearchSection.all:
        return Icons.apps_rounded;
    }
  }

  Color _colorFor(_SearchSection section) {
    switch (section) {
      case _SearchSection.appointment:
        return KeepiColors.orange;
      case _SearchSection.document:
        return KeepiColors.skyBlue;
      case _SearchSection.analysis:
        return KeepiColors.green;
      case _SearchSection.all:
        return KeepiColors.slate;
    }
  }

  String _sectionTag(_SearchSection section) {
    switch (section) {
      case _SearchSection.appointment:
        return 'CITAS';
      case _SearchSection.document:
        return 'DOCUMENTOS';
      case _SearchSection.analysis:
        return 'ANÁLISIS';
      case _SearchSection.all:
        return 'TODO';
    }
  }

  String _sectionLabel(_SearchSection section) {
    switch (section) {
      case _SearchSection.appointment:
        return 'Citas';
      case _SearchSection.document:
        return 'Documentos';
      case _SearchSection.analysis:
        return 'Análisis';
      case _SearchSection.all:
        return 'Todos';
    }
  }

  String _formatDate(DateTime d) {
    final local = d.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }

  List<GlobalSearchItem> _itemsForSection(_SearchSection section) {
    if (section == _SearchSection.all) return _results;
    final type = _apiItemType(section);
    return _results.where((r) => r.type == type).toList();
  }

  List<_SearchSection> get _visibleSections {
    if (_section != _SearchSection.all) return [_section];
    return _sectionOrder
        .where((s) => _itemsForSection(s).isNotEmpty)
        .toList();
  }

  Future<void> _openItem(GlobalSearchItem item) async {
    await SearchResultNavigation.open(
      context,
      item,
      patients: widget.patients,
      onDoctorOpenAgenda: widget.onDoctorOpenAgenda != null
          ? () {
              Navigator.of(context).pop();
              widget.onDoctorOpenAgenda!();
            }
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: KeepiColors.surfaceBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: KeepiColors.slate),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Buscar',
          style: TextStyle(
            color: KeepiColors.slate,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: DecorativeBackground(
        blobOpacity: 0.15,
        child: SafeArea(
          top: false,
          child: RefreshIndicator(
            color: KeepiColors.orange,
            onRefresh: () => _runSearch(
              query: _controller.text.trim().isEmpty ? null : _controller.text,
            ),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                Text(
                  'Citas, documentos y análisis que has añadido',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: KeepiColors.slateLight,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  onChanged: _onQueryChanged,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre, motivo, categoría…',
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: KeepiColors.slateLight,
                    ),
                    suffixIcon: _controller.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 20),
                            onPressed: () {
                              _controller.clear();
                              _runSearch(query: null);
                            },
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: KeepiColors.cardBorder.withValues(alpha: 0.8),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: KeepiColors.cardBorder.withValues(alpha: 0.8),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: KeepiColors.orange,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _SectionChip(
                        label: 'Todos',
                        icon: _iconFor(_SearchSection.all),
                        accent: _colorFor(_SearchSection.all),
                        selected: _section == _SearchSection.all,
                        onTap: () => _onSectionChanged(_SearchSection.all),
                      ),
                      const SizedBox(width: 8),
                      _SectionChip(
                        label: 'Citas',
                        icon: _iconFor(_SearchSection.appointment),
                        accent: _colorFor(_SearchSection.appointment),
                        selected: _section == _SearchSection.appointment,
                        onTap: () =>
                            _onSectionChanged(_SearchSection.appointment),
                      ),
                      const SizedBox(width: 8),
                      _SectionChip(
                        label: 'Documentos',
                        icon: _iconFor(_SearchSection.document),
                        accent: _colorFor(_SearchSection.document),
                        selected: _section == _SearchSection.document,
                        onTap: () => _onSectionChanged(_SearchSection.document),
                      ),
                      const SizedBox(width: 8),
                      _SectionChip(
                        label: 'Análisis',
                        icon: _iconFor(_SearchSection.analysis),
                        accent: _colorFor(_SearchSection.analysis),
                        selected: _section == _SearchSection.analysis,
                        onTap: () => _onSectionChanged(_SearchSection.analysis),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: KeepiColors.orange,
                        ),
                      ),
                    ),
                  )
                else if (_error != null)
                  _EmptySectionHint(label: _error!)
                else if (_results.isEmpty)
                  _EmptySectionHint(
                    label: _section == _SearchSection.all
                        ? 'No hay elementos recientes'
                        : 'No hay ${_sectionLabel(_section).toLowerCase()}',
                  )
                else if (_visibleSections.isEmpty)
                  const _EmptySectionHint(
                    label: 'No hay resultados en esta sección',
                  )
                else
                  ..._visibleSections.expand((sec) {
                    final items = _itemsForSection(sec);
                    final accent = _colorFor(sec);
                    return [
                      _SearchSectionHeader(
                        tag: _sectionTag(sec),
                        count: items.length,
                        icon: _iconFor(sec),
                        accent: accent,
                      ),
                      const SizedBox(height: 10),
                      _SearchSectionCard(
                        children: [
                          for (int i = 0; i < items.length; i++) ...[
                            _SearchResultTile(
                              item: items[i],
                              icon: _iconFor(sec),
                              accent: accent,
                              dateLabel: _formatDate(items[i].date),
                              onTap: () => _openItem(items[i]),
                            ),
                            if (i < items.length - 1)
                              Divider(
                                height: 1,
                                indent: 56,
                                color:
                                    KeepiColors.cardBorder.withValues(alpha: 0.8),
                              ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 20),
                    ];
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionChip extends StatelessWidget {
  const _SectionChip({
    required this.label,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.14)
                : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.55)
                  : KeepiColors.cardBorder.withValues(alpha: 0.8),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? accent : KeepiColors.slateLight,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? accent : KeepiColors.slate,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchSectionHeader extends StatelessWidget {
  const _SearchSectionHeader({
    required this.tag,
    required this.count,
    required this.icon,
    required this.accent,
  });

  final String tag;
  final int count;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: accent),
        ),
        const SizedBox(width: 10),
        Container(
          width: 18,
          height: 1,
          color: KeepiColors.slate.withValues(alpha: 0.45),
        ),
        const SizedBox(width: 10),
        Text(
          tag,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
            color: KeepiColors.slate,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            count.toString().padLeft(2, '0'),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: accent,
              letterSpacing: 0.3,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: KeepiColors.slate.withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }
}

class _SearchSectionCard extends StatelessWidget {
  const _SearchSectionCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: KeepiColors.cardBorder.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: KeepiColors.slate.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _EmptySectionHint extends StatelessWidget {
  const _EmptySectionHint({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: KeepiColors.cardBorder.withValues(alpha: 0.5),
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: KeepiColors.slateLight,
              ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.item,
    required this.icon,
    required this.accent,
    required this.dateLabel,
    required this.onTap,
  });

  final GlobalSearchItem item;
  final IconData icon;
  final Color accent;
  final String dateLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: KeepiColors.slate,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: KeepiColors.slateLight,
                      ),
                    ),
                    if (item.subtitle != null && item.subtitle!.isNotEmpty)
                      Text(
                        item.subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: KeepiColors.slateLight.withValues(alpha: 0.9),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: KeepiColors.slateLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
