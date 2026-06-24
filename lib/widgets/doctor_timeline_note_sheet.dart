import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../models/timeline_event.dart';
import '../services/api_client.dart';
import '../services/doctor_service.dart';
import 'notification_web_dialog.dart';

Future<void> showDoctorTimelineNote(
  BuildContext context, {
  required String patientId,
  required TimelineEvent event,
}) async {
  final theme = NotificationDialogTheme.timelineNote();
  await NotificationWebDialog.show<void>(
    context,
    title: event.title,
    tag: theme.tag,
    accent: theme.accent,
    icon: theme.icon,
    subtitle: 'Registrada en el historial clínico',
    maxWidth: 520,
    maxHeightFactor: 0.72,
    child: _DoctorNoteContent(patientId: patientId, event: event),
  );
}

class _DoctorNoteContent extends StatefulWidget {
  const _DoctorNoteContent({
    required this.patientId,
    required this.event,
  });

  final String patientId;
  final TimelineEvent event;

  @override
  State<_DoctorNoteContent> createState() => _DoctorNoteContentState();
}

class _DoctorNoteContentState extends State<_DoctorNoteContent> {
  bool _loading = true;
  String? _error;
  String _content = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = context.read<ApiClient>();
      final data = await DoctorService(api).fetchTimelineDoctorNote(
        patientId: widget.patientId,
        eventId: widget.event.id,
      );
      if (!mounted) return;
      setState(() {
        _content = (data['content'] as String?)?.trim() ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = DoctorService.messageFromDio(e);
        _content = widget.event.doctorNotePreview?.trim() ?? '';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: CircularProgressIndicator(color: KeepiColors.orange),
        ),
      );
    }

    if (_error != null && _content.isEmpty) {
      return Text(_error!, style: const TextStyle(color: Colors.red));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: KeepiColors.surfaceBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: Text(
        _content.isNotEmpty ? _content : 'Sin contenido en la nota.',
        style: const TextStyle(
          fontSize: 15,
          height: 1.55,
          color: KeepiColors.slate,
        ),
      ),
    );
  }
}
