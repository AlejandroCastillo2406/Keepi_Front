import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'; // Necesario para kIsWeb
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import '../../services/prescription_service.dart';

class DoctorAssignPrescriptionScreen extends StatefulWidget {
  const DoctorAssignPrescriptionScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  final String patientId;
  final String patientName;

  @override
  State<DoctorAssignPrescriptionScreen> createState() => _DoctorAssignPrescriptionScreenState();
}

class _DoctorAssignPrescriptionScreenState extends State<DoctorAssignPrescriptionScreen> {
  bool _loading = false;
  bool _saving = false;
  String? _draftId;
  final _textCtrl = TextEditingController();
  List<_ItemEditor> _items = [];

  @override
  void dispose() {
    _textCtrl.dispose();
    for (final e in _items) {
      e.dispose();
    }
    super.dispose();
  }

  Future<void> _pickAndAnalyze() async {
    final api = context.read<ApiClient>();
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom, 
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      withData: true, // Obligatorio para leer en la Web
    );
    
    if (picked == null) return;

    final platformFile = picked.files.single;

    // Validación segura para ambas plataformas
    if (kIsWeb && platformFile.bytes == null) return;
    if (!kIsWeb && platformFile.path == null) return;

    setState(() => _loading = true);
    final svc = PrescriptionService(api);
    
    try {
      // Asignación directa y segura dependiendo de la plataforma
      final draft = kIsWeb
          ? await svc.createDraft(
              patientId: widget.patientId,
              fileBytes: platformFile.bytes,
              fileName: platformFile.name,
            )
          : await svc.createDraft(
              patientId: widget.patientId,
              file: File(platformFile.path!),
            );

      if (!mounted) return;
      _textCtrl.text = draft.extractedText;
      for (final e in _items) {
        e.dispose();
      }
      _items = draft.items.map((i) => _ItemEditor.fromDto(i)).toList();
      _draftId = draft.id;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(PrescriptionService.messageFromDio(e))));
    }
  }

  Future<void> _confirmAndAssign() async {
    final draftId = _draftId;
    if (draftId == null) return;
    setState(() => _saving = true);
    final svc = PrescriptionService(context.read<ApiClient>());
    try {
      await svc.confirm(
        prescriptionId: draftId,
        extractedText: _textCtrl.text.trim(),
        items: _items.map((e) => e.toDto()).toList(),
      );
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receta asignada y paciente notificado')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(PrescriptionService.messageFromDio(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Asignar receta a ${widget.patientName}'),
        backgroundColor: Colors.white,
        foregroundColor: KeepiColors.slate,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: _loading ? null : _pickAndAnalyze,
            icon: _loading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.upload_file_rounded),
            label: const Text('Escanear receta (OCR)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _textCtrl,
            minLines: 5,
            maxLines: 12,
            decoration: const InputDecoration(
              labelText: 'Texto extraído (editable)',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          Text('Medicamentos detectados', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_items.isEmpty)
            const Text('Sin medicamentos detectados aún.')
          else
            ..._items.map((i) => i.build()),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: (_saving || _draftId == null) ? null : _confirmAndAssign,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Confirmar y asignar'),
          ),
        ],
      ),
    );
  }
}

class _ItemEditor {
  _ItemEditor({
    required this.medCtrl,
    required this.hoursCtrl,
    required this.daysCtrl,
    required this.routeCtrl,
  });
  final TextEditingController medCtrl;
  final TextEditingController hoursCtrl;
  final TextEditingController daysCtrl;
  final TextEditingController routeCtrl;

  factory _ItemEditor.fromDto(PrescriptionItemDto dto) => _ItemEditor(
        medCtrl: TextEditingController(text: dto.medication),
        hoursCtrl: TextEditingController(text: dto.everyHours?.toString() ?? ''),
        daysCtrl: TextEditingController(text: dto.durationDays?.toString() ?? ''),
        routeCtrl: TextEditingController(text: dto.route ?? ''),
      );

  Widget build() {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            TextField(controller: medCtrl, decoration: const InputDecoration(labelText: 'Medicamento')),
            Row(
              children: [
                Expanded(child: TextField(controller: hoursCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cada (horas)'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: daysCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Duración (días)'))),
              ],
            ),
            TextField(controller: routeCtrl, decoration: const InputDecoration(labelText: 'Vía administración')),
          ],
        ),
      ),
    );
  }

  PrescriptionItemDto toDto() => PrescriptionItemDto(
        medication: medCtrl.text.trim(),
        everyHours: int.tryParse(hoursCtrl.text.trim()),
        durationDays: int.tryParse(daysCtrl.text.trim()),
        route: routeCtrl.text.trim().isEmpty ? null : routeCtrl.text.trim(),
      );

  void dispose() {
    medCtrl.dispose();
    hoursCtrl.dispose();
    daysCtrl.dispose();
    routeCtrl.dispose();
  }
}