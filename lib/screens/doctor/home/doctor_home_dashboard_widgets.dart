import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/keepi_timezone.dart';
import '../../../core/web_layout.dart';
import '../../../services/appointment_service.dart';
import '../../../services/doctor_service.dart';
import 'doctor_home_helpers.dart';
import 'doctor_home_shared_widgets.dart';

class DoctorHomeGreeting extends StatelessWidget {
  const DoctorHomeGreeting({
    required this.greeting,
    required this.name,
  });

  final String greeting;
  final String name;

  @override
  Widget build(BuildContext context) {
    final firstName = name.split(' ').first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 22, height: 2, color: KeepiColors.slate),
            const SizedBox(width: 8),
            Text(
              doctorHomeTodayStamp(),
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8,
                color: KeepiColors.slate,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: isWebWide(context) ? 30 : 26,
              fontWeight: FontWeight.w800,
              color: KeepiColors.slate,
              height: 1.1,
              letterSpacing: -0.7,
            ),
            children: [
              TextSpan(text: '$greeting, Dr. '),
              TextSpan(
                text: firstName,
                style: const TextStyle(color: KeepiColors.orange),
              ),
              const TextSpan(
                text: '.',
                style: TextStyle(color: KeepiColors.slate),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Tu consultorio digital, en un vistazo.',
          style: TextStyle(
            fontSize: 13.5,
            color: KeepiColors.slateLight,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class DoctorHomeNextAppointmentHero extends StatelessWidget {
  const DoctorHomeNextAppointmentHero({
    required this.appointment,
    required this.patient,
    required this.onOpenProfile,
    required this.onOpenConsultation,
    this.compact = false,
    this.featured = false,
    this.slotDurationMinutes = 30,
    this.onMarkAttendance,
    this.markingAttendance = false,
  });

  final AppointmentDto appointment;
  final PatientListItem? patient;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenConsultation;
  final bool compact;
  final bool featured;
  final int slotDurationMinutes;
  final Future<void> Function(AppointmentDto, String status)? onMarkAttendance;
  final bool markingAttendance;

  String get _patientName =>
      patient?.name ?? appointment.patientName ?? 'Paciente';

  String _dayLabel(DateTime? date) {
    if (date == null) return '—';
    final now = DateTime.now();
    if (doctorHomeSameDay(date, now)) return 'Hoy';
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    if (doctorHomeSameDay(date, tomorrow)) return 'Mañana';
    return '${doctorHomeTwoDigits(date.day)} ${doctorHomeMonthsEsUpper[date.month - 1]}';
  }

  String _statusLabel() {
    switch (appointment.status) {
      case 'pending_patient_approval':
        return 'POR CONFIRMAR';
      case 'scheduled':
        return 'CONFIRMADA';
      case 'pending_doctor_proposal':
        return 'ESPERANDO FECHA';
      case 'pending_doctor_approval':
        return 'POR CONFIRMAR';
      default:
        return appointment.status.toUpperCase();
    }
  }

  Color _statusColor() {
    switch (appointment.status) {
      case 'scheduled':
        return KeepiColors.green;
      case 'pending_patient_approval':
      case 'pending_doctor_proposal':
      case 'pending_doctor_approval':
        return KeepiColors.orange;
      default:
        return KeepiColors.slateLight;
    }
  }

  String get _badgeLabel {
    switch (appointment.attendanceStatus) {
      case 'attended':
        return 'ASISTIÓ';
      case 'no_show':
        return 'NO ASISTIÓ';
      default:
        return _statusLabel();
    }
  }

  Color get _badgeColor {
    switch (appointment.attendanceStatus) {
      case 'attended':
        return KeepiColors.green;
      case 'no_show':
        return KeepiColors.slate;
      default:
        return _statusColor();
    }
  }

  Widget _buildHeaderRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Text(
            'PRÓXIMA CITA',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
              color: KeepiColors.orange,
            ),
          ),
        ),
        DoctorHomeStatusBadge(label: _badgeLabel, color: _badgeColor),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = appointment.appointmentDate?.asScheduleLocal;
    final timeLabel =
        date != null ? '${doctorHomeTwoDigits(date.hour)}:${doctorHomeTwoDigits(date.minute)}' : 'Sin hora';
    final reason = appointment.reason.isEmpty
        ? 'Consulta médica'
        : appointment.reason;
    final initial =
        _patientName.isEmpty ? '?' : _patientName[0].toUpperCase();
    final wideLayout = isWebWide(context) && !compact;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: featured
              ? KeepiColors.orange.withValues(alpha: 0.35)
              : KeepiColors.cardBorder,
          width: featured ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: KeepiColors.slate.withValues(alpha: featured ? 0.1 : 0.06),
            blurRadius: featured ? 28 : 24,
            offset: Offset(0, featured ? 10 : 8),
          ),
        ],
      ),
      padding: EdgeInsets.all(wideLayout ? 28 : (featured ? 24 : 20)),
      child: wideLayout
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderRow(),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                        child: _buildContentBody(timeLabel, reason, date)),
                    const SizedBox(width: 24),
                    DoctorHomePatientAvatarLarge(initial: initial, size: 140),
                  ],
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderRow(),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: _buildContentBody(timeLabel, reason, date)),
                    const SizedBox(width: 12),
                    DoctorHomePatientAvatarLarge(
                      initial: initial,
                      size: featured ? 80 : 72,
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildContentBody(String timeLabel, String reason, DateTime? date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _patientName,
          style: TextStyle(
            fontSize: featured ? 30 : 28,
            fontWeight: FontWeight.w800,
            color: KeepiColors.slate,
            letterSpacing: -0.8,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 20,
          runSpacing: 10,
          children: [
            DoctorHomeHeroInfoChip(
              icon: Icons.schedule_rounded,
              iconColor: KeepiColors.orange,
              label: 'Hora',
              value: timeLabel,
            ),
            DoctorHomeHeroInfoChip(
              icon: Icons.calendar_today_outlined,
              iconColor: KeepiColors.slate,
              label: 'Día',
              value: _dayLabel(date),
            ),
            DoctorHomeHeroInfoChip(
              icon: Icons.event_note_outlined,
              iconColor: KeepiColors.skyBlue,
              label: 'Motivo',
              value: reason,
            ),
          ],
        ),
        if (onMarkAttendance != null &&
            doctorHomeCanConfirmAttendance(appointment, slotDurationMinutes)) ...[
          const SizedBox(height: 14),
          if (markingAttendance)
            const SizedBox(
              height: 28,
              width: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                DoctorHomeAttendanceActionButton(
                  icon: Icons.check_rounded,
                  label: 'Confirmar asistencia',
                  color: KeepiColors.green,
                  onTap: () => onMarkAttendance!(appointment, 'attended'),
                ),
                DoctorHomeAttendanceActionButton(
                  icon: Icons.close_rounded,
                  label: 'No asistió',
                  color: KeepiColors.slate,
                  onTap: () => onMarkAttendance!(appointment, 'no_show'),
                ),
              ],
            ),
        ],
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: onOpenConsultation,
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Iniciar consulta'),
            ),
            OutlinedButton.icon(
              onPressed: onOpenProfile,
              style: OutlinedButton.styleFrom(
                foregroundColor: KeepiColors.slate,
                side: const BorderSide(color: KeepiColors.cardBorder),
              ),
              icon: const Icon(Icons.folder_copy_outlined, size: 18),
              label: const Text('Abrir expediente'),
            ),
          ],
        ),
      ],
    );
  }
}

class DoctorHomeEmptyNextAppointmentCard extends StatelessWidget {
  const DoctorHomeEmptyNextAppointmentCard({
    this.message,
    this.featured = false,
  });

  final String? message;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: featured
              ? KeepiColors.orange.withValues(alpha: 0.35)
              : KeepiColors.cardBorder,
          width: featured ? 1.5 : 1,
        ),
      ),
      child: DoctorHomeInlineEmpty(
        icon: Icons.event_available_outlined,
        message: message ??
            'No hay citas próximas. Revisa la agenda o crea una nueva.',
      ),
    );
  }
}

class DoctorHomeHeroInfoChip extends StatelessWidget {
  const DoctorHomeHeroInfoChip({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: KeepiColors.slateLight,
                letterSpacing: 0.4,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: KeepiColors.slate,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class DoctorHomeStatusBadge extends StatelessWidget {
  const DoctorHomeStatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class DoctorHomePatientAvatarLarge extends StatelessWidget {
  const DoctorHomePatientAvatarLarge({required this.initial, required this.size});

  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: KeepiColors.skyBlueSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KeepiColors.cardBorder, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.34,
          fontWeight: FontWeight.w800,
          color: KeepiColors.skyBlue,
        ),
      ),
    );
  }
}

class DoctorHomeWebPendingCard extends StatelessWidget {
  const DoctorHomeWebPendingCard({
    required this.pending,
    required this.patients,
    required this.onOpen,
    required this.onViewAll,
  });

  final List<AppointmentDto> pending;
  final List<PatientListItem> patients;
  final ValueChanged<AppointmentDto> onOpen;
  final VoidCallback onViewAll;

  String _patientName(AppointmentDto a) {
    final match = patients.where((p) => p.id == a.patientId);
    if (match.isEmpty) return a.patientName ?? 'Paciente';
    return match.first.name;
  }

  String _statusHint(String status) {
    switch (status) {
      case 'pending_patient_approval':
        return 'Espera confirmación del paciente';
      case 'pending_doctor_proposal':
        return 'Propón una fecha';
      case 'pending_doctor_approval':
        return 'Confirma la cita';
      default:
        return status;
    }
  }

  String _statusTag(String status) {
    switch (status) {
      case 'pending_patient_approval':
        return 'POR CONFIRMAR';
      case 'pending_doctor_proposal':
        return 'SIN FECHA';
      case 'pending_doctor_approval':
        return 'POR CONFIRMAR';
      default:
        return 'PENDIENTE';
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending_patient_approval':
        return Icons.hourglass_top_rounded;
      case 'pending_doctor_proposal':
        return Icons.edit_calendar_outlined;
      case 'pending_doctor_approval':
      default:
        return Icons.event_available_outlined;
    }
  }

  Color _statusColor(String status) => KeepiColors.orange;

  String _appointmentTime(AppointmentDto a) {
    final dt = a.appointmentDate?.asScheduleLocal;
    if (dt == null) return 'Sin hora';
    return '${doctorHomeWeekdaysEsUpper[dt.weekday - 1]} · ${doctorHomeTwoDigits(dt.hour)}:${doctorHomeTwoDigits(dt.minute)}';
  }

  Widget _buildDateStamp(AppointmentDto a) {
    final date = a.appointmentDate?.asScheduleLocal;
    final day = date?.day ?? 0;
    final monthAbbr = date != null ? doctorHomeMonthsEsUpper[date.month - 1] : '—';
    return SizedBox(
      width: 44,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            day > 0 ? doctorHomeTwoDigits(day) : '—',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: KeepiColors.slate,
              height: 1,
              letterSpacing: -0.8,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            monthAbbr,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: KeepiColors.slateLight,
              letterSpacing: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(AppointmentDto a) {
    final color = _statusColor(a.status);
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1.8),
      ),
      child: Icon(_statusIcon(a.status), size: 16, color: color),
    );
  }

  Widget _buildPendingBody(AppointmentDto a) {
    final color = _statusColor(a.status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            const Text(
              'CITA',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: KeepiColors.orange,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 2,
              height: 2,
              decoration: BoxDecoration(
                color: KeepiColors.slateLight.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _statusTag(a.status),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _patientName(a),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: KeepiColors.slate,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _statusHint(a.status),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            color: KeepiColors.slateLight,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Container(
              width: 10,
              height: 1,
              color: KeepiColors.slate.withValues(alpha: 0.55),
            ),
            const SizedBox(width: 6),
            Text(
              _appointmentTime(a),
              style: const TextStyle(
                fontSize: 12,
                color: KeepiColors.slate,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown = pending.take(3).toList();
    final single = pending.length == 1 ? pending.first : null;

    Widget cardContent = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: KeepiColors.orange.withValues(alpha: 0.45),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'POR CONFIRMAR',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                  color: KeepiColors.orange,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: KeepiColors.orangeSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  doctorHomeTwoDigits(pending.length),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: KeepiColors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final a in shown)
            InkWell(
              onTap: () => onOpen(a),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDateStamp(a),
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: _buildStatusIcon(a),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _buildPendingBody(a)),
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: KeepiColors.slateLight,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (pending.length > shown.length)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onViewAll,
                child: Text('Ver  más'),
              ),
            ),
        ],
      ),
    );

    if (single != null) {
      cardContent = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onOpen(single),
          borderRadius: BorderRadius.circular(16),
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}
class DoctorHomeTopActionsStrip extends StatelessWidget {
  const DoctorHomeTopActionsStrip({
    required this.onNewPatient,
    required this.onScheduleAppointment,
  });

  final VoidCallback onNewPatient;
  final VoidCallback onScheduleAppointment;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DoctorHomeTopActionCell(
            icon: Icons.person_add_alt_1_rounded,
            label: 'NUEVO PACIENTE',
            onPressed: onNewPatient,
            accent: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DoctorHomeTopActionCell(
            icon: Icons.event_available_rounded,
            label: 'AGENDAR CITA',
            onPressed: onScheduleAppointment,
            accent: true,
          ),
        ),
      ],
    );
  }
}

class DoctorHomeTopActionCell extends StatelessWidget {
  const DoctorHomeTopActionCell({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ? KeepiColors.orange : KeepiColors.slate;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: KeepiColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: color,
                    height: 1.15,
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
//   AGENDA CARD

class DoctorHomeAttendanceActionButton extends StatelessWidget {
  const DoctorHomeAttendanceActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DoctorHomeAgendaCard extends StatelessWidget {
  const DoctorHomeAgendaCard({
    required this.appointment,
    required this.patients,
    required this.slotDurationMinutes,
    required this.onMarkAttendance,
    this.markingAttendance = false,
    this.onTap,
  });
  final AppointmentDto appointment;
  final List<PatientListItem> patients;
  final int slotDurationMinutes;
  final Future<void> Function(AppointmentDto, String status) onMarkAttendance;
  final bool markingAttendance;
  final VoidCallback? onTap;

  String _statusLabel() {
    switch (appointment.status) {
      case 'pending_patient_approval':
        return 'POR CONFIRMAR';
      case 'scheduled':
        return 'CONFIRMADA';
      case 'pending_doctor_proposal':
        return 'ESPERANDO FECHA';
      case 'canceled':
        return 'CANCELADA';
      default:
        return appointment.status.toUpperCase();
    }
  }

  Color _statusColor() {
    switch (appointment.status) {
      case 'pending_patient_approval':
      case 'pending_doctor_proposal':
        return KeepiColors.orange;
      case 'scheduled':
        return KeepiColors.green;
      case 'canceled':
        return Colors.red;
      default:
        return KeepiColors.slateLight;
    }
  }

  String _patientName() {
    final match = patients.where((p) => p.id == appointment.patientId).toList();
    if (match.isEmpty) return 'Paciente';
    return match.first.name;
  }

  Widget _buildTrailingAction() {
    final status = appointment.attendanceStatus;
    if (status == 'attended') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: KeepiColors.green.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: KeepiColors.green.withValues(alpha: 0.45)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 14, color: KeepiColors.green),
            SizedBox(width: 4),
            Text(
              'Asistió',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: KeepiColors.green,
              ),
            ),
          ],
        ),
      );
    }
    if (status == 'no_show') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: KeepiColors.slate.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: KeepiColors.slate.withValues(alpha: 0.25)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off_outlined, size: 14, color: KeepiColors.slate),
            SizedBox(width: 4),
            Text(
              'No asistió',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: KeepiColors.slate,
              ),
            ),
          ],
        ),
      );
    }
    if (!doctorHomeCanConfirmAttendance(appointment, slotDurationMinutes)) {
      return Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: KeepiColors.skyBlue, width: 1.6),
        ),
        child: const Icon(
          Icons.event_available_outlined,
          size: 17,
          color: KeepiColors.skyBlue,
        ),
      );
    }
    if (markingAttendance) {
      return const SizedBox(
        width: 34,
        height: 34,
        child: Padding(
          padding: EdgeInsets.all(6),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DoctorHomeAttendanceActionButton(
          icon: Icons.check_rounded,
          label: 'Asistió',
          color: KeepiColors.green,
          onTap: () => onMarkAttendance(appointment, 'attended'),
        ),
        const SizedBox(height: 6),
        DoctorHomeAttendanceActionButton(
          icon: Icons.close_rounded,
          label: 'No asistió',
          color: KeepiColors.slate,
          onTap: () => onMarkAttendance(appointment, 'no_show'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = appointment.appointmentDate?.asScheduleLocal;
    final day = date?.day ?? 0;
    final monthAbbr = date != null ? doctorHomeMonthsEsUpper[date.month - 1] : '—';
    final timeLabel =
        date != null ? '${doctorHomeTwoDigits(date.hour)}:${doctorHomeTwoDigits(date.minute)}' : 'Sin hora';
    final statusColor = _statusColor();
    final needsAttention = appointment.status == 'pending_patient_approval' ||
        appointment.status == 'pending_doctor_proposal';

    final card = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: needsAttention
              ? KeepiColors.orange.withValues(alpha: 0.55)
              : KeepiColors.cardBorder,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day > 0 ? doctorHomeTwoDigits(day) : '—',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: KeepiColors.slate,
                    height: 1,
                    letterSpacing: -1,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  monthAbbr,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: KeepiColors.slateLight,
                    letterSpacing: 1.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: KeepiColors.skyBlue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    const Text(
                      'CITA',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        color: KeepiColors.skyBlue,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Container(
                      width: 2,
                      height: 2,
                      decoration: BoxDecoration(
                        color: KeepiColors.slateLight.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        _statusLabel(),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  height: 2,
                  width: 22,
                  decoration: BoxDecoration(
                    color: KeepiColors.skyBlue,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _patientName(),
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: KeepiColors.slate,
                    letterSpacing: -0.25,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  appointment.reason.isEmpty
                      ? 'Consulta médica'
                      : appointment.reason,
                  style: const TextStyle(
                    fontSize: 13,
                    color: KeepiColors.slateLight,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 1,
                      color: KeepiColors.slate.withValues(alpha: 0.55),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timeLabel,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: KeepiColors.slate,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 2),
            child: _buildTrailingAction(),
          ),
        ],
      ),
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: card,
      ),
    );
  }
}

//   SHORTCUTS STRIP

class DoctorHomeShortcutsStrip extends StatelessWidget {
  const DoctorHomeShortcutsStrip({
    required this.onPatients,
    required this.onDocuments,
    required this.onQuestionnaires,
    required this.onAgenda,
  });

  final VoidCallback onPatients;
  final VoidCallback onDocuments;
  final VoidCallback onQuestionnaires;
  final VoidCallback onAgenda;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DoctorHomeShortcutTile(
            icon: Icons.people_alt_outlined,
            label: 'Pacientes',
            accent: KeepiColors.skyBlue,
            onTap: onPatients,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DoctorHomeShortcutTile(
            icon: Icons.folder_copy_outlined,
            label: 'Expedientes',
            accent: const Color(0xFF7C3AED),
            onTap: onDocuments,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DoctorHomeShortcutTile(
            icon: Icons.quiz_outlined,
            label: 'Cuestionarios',
            accent: KeepiColors.orange,
            onTap: onQuestionnaires,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DoctorHomeShortcutTile(
            icon: Icons.calendar_month_outlined,
            label: 'Agenda',
            accent: KeepiColors.slate,
            onTap: onAgenda,
          ),
        ),
      ],
    );
  }
}

class DoctorHomeShortcutTile extends StatelessWidget {
  const DoctorHomeShortcutTile({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 10, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: KeepiColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: accent, width: 1.6),
              ),
              child: Icon(icon, color: accent, size: 16),
            ),
            const SizedBox(height: 14),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: KeepiColors.slate,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(height: 2),
            const Row(
              children: [
                Text(
                  'ABRIR',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: KeepiColors.slateLight,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded,
                    size: 11, color: KeepiColors.slateLight),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
