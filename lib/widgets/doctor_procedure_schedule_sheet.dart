import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/appointment_service.dart';
import 'doctor_appointment_slot_picker.dart';

const _procedureAccent = Color(0xFF7C3AED);

class ProcedureScheduleResult {
  const ProcedureScheduleResult({
    required this.title,
    required this.startAt,
    required this.endAt,
  });

  final String title;
  final DateTime startAt;
  final DateTime endAt;
}

class OccupiedRange {
  const OccupiedRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

int consultationMinutesFromTime(String value) {
  final parts = value.split(':');
  final h = int.tryParse(parts.first.trim()) ?? 0;
  final m = parts.length > 1 ? (int.tryParse(parts[1].trim()) ?? 0) : 0;
  return h * 60 + m;
}

DateTime consultationDayEnd(DateTime day, String endTime) {
  final endMin = consultationMinutesFromTime(endTime);
  return DateTime(day.year, day.month, day.day, endMin ~/ 60, endMin % 60);
}

bool isSameCalendarDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

bool isBlockingAppointmentStatus(String status) {
  switch (status) {
    case 'scheduled':
    case 'pending_patient_approval':
    case 'pending_doctor_approval':
      return true;
    default:
      return false;
  }
}

List<OccupiedRange> buildOccupiedRangesForDay({
  required DateTime day,
  required List<AppointmentDto> appointments,
  required List<ProcedureBlockDto> procedures,
  required int slotDurationMinutes,
}) {
  final ranges = <OccupiedRange>[];

  for (final appointment in appointments) {
    if (!isBlockingAppointmentStatus(appointment.status)) continue;
    final start = appointment.appointmentDate?.toLocal();
    if (start == null || !isSameCalendarDay(start, day)) continue;
    final end = appointment.endDate?.toLocal() ??
        start.add(Duration(minutes: slotDurationMinutes));
    ranges.add(OccupiedRange(start: start, end: end));
  }

  for (final procedure in procedures) {
    final start = procedure.startAt.toLocal();
    if (!isSameCalendarDay(start, day)) continue;
    ranges.add(OccupiedRange(start: start, end: procedure.endAt.toLocal()));
  }

  ranges.sort((a, b) => a.start.compareTo(b.start));
  return ranges;
}

bool isInsideOccupied(DateTime instant, List<OccupiedRange> occupied) {
  for (final range in occupied) {
    if (!instant.isBefore(range.start) && instant.isBefore(range.end)) {
      return true;
    }
  }
  return false;
}

DateTime? nextOccupiedStartAfter(DateTime after, List<OccupiedRange> occupied) {
  DateTime? next;
  for (final range in occupied) {
    if (range.start.isAfter(after)) {
      if (next == null || range.start.isBefore(next)) {
        next = range.start;
      }
    }
  }
  return next;
}

/// Horarios de inicio alineados al grid de consulta (misma duración que las citas).
List<DateTime> buildConsultationGridStarts({
  required DateTime day,
  required String startTime,
  required String endTime,
  required int slotDurationMinutes,
}) {
  if (slotDurationMinutes <= 0) return const [];

  final startMin = consultationMinutesFromTime(startTime);
  final endMin = consultationMinutesFromTime(endTime);
  final slots = <DateTime>[];

  var cursor = startMin;
  while (cursor + slotDurationMinutes <= endMin) {
    slots.add(DateTime(
      day.year,
      day.month,
      day.day,
      cursor ~/ 60,
      cursor % 60,
    ));
    cursor += slotDurationMinutes;
  }
  return slots;
}

/// Fin dinámico: solo hasta el próximo bloque ocupado (cita o procedimiento).
List<DateTime> buildProcedureEndOptions({
  required DateTime startAt,
  required DateTime dayEnd,
  required int slotDurationMinutes,
  List<OccupiedRange> occupied = const [],
}) {
  if (slotDurationMinutes <= 0) return const [];

  final nextBlock = nextOccupiedStartAfter(startAt, occupied);
  final maxEnd = nextBlock != null && nextBlock.isBefore(dayEnd)
      ? nextBlock
      : dayEnd;

  final options = <DateTime>[];
  var end = startAt.add(Duration(minutes: slotDurationMinutes));
  while (!end.isAfter(maxEnd)) {
    options.add(end);
    end = end.add(Duration(minutes: slotDurationMinutes));
  }
  return options;
}

List<DateTime> buildAvailableProcedureStartOptions({
  required DateTime day,
  required String scheduleStartTime,
  required String scheduleEndTime,
  required int slotDurationMinutes,
  required List<OccupiedRange> occupied,
}) {
  final dayEnd = consultationDayEnd(day, scheduleEndTime);
  return buildConsultationGridStarts(
    day: day,
    startTime: scheduleStartTime,
    endTime: scheduleEndTime,
    slotDurationMinutes: slotDurationMinutes,
  ).where((start) {
    if (isInsideOccupied(start, occupied)) return false;
    return buildProcedureEndOptions(
      startAt: start,
      dayEnd: dayEnd,
      slotDurationMinutes: slotDurationMinutes,
      occupied: occupied,
    ).isNotEmpty;
  }).toList();
}

ConsultationScheduleDayDto? consultationScheduleForDay(
  ConsultationScheduleDto? schedule,
  DateTime day,
) {
  if (schedule == null) return null;
  final weekday = day.weekday - 1;
  for (final item in schedule.days) {
    if (item.weekday == weekday) return item;
  }
  return null;
}

Future<ProcedureScheduleResult?> showDoctorProcedureScheduleSheet(
  BuildContext context, {
  required DateTime initialDate,
  required ConsultationScheduleDto? consultationSchedule,
  required List<AppointmentDto> appointments,
  required List<ProcedureBlockDto> procedures,
}) {
  return showDialog<ProcedureScheduleResult>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (ctx) => _ProcedureScheduleDialog(
      initialDate: initialDate,
      consultationSchedule: consultationSchedule,
      appointments: appointments,
      procedures: procedures,
    ),
  );
}

class _ProcedureScheduleDialog extends StatefulWidget {
  const _ProcedureScheduleDialog({
    required this.initialDate,
    required this.consultationSchedule,
    required this.appointments,
    required this.procedures,
  });

  final DateTime initialDate;
  final ConsultationScheduleDto? consultationSchedule;
  final List<AppointmentDto> appointments;
  final List<ProcedureBlockDto> procedures;

  @override
  State<_ProcedureScheduleDialog> createState() =>
      _ProcedureScheduleDialogState();
}

class _ProcedureScheduleDialogState extends State<_ProcedureScheduleDialog> {
  final _titleCtrl = TextEditingController();
  late DateTime _day;
  DateTime? _startAt;
  DateTime? _endAt;

  int get _slotDuration =>
      widget.consultationSchedule?.slotDurationMinutes ?? 30;

  ConsultationScheduleDayDto? get _scheduleDay =>
      consultationScheduleForDay(widget.consultationSchedule, _day);

  List<OccupiedRange> get _occupied => buildOccupiedRangesForDay(
        day: _day,
        appointments: widget.appointments,
        procedures: widget.procedures,
        slotDurationMinutes: _slotDuration,
      );

  List<DateTime> get _startOptions {
    final day = _scheduleDay;
    if (day == null) return const [];
    return buildAvailableProcedureStartOptions(
      day: _day,
      scheduleStartTime: day.startTime,
      scheduleEndTime: day.endTime,
      slotDurationMinutes: _slotDuration,
      occupied: _occupied,
    );
  }

  List<DateTime> get _endOptions {
    final day = _scheduleDay;
    if (day == null || _startAt == null) return const [];
    return buildProcedureEndOptions(
      startAt: _startAt!,
      dayEnd: consultationDayEnd(_day, day.endTime),
      slotDurationMinutes: _slotDuration,
      occupied: _occupied,
    );
  }

  void _syncDefaultSelection() {
    final starts = _startOptions;
    if (starts.isEmpty) {
      _startAt = null;
      _endAt = null;
      return;
    }
    if (_startAt == null || !starts.any((s) => _sameMinute(s, _startAt))) {
      _startAt = starts.first;
    }
    final ends = _endOptions;
    if (ends.isEmpty) {
      _endAt = null;
      return;
    }
    if (_endAt == null || !ends.any((e) => _sameMinute(e, _endAt))) {
      _endAt = ends.first;
    }
  }

  bool _sameMinute(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day &&
        a.hour == b.hour &&
        a.minute == b.minute;
  }

  @override
  void initState() {
    super.initState();
    _day = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    _syncDefaultSelection();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: KeepiColors.orange),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _day = DateTime(picked.year, picked.month, picked.day);
      _startAt = null;
      _endAt = null;
      _syncDefaultSelection();
    });
  }

  void _selectStart(DateTime? value) {
    if (value == null) return;
    setState(() {
      _startAt = value;
      _endAt = null;
      _syncDefaultSelection();
    });
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un título para el procedimiento')),
      );
      return;
    }
    if (_startAt == null || _endAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona inicio y fin del procedimiento')),
      );
      return;
    }
    Navigator.pop(
      context,
      ProcedureScheduleResult(
        title: title,
        startAt: _startAt!,
        endAt: _endAt!,
      ),
    );
  }

  String _dateLabel() {
    const months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    return '${_day.day} de ${months[_day.month - 1]}';
  }

  String? _nextBlockHint() {
    if (_startAt == null) return null;
    final next = nextOccupiedStartAfter(_startAt!, _occupied);
    if (next == null) return null;
    return 'Disponible hasta ${formatSlotTimeLocal(next)} (siguiente ocupado)';
  }

  @override
  Widget build(BuildContext context) {
    final scheduleDay = _scheduleDay;
    final startOptions = _startOptions;
    final endOptions = _endOptions;
    final blockHint = _nextBlockHint();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: KeepiColors.cardBorder),
      ),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _procedureAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.medical_services_outlined,
                      color: _procedureAccent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nuevo procedimiento',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                            color: KeepiColors.slate,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Intervalos de $_slotDuration min · respeta citas existentes',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: KeepiColors.slateLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: KeepiColors.slateLight),
                    tooltip: 'Cerrar',
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Título',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: KeepiColors.slate,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Ej. Cirugía menor, bloque quirófano…',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: KeepiColors.cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: KeepiColors.cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _procedureAccent.withValues(alpha: 0.65),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    InkWell(
                      onTap: _pickDay,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: KeepiColors.cardBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 18,
                              color: _procedureAccent,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _dateLabel(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: KeepiColors.slate,
                                ),
                              ),
                            ),
                            if (scheduleDay != null)
                              Text(
                                '${scheduleDay.startTime} – ${scheduleDay.endTime}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: KeepiColors.slateLight,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (scheduleDay == null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: KeepiColors.orangeSoft,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: KeepiColors.orange.withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Text(
                          'Este día no tiene horario de consulta configurado.',
                          style: TextStyle(
                            color: KeepiColors.slate,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ] else if (startOptions.isEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'No hay horarios libres para este día.',
                        style: TextStyle(
                          color: KeepiColors.slateLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 20),
                      _ProcedureTimeSelect(
                        label: 'Inicio',
                        value: _startAt,
                        options: startOptions,
                        onChanged: _selectStart,
                      ),
                      const SizedBox(height: 16),
                      _ProcedureTimeSelect(
                        label: 'Fin',
                        value: _endAt,
                        options: endOptions,
                        enabled: _startAt != null && endOptions.isNotEmpty,
                        onChanged: (value) => setState(() => _endAt = value),
                      ),
                      if (blockHint != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          blockHint,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _procedureAccent.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                      if (_startAt != null && _endAt != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Duración: ${_endAt!.difference(_startAt!).inMinutes} min',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: KeepiColors.slateLight,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 22),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: KeepiColors.slate,
                        side: const BorderSide(color: KeepiColors.cardBorder),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: scheduleDay == null || startOptions.isEmpty
                          ? null
                          : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: _procedureAccent,
                        disabledBackgroundColor:
                            _procedureAccent.withValues(alpha: 0.35),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Guardar',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProcedureTimeSelect extends StatelessWidget {
  const _ProcedureTimeSelect({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final DateTime? value;
  final List<DateTime> options;
  final ValueChanged<DateTime?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: KeepiColors.slateLight,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<DateTime>(
          value: value != null && options.any((o) => _sameMinute(o, value))
              ? value
              : null,
          isExpanded: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: KeepiColors.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: KeepiColors.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _procedureAccent.withValues(alpha: 0.65),
              ),
            ),
          ),
          hint: Text(
            enabled ? 'Selecciona hora' : 'Elige primero el inicio',
            style: const TextStyle(
              color: KeepiColors.slateLight,
              fontWeight: FontWeight.w600,
            ),
          ),
          icon: const Icon(Icons.expand_more_rounded, color: _procedureAccent),
          items: options
              .map(
                (time) => DropdownMenuItem<DateTime>(
                  value: time,
                  child: Text(
                    formatSlotTimeLocal(time),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: KeepiColors.slate,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }

  bool _sameMinute(DateTime a, DateTime? b) {
    if (b == null) return false;
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day &&
        a.hour == b.hour &&
        a.minute == b.minute;
  }
}
