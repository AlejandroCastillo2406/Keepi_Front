
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import '../../services/appointment_service.dart';
import '../../services/notifications_service.dart';
import '../../services/prescription_service.dart';
import '../../providers/auth_provider.dart';

const _monthsEsUpper = <String>[
  'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
  'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC',
];

String _two(int v) => v.toString().padLeft(2, '0');

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

  // â”€â”€ Acciones de recordatorio de receta â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _openReminderPrompt(AppNotificationDto n) async {
    final prescriptionId = n.prescriptionId;
    if (prescriptionId == null || prescriptionId.isEmpty) return;
    final api = context.read<ApiClient>();
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(n.title),
        content: Text(n.reminderQuestion),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('No', style: TextStyle(color: KeepiColors.slateLight))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
            onPressed: () => Navigator.of(context).pop(true), 
            child: const Text('SÃ­', style: TextStyle(fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
    if (answer == null) return;
    try {
      await PrescriptionService(api).setReminderOptIn(prescriptionId, answer);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            answer ? 'Recordatorios activados' : 'Recordatorios desactivados',
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

  // â”€â”€ Acciones de citas (FLUJO NUEVO) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _openAppointmentPrompt(AppNotificationDto n) async {
    final appointmentId = n.appointmentId; 
    if (appointmentId == null || appointmentId.isEmpty) return;

    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final isDoctor = authProv.roleName == 'DOCTOR';
    final appointmentSvc = Provider.of<AppointmentService>(context, listen: false);

    if (isDoctor) {
      // --- FLUJO DEL DOCTOR (Asignar Fecha desde la NotificaciÃ³n) ---
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.edit_calendar_outlined, color: KeepiColors.orange),
              SizedBox(width: 8),
              Text('Solicitud de Cita', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Text('${n.message}\n\nÂ¿Deseas asignar una fecha ahora?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('DespuÃ©s', style: TextStyle(color: KeepiColors.slateLight))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: KeepiColors.orange),
              onPressed: () => Navigator.of(ctx).pop(true), 
              child: const Text('Asignar Fecha', style: TextStyle(fontWeight: FontWeight.bold))
            ),
          ],
        ),
      );

      if (confirm == true) {
        try {
          final dt = await _pickDateTime();
          if (dt == null) return;
          
          if (!mounted) return;
          showDialog(
            context: context, 
            barrierDismissible: false, 
            builder: (_) => const Center(child: CircularProgressIndicator(color: KeepiColors.orange))
          );

          await appointmentSvc.doctorProposeTime(
            appointmentId: appointmentId,
            proposedStartAt: dt,
            durationMinutes: 30, 
          );
          
          if (!mounted) return;
          Navigator.pop(context); // Cierra el loading

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fecha propuesta enviada al paciente.')),
          );
          await _load();
        } catch (e) {
          if (!mounted) return;
          Navigator.pop(context); // Cierra el loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppointmentService.messageFromDio(e))),
          );
        }
      }
    } else {
      // --- FLUJO DEL PACIENTE (Aceptar / Rechazar desde la NotificaciÃ³n) ---
      final String? action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.event_available_outlined, color: KeepiColors.skyBlue),
              SizedBox(width: 8),
              Text('Propuesta de Cita', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Text(n.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('reject'), 
              child: const Text('Rechazar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: KeepiColors.skyBlue),
              onPressed: () => Navigator.of(ctx).pop('accept'), 
              child: const Text('Aceptar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (action != null) {
        try {
          if (!mounted) return;
          showDialog(
            context: context, 
            barrierDismissible: false, 
            builder: (_) => const Center(child: CircularProgressIndicator(color: KeepiColors.skyBlue))
          );

          await appointmentSvc.patientRespondProposal(
            appointmentId: appointmentId,
            action: action,
          );
          
          if (!mounted) return;
          Navigator.pop(context); // Cierra el loading

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(action == 'accept' ? 'Cita confirmada exitosamente' : 'Cita rechazada')),
          );
          await _load();
        } catch (e) {
          if (!mounted) return;
          Navigator.pop(context); // Cierra el loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppointmentService.messageFromDio(e))),
          );
        }
      }
    }
  }

  Future<DateTime?> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: KeepiColors.orange)),
        child: child!,
      ),
    );
    if (date == null || !mounted) return null;
    
    final time = await showTimePicker(
      context: context, 
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: KeepiColors.orange)),
        child: child!,
      ),
    );
    if (time == null) return null;
    
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  // â”€â”€ Build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  @override
  Widget build(BuildContext context) {
    final unread = _items.where((n) => !n.read).length;

    return Scaffold(
      backgroundColor: KeepiColors.surfaceBg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: KeepiColors.orange,
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _NotifTopBar(onBack: () => Navigator.of(context).maybePop())),
              SliverToBoxAdapter(child: _NotifHero(total: _items.length, unread: unread)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 40),
                sliver: SliverToBoxAdapter(child: _bodyBlock()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bodyBlock() {
    if (_loading) return const _NotifLoadingBox();
    if (_error != null) return _NotifErrorBox(message: _error!, onRetry: _load);
    if (_items.isEmpty) {
      return const _NotifEmptyCard(
        tag: 'NOTIFICACIONES',
        title: 'Todo al dÃ­a',
        message: 'No tienes avisos pendientes.',
        icon: Icons.mark_email_read_outlined,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NotifSectionDivider(tag: 'RECIENTES', count: _items.length),
        const SizedBox(height: 14),
        for (final n in _items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _NotifCard(
              data: n,
              onTap: () {
                if (n.isQuestionnaireCompleted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cuestionario completado por el paciente.')),
                  );
                  return;
                }
                if (n.appointmentId != null) {
                  _openAppointmentPrompt(n);
                  return;
                }
                _openReminderPrompt(n);
              },
            ),
          ),
      ],
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//   TOP BAR
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _NotifTopBar extends StatelessWidget {
  const _NotifTopBar({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Row(
        children: [
          _IconPill(icon: Icons.arrow_back_rounded, onTap: onBack),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/logo.png',
              width: 34,
              height: 34,
              fit: BoxFit.cover,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _IconPill extends StatelessWidget {
  const _IconPill({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: KeepiColors.cardBorder),
        ),
        child: Icon(icon, size: 19, color: KeepiColors.slate),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//   HERO
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _NotifHero extends StatelessWidget {
  const _NotifHero({required this.total, required this.unread});
  final int total;
  final int unread;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 22, height: 2, color: KeepiColors.slate),
              const SizedBox(width: 8),
              const Text(
                'BANDEJA',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                  color: KeepiColors.slate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Notificaciones.',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: KeepiColors.slate,
              height: 1.1,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Recordatorios de tus recetas y cambios en tus citas.',
            style: TextStyle(fontSize: 13.5, color: KeepiColors.slateLight, height: 1.4),
          ),
          const SizedBox(height: 18),
          _NotifStatsStrip(
            items: [
              _NotifStat(value: total, label: 'TOTAL'),
              _NotifStat(value: unread, label: 'SIN LEER', accent: unread > 0),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotifStat {
  const _NotifStat({required this.value, required this.label, this.accent = false});
  final int value;
  final String label;
  final bool accent;
}

class _NotifStatsStrip extends StatelessWidget {
  const _NotifStatsStrip({required this.items});
  final List<_NotifStat> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              Expanded(child: _NotifStatCell(item: items[i])),
              if (i < items.length - 1)
                Container(width: 1, color: KeepiColors.cardBorder),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotifStatCell extends StatelessWidget {
  const _NotifStatCell({required this.item});
  final _NotifStat item;

  @override
  Widget build(BuildContext context) {
    final color = item.accent ? KeepiColors.orange : KeepiColors.slate;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _two(item.value),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1,
              letterSpacing: -1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              item.label,
              maxLines: 2,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: KeepiColors.slateLight,
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//   DIVIDER
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _NotifSectionDivider extends StatelessWidget {
  const _NotifSectionDivider({required this.tag, required this.count});
  final String tag;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 18, height: 1, color: KeepiColors.slate.withValues(alpha: 0.45)),
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
            color: KeepiColors.slateSoft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _two(count),
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: KeepiColors.slate,
              letterSpacing: 0.3,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(height: 1, color: KeepiColors.slate.withValues(alpha: 0.12)),
        ),
      ],
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//   CARD
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _NotifCard extends StatelessWidget {
  const _NotifCard({required this.data, required this.onTap});
  final AppNotificationDto data;
  final VoidCallback onTap;

  ({String tag, Color color, IconData icon, String actionHint}) _meta() {
    if (data.isQuestionnaireCompleted) {
      return (
        tag: 'CUESTIONARIO',
        color: KeepiColors.orange,
        icon: Icons.assignment_turned_in_outlined,
        actionHint: 'Completado por paciente',
      );
    }
    if (data.appointmentId != null) {
      return (
        tag: 'CITA',
        color: KeepiColors.skyBlue,
        icon: Icons.event_available_outlined,
        actionHint: 'Toca para responder',
      );
    }
    if (data.prescriptionId != null) {
      return (
        tag: 'RECETA',
        color: const Color(0xFF7C3AED),
        icon: Icons.medication_outlined,
        actionHint: 'Toca para responder',
      );
    }
    return (
      tag: 'AVISO',
      color: KeepiColors.slate,
      icon: Icons.info_outline_rounded,
      actionHint: '',
    );
  }

  String get _dateStamp {
    final raw = data.createdAt;
    if (raw == null || raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return '';
    return '${_two(dt.day)} ${_monthsEsUpper[dt.month - 1]} Â· ${_two(dt.hour)}:${_two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final m = _meta();
    final stateColor = data.read ? KeepiColors.slateLight : KeepiColors.orange;
    final stateLabel = data.read ? 'LEÃDA' : 'NUEVA';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: data.read
                ? KeepiColors.cardBorder
                : KeepiColors.orange.withValues(alpha: 0.45),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: m.color, width: 1.6),
                ),
                child: Icon(m.icon, size: 19, color: m.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(color: stateColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          m.tag,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                            color: m.color,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Container(
                          width: 2,
                          height: 2,
                          decoration: BoxDecoration(
                            color: KeepiColors.slateLight.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            stateLabel,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: stateColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 2,
                      width: 20,
                      decoration: BoxDecoration(
                        color: m.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data.title,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: KeepiColors.slate,
                        height: 1.25,
                        letterSpacing: -0.25,
                      ),
                    ),
                    if (data.message.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        data.message.trim(),
                        style: const TextStyle(
                          fontSize: 13,
                          color: KeepiColors.slateLight,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (_dateStamp.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 1,
                            color: KeepiColors.slate.withValues(alpha: 0.55),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _dateStamp,
                              style: TextStyle(
                                fontSize: 12,
                                color: KeepiColors.slate.withValues(alpha: 0.85),
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w500,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (m.actionHint.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            m.actionHint.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                              color: KeepiColors.slate,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: KeepiColors.slate,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//   STATE WIDGETS
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _NotifLoadingBox extends StatelessWidget {
  const _NotifLoadingBox();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: SizedBox(
          width: 22, height: 22,
          child: CircularProgressIndicator(color: KeepiColors.orange, strokeWidth: 2.4),
        ),
      ),
    );
  }
}

class _NotifErrorBox extends StatelessWidget {
  const _NotifErrorBox({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KeepiColors.orange.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: KeepiColors.orange, size: 18),
              SizedBox(width: 8),
              Text(
                'NO PUDIMOS CARGAR',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: KeepiColors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(fontSize: 13.5, color: KeepiColors.slate, height: 1.4),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: onRetry,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: KeepiColors.slate),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, size: 16, color: KeepiColors.slate),
                  SizedBox(width: 6),
                  Text(
                    'REINTENTAR',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: KeepiColors.slate,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotifEmptyCard extends StatelessWidget {
  const _NotifEmptyCard({
    required this.tag,
    required this.title,
    required this.message,
    required this.icon,
  });

  final String tag;
  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 18, height: 1, color: KeepiColors.slate.withValues(alpha: 0.45)),
              const SizedBox(width: 8),
              Text(
                tag,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                  color: KeepiColors.slate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: KeepiColors.slateLight, width: 1.4),
            ),
            child: Icon(icon, size: 26, color: KeepiColors.slateLight),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: KeepiColors.slate,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13.5,
              color: KeepiColors.slateLight,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
