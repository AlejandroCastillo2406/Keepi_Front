import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../services/api_client.dart';
import '../services/scheduling_service.dart';

String formatSlotTimeLocal(DateTime dt) {
  final local = dt.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
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

/// Elige fecha y horario disponible según la configuración del médico.
Future<DateTime?> pickDoctorAppointmentSlot(
  BuildContext context, {
  DateTime? initialDate,
}) async {
  final api = context.read<ApiClient>();
  final scheduling = SchedulingService(api);

  final pickedDate = await showDatePicker(
    context: context,
    initialDate: initialDate ?? DateTime.now(),
    firstDate: DateTime.now(),
    lastDate: DateTime.now().add(const Duration(days: 365)),
    builder: (context, child) => Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.light(primary: KeepiColors.orange),
      ),
      child: child!,
    ),
  );
  if (pickedDate == null || !context.mounted) return null;

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
      from: pickedDate,
      to: pickedDate,
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

  final selected = await showModalBottomSheet<AvailabilitySlotDto>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _SlotPickerSheet(
      date: pickedDate,
      slots: slots,
    ),
  );

  return selected?.startAt.toLocal();
}

Future<void> showAppointmentReasonDialog(
  BuildContext context, {
  required String patientName,
  required String reason,
  required String status,
}) async {
  final trimmed = reason.trim();
  final displayReason = trimmed.isEmpty
      ? 'Sin motivo registrado.'
      : trimmed;
  final bookedBy = _appointmentBookedByLabel(status, reason);

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Motivo de la consulta',
        style: TextStyle(fontWeight: FontWeight.w800, color: KeepiColors.slate),
      ),
      content: Column(
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}

class ConsultationReasonField extends StatelessWidget {
  const ConsultationReasonField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Motivo de la consulta',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: KeepiColors.slate,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: 3,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Ej. control de diabetes, seguimiento postoperatorio…',
            filled: true,
            fillColor: Colors.white,
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
                color: KeepiColors.orange.withValues(alpha: 0.7),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SlotPickerSheet extends StatelessWidget {
  const _SlotPickerSheet({
    required this.date,
    required this.slots,
  });

  final DateTime date;
  final List<AvailabilitySlotDto> slots;

  String _dateLabel() {
    const months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    return '${date.day} de ${months[date.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final morning = slots.where((s) => s.startAt.toLocal().hour < 12).toList();
    final afternoon = slots.where((s) => s.startAt.toLocal().hour >= 12).toList();

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
  const _SlotGrid({required this.slots, required this.onSelected});

  final List<AvailabilitySlotDto> slots;
  final ValueChanged<AvailabilitySlotDto> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: slots.map((slot) {
        final label = formatSlotTimeLocal(slot.startAt);
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
