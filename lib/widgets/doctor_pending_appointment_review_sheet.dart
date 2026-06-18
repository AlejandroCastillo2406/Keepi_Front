import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../services/api_client.dart';
import '../services/appointment_service.dart';
import '../services/scheduling_service.dart';
import '../widgets/doctor_appointment_slot_picker.dart';

/// Detalle y acciones para citas solicitadas por el paciente en la web.
class DoctorPendingAppointmentReviewSheet {
  static Future<void> show(
    BuildContext context, {
    required String appointmentId,
    VoidCallback? onChanged,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DoctorPendingAppointmentReviewBody(
        appointmentId: appointmentId,
        onChanged: onChanged,
      ),
    );
  }
}

class _DoctorPendingAppointmentReviewBody extends StatefulWidget {
  const _DoctorPendingAppointmentReviewBody({
    required this.appointmentId,
    this.onChanged,
  });

  final String appointmentId;
  final VoidCallback? onChanged;

  @override
  State<_DoctorPendingAppointmentReviewBody> createState() =>
      _DoctorPendingAppointmentReviewBodyState();
}

class _DoctorPendingAppointmentReviewBodyState
    extends State<_DoctorPendingAppointmentReviewBody> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  AppointmentDto? _appointment;

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
      final appt = await AppointmentService(context.read<ApiClient>())
          .fetchById(widget.appointmentId);
      if (!mounted) return;
      setState(() {
        _appointment = appt;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppointmentService.messageFromDio(e);
        _loading = false;
      });
    }
  }

  String _formatWhen(AppointmentDto appt) {
    final dt = appt.appointmentDate?.toLocal();
    if (dt == null) return 'Sin fecha';
    final d = '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    return '$d · ${formatSlotTimeLocal(dt)}';
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      widget.onChanged?.call();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success), backgroundColor: KeepiColors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppointmentService.messageFromDio(e)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _titleFor(AppointmentDto appt) {
    switch (appt.status) {
      case 'pending_doctor_approval':
        return 'Solicitud de cita (web)';
      case 'pending_patient_approval':
        return 'Esperando al paciente';
      case 'pending_doctor_proposal':
        return 'Solicitud sin fecha';
      default:
        return 'Cita pendiente';
    }
  }

  String? _hintFor(AppointmentDto appt) {
    switch (appt.status) {
      case 'pending_patient_approval':
        return 'El paciente debe confirmar por correo o desde la app.';
      case 'pending_doctor_proposal':
        return 'Asigna una fecha para enviar la propuesta al paciente.';
      default:
        return null;
    }
  }

  bool _canManage(AppointmentDto? appt) {
    if (appt == null) return false;
    return appt.status == 'pending_doctor_approval' ||
        appt.status == 'pending_patient_approval' ||
        appt.status == 'pending_doctor_proposal';
  }

  bool _showConfirm(AppointmentDto appt) =>
      appt.status == 'pending_doctor_approval';

  bool _showReschedule(AppointmentDto appt) =>
      appt.status == 'pending_doctor_approval' ||
      appt.status == 'pending_patient_approval';

  bool _showAssignDate(AppointmentDto appt) =>
      appt.status == 'pending_doctor_proposal';

  Future<void> _confirm() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar solicitud'),
        content: const Text(
          '¿Confirmar esta cita solicitada por el paciente?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() async {
      await AppointmentService(context.read<ApiClient>())
          .doctorApproveAppointment(appointmentId: widget.appointmentId);
    }, 'Cita confirmada');
  }

  Future<void> _cancel() async {
    final appt = _appointment;
    final isWebReject = appt?.status == 'pending_doctor_approval';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isWebReject ? 'Cancelar solicitud' : 'Rechazar cita'),
        content: Text(
          isWebReject
              ? '¿Rechazar esta cita solicitada por el paciente?'
              : '¿Rechazar esta cita pendiente?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() async {
      final svc = AppointmentService(context.read<ApiClient>());
      if (isWebReject) {
        await svc.doctorRejectAppointment(appointmentId: widget.appointmentId);
      } else {
        await svc.cancelAppointment(appointmentId: widget.appointmentId);
      }
    }, 'Solicitud rechazada');
  }

  Future<void> _reschedule() async {
    final slot = await pickDoctorAppointmentSlot(context);
    if (slot == null || !mounted) return;
    await _run(() async {
      await AppointmentService(context.read<ApiClient>())
          .doctorRescheduleWebAppointment(
        appointmentId: widget.appointmentId,
        proposedStartAt: slot.toUtc(),
      );
    }, 'Propuesta enviada al paciente por correo');
  }

  Future<void> _assignDate() async {
    final slot = await pickDoctorAppointmentSlot(context);
    if (slot == null || !mounted) return;
    final settings =
        await SchedulingService(context.read<ApiClient>()).fetchSettings();
    await _run(() async {
      await AppointmentService(context.read<ApiClient>()).doctorProposeTime(
        appointmentId: widget.appointmentId,
        proposedStartAt: slot.toUtc(),
        durationMinutes: settings.slotDurationMinutes,
      );
    }, 'Fecha enviada al paciente');
  }

  @override
  Widget build(BuildContext context) {
    final appt = _appointment;
    final canManage = _canManage(appt);
    final hint = appt != null ? _hintFor(appt) : null;

    final body = Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: KeepiColors.slate.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: _loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: CircularProgressIndicator(color: KeepiColors.orange),
              ),
            )
          : _error != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, style: const TextStyle(color: KeepiColors.slate)),
                    const SizedBox(height: 16),
                    OutlinedButton(onPressed: _load, child: const Text('Reintentar')),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: KeepiColors.skyBlue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.event_available_outlined,
                            color: KeepiColors.skyBlue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            appt != null ? _titleFor(appt) : 'Cita pendiente',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: KeepiColors.slate,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _busy ? null : () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _InfoRow(
                      label: 'Paciente',
                      value: (appt?.patientName ?? '').trim().isNotEmpty
                          ? appt!.patientName!.trim()
                          : 'Paciente',
                    ),
                    const SizedBox(height: 10),
                    _InfoRow(label: 'Fecha y hora', value: _formatWhen(appt!)),
                    const SizedBox(height: 10),
                    _InfoRow(
                      label: 'Motivo',
                      value: appt.reason.trim().isEmpty
                          ? 'Consulta en línea'
                          : appt.reason.trim(),
                    ),
                    if (hint != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        hint,
                        style: const TextStyle(color: KeepiColors.slateLight),
                      ),
                    ],
                    if (!canManage) ...[
                      const SizedBox(height: 12),
                      Text(
                        appt.status == 'scheduled'
                            ? 'Esta cita ya fue confirmada.'
                            : 'Esta solicitud ya fue gestionada.',
                        style: const TextStyle(color: KeepiColors.slateLight),
                      ),
                    ],
                    if (canManage) ...[
                      const SizedBox(height: 20),
                      if (_showConfirm(appt))
                        FilledButton(
                          onPressed: _busy ? null : _confirm,
                          style: FilledButton.styleFrom(
                            backgroundColor: KeepiColors.orange,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Confirmar',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      if (_showAssignDate(appt)) ...[
                        FilledButton(
                          onPressed: _busy ? null : _assignDate,
                          style: FilledButton.styleFrom(
                            backgroundColor: KeepiColors.orange,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Asignar fecha',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                      if (_showReschedule(appt)) ...[
                        if (_showConfirm(appt) || _showAssignDate(appt))
                          const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: _busy ? null : _reschedule,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'Reprogramar',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _busy ? null : _cancel,
                        child: Text(
                          appt.status == 'pending_doctor_approval'
                              ? 'Cancelar solicitud'
                              : 'Rechazar',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ],
                ),
    );

    if (!_busy) return body;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        body,
        Positioned.fill(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: KeepiColors.orange),
                SizedBox(height: 16),
                Text(
                  'Procesando…',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: KeepiColors.slate,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: KeepiColors.slateLight,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: KeepiColors.slate,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
