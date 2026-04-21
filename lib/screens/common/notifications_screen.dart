import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import '../../services/appointment_service.dart';
import '../../services/notifications_service.dart';
import '../../services/prescription_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  String? _error;
  List<AppNotificationDto> _items = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final svc = NotificationsService(context.read<ApiClient>());
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await svc.fetchNotifications();
      if (!mounted) return;
      setState(() {
        _items = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = NotificationsService.messageFromDio(e);
        _loading = false;
      });
    }
  }

  Future<void> _openReminderPrompt(AppNotificationDto notification) async {
    final prescriptionId = notification.prescriptionId;
    if (prescriptionId == null || prescriptionId.isEmpty) return;
    final api = context.read<ApiClient>();
    final question = notification.reminderQuestion;
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notification.title),
        content: Text(question),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sí'),
          ),
        ],
      ),
    );
    if (answer == null) return;
    final svc = PrescriptionService(api);
    try {
      await svc.setReminderOptIn(prescriptionId, answer);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            answer
                ? 'Recordatorios activados para esta receta'
                : 'Recordatorios desactivados para esta receta',
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(PrescriptionService.messageFromDio(e))),
      );
    }
  }

  Future<void> _openAppointmentPrompt(AppNotificationDto notification) async {
    final appointmentId = notification.appointmentId;
    if (appointmentId == null || appointmentId.isEmpty) return;
    final api = context.read<ApiClient>();
    final appointmentSvc = AppointmentService(api);
    final wantsDoctorReview = notification.appointmentAction == 'doctor_review';

    if (wantsDoctorReview) {
      final answer = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(notification.title),
          content: Text(notification.message),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Contrapropuesta')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Aceptar')),
          ],
        ),
      );
      if (answer == null) return;
      try {
        if (answer) {
          await appointmentSvc.doctorAccept(appointmentId);
        } else {
          final dt = await _pickDateTime();
          if (dt == null) return;
          await appointmentSvc.doctorCounterPropose(
            appointmentId: appointmentId,
            proposedStartAt: dt,
          );
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Respuesta enviada para la cita')),
        );
        await _load();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppointmentService.messageFromDio(e))),
        );
      }
      return;
    }

    final answer = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(notification.title),
        content: Text(notification.message),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cambiar hora')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Confirmar')),
        ],
      ),
    );
    if (answer == null) return;
    try {
      if (answer) {
        await appointmentSvc.patientConfirm(appointmentId);
      } else {
        final dt = await _pickDateTime();
        if (dt == null) return;
        await appointmentSvc.patientRequestChange(
          appointmentId: appointmentId,
          proposedStartAt: dt,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Respuesta enviada para la cita')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppointmentService.messageFromDio(e))),
      );
    }
  }

  Future<DateTime?> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        backgroundColor: Colors.white,
        foregroundColor: KeepiColors.slate,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: KeepiColors.orange))
          : _error != null
              ? Center(child: Text(_error!))
              : _items.isEmpty
                  ? const Center(child: Text('No tienes notificaciones'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final n = _items[index];
                          return Card(
                            child: ListTile(
                              leading: Icon(
                                n.read ? Icons.mark_email_read_outlined : Icons.notifications_active_outlined,
                                color: n.read ? KeepiColors.slateLight : KeepiColors.orange,
                              ),
                              title: Text(
                                n.title,
                                style: TextStyle(
                                  fontWeight: n.read ? FontWeight.w500 : FontWeight.w700,
                                ),
                              ),
                              onTap: () {
                                if (n.appointmentId != null) {
                                  _openAppointmentPrompt(n);
                                  return;
                                }
                                _openReminderPrompt(n);
                              },
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

