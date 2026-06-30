import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/web_layout.dart';
import '../../../services/doctor_service.dart';
import '../../../widgets/doctor_patient_web_blocks.dart';
import 'doctor_home_helpers.dart';
import 'doctor_home_shared_widgets.dart';

class DoctorHomePatientsHero extends StatelessWidget {
  const DoctorHomePatientsHero({required this.total, required this.filtered});
  final int total;
  final int filtered;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 22, height: 2, color: KeepiColors.slate),
              const SizedBox(width: 8),
              const Text(
                'DIRECTORIO',
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
            'Tus pacientes.',
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
            'Toca una tarjeta para ver su historial, agendar citas, recetas o análisis.',
            style: TextStyle(
              fontSize: 13.5,
              color: KeepiColors.slateLight,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          DoctorHomeStatsStrip(
            items: [
              DoctorHomeStatItem(value: total, label: 'TOTAL'),
              DoctorHomeStatItem(
                  value: filtered,
                  label: 'MOSTRANDO',
                  accent: filtered != total && total > 0),
            ],
          ),
        ],
      ),
    );
  }
}

class DoctorHomePatientsWebHero extends StatelessWidget {
  const DoctorHomePatientsWebHero({
    required this.total,
    required this.filtered,
  });

  final int total;
  final int filtered;

  @override
  Widget build(BuildContext context) {
    final filtering = filtered != total && total > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 22, height: 2, color: KeepiColors.slate),
            const SizedBox(width: 8),
            const Text(
              'DIRECTORIO',
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(
              child: Text(
                'Tus pacientes.',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: KeepiColors.slate,
                  height: 1.05,
                  letterSpacing: -0.8,
                ),
              ),
            ),
            const SizedBox(width: 16),
            _WebCountChip(
              value: total,
              label: 'TOTAL',
              accent: false,
            ),
            const SizedBox(width: 8),
            _WebCountChip(
              value: filtered,
              label: 'MOSTRANDO',
              accent: filtering,
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Toca una tarjeta para ver historial, agendar citas, recetas o análisis.',
          style: TextStyle(
            fontSize: 14,
            color: KeepiColors.slateLight,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _WebCountChip extends StatelessWidget {
  const _WebCountChip({
    required this.value,
    required this.label,
    required this.accent,
  });

  final int value;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ? KeepiColors.orange : KeepiColors.slate;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: accent ? KeepiColors.orangeSoft : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accent
              ? KeepiColors.orange.withValues(alpha: 0.35)
              : KeepiColors.cardBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            doctorHomeTwoDigits(value),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: color.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

class DoctorHomePatientActionsSheet extends StatelessWidget {
  const DoctorHomePatientActionsSheet({
    required this.patient,
    required this.onTimeline,
    required this.onSchedule,
    required this.onPrescription,
    required this.onAnalysis,
    required this.onQuestionnaire,
    required this.onSendSchedulingLink,
    this.asWebDialog = false,
  });

  final PatientListItem patient;
  final VoidCallback onTimeline;
  final VoidCallback onSchedule;
  final VoidCallback onPrescription;
  final VoidCallback onAnalysis;
  final VoidCallback onQuestionnaire;
  final VoidCallback onSendSchedulingLink;
  final bool asWebDialog;

  List<_PatientActionDef> get _actions => [
        _PatientActionDef(
          icon: Icons.link_rounded,
          accent: KeepiColors.skyBlue,
          soft: KeepiColors.skyBlueSoft,
          title: 'Enviar link de agenda',
          subtitle: 'Correo con enlace para agendar citas.',
          onTap: onSendSchedulingLink,
        ),
        _PatientActionDef(
          icon: Icons.timeline_rounded,
          accent: KeepiColors.slate,
          soft: KeepiColors.slateSoft,
          title: 'Ver historial',
          subtitle: 'Expediente clínico y movimientos recientes.',
          onTap: onTimeline,
        ),
        _PatientActionDef(
          icon: Icons.event_available_outlined,
          accent: const Color(0xFF0D9488),
          soft: const Color(0xFFCCFBF1),
          title: 'Asignar cita',
          subtitle: 'Propón fecha y hora para la consulta.',
          onTap: onSchedule,
        ),
        _PatientActionDef(
          icon: Icons.medication_outlined,
          accent: const Color(0xFF7C3AED),
          soft: const Color(0xFFF3E8FF),
          title: 'Asignar receta',
          subtitle: 'Nueva prescripción con recordatorios.',
          onTap: onPrescription,
        ),
        _PatientActionDef(
          icon: Icons.biotech_outlined,
          accent: KeepiColors.orange,
          soft: KeepiColors.orangeSoft,
          title: 'Solicitar análisis',
          subtitle: 'Estudios de laboratorio o imagen.',
          onTap: onAnalysis,
        ),
        _PatientActionDef(
          icon: Icons.outgoing_mail,
          accent: const Color(0xFF2563EB),
          soft: const Color(0xFFEFF6FF),
          title: 'Enviar ficha clínica',
          subtitle: 'Link con plantillas o preguntas personalizadas.',
          onTap: onQuestionnaire,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    if (asWebDialog) return _buildWebDialog(context);
    return _buildMobileSheet(context);
  }

  Widget _buildWebDialog(BuildContext context) {
    final initial =
        patient.name.isEmpty ? '?' : patient.name.trim()[0].toUpperCase();
    final avatarTheme = PatientAvatarTheme.fromSex(patient.sex);
    final profileOk = patient.hasClinicalProfile;

    final hasPhone = (patient.phone ?? '').trim().isNotEmpty;
    final hasAge = patient.ageYears != null;

    return Container(
      constraints: const BoxConstraints(maxWidth: 780),
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
          // ── Hero header ──────────────────────────────────────────
          Stack(
            children: [
              // Fondo degradado
              Container(
                height: 140,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF2D3F4C),
                      KeepiColors.slate,
                    ],
                  ),
                ),
              ),
              // Círculos decorativos
              Positioned(
                right: -30,
                top: -30,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.04),
                  ),
                ),
              ),
              Positioned(
                right: 60,
                bottom: -20,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: KeepiColors.orange.withValues(alpha: 0.12),
                  ),
                ),
              ),
              // Contenido del header
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 22, 18, 22),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar grande
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: avatarTheme.soft,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: TextStyle(
                          color: avatarTheme.accent,
                          fontWeight: FontWeight.w900,
                          fontSize: 30,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    // Info del paciente
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patient.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.4,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              const Icon(
                                Icons.mail_outline_rounded,
                                size: 13,
                                color: Color(0xFF9DB4C2),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  patient.email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF9DB4C2),
                                    height: 1,
                                  ),
                                ),
                              ),
                              if (hasPhone) ...[
                                const SizedBox(width: 14),
                                const Icon(
                                  Icons.phone_outlined,
                                  size: 13,
                                  color: Color(0xFF9DB4C2),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  patient.phone!.trim(),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF9DB4C2),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Pills de info
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _HeaderPill(
                                icon: profileOk
                                    ? Icons.check_circle_rounded
                                    : Icons.warning_amber_rounded,
                                label: profileOk
                                    ? 'Perfil clínico'
                                    : 'Sin perfil clínico',
                                color: profileOk
                                    ? KeepiColors.green
                                    : KeepiColors.orange,
                              ),
                              if (hasAge)
                                _HeaderPill(
                                  icon: Icons.cake_outlined,
                                  label: '${patient.ageYears} años',
                                  color: Colors.white,
                                ),
                              _HeaderPill(
                                icon: Icons.folder_outlined,
                                label:
                                    '${patient.documentsTotal} doc${patient.documentsTotal == 1 ? '' : 's'}',
                                color: Colors.white,
                              ),
                              if (patient.nextAppointmentDate != null)
                                _HeaderPill(
                                  icon: Icons.event_available_outlined,
                                  label: 'Cita próxima',
                                  color: const Color(0xFF5EEAD4),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Botón cerrar
                    Align(
                      alignment: Alignment.topRight,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
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
                    ),
                  ],
                ),
              ),
            ],
          ),
          // ── Grid de acciones ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 16,
                      height: 2,
                      color: KeepiColors.slate.withValues(alpha: 0.4),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'QUÉ QUIERES HACER',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.8,
                        color: KeepiColors.slateLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _PatientActionWebTile(action: _actions[0])),
                    const SizedBox(width: 10),
                    Expanded(child: _PatientActionWebTile(action: _actions[1])),
                    const SizedBox(width: 10),
                    Expanded(child: _PatientActionWebTile(action: _actions[2])),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _PatientActionWebTile(action: _actions[3])),
                    const SizedBox(width: 10),
                    Expanded(child: _PatientActionWebTile(action: _actions[4])),
                    const SizedBox(width: 10),
                    Expanded(child: _PatientActionWebTile(action: _actions[5])),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileSheet(BuildContext context) {
    final initial =
        patient.name.isEmpty ? '?' : patient.name.trim()[0].toUpperCase();
    final avatarTheme = PatientAvatarTheme.fromSex(patient.sex);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: KeepiColors.slateSoft,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: avatarTheme.soft,
                    shape: BoxShape.circle,
                    border: Border.all(color: avatarTheme.accent, width: 1.6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: avatarTheme.accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: KeepiColors.slate,
                          letterSpacing: -0.25,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        patient.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: KeepiColors.slateLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const DoctorHomeSectionDivider(tag: 'ACCIONES', count: 6),
            const SizedBox(height: 14),
            for (var i = 0; i < _actions.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              DoctorHomeActionRow(
                icon: _actions[i].icon,
                accent: _actions[i].accent,
                soft: _actions[i].soft,
                title: _actions[i].title,
                subtitle: _actions[i].subtitle,
                onTap: _actions[i].onTap,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PatientActionDef {
  const _PatientActionDef({
    required this.icon,
    required this.accent,
    required this.soft,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final Color soft;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _PatientActionWebTile extends StatefulWidget {
  const _PatientActionWebTile({required this.action});

  final _PatientActionDef action;

  @override
  State<_PatientActionWebTile> createState() => _PatientActionWebTileState();
}

class _PatientActionWebTileState extends State<_PatientActionWebTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: action.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
          decoration: BoxDecoration(
            color: _hovered ? action.soft : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hovered
                  ? action.accent.withValues(alpha: 0.55)
                  : KeepiColors.cardBorder,
              width: _hovered ? 1.5 : 1,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: action.accent.withValues(alpha: 0.14),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _hovered ? action.accent : action.soft,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      action.icon,
                      color: _hovered ? Colors.white : action.accent,
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  AnimatedOpacity(
                    opacity: _hovered ? 1 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: action.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                action.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: _hovered ? action.accent : KeepiColors.slate,
                  letterSpacing: -0.2,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                action.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: KeepiColors.slateLight,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Abre el menú de acciones del paciente (dialog web / bottom sheet móvil).
Future<void> openDoctorPatientActionsSheet({
  required BuildContext context,
  required PatientListItem patient,
  required VoidCallback onTimeline,
  required VoidCallback onSchedule,
  required VoidCallback onPrescription,
  required VoidCallback onAnalysis,
  required VoidCallback onQuestionnaire,
  required VoidCallback onSendSchedulingLink,
}) {
  final asWebDialog = isWebWide(context);

  Widget buildSheet(BuildContext ctx) => DoctorHomePatientActionsSheet(
        patient: patient,
        asWebDialog: asWebDialog,
        onTimeline: () {
          Navigator.of(ctx).pop();
          onTimeline();
        },
        onSchedule: () {
          Navigator.of(ctx).pop();
          onSchedule();
        },
        onPrescription: () {
          Navigator.of(ctx).pop();
          onPrescription();
        },
        onAnalysis: () {
          Navigator.of(ctx).pop();
          onAnalysis();
        },
        onQuestionnaire: () {
          Navigator.of(ctx).pop();
          onQuestionnaire();
        },
        onSendSchedulingLink: () {
          Navigator.of(ctx).pop();
          onSendSchedulingLink();
        },
      );

  if (asWebDialog) {
    return showDialog<void>(
      context: context,
      barrierColor: KeepiColors.slate.withValues(alpha: 0.48),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: buildSheet(ctx),
      ),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: buildSheet,
  );
}

class DoctorHomeActionRow extends StatelessWidget {
  const DoctorHomeActionRow({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.soft,
  });

  final IconData icon;
  final Color accent;
  final Color? soft;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bgSoft = soft ?? accent.withValues(alpha: 0.08);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: KeepiColors.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: bgSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.28)),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: KeepiColors.slate,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: KeepiColors.slateLight,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_rounded,
                color: accent.withValues(alpha: 0.85),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class DoctorHomeSearchField extends StatelessWidget {
  const DoctorHomeSearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.elevated = false,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(elevated ? 16 : 14),
            border: Border.all(
              color: elevated
                  ? KeepiColors.cardBorder.withValues(alpha: 0.9)
                  : KeepiColors.cardBorder,
            ),
            boxShadow: elevated
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: TextField(
            controller: controller,
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
                color: KeepiColors.slateLight,
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
              errorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: elevated ? 15 : 12,
              ),
              filled: false,
            ),
          ),
        );
      },
    );
  }
}
