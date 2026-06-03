import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../models/timeline_event.dart';
import '../services/api_client.dart';
import '../services/doctor_service.dart';

Future<void> showDoctorTimelineNote(
  BuildContext context, {
  required String patientId,
  required TimelineEvent event,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return _DoctorNoteSheet(patientId: patientId, event: event);
    },
  );
}

class _DoctorNoteSheet extends StatefulWidget {
  const _DoctorNoteSheet({
    required this.patientId,
    required this.event,
  });

  final String patientId;
  final TimelineEvent event;

  @override
  State<_DoctorNoteSheet> createState() => _DoctorNoteSheetState();
}

class _DoctorNoteSheetState extends State<_DoctorNoteSheet> {
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
    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.28,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
        child: ListView(
          controller: controller,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.sticky_note_2_outlined, color: KeepiColors.orange),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.event.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: KeepiColors.slate,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Nota clínica del médico',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: KeepiColors.slateLight,
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: KeepiColors.orange),
                ),
              )
            else if (_error != null && _content.isEmpty)
              Text(_error!, style: const TextStyle(color: Colors.red))
            else
              Text(
                _content.isNotEmpty ? _content : 'Sin contenido en la nota.',
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: KeepiColors.slate,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
