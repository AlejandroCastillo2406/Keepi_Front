import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../services/api_client.dart';
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
                              onTap: () => _openReminderPrompt(n),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

