import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/web_layout.dart';
import '../services/doctor_service.dart';
import 'doctor_patient_web_blocks.dart';

/// Abre el selector de paciente (dialog web / bottom sheet móvil).
/// Devuelve el paciente elegido o `null` si se cancela.
Future<PatientListItem?> openDoctorPatientPicker(
  BuildContext context, {
  required List<PatientListItem> patients,
}) {
  final asWebDialog = isWebWide(context);

  Widget buildSheet(BuildContext ctx) => DoctorPatientPickerSheet(
        patients: patients,
        asWebDialog: asWebDialog,
        onSelect: (p) => Navigator.of(ctx).pop(p),
        onClose: () => Navigator.of(ctx).pop(),
      );

  if (asWebDialog) {
    return showDialog<PatientListItem>(
      context: context,
      barrierColor: KeepiColors.slate.withValues(alpha: 0.48),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: buildSheet(ctx),
      ),
    );
  }

  return showModalBottomSheet<PatientListItem>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: buildSheet,
  );
}

List<PatientListItem> filterPatientsByQuery(
  List<PatientListItem> patients,
  String query,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return patients;
  return patients
      .where(
        (p) =>
            p.name.toLowerCase().contains(q) ||
            p.email.toLowerCase().contains(q),
      )
      .toList();
}

class DoctorPatientPickerSheet extends StatefulWidget {
  const DoctorPatientPickerSheet({
    super.key,
    required this.patients,
    required this.asWebDialog,
    required this.onSelect,
    required this.onClose,
  });

  final List<PatientListItem> patients;
  final bool asWebDialog;
  final ValueChanged<PatientListItem> onSelect;
  final VoidCallback onClose;

  @override
  State<DoctorPatientPickerSheet> createState() =>
      _DoctorPatientPickerSheetState();
}

class _DoctorPatientPickerSheetState extends State<DoctorPatientPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    if (widget.asWebDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) FocusScope.of(context).requestFocus(_searchFocus);
      });
    }
  }

  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<PatientListItem> get _filtered =>
      filterPatientsByQuery(widget.patients, _query);

  @override
  Widget build(BuildContext context) {
    if (widget.asWebDialog) return _buildWebDialog(context);
    return _buildMobileSheet(context);
  }

  Widget _buildWebDialog(BuildContext context) {
    final filtered = _filtered;
    final total = widget.patients.length;

    return Container(
      constraints: const BoxConstraints(maxWidth: 640, maxHeight: 620),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 60,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildWebHeader(total: total, showing: filtered.length),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: _PickerSearchField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              hint: 'Buscar por nombre o correo…',
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: filtered.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      return _PatientPickerWebTile(
                        patient: filtered[index],
                        onTap: () => widget.onSelect(filtered[index]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebHeader({required int total, required int showing}) {
    return Stack(
      children: [
        Container(
          height: 118,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2D3F4C), Color(0xFF46555F)],
            ),
          ),
        ),
        Positioned(
          right: -24,
          top: -24,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
        ),
        Positioned(
          right: 48,
          bottom: -18,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: KeepiColors.orange.withValues(alpha: 0.18),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 16, 0),
          child: SizedBox(
            height: 118,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: KeepiColors.orange.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: KeepiColors.orange.withValues(alpha: 0.42),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.person_search_rounded,
                    color: Color(0xFFFFBF7A),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Selecciona un paciente',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.35,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Busca por nombre o correo para agendar la cita.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _HeaderCountChip(
                        total: total,
                        showing: showing,
                        filtered: _query.trim().isNotEmpty,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: widget.onClose,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileSheet(BuildContext context) {
    final filtered = _filtered;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Color(0x1A46555F),
              blurRadius: 24,
              offset: Offset(0, -4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: KeepiColors.slateLight.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 12, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: KeepiColors.orangeSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person_search_rounded,
                      color: KeepiColors.orange,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selecciona un paciente',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: KeepiColors.slate,
                            letterSpacing: -0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Busca por nombre o correo',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: KeepiColors.slateLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onClose,
                    style: IconButton.styleFrom(
                      backgroundColor: KeepiColors.slateSoft,
                      foregroundColor: KeepiColors.slateLight,
                    ),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
              child: _PickerSearchField(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                hint: 'Nombre o correo…',
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmptyState(compact: true)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final p = filtered[index];
                        final theme = PatientAvatarTheme.fromSex(p.sex);
                        final initial = p.name.trim().isEmpty
                            ? '?'
                            : p.name.trim()[0].toUpperCase();
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => widget.onSelect(p),
                            borderRadius: BorderRadius.circular(14),
                            child: Ink(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: KeepiColors.cardBorder,
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: theme.soft,
                                    child: Text(
                                      initial,
                                      style: TextStyle(
                                        color: theme.accent,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: KeepiColors.slate,
                                          ),
                                        ),
                                        Text(
                                          p.email,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            color: KeepiColors.slateLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: KeepiColors.slateLight,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({bool compact = false}) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 24 : 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 52 : 64,
              height: compact ? 52 : 64,
              decoration: BoxDecoration(
                color: KeepiColors.slateSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: compact ? 26 : 32,
                color: KeepiColors.slateLight,
              ),
            ),
            SizedBox(height: compact ? 12 : 16),
            Text(
              _query.trim().isEmpty
                  ? 'No hay pacientes registrados'
                  : 'Sin resultados para "$_query"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: KeepiColors.slate,
              ),
            ),
            if (_query.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              const Text(
                'Prueba con otro nombre o correo.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: KeepiColors.slateLight,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeaderCountChip extends StatelessWidget {
  const _HeaderCountChip({
    required this.total,
    required this.showing,
    required this.filtered,
  });

  final int total;
  final int showing;
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    final label = filtered ? '$showing de $total pacientes' : '$total pacientes';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: 0.85),
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _PickerSearchField extends StatelessWidget {
  const _PickerSearchField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: KeepiColors.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            style: const TextStyle(fontSize: 14.5, color: KeepiColors.slate),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: KeepiColors.slateLight,
                fontSize: 14.5,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: KeepiColors.orange,
                size: 21,
              ),
              suffixIcon: value.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: KeepiColors.slateLight,
                      ),
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                    ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PatientPickerWebTile extends StatefulWidget {
  const _PatientPickerWebTile({
    required this.patient,
    required this.onTap,
  });

  final PatientListItem patient;
  final VoidCallback onTap;

  @override
  State<_PatientPickerWebTile> createState() => _PatientPickerWebTileState();
}

class _PatientPickerWebTileState extends State<_PatientPickerWebTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;
    final theme = PatientAvatarTheme.fromSex(p.sex);
    final initial =
        p.name.trim().isEmpty ? '?' : p.name.trim()[0].toUpperCase();
    final hasPhone = (p.phone ?? '').trim().isNotEmpty;
    final hasAge = p.ageYears != null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovered ? KeepiColors.orange : KeepiColors.cardBorder,
              width: _hovered ? 1.5 : 1,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: KeepiColors.orange.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.soft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.accent.withValues(alpha: 0.25)),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: theme.accent,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _hovered ? KeepiColors.orange : KeepiColors.slate,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.email,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: KeepiColors.slateLight,
                      ),
                    ),
                    if (hasPhone || hasAge) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (hasAge)
                            _MetaPill(
                              icon: Icons.cake_outlined,
                              label: '${p.ageYears} años',
                            ),
                          if (hasPhone)
                            _MetaPill(
                              icon: Icons.phone_outlined,
                              label: p.phone!.trim(),
                            ),
                          if (p.hasClinicalProfile)
                            const _MetaPill(
                              icon: Icons.verified_outlined,
                              label: 'Perfil clínico',
                              accent: Color(0xFF0D9488),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: _hovered ? 1 : 0.35,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _hovered
                        ? KeepiColors.orangeSoft
                        : KeepiColors.slateSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: _hovered ? KeepiColors.orange : KeepiColors.slateLight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
    this.accent,
  });

  final IconData icon;
  final String label;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? KeepiColors.slateLight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (accent ?? KeepiColors.slateLight).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
