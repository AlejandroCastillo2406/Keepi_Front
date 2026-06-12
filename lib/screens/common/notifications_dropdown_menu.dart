import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import '../../services/notification_navigation.dart';
import '../../services/notifications_service.dart';
import 'notifications_screen.dart';


class NotificationBellMenu extends StatefulWidget {

  final VoidCallback? onViewAll;
  
  const NotificationBellMenu({super.key, this.onViewAll});

  @override
  State<NotificationBellMenu> createState() => _NotificationBellMenuState();
}

class _NotificationBellMenuState extends State<NotificationBellMenu> {
  final OverlayPortalController _overlayController = OverlayPortalController();
  final LayerLink _link = LayerLink();

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      groupId: 'noti_menu',
      onTapOutside: (event) {
        if (_overlayController.isShowing) {
          _overlayController.hide();
        }
      },
      child: CompositedTransformTarget(
        link: _link,
        child: OverlayPortal(
          controller: _overlayController,
          overlayChildBuilder: (BuildContext context) {
            return CompositedTransformFollower(
              link: _link,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(0, 10),
              child: Material(
                color: Colors.transparent,
                child: Align(
                  alignment: Alignment.topRight,
                  child: _NotificationsDropdownContent(
                    onClose: () => _overlayController.hide(),
                    onViewAll: widget.onViewAll, // Pasamos la función al contenido
                  ),
                ),
              ),
            );
          },
          child: InkWell(
            onTap: _overlayController.toggle,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: KeepiColors.cardBorder),
                color: _overlayController.isShowing ? KeepiColors.slateSoft : Colors.transparent,
              ),
              child: const Icon(Icons.notifications_none_rounded, size: 19, color: KeepiColors.slate),
            ),
          ),
        ),
      ),
    );
  }
}


class _NotificationsDropdownContent extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback? onViewAll; // NUEVO
  
  const _NotificationsDropdownContent({required this.onClose, this.onViewAll});

  @override
  State<_NotificationsDropdownContent> createState() => _NotificationsDropdownContentState();
}

class _NotificationsDropdownContentState extends State<_NotificationsDropdownContent> {
  bool _loading = true;
  String? _error;
  List<AppNotificationDto> _items = [];
  bool _showUnreadOnly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final svc = NotificationsService(context.read<ApiClient>());
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await svc.fetchNotifications();
      if (!mounted) return;
      setState(() { _items = rows; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = NotificationsService.messageFromDio(e); _loading = false; });
    }
  }

  Future<void> _openAnalysisDocument(AppNotificationDto n) async {
    widget.onClose(); 
    final data = NotificationNavigation.dataFromNotification(n);
    if (!NotificationNavigation.isAnalysisRequestCompleted(data)) return;
    await NotificationNavigation.openAnalysisDocument(context, data: data, title: n.title);
  }

  Future<void> _openDocumentReplacement(AppNotificationDto n) async {
    widget.onClose();
    final data = NotificationNavigation.dataFromNotification(n);
    if (!NotificationNavigation.isDocumentReplaced(data)) return;
    await NotificationNavigation.openDocumentReplacement(context, data: data);
  }

  Future<void> _openReminderPrompt(AppNotificationDto n) async {
    widget.onClose();
  }

  Future<void> _openAppointmentPrompt(AppNotificationDto n) async {
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _items.where((n) => !n.read).length;

    return TapRegion(
      groupId: 'noti_menu',
      child: Container(
        width: 380,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        margin: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: KeepiColors.surfaceBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KeepiColors.cardBorder),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 8))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Notificaciones',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: KeepiColors.slate, letterSpacing: -0.5),
                      ),
                      if (unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: KeepiColors.orange, borderRadius: BorderRadius.circular(10)),
                          child: Text('${unreadCount.toString().padLeft(2, '0')} nuevas', 
                            style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                        )
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _FilterPill(label: 'Todas', isSelected: !_showUnreadOnly, onTap: () => setState(() => _showUnreadOnly = false)),
                      const SizedBox(width: 8),
                      _FilterPill(label: 'No leídas', isSelected: _showUnreadOnly, onTap: () => setState(() => _showUnreadOnly = true)),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: KeepiColors.cardBorder),
            
            Flexible(child: _buildBody()),

            const Divider(height: 1, color: KeepiColors.cardBorder),
            InkWell(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              onTap: () {
                widget.onClose(); // Cerramos el dropdown
                
                // Si la pantalla principal nos pasó la función, la usamos para mantener el sidebar
                if (widget.onViewAll != null) {
                  widget.onViewAll!();
                } else {
                  // Fallback por si acaso
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen()));
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                child: const Text(
                  'Ver todas las notificaciones',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: KeepiColors.skyBlue),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: KeepiColors.orange)));
    if (_error != null) return Padding(padding: const EdgeInsets.all(20), child: Text(_error!, style: const TextStyle(color: Colors.red)));
    
    final filteredItems = _showUnreadOnly ? _items.where((n) => !n.read).toList() : _items;

    if (filteredItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.mark_email_read_outlined, size: 40, color: KeepiColors.slateLight.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              const Text('Todo al día', style: TextStyle(color: KeepiColors.slate, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              const Text('No tienes avisos en esta sección.', style: TextStyle(color: KeepiColors.slateLight, fontSize: 13)),
            ],
          )
        ),
      );
    }
    
    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.all(12),
      itemCount: filteredItems.length,
      itemBuilder: (context, i) {
        final n = filteredItems[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _DropdownNotifCard(
            data: n,
            onTap: () {
              if (n.isDocumentReplaced) {
                _openDocumentReplacement(n);
                return;
              }
              if (n.isAnalysisRequestCompleted) {
                _openAnalysisDocument(n);
                return;
              }
              if (n.appointmentId != null) {
                _openAppointmentPrompt(n);
                return;
              }
              if (n.isQuestionnaireCompleted) {
                widget.onClose();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cuestionario completado por el paciente.'))
                );
                return;
              }
              _openReminderPrompt(n);
            },
          ),
        );
      },
    );
  }
}


class _FilterPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterPill({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? KeepiColors.skyBlueSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? KeepiColors.skyBlueSoft : KeepiColors.cardBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? KeepiColors.skyBlue : KeepiColors.slate,
          ),
        ),
      ),
    );
  }
}


class _DropdownNotifCard extends StatelessWidget {
  const _DropdownNotifCard({required this.data, required this.onTap});
  final AppNotificationDto data;
  final VoidCallback onTap;

  ({String tag, Color color, IconData icon}) _meta() {
    if (data.isAnalysisRequestCompleted) return (tag: 'ANÁLISIS', color: KeepiColors.orange, icon: Icons.biotech_outlined);
    if (data.isQuestionnaireCompleted) return (tag: 'CUESTIONARIO', color: KeepiColors.orange, icon: Icons.assignment_turned_in_outlined);
    if (data.appointmentId != null) return (tag: 'CITA', color: KeepiColors.skyBlue, icon: Icons.event_available_outlined);
    if (data.prescriptionId != null) return (tag: 'RECETA', color: const Color(0xFF7C3AED), icon: Icons.medication_outlined);
    return (tag: 'AVISO', color: KeepiColors.slate, icon: Icons.info_outline_rounded);
  }

  String get _dateStamp {
    final raw = data.createdAt;
    if (raw == null || raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return '';
    const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} · ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final m = _meta();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: data.read ? Colors.transparent : m.color.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: data.read ? Colors.transparent : m.color.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: m.color, width: 1.5)),
              child: Icon(m.icon, size: 18, color: m.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(m.tag, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: m.color)),
                      const Spacer(),
                      if (_dateStamp.isNotEmpty)
                        Text(_dateStamp, style: const TextStyle(fontSize: 11, color: KeepiColors.slateLight)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.title,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: KeepiColors.slate),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: KeepiColors.slateLight, height: 1.3),
                  ),
                ],
              ),
            ),
            if (!data.read) ...[
              const SizedBox(width: 8),
              Container(
                margin: const EdgeInsets.only(top: 14),
                width: 10, height: 10, 
                decoration: BoxDecoration(color: KeepiColors.orange, shape: BoxShape.circle)
              ),
            ]
          ],
        ),
      ),
    );
  }
}