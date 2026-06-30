import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/web_layout.dart';
import '../services/doctor_service.dart';
import '../utils/attendance_kpi.dart';
import 'doctor_patient_web_blocks.dart';

class DoctorPatientDirectoryTile extends StatefulWidget {
  const DoctorPatientDirectoryTile({
    super.key,
    required this.patient,
    required this.onProfileTap,
    required this.onDeleteTap,
    required this.onArrowTap,
  });

  final PatientListItem patient;
  final VoidCallback onProfileTap;
  final VoidCallback onDeleteTap;
  final VoidCallback onArrowTap;

  @override
  State<DoctorPatientDirectoryTile> createState() =>
      _DoctorPatientDirectoryTileState();
}

class _DoctorPatientDirectoryTileState extends State<DoctorPatientDirectoryTile> {
  bool _hovered = false;

  PatientListItem get patient => widget.patient;

  String get _initial =>
      patient.name.trim().isEmpty ? '?' : patient.name.trim()[0].toUpperCase();

  String get _sexLabel {
    final value = (patient.sex ?? '').trim();
    if (value.isEmpty) return '—';
    final lower = value.toLowerCase();
    if (lower == 'male' || lower == 'm') return 'Masculino';
    if (lower == 'female' || lower == 'f') return 'Femenino';
    return value;
  }

  bool get _validBloodType {
    final value = (patient.bloodType ?? '').trim().toLowerCase();
    return value.isNotEmpty && value != 'desconocido';
  }

  int get _attendancePercent {
    final total = patient.appointmentsAttended + patient.appointmentsNoShow;
    if (total == 0) return 0;
    return ((patient.appointmentsAttended / total) * 100).round();
  }

  String _dateShort(DateTime? date) {
    if (date == null) return 'Sin registro';
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final webWide = isWebWide(context);
    final hasPhone = (patient.phone ?? '').trim().isNotEmpty;
    final hasAllergies = (patient.allergies ?? '').trim().isNotEmpty;
    final hasNextAppointment = patient.nextAppointmentDate != null;
    final avatarTheme = PatientAvatarTheme.fromSex(patient.sex);

    final card = Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(webWide ? 18 : 20),
      clipBehavior: Clip.antiAlias,
      elevation: webWide && _hovered ? 3 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        onTap: widget.onProfileTap,
        hoverColor: KeepiColors.orangeSoft.withValues(alpha: 0.35),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(webWide ? 18 : 20),
            border: Border.all(
              color: _hovered && webWide
                  ? KeepiColors.orange.withValues(alpha: 0.28)
                  : KeepiColors.cardBorder,
            ),
          ),
          padding: EdgeInsets.all(webWide ? 20 : 18),
          child: webWide
              ? _webBody(
                  hasPhone: hasPhone,
                  hasAllergies: hasAllergies,
                  hasNextAppointment: hasNextAppointment,
                  avatarTheme: avatarTheme,
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 760;
                    return compact
                        ? _mobileBody(
                            hasPhone: hasPhone,
                            hasAllergies: hasAllergies,
                            hasNextAppointment: hasNextAppointment,
                            avatarTheme: avatarTheme,
                            compact: true,
                          )
                        : _mobileBody(
                            hasPhone: hasPhone,
                            hasAllergies: hasAllergies,
                            hasNextAppointment: hasNextAppointment,
                            avatarTheme: avatarTheme,
                            compact: false,
                          );
                  },
                ),
        ),
      ),
    );

    if (!webWide) return card;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: card,
    );
  }

  Widget _webBody({
    required bool hasPhone,
    required bool hasAllergies,
    required bool hasNextAppointment,
    required PatientAvatarTheme avatarTheme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Avatar(
              initial: _initial,
              size: 56,
              theme: avatarTheme,
              rounded: true,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _IdentityBlock(
                patient: patient,
                hasPhone: hasPhone,
                compact: true,
              ),
            ),
            IconButton(
              onPressed: widget.onDeleteTap,
              tooltip: 'Desactivar paciente',
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.delete_outline_rounded,
                color: KeepiColors.slateLight.withValues(alpha: 0.75),
                size: 21,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 5,
              child: _ClinicalGrid(
                patient: patient,
                sexLabel: _sexLabel,
                validBloodType: _validBloodType,
                compact: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 4,
              child: _AttendanceStrip(
                attended: patient.appointmentsAttended,
                noShow: patient.appointmentsNoShow,
                percent: _attendancePercent,
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 210,
              child: _AppointmentSummary(
                hasNextAppointment: hasNextAppointment,
                label: hasNextAppointment ? 'Próxima cita' : 'Última cita',
                value: hasNextAppointment
                    ? _dateShort(patient.nextAppointmentDate)
                    : _dateShort(patient.lastAppointmentDate),
                compact: true,
              ),
            ),
            const SizedBox(width: 12),
            _Actions(
              onProfileTap: widget.onProfileTap,
              onArrowTap: widget.onArrowTap,
              compact: true,
            ),
          ],
        ),
        if (hasAllergies) ...[
          const SizedBox(height: 12),
          _AllergyBox(allergies: patient.allergies!.trim()),
        ],
      ],
    );
  }

  Widget _mobileBody({
    required bool hasPhone,
    required bool hasAllergies,
    required bool hasNextAppointment,
    required PatientAvatarTheme avatarTheme,
    required bool compact,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Avatar(
              initial: _initial,
              size: compact ? 58 : 70,
              theme: avatarTheme,
            ),
            SizedBox(width: compact ? 14 : 22),
            Expanded(
              child: _IdentityBlock(
                patient: patient,
                hasPhone: hasPhone,
                compact: compact,
              ),
            ),
            IconButton(
              onPressed: widget.onDeleteTap,
              tooltip: 'Desactivar paciente',
              icon: Icon(
                Icons.delete_outline_rounded,
                color: KeepiColors.slateLight.withValues(alpha: 0.7),
                size: compact ? 22 : 24,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _SoftDivider(),
        const SizedBox(height: 16),
        if (compact) ...[
          _ClinicalGrid(
            patient: patient,
            sexLabel: _sexLabel,
            validBloodType: _validBloodType,
          ),
          const SizedBox(height: 14),
          _AttendanceStrip(
            attended: patient.appointmentsAttended,
            noShow: patient.appointmentsNoShow,
            percent: _attendancePercent,
          ),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _ClinicalGrid(
                  patient: patient,
                  sexLabel: _sexLabel,
                  validBloodType: _validBloodType,
                ),
              ),
              const SizedBox(width: 18),
              _AttendanceStrip(
                attended: patient.appointmentsAttended,
                noShow: patient.appointmentsNoShow,
                percent: _attendancePercent,
              ),
            ],
          ),
        if (hasAllergies) ...[
          const SizedBox(height: 14),
          _AllergyBox(allergies: patient.allergies!.trim()),
        ],
        const SizedBox(height: 18),
        const _SoftDivider(),
        const SizedBox(height: 16),
        if (compact)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AppointmentSummary(
                hasNextAppointment: hasNextAppointment,
                label: hasNextAppointment ? 'Próxima cita:' : 'Última cita:',
                value: hasNextAppointment
                    ? _dateShort(patient.nextAppointmentDate)
                    : _dateShort(patient.lastAppointmentDate),
              ),
              const SizedBox(height: 14),
              _Actions(
                onProfileTap: widget.onProfileTap,
                onArrowTap: widget.onArrowTap,
                fullWidth: true,
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: _AppointmentSummary(
                  hasNextAppointment: hasNextAppointment,
                  label:
                      hasNextAppointment ? 'Próxima cita:' : 'Última cita:',
                  value: hasNextAppointment
                      ? _dateShort(patient.nextAppointmentDate)
                      : _dateShort(patient.lastAppointmentDate),
                ),
              ),
              const SizedBox(width: 16),
              _Actions(
                onProfileTap: widget.onProfileTap,
                onArrowTap: widget.onArrowTap,
              ),
            ],
          ),
      ],
    );
  }
}

class _IdentityBlock extends StatelessWidget {
  const _IdentityBlock({
    required this.patient,
    required this.hasPhone,
    this.compact = false,
  });

  final PatientListItem patient;
  final bool hasPhone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              patient.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 18 : 22,
                fontWeight: FontWeight.w900,
                color: KeepiColors.slate,
                letterSpacing: -0.4,
              ),
            ),
            _StatusBadge(
              label: patient.hasClinicalProfile
                  ? 'PERFIL CLÍNICO'
                  : 'FALTA PERFIL',
              color: patient.hasClinicalProfile
                  ? KeepiColors.green
                  : KeepiColors.orange,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            _InlineInfo(
              icon: Icons.mail_outline_rounded,
              text: patient.email,
            ),
            if (hasPhone)
              _InlineInfo(
                icon: Icons.phone_outlined,
                text: patient.phone!.trim(),
              ),
          ],
        ),
      ],
    );
  }
}

class _ClinicalGrid extends StatelessWidget {
  const _ClinicalGrid({
    required this.patient,
    required this.sexLabel,
    required this.validBloodType,
    this.compact = false,
  });

  final PatientListItem patient;
  final String sexLabel;
  final bool validBloodType;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final items = <_ClinicalValue>[
      if (patient.ageYears != null)
        _ClinicalValue(label: 'EDAD', value: '${patient.ageYears} años'),
      _ClinicalValue(label: 'SEXO', value: sexLabel),
      if (validBloodType)
        _ClinicalValue(label: 'SANGRE', value: patient.bloodType!.trim()),
      if (patient.weightKg != null)
        _ClinicalValue(
          label: 'PESO',
          value:
              '${patient.weightKg!.toStringAsFixed(patient.weightKg! % 1 == 0 ? 0 : 1)} kg',
        ),
      _ClinicalValue(
        label: 'DOCUMENTOS',
        value: patient.documentsTotal.toString(),
      ),
    ];

    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Expanded(child: items[i]),
          if (i < items.length - 1)
            Container(
              width: 1,
              height: compact ? 34 : 38,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: KeepiColors.cardBorder.withValues(alpha: 0.8),
            ),
        ],
      ],
    );
  }
}

class _AttendanceStrip extends StatelessWidget {
  const _AttendanceStrip({
    required this.attended,
    required this.noShow,
    required this.percent,
  });

  final int attended;
  final int noShow;
  final int percent;

  @override
  Widget build(BuildContext context) {
    final rateColor = percent > 0
        ? AttendanceKpi.colorForPercent(percent.toDouble())
        : KeepiColors.slateLight;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: _MetricPill(
              value: attended.toString().padLeft(2, '0'),
              label: 'ASISTIÓ',
              color: attended > 0
                  ? KeepiColors.green
                  : KeepiColors.slateLight,
            ),
          ),
          Container(
            width: 1,
            height: 28,
            color: KeepiColors.cardBorder,
          ),
          Expanded(
            child: _MetricPill(
              value: noShow.toString().padLeft(2, '0'),
              label: 'NO ASISTIÓ',
              color: noShow > 0
                  ? const Color(0xFFDC2626)
                  : KeepiColors.slateLight,
            ),
          ),
          Container(
            width: 1,
            height: 28,
            color: KeepiColors.cardBorder,
          ),
          Expanded(
            child: _MetricPill(
              value: '$percent%',
              label: 'TASA',
              color: rateColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: color,
            height: 1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: color.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.onProfileTap,
    required this.onArrowTap,
    this.fullWidth = false,
    this.compact = false,
  });

  final VoidCallback onProfileTap;
  final VoidCallback onArrowTap;
  final bool fullWidth;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton.icon(
      onPressed: onProfileTap,
      icon: Icon(Icons.folder_open_outlined, size: compact ? 16 : 17),
      label: const Text('Expediente'),
      style: FilledButton.styleFrom(
        backgroundColor: KeepiColors.orange,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 18 : 22,
          vertical: compact ? 14 : 16,
        ),
        minimumSize: Size(compact ? 0 : 120, compact ? 42 : 48),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: compact ? 13 : 14,
        ),
      ),
    );

    return Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (fullWidth) Expanded(child: button) else button,
        const SizedBox(width: 8),
        Material(
          color: KeepiColors.slateSoft,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onArrowTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: compact ? 42 : 48,
              height: compact ? 42 : 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: KeepiColors.cardBorder),
              ),
              child: const Icon(
                Icons.more_horiz_rounded,
                color: KeepiColors.slate,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.initial,
    required this.size,
    required this.theme,
    this.rounded = false,
  });

  final String initial;
  final double size;
  final PatientAvatarTheme theme;
  final bool rounded;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.soft,
        borderRadius: BorderRadius.circular(rounded ? size * 0.32 : 16),
        border: Border.all(color: theme.accent.withValues(alpha: 0.55), width: 1.6),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w900,
          color: theme.accent,
        ),
      ),
    );
  }
}

class _AppointmentSummary extends StatelessWidget {
  const _AppointmentSummary({
    required this.hasNextAppointment,
    required this.label,
    required this.value,
    this.compact = false,
  });

  final bool hasNextAppointment;
  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 0,
        vertical: compact ? 10 : 0,
      ),
      decoration: compact
          ? BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: KeepiColors.cardBorder),
            )
          : null,
      child: Row(
        children: [
          Icon(
            hasNextAppointment
                ? Icons.event_available_outlined
                : Icons.calendar_month_outlined,
            size: 18,
            color: KeepiColors.slate,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: KeepiColors.slateLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: KeepiColors.slate,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AllergyBox extends StatelessWidget {
  const _AllergyBox({required this.allergies});

  final String allergies;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: KeepiColors.orangeSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KeepiColors.orange.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: KeepiColors.orange,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Alergias: $allergies',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: KeepiColors.slate,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _InlineInfo extends StatelessWidget {
  const _InlineInfo({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: KeepiColors.slateLight),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            color: KeepiColors.slateLight,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ClinicalValue extends StatelessWidget {
  const _ClinicalValue({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: KeepiColors.slateLight,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: KeepiColors.slate,
          ),
        ),
      ],
    );
  }
}

class _SoftDivider extends StatelessWidget {
  const _SoftDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: KeepiColors.cardBorder.withValues(alpha: 0.75),
    );
  }
}
