import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/keepi_timezone.dart';
import '../core/app_theme.dart';
import '../core/web_layout.dart';
import '../services/api_client.dart';
import '../services/appointment_service.dart';
import '../services/calendar_export_save.dart';
import 'keepi_web_dialog.dart';

enum DoctorCalendarIcsRange {
  oneMonth(1, 'Próximo mes'),
  threeMonths(3, 'Próximos 3 meses'),
  sixMonths(6, 'Próximos 6 meses'),
  oneYear(12, 'Próximo año');

  const DoctorCalendarIcsRange(this.months, this.label);

  final int months;
  final String label;
}

class DoctorCalendarIcsExportOptions {
  const DoctorCalendarIcsExportOptions({
    required this.range,
    required this.includeScheduled,
    required this.includePending,
    required this.includeProcedures,
  });

  final DoctorCalendarIcsRange range;
  final bool includeScheduled;
  final bool includePending;
  final bool includeProcedures;

  bool get hasSelection =>
      includeScheduled || includePending || includeProcedures;

  (DateTime from, DateTime to) resolveRange() {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day);
    final to = DateTime(
      from.year,
      from.month + range.months,
      from.day,
      23,
      59,
      59,
    );
    return (from, to);
  }
}

Future<void> showDoctorCalendarIcsExportDialog(BuildContext context) async {
  if (isWebWide(context)) {
    await KeepiWebDialogShell.show<void>(
      context,
      title: 'Exportar calendario',
      subtitle: 'Elige qué eventos incluir. Las horas coinciden con tu agenda en Keepi.',
      icon: Icons.event_available_outlined,
      maxWidth: 560,
      child: const _DoctorCalendarIcsExportBody(),
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _DoctorCalendarIcsExportSheet(),
  );
}

class _DoctorCalendarIcsExportSheet extends StatelessWidget {
  const _DoctorCalendarIcsExportSheet();

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: KeepiColors.cardBorder,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: const _DoctorCalendarIcsExportBody(compact: true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoctorCalendarIcsExportBody extends StatefulWidget {
  const _DoctorCalendarIcsExportBody({this.compact = false});

  final bool compact;

  @override
  State<_DoctorCalendarIcsExportBody> createState() =>
      _DoctorCalendarIcsExportBodyState();
}

class _DoctorCalendarIcsExportBodyState
    extends State<_DoctorCalendarIcsExportBody> {
  static const _accent = KeepiColors.orange;

  DoctorCalendarIcsRange _range = DoctorCalendarIcsRange.threeMonths;
  bool _includeScheduled = true;
  bool _includePending = false;
  bool _includeProcedures = true;
  bool _exporting = false;
  int? _previewCount;
  bool _loadingPreview = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshPreview());
  }

  DoctorCalendarIcsExportOptions get _options => DoctorCalendarIcsExportOptions(
        range: _range,
        includeScheduled: _includeScheduled,
        includePending: _includePending,
        includeProcedures: _includeProcedures,
      );

  Future<void> _refreshPreview() async {
    if (!_options.hasSelection) {
      setState(() {
        _previewCount = 0;
        _loadingPreview = false;
      });
      return;
    }

    setState(() => _loadingPreview = true);
    try {
      final (from, to) = _options.resolveRange();
      final payload = await AppointmentService(context.read<ApiClient>())
          .fetchDoctorCalendar(from: from, to: to);
      final count = _countEvents(
        appointments: payload.appointments,
        procedures: payload.procedures,
      );
      if (!mounted) return;
      setState(() {
        _previewCount = count;
        _loadingPreview = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _previewCount = null;
        _loadingPreview = false;
      });
    }
  }

  int _countEvents({
    required List<AppointmentDto> appointments,
    required List<ProcedureBlockDto> procedures,
  }) {
    final (from, to) = _options.resolveRange();
    var count = 0;

    if (_includeScheduled || _includePending) {
      for (final a in appointments) {
        if (a.appointmentDate == null || a.status == 'canceled') continue;
        final start = a.appointmentDate!.asScheduleLocal;
        final end = (a.endDate ?? a.appointmentDate)!.asScheduleLocal;
        if (!_overlaps(from, to, start, end)) continue;

        final scheduled =
            a.status == 'scheduled' || a.status == 'confirmed';
        final pending = a.status == 'pending_doctor_proposal' ||
            a.status == 'pending_patient_approval' ||
            a.status == 'pending_doctor_approval';

        if (scheduled && _includeScheduled) count++;
        if (pending && _includePending) count++;
      }
    }

    if (_includeProcedures) {
      for (final p in procedures) {
        final start = p.startAt.asScheduleLocal;
        final end = p.endAt.asScheduleLocal;
        if (_overlaps(from, to, start, end)) count++;
      }
    }

    return count;
  }

  bool _overlaps(
    DateTime rangeStart,
    DateTime rangeEnd,
    DateTime start,
    DateTime end,
  ) {
    return start.isBefore(rangeEnd) && end.isAfter(rangeStart);
  }

  void _setRange(DoctorCalendarIcsRange value) {
    setState(() => _range = value);
    _refreshPreview();
  }

  void _toggleScheduled(bool value) {
    setState(() => _includeScheduled = value);
    _refreshPreview();
  }

  void _togglePending(bool value) {
    setState(() => _includePending = value);
    _refreshPreview();
  }

  void _toggleProcedures(bool value) {
    setState(() => _includeProcedures = value);
    _refreshPreview();
  }

  Future<void> _export() async {
    if (!_options.hasSelection || _exporting) return;

    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final (from, to) = _options.resolveRange();
      final bytes = await AppointmentService(context.read<ApiClient>())
          .downloadDoctorCalendarIcs(
        from: from,
        to: to,
        includeScheduled: _includeScheduled,
        includePending: _includePending,
        includeProcedures: _includeProcedures,
      );

      if (!mounted) return;

      final stamp = DateTime.now();
      final fileName =
          'keepi-agenda-${stamp.year}${_two(stamp.month)}${_two(stamp.day)}.ics';

      final savedPath = await CalendarExportSave.promptSaveIcs(
        bytes: bytes,
        fileName: fileName,
      );

      if (!mounted) return;

      if (savedPath == null || savedPath.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Exportación cancelada.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            widget.compact
                ? 'Calendario guardado. Ábrelo en Google Calendar o Calendario de iPhone.'
                : 'Archivo .ics listo. Impórtalo en Google Calendar o Calendario de iPhone.',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(AppointmentService.messageFromDio(e)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade800,
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_exporting,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.compact) ...[
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.event_available_outlined,
                    color: _accent,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Exportar calendario',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Elige qué eventos incluir en el .ics',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: KeepiColors.slateLight,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _exporting ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
          ],
          _sectionTitle('Rango de fechas'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: DoctorCalendarIcsRange.values
                .map(
                  (item) => ChoiceChip(
                    label: Text(item.label),
                    selected: _range == item,
                    onSelected: _exporting ? null : (_) => _setRange(item),
                    selectedColor: _accent.withValues(alpha: 0.16),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _range == item ? _accent : KeepiColors.slate,
                    ),
                    side: BorderSide(
                      color: _range == item
                          ? _accent.withValues(alpha: 0.45)
                          : KeepiColors.cardBorder,
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 22),
          _sectionTitle('Eventos a incluir'),
          const SizedBox(height: 10),
          _EventToggleTile(
            title: 'Citas confirmadas',
            subtitle: 'Citas agendadas y confirmadas con pacientes.',
            icon: Icons.event_available_outlined,
            iconColor: KeepiColors.green,
            value: _includeScheduled,
            onChanged: _exporting ? null : _toggleScheduled,
          ),
          const SizedBox(height: 8),
          _EventToggleTile(
            title: 'Citas pendientes',
            subtitle: 'Solicitudes en espera de aprobación o propuesta.',
            icon: Icons.pending_actions_outlined,
            iconColor: KeepiColors.skyBlue,
            value: _includePending,
            onChanged: _exporting ? null : _togglePending,
          ),
          const SizedBox(height: 8),
          _EventToggleTile(
            title: 'Procedimientos',
            subtitle: 'Bloques reservados en el calendario.',
            icon: Icons.medical_services_outlined,
            iconColor: const Color(0xFF7C3AED),
            value: _includeProcedures,
            onChanged: _exporting ? null : _toggleProcedures,
          ),
          const SizedBox(height: 18),
          _buildPreview(),
          const SizedBox(height: 20),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _sectionTitle(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.2,
        color: KeepiColors.slate,
      ),
    );
  }

  Widget _buildPreview() {
    if (!_options.hasSelection) {
      return _infoBox(
        'Selecciona al menos un tipo de evento para exportar.',
        icon: Icons.info_outline_rounded,
        color: KeepiColors.slateLight,
      );
    }

    if (_loadingPreview) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: _accent),
          ),
        ),
      );
    }

    final count = _previewCount;
    if (count == null) return const SizedBox.shrink();

    return _infoBox(
      count == 0
          ? 'No hay eventos en el rango seleccionado.'
          : '$count evento${count == 1 ? '' : 's'} se incluirán en el archivo.',
      icon: count == 0 ? Icons.event_busy_outlined : Icons.event_note_outlined,
      color: count == 0 ? KeepiColors.slateLight : _accent,
    );
  }

  Widget _infoBox(String text, {required IconData icon, required Color color}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final canExport = _options.hasSelection && (_previewCount ?? 0) > 0;

    if (_exporting) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _accent.withValues(alpha: 0.2)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: _accent),
            ),
            SizedBox(width: 12),
            Text(
              'Generando archivo…',
              style: TextStyle(fontWeight: FontWeight.w700, color: _accent),
            ),
          ],
        ),
      );
    }

    return FilledButton.icon(
      onPressed: canExport ? _export : null,
      style: FilledButton.styleFrom(
        backgroundColor: _accent,
        disabledBackgroundColor: KeepiColors.slateLight.withValues(alpha: 0.35),
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white70,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.download_rounded, size: 20),
      label: Text(
        !_options.hasSelection
            ? 'Selecciona al menos un tipo'
            : canExport
                ? 'Descargar .ics'
                : 'Sin eventos en el rango',
        style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.3),
      ),
    );
  }
}

class _EventToggleTile extends StatelessWidget {
  const _EventToggleTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: value
                  ? iconColor.withValues(alpha: 0.35)
                  : KeepiColors.cardBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: KeepiColors.slateLight,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeTrackColor: iconColor.withValues(alpha: 0.45),
                activeThumbColor: iconColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
