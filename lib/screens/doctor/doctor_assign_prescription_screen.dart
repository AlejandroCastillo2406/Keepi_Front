import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/web_layout.dart';
import '../../services/api_client.dart';
import '../../services/prescription_service.dart';

class DoctorAssignPrescriptionScreen extends StatefulWidget {
  const DoctorAssignPrescriptionScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    this.embedded = false,
    this.onBack,
  });

  final String patientId;
  final String patientName;
  final bool embedded;
  final VoidCallback? onBack;

  @override
  State<DoctorAssignPrescriptionScreen> createState() =>
      _DoctorAssignPrescriptionScreenState();
}

class _DoctorAssignPrescriptionScreenState
    extends State<DoctorAssignPrescriptionScreen> {
  bool _loading = false;
  bool _bootstrapping = true;
  bool _saving = false;
  String? _draftId;
  final _textCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  List<_ItemEditor> _items = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initManualDraft());
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _noteCtrl.dispose();
    for (final e in _items) {
      e.dispose();
    }
    super.dispose();
  }

  void _onFieldsChanged() {
    if (mounted) setState(() {});
  }

  void _clearItems() {
    for (final e in _items) {
      e.dispose();
    }
    _items = [];
  }

  void _applyDraft(PrescriptionDraftDto draft) {
    _textCtrl.text = draft.extractedText;
    _clearItems();
    _items = draft.items.map((i) => _ItemEditor.fromDto(i)).toList();
    if (_items.isEmpty) {
      _items = [_ItemEditor.empty()];
    }
    for (final item in _items) {
      item.attachListener(_onFieldsChanged);
    }
    _draftId = draft.id;
  }

  Future<void> _initManualDraft() async {
    if (_draftId != null) return;
    setState(() {
      _loading = true;
      _bootstrapping = true;
    });
    final svc = PrescriptionService(context.read<ApiClient>());
    try {
      final draft = await svc.createManualDraft(patientId: widget.patientId);
      if (!mounted) return;
      setState(() {
        _applyDraft(draft);
        _loading = false;
        _bootstrapping = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _bootstrapping = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(PrescriptionService.messageFromDio(e))),
      );
    }
  }

  Future<void> _pickAndAnalyze() async {
    final api = context.read<ApiClient>();
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      withData: true,
    );

    if (picked == null) return;

    final platformFile = picked.files.single;

    if (kIsWeb && platformFile.bytes == null) return;
    if (!kIsWeb && platformFile.path == null) return;

    setState(() => _loading = true);
    final svc = PrescriptionService(api);

    try {
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
      setState(() {
        _applyDraft(draft);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(PrescriptionService.messageFromDio(e))),
      );
    }
  }

  bool get _canAddMedication =>
      _draftId != null &&
      !_loading &&
      _items.isNotEmpty &&
      _items.last.isComplete;

  void _addMedication() {
    if (!_canAddMedication) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Completa todos los campos del medicamento actual antes de agregar otro.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final item = _ItemEditor.empty();
    item.attachListener(_onFieldsChanged);
    setState(() => _items.add(item));
  }

  void _removeMedication(int index) {
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
      if (_items.isEmpty) {
        final item = _ItemEditor.empty();
        item.attachListener(_onFieldsChanged);
        _items = [item];
      }
    });
  }

  bool _hasValidContent() {
    final text = _textCtrl.text.trim();
    if (text.isNotEmpty) return true;
    return _items.any((e) => e.isComplete);
  }

  Future<void> _confirmAndAssign() async {
    final draftId = _draftId;
    if (draftId == null) return;

    final items = _items
        .map((e) => e.toDto())
        .where((i) => i.medication.trim().isNotEmpty)
        .toList();

    if (!_hasValidContent()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Agrega al menos un medicamento completo o escribe el texto de la receta.',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final svc = PrescriptionService(context.read<ApiClient>());
    try {
      await svc.confirm(
        prescriptionId: draftId,
        extractedText: _textCtrl.text.trim(),
        items: items,
        doctorNote: _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receta asignada y paciente notificado')),
      );
      if (widget.onBack != null) {
        widget.onBack!();
      } else {
        context.pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(PrescriptionService.messageFromDio(e))),
      );
    }
  }

  Widget _buildMedicationsSection() {
    final filledCount = _items.where((e) => e.isComplete).length;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KeepiColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: KeepiColors.orange.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  KeepiColors.orange.withValues(alpha: 0.14),
                  KeepiColors.orangeSoft.withValues(alpha: 0.35),
                ],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: KeepiColors.orange.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Icon(
                    Icons.medication_liquid_rounded,
                    color: KeepiColors.orange,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MEDICAMENTOS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                          color: KeepiColors.orange,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$filledCount de ${_items.length} completos',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: KeepiColors.slate,
                        ),
                      ),
                    ],
                  ),
                ),
                Tooltip(
                  message: 'Escanear receta con OCR',
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: KeepiColors.orange.withValues(alpha: 0.35),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _loading ? null : _pickAndAnalyze,
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: _loading
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: KeepiColors.orange,
                                ),
                              )
                            : const Icon(
                                Icons.document_scanner_outlined,
                                color: KeepiColors.orange,
                                size: 20,
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: _canAddMedication
                      ? 'Agregar otro medicamento'
                      : 'Completa el medicamento actual',
                  child: Material(
                    color: _canAddMedication
                        ? KeepiColors.orange
                        : KeepiColors.slateLight.withValues(alpha: 0.35),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    elevation: _canAddMedication ? 2 : 0,
                    shadowColor: KeepiColors.orange.withValues(alpha: 0.35),
                    child: InkWell(
                      onTap: _addMedication,
                      child: const SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              children: [
                if (!_canAddMedication && _items.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: KeepiColors.skyBlueSoft.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: KeepiColors.skyBlue.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: KeepiColors.skyBlue,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Llena medicamento, horas, días y vía para habilitar el +',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: KeepiColors.slate,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ...List.generate(
                  _items.length,
                  (index) => _items[index].build(
                    index: index,
                    onChanged: _onFieldsChanged,
                    onRemove: _items.length > 1
                        ? () => _removeMedication(index)
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _textFieldMinLines(String text, {required bool showFullText}) {
    if (!showFullText) return 2;
    if (text.trim().isEmpty) return 6;
    return text.split('\n').length.clamp(6, 40);
  }

  Widget _buildOptionalExpansion({
    required String title,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    bool showFullText = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Icon(icon, size: 20, color: KeepiColors.slateLight),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: KeepiColors.slate,
            ),
          ),
          subtitle: controller.text.trim().isEmpty
              ? const Text(
                  'Opcional · toca para expandir',
                  style: TextStyle(fontSize: 12, color: KeepiColors.slateLight),
                )
              : Text(
                  controller.text.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: KeepiColors.slate,
                  ),
                ),
          onExpansionChanged: (_) => setState(() {}),
          children: [
            TextField(
              controller: controller,
              enabled: !_saving,
              maxLines: showFullText ? null : 3,
              minLines: _textFieldMinLines(
                controller.text,
                showFullText: showFullText,
              ),
              onChanged: (_) => setState(() {}),
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: hint,
                isDense: true,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
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
                  borderSide: const BorderSide(
                    color: KeepiColors.orange,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    if (_bootstrapping) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(color: KeepiColors.orange),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        widget.embedded ? 28 : 16,
        widget.embedded ? 20 : 12,
        widget.embedded ? 28 : 16,
        24,
      ),
      children: [
        _buildMedicationsSection(),
        const SizedBox(height: 12),
        _buildOptionalExpansion(
          title: 'Texto extraído de la receta',
          hint: 'Texto detectado en la imagen…',
          controller: _textCtrl,
          icon: Icons.notes_rounded,
          showFullText: true,
        ),
        _buildOptionalExpansion(
          title: 'Nota clínica',
          hint: 'Solo visible para ti, en el timeline…',
          controller: _noteCtrl,
          icon: Icons.sticky_note_2_outlined,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: (_saving || _draftId == null) ? null : _confirmAndAssign,
            style: FilledButton.styleFrom(
              backgroundColor: KeepiColors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(
              _saving ? 'Guardando…' : 'Asignar receta',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return EmbeddedWebPage(
        title: 'Asignar receta a ${widget.patientName}',
        onBack: widget.onBack,
        child: _buildForm(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Asignar receta a ${widget.patientName}'),
        backgroundColor: Colors.white,
        foregroundColor: KeepiColors.slate,
        elevation: 0,
      ),
      body: _buildForm(),
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
  VoidCallback? _listener;

  bool get isComplete {
    final med = medCtrl.text.trim();
    final hours = hoursCtrl.text.trim();
    final days = daysCtrl.text.trim();
    final route = routeCtrl.text.trim();
    return med.isNotEmpty &&
        hours.isNotEmpty &&
        int.tryParse(hours) != null &&
        days.isNotEmpty &&
        int.tryParse(days) != null &&
        route.isNotEmpty;
  }

  void attachListener(VoidCallback listener) {
    _listener = listener;
    medCtrl.addListener(listener);
    hoursCtrl.addListener(listener);
    daysCtrl.addListener(listener);
    routeCtrl.addListener(listener);
  }

  factory _ItemEditor.empty() => _ItemEditor(
        medCtrl: TextEditingController(),
        hoursCtrl: TextEditingController(),
        daysCtrl: TextEditingController(),
        routeCtrl: TextEditingController(),
      );

  factory _ItemEditor.fromDto(PrescriptionItemDto dto) => _ItemEditor(
        medCtrl: TextEditingController(text: dto.medication),
        hoursCtrl: TextEditingController(text: dto.everyHours?.toString() ?? ''),
        daysCtrl: TextEditingController(text: dto.durationDays?.toString() ?? ''),
        routeCtrl: TextEditingController(text: dto.route ?? ''),
      );

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    bool complete = false,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: KeepiColors.orange),
      filled: true,
      fillColor: complete
          ? KeepiColors.orangeSoft.withValues(alpha: 0.25)
          : const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: KeepiColors.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: complete
              ? KeepiColors.orange.withValues(alpha: 0.35)
              : KeepiColors.cardBorder,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: KeepiColors.orange, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget build({
    required int index,
    required VoidCallback onChanged,
    VoidCallback? onRemove,
  }) {
    final number = (index + 1).toString().padLeft(2, '0');
    final complete = isComplete;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: complete
              ? KeepiColors.orange.withValues(alpha: 0.4)
              : KeepiColors.cardBorder,
          width: complete ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: KeepiColors.slate.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
            decoration: BoxDecoration(
              color: complete
                  ? KeepiColors.orangeSoft.withValues(alpha: 0.45)
                  : KeepiColors.slateSoft.withValues(alpha: 0.35),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: complete
                          ? [KeepiColors.orange, const Color(0xFFFF9A56)]
                          : [
                              KeepiColors.slateLight.withValues(alpha: 0.5),
                              KeepiColors.slateLight.withValues(alpha: 0.3),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    number,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: complete ? Colors.white : KeepiColors.slate,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    complete ? 'Medicamento listo' : 'Medicamento $number',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: complete ? KeepiColors.orange : KeepiColors.slate,
                    ),
                  ),
                ),
                if (complete)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: KeepiColors.green,
                    size: 20,
                  ),
                if (onRemove != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: KeepiColors.slateLight,
                    tooltip: 'Quitar medicamento',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
            child: Column(
              children: [
                TextField(
                  controller: medCtrl,
                  onChanged: (_) => onChanged(),
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _fieldDecoration(
                    label: 'Medicamento',
                    icon: Icons.medication_outlined,
                    complete: medCtrl.text.trim().isNotEmpty,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: hoursCtrl,
                        onChanged: (_) => onChanged(),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: _fieldDecoration(
                          label: 'Cada (horas)',
                          icon: Icons.schedule_rounded,
                          complete: int.tryParse(hoursCtrl.text.trim()) != null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: daysCtrl,
                        onChanged: (_) => onChanged(),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: _fieldDecoration(
                          label: 'Duración (días)',
                          icon: Icons.calendar_today_rounded,
                          complete: int.tryParse(daysCtrl.text.trim()) != null,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: routeCtrl,
                  onChanged: (_) => onChanged(),
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _fieldDecoration(
                    label: 'Vía administración',
                    icon: Icons.route_rounded,
                    complete: routeCtrl.text.trim().isNotEmpty,
                  ),
                ),
              ],
            ),
          ),
        ],
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
    final listener = _listener;
    if (listener != null) {
      medCtrl.removeListener(listener);
      hoursCtrl.removeListener(listener);
      daysCtrl.removeListener(listener);
      routeCtrl.removeListener(listener);
    }
    medCtrl.dispose();
    hoursCtrl.dispose();
    daysCtrl.dispose();
    routeCtrl.dispose();
  }
}
