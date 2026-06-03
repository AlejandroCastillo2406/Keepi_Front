import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../models/timeline_event.dart';
import '../services/api_client.dart';
import '../services/doctor_service.dart';

/// Bloque de nota del médico dentro del detalle de un evento del timeline.
class DoctorEventNoteSection extends StatefulWidget {
  const DoctorEventNoteSection({
    super.key,
    required this.patientId,
    required this.event,
    this.onNoteSaved,
    this.embeddedInAppointment = false,
  });

  final String patientId;
  final TimelineEvent event;
  final VoidCallback? onNoteSaved;

  /// En citas: la nota se muestra bajo «Motivo de consulta» (sin bloque aparte).
  final bool embeddedInAppointment;

  @override
  State<DoctorEventNoteSection> createState() => _DoctorEventNoteSectionState();
}

class _DoctorEventNoteSectionState extends State<DoctorEventNoteSection> {
  bool _loading = false;
  bool _saving = false;
  bool _editing = false;
  bool _hasNote = false;
  String _content = '';
  String? _error;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _hasNote = widget.event.hasDoctorNote;
    _content = widget.event.doctorNotePreview?.trim() ?? '';
    _controller = TextEditingController(text: _content);
    if (widget.embeddedInAppointment || _hasNote || _content.isNotEmpty) {
      _loadNote();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadNote() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiClient>();
      final data = await DoctorService(api).fetchTimelineDoctorNote(
        patientId: widget.patientId,
        eventId: widget.event.id,
      );
      if (!mounted) return;
      final text = (data['content'] as String?)?.trim() ?? '';
      setState(() {
        _content = text;
        _hasNote = text.isNotEmpty;
        _controller.text = text;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.response?.statusCode == 404) {
        setState(() {
          _hasNote = false;
          _content = '';
          _loading = false;
        });
        return;
      }
      setState(() {
        _error = DoctorService.messageFromDio(e);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = DoctorService.messageFromDio(e);
        _loading = false;
      });
    }
  }

  void _startEditing() {
    _controller.text = _content;
    setState(() => _editing = true);
  }

  void _cancelEditing() {
    _controller.text = _content;
    setState(() => _editing = false);
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe el contenido de la nota.')),
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final api = context.read<ApiClient>();
      final data = await DoctorService(api).upsertTimelineDoctorNote(
        patientId: widget.patientId,
        eventId: widget.event.id,
        eventType: widget.event.eventType,
        doctorNote: text,
      );
      if (!mounted) return;
      final saved = (data['content'] as String?)?.trim() ?? text;
      setState(() {
        _content = saved;
        _hasNote = saved.isNotEmpty;
        _controller.text = saved;
        _editing = false;
        _saving = false;
      });
      widget.onNoteSaved?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nota guardada')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = DoctorService.messageFromDio(e);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DoctorService.messageFromDio(e))),
      );
    }
  }

  String get _sectionTitle =>
      widget.embeddedInAppointment ? 'Motivo de consulta:' : 'Nota del médico';

  String get _emptyLabel => widget.embeddedInAppointment
      ? 'Sin nota registrada.'
      : 'Sin nota registrada para este evento.';

  @override
  Widget build(BuildContext context) {
    final embedded = widget.embeddedInAppointment;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!embedded) ...[
          const Divider(height: 32),
          const Row(
            children: [
              Icon(Icons.sticky_note_2_outlined,
                  size: 20, color: KeepiColors.orange),
              SizedBox(width: 8),
              Text(
                'Nota del médico',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: KeepiColors.slate,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Solo visible para el médico; el paciente no la ve.',
            style: TextStyle(
              fontSize: 12,
              color: KeepiColors.slateLight.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 12),
        ] else ...[
          Text(
            _sectionTitle,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: KeepiColors.slate,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: CircularProgressIndicator(
                color: KeepiColors.orange,
                strokeWidth: 2,
              ),
            ),
          )
        else if (_editing) ...[
          TextField(
            controller: _controller,
            maxLines: 5,
            minLines: 3,
            enabled: !_saving,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Escribe la nota clínica…',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: KeepiColors.cardBorder),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : _cancelEditing,
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: KeepiColors.orange,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Guardar'),
                ),
              ),
            ],
          ),
        ] else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: embedded
                    ? Colors.grey.shade200
                    : KeepiColors.orange.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              _hasNote && _content.isNotEmpty ? _content : _emptyLabel,
              style: TextStyle(
                fontSize: embedded ? 15 : 14,
                height: 1.5,
                color: _hasNote && _content.isNotEmpty
                    ? KeepiColors.slate
                    : KeepiColors.slateLight,
                fontStyle: _hasNote && _content.isNotEmpty
                    ? FontStyle.normal
                    : FontStyle.italic,
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _startEditing,
              icon: Icon(_hasNote ? Icons.edit_outlined : Icons.add),
              label: Text(_hasNote ? 'Editar nota' : 'Añadir nota'),
              style: OutlinedButton.styleFrom(
                foregroundColor: KeepiColors.orange,
                side: const BorderSide(color: KeepiColors.orange),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
