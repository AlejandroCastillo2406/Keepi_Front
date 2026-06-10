import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/web_layout.dart';
import '../../services/api_client.dart';
import '../../services/scheduling_service.dart';
import '../../widgets/profile_settings_widgets.dart';

const _weekdayLabels = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

const _weekdayShort = ['LU', 'MA', 'MI', 'JU', 'VI', 'SA', 'DO'];

class DoctorSchedulingSettingsScreen extends StatefulWidget {
  const DoctorSchedulingSettingsScreen({
    super.key,
    this.canSkip = false,
    this.onFinished,
    this.embedded = false,
    this.onBack,
  });

  final bool canSkip;
  final VoidCallback? onFinished;
  /// Sin Scaffold: se muestra dentro del shell web (navbar visible).
  final bool embedded;
  final VoidCallback? onBack;

  @override
  State<DoctorSchedulingSettingsScreen> createState() =>
      _DoctorSchedulingSettingsScreenState();
}

class _DayRuleEditor {
  _DayRuleEditor({
    required this.weekday,
    required this.enabled,
    required this.start,
    required this.end,
  });

  final int weekday;
  bool enabled;
  TimeOfDay start;
  TimeOfDay end;
}

class _DoctorSchedulingSettingsScreenState
    extends State<DoctorSchedulingSettingsScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  int _slotDuration = 30;
  final List<_DayRuleEditor> _days = List.generate(
    7,
    (i) => _DayRuleEditor(
      weekday: i,
      enabled: i < 5,
      start: const TimeOfDay(hour: 9, minute: 0),
      end: const TimeOfDay(hour: 17, minute: 0),
    ),
  );

  int get _activeDaysCount => _days.where((d) => d.enabled).length;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = SchedulingService(context.read<ApiClient>());
      final settings = await svc.fetchSettings();
      final rules = await svc.fetchRules();
      if (!mounted) return;
      for (final d in _days) {
        d.enabled = false;
      }
      for (final r in rules) {
        if (r.weekday < 0 || r.weekday > 6) continue;
        final d = _days[r.weekday];
        d.enabled = r.isEnabled;
        d.start = _parseTime(r.startTime, d.start);
        d.end = _parseTime(r.endTime, d.end);
      }
      setState(() {
        _slotDuration = settings.slotDurationMinutes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = SchedulingService.messageFromDio(e);
        _loading = false;
      });
    }
  }

  TimeOfDay _parseTime(String raw, TimeOfDay fallback) {
    final parts = raw.split(':');
    if (parts.length != 2) return fallback;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return fallback;
    return TimeOfDay(hour: h, minute: m);
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(_DayRuleEditor day, bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? day.start : day.end,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: KeepiColors.orange),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        day.start = picked;
      } else {
        day.end = picked;
      }
    });
  }

  void _copyMondayToWeekdays() {
    final monday = _days[0];
    if (!monday.enabled) return;
    setState(() {
      for (var i = 1; i <= 4; i++) {
        _days[i].enabled = true;
        _days[i].start = monday.start;
        _days[i].end = monday.end;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Horario de Lunes aplicado a Mar–Vie'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final svc = SchedulingService(context.read<ApiClient>());
      await svc.updateSettings(
        slotDurationMinutes: _slotDuration,
        timezone: 'America/Mexico_City',
      );
      final rules = _days
          .where((d) => d.enabled)
          .map(
            (d) => AvailabilityRuleDto(
              weekday: d.weekday,
              startTime: _formatTime(d.start),
              endTime: _formatTime(d.end),
              isEnabled: true,
            ),
          )
          .toList();
      await svc.saveRules(rules);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Horario guardado'),
          backgroundColor: KeepiColors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onFinished?.call();
      if (widget.canSkip) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = SchedulingService.messageFromDio(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _handleBack() {
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }
    Navigator.of(context).maybePop();
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          onPressed: _handleBack,
          icon: const Icon(Icons.arrow_back_rounded, color: KeepiColors.slate),
          tooltip: 'Volver',
        ),
        const Expanded(
          child: Text(
            'Horario de consulta',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: KeepiColors.slate,
              letterSpacing: -0.3,
            ),
          ),
        ),
        if (widget.canSkip)
          TextButton(
            onPressed: _saving
                ? null
                : () {
                    widget.onFinished?.call();
                    _handleBack();
                  },
            child: const Text('Omitir'),
          ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: KeepiColors.orangeSoft.withValues(alpha: 0.55),
              shape: BoxShape.circle,
              border: Border.all(
                color: KeepiColors.orange.withValues(alpha: 0.35),
              ),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              color: KeepiColors.orange,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_activeDaysCount días activos · $_slotDuration min por cita',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: KeepiColors.slate,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Los pacientes solo ven huecos libres en estos horarios.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: KeepiColors.slateLight,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.timelapse_rounded, size: 18, color: KeepiColors.orange),
              SizedBox(width: 8),
              Text(
                'Duración de cada cita',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                  color: KeepiColors.slate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _slotDuration,
            decoration: InputDecoration(
              filled: true,
              fillColor: KeepiColors.surfaceBg,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: KeepiColors.cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: KeepiColors.cardBorder),
              ),
            ),
            items: const [
              DropdownMenuItem(value: 15, child: Text('15 minutos')),
              DropdownMenuItem(value: 30, child: Text('30 minutos')),
              DropdownMenuItem(value: 45, child: Text('45 minutos')),
              DropdownMenuItem(value: 60, child: Text('60 minutos')),
            ],
            onChanged: _saving
                ? null
                : (v) {
                    if (v != null) setState(() => _slotDuration = v);
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildTimeChip({
    required String label,
    required TimeOfDay time,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: KeepiColors.orangeSoft.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: KeepiColors.orange.withValues(alpha: 0.28),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: KeepiColors.slateLight,
                letterSpacing: 0.4,
              ),
            ),
            Text(
              _formatTime(time),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: KeepiColors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayTile(_DayRuleEditor day, {required bool isLast}) {
    final short = _weekdayShort[day.weekday];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: KeepiColors.cardBorder),
              ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: day.enabled
                      ? KeepiColors.orangeSoft.withValues(alpha: 0.55)
                      : KeepiColors.slateSoft,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: day.enabled
                        ? KeepiColors.orange.withValues(alpha: 0.35)
                        : KeepiColors.cardBorder,
                  ),
                ),
                child: Text(
                  short,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: day.enabled
                        ? KeepiColors.orange
                        : KeepiColors.slateLight,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _weekdayLabels[day.weekday],
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: day.enabled
                        ? KeepiColors.slate
                        : KeepiColors.slateLight,
                  ),
                ),
              ),
              Switch.adaptive(
                value: day.enabled,
                activeColor: KeepiColors.orange,
                onChanged: _saving
                    ? null
                    : (v) => setState(() => day.enabled = v),
              ),
            ],
          ),
          if (day.enabled) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildTimeChip(
                    label: 'INICIO',
                    time: day.start,
                    onTap: _saving ? null : () => _pickTime(day, true),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: KeepiColors.slateLight,
                  ),
                ),
                Expanded(
                  child: _buildTimeChip(
                    label: 'FIN',
                    time: day.end,
                    onTap: _saving ? null : () => _pickTime(day, false),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDaysCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Días y horarios',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                  color: KeepiColors.slate,
                ),
              ),
            ),
            if (_days[0].enabled)
              TextButton.icon(
                onPressed: _saving ? null : _copyMondayToWeekdays,
                icon: const Icon(Icons.copy_all_rounded, size: 16),
                label: const Text('Copiar Lunes → Vie'),
                style: TextButton.styleFrom(
                  foregroundColor: KeepiColors.skyBlue,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: KeepiColors.cardBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < _days.length; i++)
                _buildDayTile(_days[i], isLast: i == _days.length - 1),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return FilledButton(
      onPressed: _saving ? null : _save,
      style: FilledButton.styleFrom(
        backgroundColor: KeepiColors.orange,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _saving
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Text(
              'Guardar horario',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: KeepiColors.orange),
      );
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.embedded) _buildHeader() else const SizedBox.shrink(),
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: KeepiColors.orangeSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: KeepiColors.orange.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              _error!,
              style: const TextStyle(color: KeepiColors.slate),
            ),
          ),
          const SizedBox(height: 14),
        ],
        const ProfileSectionDivider(tag: 'RESUMEN', count: 1),
        const SizedBox(height: 12),
        _buildSummaryCard(),
        const SizedBox(height: 22),
        const ProfileSectionDivider(tag: 'CITAS', count: 1),
        const SizedBox(height: 12),
        _buildDurationCard(),
        const SizedBox(height: 22),
        const ProfileSectionDivider(tag: 'DISPONIBILIDAD', count: 7),
        const SizedBox(height: 12),
        _buildDaysCard(),
        const SizedBox(height: 24),
        _buildSaveButton(),
      ],
    );

    return WebContentFrame(
      maxWidth: 680,
      padding: EdgeInsets.zero,
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPad = isWebWide(context) || widget.embedded ? 28.0 : 18.0;

    if (widget.embedded) {
      return ColoredBox(
        color: KeepiColors.surfaceBg,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(horizontalPad, 8, horizontalPad, 32),
          child: _buildBody(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: KeepiColors.surfaceBg,
      appBar: AppBar(
        title: const Text('Horario de consulta'),
        actions: [
          if (widget.canSkip)
            TextButton(
              onPressed: _saving
                  ? null
                  : () {
                      widget.onFinished?.call();
                      Navigator.of(context).pop();
                    },
              child: const Text('Omitir'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(horizontalPad, 12, horizontalPad, 28),
        child: _buildBody(),
      ),
    );
  }
}
