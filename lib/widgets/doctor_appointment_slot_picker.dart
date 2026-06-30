import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/keepi_timezone.dart';
import '../core/app_theme.dart';
import '../core/web_layout.dart';
import '../services/api_client.dart';
import '../services/scheduling_service.dart';
import 'doctor_note_field.dart';
import 'keepi_web_dialog.dart';

String formatSlotTimeLocal(DateTime dt) => KeepiTimezone.formatScheduleTime(dt);

int _backendWeekday(DateTime date) => date.weekday - 1;

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool isDoctorWorkingDay(DateTime date, List<AvailabilityRuleDto> rules) {
  if (rules.isEmpty) return true;
  final wd = _backendWeekday(date);
  for (final rule in rules) {
    if (rule.weekday == wd && rule.isEnabled) return true;
  }
  return false;
}

bool isSelectableAppointmentDay(DateTime date, List<AvailabilityRuleDto> rules) {
  final day = _dateOnly(date);
  if (day.isBefore(_dateOnly(DateTime.now()))) return false;
  return isDoctorWorkingDay(date, rules);
}

DateTime _firstSelectableDay(
  DateTime from,
  DateTime lastDate,
  List<AvailabilityRuleDto> rules,
) {
  var cursor = _dateOnly(from);
  final end = _dateOnly(lastDate);
  while (!cursor.isAfter(end)) {
    if (isSelectableAppointmentDay(cursor, rules)) return cursor;
    cursor = cursor.add(const Duration(days: 1));
  }
  return _dateOnly(from);
}

AvailabilityRuleDto? _ruleForDay(DateTime date, List<AvailabilityRuleDto> rules) {
  final wd = _backendWeekday(date);
  for (final rule in rules) {
    if (rule.weekday == wd) return rule;
  }
  return null;
}

String _appointmentBookedByLabel(String status, String reason) {
  if (status == 'pending_doctor_approval') {
    return 'Agendada por el paciente (web)';
  }
  if (status == 'pending_doctor_proposal') {
    return 'Solicitud del paciente';
  }
  if (reason.trim() == 'Consulta solicitada en línea') {
    return 'Agendada por el paciente (web)';
  }
  return 'Agendada por el médico';
}

const _monthNamesEs = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

const _weekdayShortEs = ['LU', 'MA', 'MI', 'JU', 'VI', 'SA', 'DO'];

/// Elige fecha y horario disponible según la configuración del médico.
Future<DateTime?> pickDoctorAppointmentSlot(
  BuildContext context, {
  DateTime? initialDate,
}) async {
  final api = context.read<ApiClient>();
  final scheduling = SchedulingService(api);
  final asWeb = isWebWide(context);
  final lastDate = DateTime.now().add(const Duration(days: 365));

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(
      child: CircularProgressIndicator(color: KeepiColors.orange),
    ),
  );

  List<AvailabilityRuleDto> rules = [];
  try {
    rules = await scheduling.fetchRules();
  } catch (e) {
    if (context.mounted) Navigator.pop(context);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(SchedulingService.messageFromDio(e)),
          backgroundColor: Colors.red,
        ),
      );
    }
    return null;
  }

  if (!context.mounted) return null;
  Navigator.pop(context);

  final seed = _firstSelectableDay(
    initialDate ?? DateTime.now(),
    lastDate,
    rules,
  );

  final DateTime? pickedDate;
  if (asWeb) {
    pickedDate = await showDialog<DateTime>(
      context: context,
      barrierColor: KeepiColors.slate.withValues(alpha: 0.48),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: _DoctorAppointmentDatePicker(
          initialDate: seed,
          lastDate: lastDate,
          rules: rules,
        ),
      ),
    );
  } else {
    pickedDate = await showDatePicker(
      context: context,
      initialDate: seed,
      firstDate: _dateOnly(DateTime.now()),
      lastDate: lastDate,
      selectableDayPredicate: (date) => isSelectableAppointmentDay(date, rules),
      helpText: 'Elige la fecha',
      cancelText: 'Cancelar',
      confirmText: 'Continuar',
    builder: (context, child) => Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.light(primary: KeepiColors.orange),
      ),
      child: child!,
    ),
  );
  }

  if (pickedDate == null || !context.mounted) return null;
  final selectedDate = pickedDate;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(
      child: CircularProgressIndicator(color: KeepiColors.orange),
    ),
  );

  List<AvailabilitySlotDto> slots = [];
  String? message;
  try {
    final result = await scheduling.fetchAvailableSlots(
      from: selectedDate,
      to: selectedDate,
    );
    slots = result.slots;
    message = result.message;
  } catch (e) {
    if (context.mounted) Navigator.pop(context);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(SchedulingService.messageFromDio(e)),
          backgroundColor: Colors.red,
        ),
      );
    }
    return null;
  }

  if (!context.mounted) return null;
  Navigator.pop(context);

  if (slots.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message?.isNotEmpty == true
              ? message!
              : 'No hay horarios disponibles para este día.',
        ),
      ),
    );
    return null;
  }

  final AvailabilitySlotDto? selected;
  if (asWeb) {
    selected = await showDialog<AvailabilitySlotDto>(
      context: context,
      barrierColor: KeepiColors.slate.withValues(alpha: 0.48),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: _SlotPickerSheet(
          date: selectedDate,
          slots: slots,
          rules: rules,
          asWebDialog: true,
        ),
      ),
    );
  } else {
    selected = await showModalBottomSheet<AvailabilitySlotDto>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _SlotPickerSheet(
        date: selectedDate,
      slots: slots,
        rules: rules,
        asWebDialog: false,
    ),
  );
  }

  return selected?.startAt.asScheduleLocal;
}

class _DoctorAppointmentDatePicker extends StatefulWidget {
  const _DoctorAppointmentDatePicker({
    required this.initialDate,
    required this.lastDate,
    required this.rules,
  });

  final DateTime initialDate;
  final DateTime lastDate;
  final List<AvailabilityRuleDto> rules;

  @override
  State<_DoctorAppointmentDatePicker> createState() =>
      _DoctorAppointmentDatePickerState();
}

class _DoctorAppointmentDatePickerState
    extends State<_DoctorAppointmentDatePicker> {
  late DateTime _focusedMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = _dateOnly(widget.initialDate);
    _focusedMonth = DateTime(_selectedDate.year, _selectedDate.month);
  }

  bool get _canGoPrevMonth {
    final currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
    return _focusedMonth.isAfter(currentMonth);
  }

  bool get _canGoNextMonth {
    final next = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
    return DateTime(next.year, next.month, 1).isBefore(widget.lastDate) ||
        (next.year == widget.lastDate.year && next.month == widget.lastDate.month);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + delta);
    });
  }

  List<DateTime?> _buildMonthCells() {
    final first = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final cells = <DateTime?>[];
    for (var i = 0; i < first.weekday - 1; i++) {
      cells.add(null);
    }
    for (var d = 1; d <= daysInMonth; d++) {
      cells.add(DateTime(_focusedMonth.year, _focusedMonth.month, d));
    }
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }

  String _scheduleHintForDay(DateTime date) {
    final rule = _ruleForDay(date, widget.rules);
    if (rule == null || !rule.isEnabled) return 'Sin consulta';
    return '${rule.startTime} – ${rule.endTime}';
  }

  @override
  Widget build(BuildContext context) {
    final cells = _buildMonthCells();
    final monthLabel =
        '${_monthNamesEs[_focusedMonth.month - 1]} ${_focusedMonth.year}';
    final selectedRule = _ruleForDay(_selectedDate, widget.rules);

    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 60,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Container(
                height: 118,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2D3F4C), Color(0xFF46555F)],
                  ),
                ),
              ),
              Positioned(
                right: -24,
                top: -24,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              Positioned(
                right: 48,
                bottom: -18,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: KeepiColors.orange.withValues(alpha: 0.18),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 16, 0),
                child: SizedBox(
                  height: 118,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: KeepiColors.orange.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: KeepiColors.orange.withValues(alpha: 0.42),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.calendar_month_rounded,
                          color: Color(0xFFFFBF7A),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Elige la fecha',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.35,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Solo días con horario de consulta activo.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xA6FFFFFF),
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: KeepiColors.cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: _canGoPrevMonth ? () => _shiftMonth(-1) : null,
                        icon: const Icon(Icons.chevron_left_rounded),
                        color: KeepiColors.slate,
                      ),
                      Expanded(
                        child: Text(
                          monthLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: KeepiColors.slate,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _canGoNextMonth ? () => _shiftMonth(1) : null,
                        icon: const Icon(Icons.chevron_right_rounded),
                        color: KeepiColors.slate,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: _weekdayShortEs
                        .map(
                          (d) => Expanded(
                            child: Center(
                              child: Text(
                                d,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: KeepiColors.slateLight,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(cells.length ~/ 7, (row) {
                    final rowCells = cells.sublist(row * 7, row * 7 + 7);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: rowCells.map((day) {
                          return Expanded(
                            child: day == null
                                ? const SizedBox(height: 42)
                                : _DayCell(
                                    date: day,
                                    selected: _sameDay(day, _selectedDate),
                                    selectable: isSelectableAppointmentDay(
                                      day,
                                      widget.rules,
                                    ),
                                    scheduleHint: _scheduleHintForDay(day),
                                    onTap: () => setState(() {
                                      _selectedDate = _dateOnly(day);
                                    }),
                                  ),
                          );
                        }).toList(),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          if (selectedRule != null && selectedRule.isEnabled) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: KeepiColors.orangeSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: KeepiColors.orange.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 18,
                      color: KeepiColors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Horario del ${_weekdayShortEs[_backendWeekday(_selectedDate)]}: ${selectedRule.startTime} – ${selectedRule.endTime}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: KeepiColors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: KeepiColors.slateLight,
                      side: const BorderSide(color: KeepiColors.cardBorder),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: isSelectableAppointmentDay(
                            _selectedDate, widget.rules)
                        ? () => Navigator.pop(context, _selectedDate)
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: KeepiColors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text(
                      'Continuar',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayCell extends StatefulWidget {
  const _DayCell({
    required this.date,
    required this.selected,
    required this.selectable,
    required this.scheduleHint,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final bool selectable;
  final String scheduleHint;
  final VoidCallback onTap;

  @override
  State<_DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<_DayCell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final today = _sameDay(widget.date, DateTime.now());
    final selected = widget.selected;
    final selectable = widget.selectable;

    Color bg = Colors.transparent;
    Color fg = KeepiColors.slate;
    Border? border;

    if (!selectable) {
      fg = KeepiColors.slateLight.withValues(alpha: 0.45);
    } else if (selected) {
      bg = KeepiColors.orange;
      fg = Colors.white;
    } else if (_hovered) {
      bg = KeepiColors.orangeSoft;
      border = Border.all(color: KeepiColors.orange.withValues(alpha: 0.35));
      fg = KeepiColors.orange;
    } else if (today) {
      border = Border.all(color: KeepiColors.orange.withValues(alpha: 0.55));
    }

    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      height: 42,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: border,
      ),
      alignment: Alignment.center,
      child: Text(
        '${widget.date.day}',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );

    if (!selectable) return child;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(message: widget.scheduleHint, child: child),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

Future<void> showAppointmentReasonDialog(
  BuildContext context, {
  required String patientName,
  required String reason,
  required String status,
}) async {
  final trimmed = reason.trim();
  final displayReason = trimmed.isEmpty ? 'Sin motivo registrado.' : trimmed;
  final bookedBy = _appointmentBookedByLabel(status, reason);

  await showDialog<void>(
    context: context,
    barrierColor: KeepiColors.slate.withValues(alpha: 0.48),
    builder: (ctx) => KeepiWebDialogShell(
      title: 'Motivo de la consulta',
      icon: Icons.chat_bubble_outline_rounded,
      iconAccent: KeepiColors.skyBlue,
      maxWidth: 480,
      maxHeightFactor: 0.55,
      footer: FilledButton(
        onPressed: () => Navigator.of(ctx).pop(),
        style: FilledButton.styleFrom(
          backgroundColor: KeepiColors.orange,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('Cerrar', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      child: keepiDialogFormCard(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            patientName,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: KeepiColors.skyBlue,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            bookedBy,
            style: const TextStyle(fontSize: 12, color: KeepiColors.slateLight),
          ),
          const SizedBox(height: 14),
          Text(
            displayReason,
            style: const TextStyle(
              fontSize: 15,
              color: KeepiColors.slate,
              height: 1.45,
            ),
          ),
        ],
      ),
      ),
    ),
  );
}

class DoctorAppointmentConfirmResult {
  const DoctorAppointmentConfirmResult({
    required this.reason,
    this.doctorNote,
  });

  final String reason;
  final String? doctorNote;
}

Future<DoctorAppointmentConfirmResult?> showDoctorAppointmentConfirmDialog(
  BuildContext context, {
  required String patientName,
  required DateTime dateTime,
}) {
  final asWeb = isWebWide(context);
  return showDialog<DoctorAppointmentConfirmResult>(
    context: context,
    barrierColor: asWeb
        ? KeepiColors.slate.withValues(alpha: 0.48)
        : null,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: asWeb
          ? const EdgeInsets.symmetric(horizontal: 24, vertical: 32)
          : const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: _DoctorAppointmentConfirmDialog(
        patientName: patientName,
        dateTime: dateTime,
        asWebDialog: asWeb,
      ),
    ),
  );
}

class _DoctorAppointmentConfirmDialog extends StatefulWidget {
  const _DoctorAppointmentConfirmDialog({
    required this.patientName,
    required this.dateTime,
    required this.asWebDialog,
  });

  final String patientName;
  final DateTime dateTime;
  final bool asWebDialog;

  @override
  State<_DoctorAppointmentConfirmDialog> createState() =>
      _DoctorAppointmentConfirmDialogState();
}

class _DoctorAppointmentConfirmDialogState
    extends State<_DoctorAppointmentConfirmDialog> {
  final _reasonCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String? _reasonError;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reasonCtrl.text.trim();
    if (reason.isEmpty) {
      setState(() {
        _reasonError = 'Indica el motivo de la consulta.';
      });
      return;
    }
    final note = _noteCtrl.text.trim();
    Navigator.pop(
      context,
      DoctorAppointmentConfirmResult(
        reason: reason,
        doctorNote: note.isEmpty ? null : note,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.asWebDialog) return _buildWebDialog(context);
    return _buildMobileDialog(context);
  }

  Widget _buildWebDialog(BuildContext context) {
    final dt = widget.dateTime.asScheduleLocal;
    final dateStr =
        '${dt.day} ${_monthNamesEs[dt.month - 1].substring(0, 3)} ${dt.year}';
    final timeStr = formatSlotTimeLocal(dt);
    final initial = widget.patientName.trim().isEmpty
        ? '?'
        : widget.patientName.trim()[0].toUpperCase();

    return Container(
      constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 60,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Container(
                height: 118,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2D3F4C), Color(0xFF46555F)],
                  ),
                ),
              ),
              Positioned(
                right: -24,
                top: -24,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              Positioned(
                right: 48,
                bottom: -18,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: KeepiColors.orange.withValues(alpha: 0.18),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 16, 0),
                child: SizedBox(
                  height: 118,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: KeepiColors.orange.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: KeepiColors.orange.withValues(alpha: 0.42),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.event_available_rounded,
                          color: Color(0xFFFFBF7A),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Confirmar cita',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.35,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Revisa los datos y completa el motivo.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xA6FFFFFF),
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Container(
              padding: const EdgeInsets.all(14),
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
                      color: KeepiColors.skyBlueSoft,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: KeepiColors.skyBlue.withValues(alpha: 0.25),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: KeepiColors.skyBlue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.patientName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: KeepiColors.slate,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _SummaryChip(
                              icon: Icons.calendar_today_rounded,
                              label: dateStr,
                              accent: KeepiColors.slate,
                              soft: KeepiColors.slateSoft,
                            ),
                            _SummaryChip(
                              icon: Icons.schedule_rounded,
                              label: timeStr,
                              accent: KeepiColors.orange,
                              soft: KeepiColors.orangeSoft,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: KeepiColors.cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ConsultationReasonField(
                      controller: _reasonCtrl,
                      errorText: _reasonError,
                      onChanged: (_) {
                        if (_reasonError != null) {
                          setState(() => _reasonError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DoctorNoteField(controller: _noteCtrl),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: KeepiColors.slateLight,
                      side: const BorderSide(color: KeepiColors.cardBorder),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: KeepiColors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text(
                      'Confirmar cita',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
        ),
      ],
    ),
  );
  }

  Widget _buildMobileDialog(BuildContext context) {
    final dt = widget.dateTime.asScheduleLocal;
    final dateStr =
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    final timeStr = formatSlotTimeLocal(dt);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 12, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: KeepiColors.orangeSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.event_available_rounded,
                    color: KeepiColors.orange,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Confirmar cita',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: KeepiColors.slate,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(
                    backgroundColor: KeepiColors.slateSoft,
                    foregroundColor: KeepiColors.slateLight,
                  ),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 14.5,
                        color: KeepiColors.slate,
                        height: 1.4,
                      ),
                      children: [
                        const TextSpan(text: '¿Asignar la cita a '),
                        TextSpan(
                          text: widget.patientName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: KeepiColors.skyBlue,
                          ),
                        ),
                        const TextSpan(text: ' el '),
                        TextSpan(
                          text: dateStr,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(text: ' a las '),
                        TextSpan(
                          text: timeStr,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(text: '?'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ConsultationReasonField(
                    controller: _reasonCtrl,
                    errorText: _reasonError,
                    onChanged: (_) {
                      if (_reasonError != null) {
                        setState(() => _reasonError = null);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  DoctorNoteField(controller: _noteCtrl),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: KeepiColors.orange,
                    ),
                    child: const Text(
                      'Confirmar',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.accent,
    required this.soft,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final Color soft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: accent),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class ConsultationReasonField extends StatelessWidget {
  const ConsultationReasonField({
    super.key,
    required this.controller,
    this.errorText,
    this.onChanged,
  });

  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;
    final errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.6),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Motivo de la consulta',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: hasError ? const Color(0xFFDC2626) : KeepiColors.slate,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: onChanged,
          maxLines: 3,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Ej. control de diabetes, seguimiento postoperatorio…',
            filled: true,
            fillColor: hasError ? const Color(0xFFFFF1F2) : Colors.white,
            border: errorBorder,
            enabledBorder: hasError ? errorBorder : OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: KeepiColors.cardBorder),
            ),
            focusedBorder: hasError ? errorBorder : OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: KeepiColors.orange.withValues(alpha: 0.7),
              ),
            ),
            errorText: hasError ? ' ' : null,
            errorStyle: const TextStyle(height: 0, fontSize: 0),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFFDC2626),
            ),
          ),
        ],
      ],
    );
  }
}

class _SlotPickerSheet extends StatelessWidget {
  const _SlotPickerSheet({
    required this.date,
    required this.slots,
    required this.rules,
    required this.asWebDialog,
  });

  final DateTime date;
  final List<AvailabilitySlotDto> slots;
  final List<AvailabilityRuleDto> rules;
  final bool asWebDialog;

  String _dateLabel() {
    const months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    return '${date.day} de ${months[date.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final morning =
        slots.where((s) => s.startAt.asScheduleLocal.hour < 12).toList();
    final afternoon =
        slots.where((s) => s.startAt.asScheduleLocal.hour >= 12).toList();
    final rule = _ruleForDay(date, rules);

    if (asWebDialog) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 560),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 60,
              offset: const Offset(0, 24),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Container(
                  height: 96,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2D3F4C), Color(0xFF46555F)],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 16, 0),
                  child: SizedBox(
                    height: 96,
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: KeepiColors.orange.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: KeepiColors.orange.withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Icon(
                            Icons.schedule_rounded,
                            color: Color(0xFFFFBF7A),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Elige horario',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              Text(
                                _dateLabel(),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.65),
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (rule != null && rule.isEnabled)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: KeepiColors.orangeSoft,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: KeepiColors.orange.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      'Disponible ${rule.startTime} – ${rule.endTime}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: KeepiColors.orange,
                      ),
                    ),
                  ),
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (morning.isNotEmpty) ...[
                      const _SlotSectionTitle(label: 'Mañana'),
                      const SizedBox(height: 10),
                      _SlotGrid(
                        slots: morning,
                        web: true,
                        onSelected: (s) => Navigator.pop(context, s),
                      ),
                      const SizedBox(height: 18),
                    ],
                    if (afternoon.isNotEmpty) ...[
                      const _SlotSectionTitle(label: 'Tarde'),
                      const SizedBox(height: 10),
                      _SlotGrid(
                        slots: afternoon,
                        web: true,
                        onSelected: (s) => Navigator.pop(context, s),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: KeepiColors.cardBorder,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Elige horario · ${_dateLabel()}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: KeepiColors.slate,
              ),
            ),
            const SizedBox(height: 16),
            if (morning.isNotEmpty) ...[
              const _SlotSectionTitle(label: 'Mañana'),
              const SizedBox(height: 8),
              _SlotGrid(
                slots: morning,
                onSelected: (s) => Navigator.pop(context, s),
              ),
              const SizedBox(height: 16),
            ],
            if (afternoon.isNotEmpty) ...[
              const _SlotSectionTitle(label: 'Tarde'),
              const SizedBox(height: 8),
              _SlotGrid(
                slots: afternoon,
                onSelected: (s) => Navigator.pop(context, s),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SlotSectionTitle extends StatelessWidget {
  const _SlotSectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: KeepiColors.slateLight,
      ),
    );
  }
}

class _SlotGrid extends StatelessWidget {
  const _SlotGrid({
    required this.slots,
    required this.onSelected,
    this.web = false,
  });

  final List<AvailabilitySlotDto> slots;
  final ValueChanged<AvailabilitySlotDto> onSelected;
  final bool web;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: web ? 10 : 8,
      runSpacing: web ? 10 : 8,
      children: slots.map((slot) {
        final label = formatSlotTimeLocal(slot.startAt);
        if (web) {
          return _WebSlotChip(label: label, onTap: () => onSelected(slot));
        }
        return InkWell(
          onTap: () => onSelected(slot),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: KeepiColors.orangeSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: KeepiColors.orange.withValues(alpha: 0.35)),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: KeepiColors.orange,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _WebSlotChip extends StatefulWidget {
  const _WebSlotChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_WebSlotChip> createState() => _WebSlotChipState();
}

class _WebSlotChipState extends State<_WebSlotChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _hovered ? KeepiColors.orange : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered
                  ? KeepiColors.orange
                  : KeepiColors.cardBorder,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: KeepiColors.orange.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: _hovered ? Colors.white : KeepiColors.orange,
            ),
          ),
        ),
      ),
    );
  }
}
