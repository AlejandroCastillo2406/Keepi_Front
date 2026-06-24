import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/web_layout.dart';
import '../../services/api_client.dart';
import '../../services/appointment_service.dart';
import '../../services/doctor_service.dart';
import '../../services/scheduling_service.dart';
import '../../widgets/doctor_note_field.dart';
import '../../widgets/doctor_appointment_slot_picker.dart';
import '../../widgets/doctor_pending_appointment_review_sheet.dart';
import '../../widgets/doctor_procedure_schedule_sheet.dart';

enum _AgendaView { today, week }

class DoctorCalendarTab extends StatefulWidget {
  const DoctorCalendarTab({
    super.key,
    this.onOpenConsultation,
  });

  final void Function(AppointmentDto appointment)? onOpenConsultation;

  @override
  State<DoctorCalendarTab> createState() => _DoctorCalendarTabState();
}

class _DoctorCalendarTabState extends State<DoctorCalendarTab> {
  DateTime _selectedDay = DateTime.now();
  bool _loading = true;
  String? _error;
  List<AppointmentDto> _appointments = [];
  List<ProcedureBlockDto> _procedures = [];
  ConsultationScheduleDto? _consultationSchedule;
  _AgendaView _agendaView = _AgendaView.today;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      final svc = AppointmentService(context.read<ApiClient>());
      
      // Pedimos el calendario con un rango amplio para traer todo el mes actual
      final from = DateTime(_selectedDay.year, _selectedDay.month - 1, 1);
      final to = DateTime(_selectedDay.year, _selectedDay.month + 2, 0);
      
      final payload = await svc.fetchDoctorCalendar(from: from, to: to);
      
      if (!mounted) return;
      setState(() {
        _appointments = payload.appointments;
        _procedures = payload.procedures;
        _consultationSchedule = payload.consultationSchedule;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppointmentService.messageFromDio(e);
        _loading = false;
      });
    }
  }
  bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year &&
      a.month == b.month &&
      a.day == b.day;
}
  String _monthName(int month) {
    const months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
    ];
    return months[month - 1];
  }

  String _hour(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  
  String _two(int v) => v.toString().padLeft(2, '0');


  int _backendWeekday(DateTime date) => date.weekday - 1;

  ConsultationScheduleDayDto? _scheduleForDay(DateTime date) {
    final schedule = _consultationSchedule;
    if (schedule == null) return null;
    final weekday = _backendWeekday(date);
    for (final day in schedule.days) {
      if (day.weekday == weekday) return day;
    }
    return null;
  }

  int _hourFromTime(String value, {int fallback = 9}) {
    final parts = value.split(':');
    if (parts.isEmpty) return fallback;
    return int.tryParse(parts.first) ?? fallback;
  }
  bool _isConfirmedAppointmentStatus(String status) {
  final value = status.toLowerCase().trim();
  return value == 'scheduled' || value == 'confirmed';
}

  String _scheduleLabelForDay(DateTime date) {
    final day = _scheduleForDay(date);
    if (day == null) return 'Sin horario configurado';
    return '${day.startTime} - ${day.endTime}';
  }

  bool _isWorkingDay(DateTime date) => _scheduleForDay(date) != null;


  List<AppointmentDto> get _pendingRows => _appointments
      .where((a) =>
          (a.status == 'pending_doctor_proposal' || a.appointmentDate == null) &&
          a.status != 'pending_doctor_approval')
      .toList();

  List<AppointmentDto> get _approvalPendingRows => _appointments
      .where((a) => a.status == 'pending_doctor_approval')
      .toList()
    ..sort((a, b) {
      final dateA = a.appointmentDate ?? DateTime(2000);
      final dateB = b.appointmentDate ?? DateTime(2000);
      return dateA.compareTo(dateB);
    });


  List<AppointmentDto> get _upcomingRows {
    final now = DateTime.now();
    return _appointments.where((a) {
      if (a.appointmentDate == null) return false;
      if (!_isConfirmedAppointmentStatus(a.status)) return false;      
      if (a.status == 'canceled') return false;
      return !a.appointmentDate!.toLocal().isBefore(now);
    }).toList()
      ..sort((a, b) => a.appointmentDate!.compareTo(b.appointmentDate!));
  }

  List<ProcedureBlockDto> get _selectedDayProcedures => _procedures
      .where((p) {
        final d = p.startAt.toLocal();
        return d.year == _selectedDay.year &&
            d.month == _selectedDay.month &&
            d.day == _selectedDay.day;
      })
      .toList()
    ..sort((a, b) => a.startAt.compareTo(b.startAt));

  String _timeRangeLabel(DateTime start, DateTime end) {
    return '${_hour(start.toLocal())} - ${_hour(end.toLocal())}';
  }

  Future<void> _scheduleProcedure() async {
    final draft = await showDoctorProcedureScheduleSheet(
      context,
      initialDate: _selectedDay,
      consultationSchedule: _consultationSchedule,
      appointments: _appointments,
      procedures: _procedures,
    );
    if (draft == null || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: KeepiColors.orange),
      ),
    );

    try {
      await AppointmentService(context.read<ApiClient>()).createDoctorProcedure(
        title: draft.title,
        startAt: draft.startAt,
        endAt: draft.endAt,
      );
      if (mounted) Navigator.pop(context);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Procedimiento agendado'),
            backgroundColor: KeepiColors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppointmentService.messageFromDio(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openProcedure(ProcedureBlockDto procedure) async {
    final start = procedure.startAt.toLocal();
    final end = procedure.endAt.toLocal();
    final delete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          procedure.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          '${_two(start.day)}/${_two(start.month)}/${start.year}\n'
          '${_timeRangeLabel(start, end)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cerrar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (delete != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: KeepiColors.orange),
      ),
    );

    try {
      await AppointmentService(context.read<ApiClient>())
          .deleteDoctorProcedure(procedure.id);
      if (mounted) Navigator.pop(context);
      _load();
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppointmentService.messageFromDio(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<AppointmentDto> get _selectedDayRows => _appointments.where((a) {
        if (a.appointmentDate == null) return false;
        if (a.status == 'pending_doctor_proposal') return false; 
        
        final d = a.appointmentDate!.toLocal();
        return d.year == _selectedDay.year && d.month == _selectedDay.month && d.day == _selectedDay.day;
      }).toList()..sort((a, b) {
        final dateA = a.appointmentDate ?? DateTime(2000);
        final dateB = b.appointmentDate ?? DateTime(2000);
        return dateA.compareTo(dateB);
      });

  Future<void> _openPendingReview(AppointmentDto a) async {
    await DoctorPendingAppointmentReviewSheet.show(
      context,
      appointmentId: a.id,
      onChanged: _load,
    );
  }

  Future<void> _openAppointment(AppointmentDto a) async {
    if (a.status == 'pending_doctor_approval' ||
        a.status == 'pending_patient_approval' ||
        a.status == 'pending_doctor_proposal') {
      await _openPendingReview(a);
      return;
    }
    widget.onOpenConsultation?.call(a);
  }

  Future<void> _rescheduleWebRequest(AppointmentDto a) async {
    final ok = await _showPremiumActionConfirm(
      title: 'Reagendar cita',
      message: 'Selecciona un nuevo horario y enviaremos la propuesta al paciente.',
      primaryLabel: 'Elegir horario',
      icon: Icons.event_repeat_rounded,
      accent: KeepiColors.skyBlue,
    );
    if (ok != true || !mounted) return;

    final proposed = await pickDoctorAppointmentSlot(context);
    if (proposed == null || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: KeepiColors.orange),
      ),
    );

    try {
      await AppointmentService(context.read<ApiClient>())
          .doctorRescheduleWebAppointment(
        appointmentId: a.id,
        proposedStartAt: proposed.toUtc(),
      );
      if (mounted) Navigator.pop(context);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Propuesta enviada al paciente por correo'),
            backgroundColor: KeepiColors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppointmentService.messageFromDio(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _reassignCanceled(AppointmentDto a) async {
    final proposed = await pickDoctorAppointmentSlot(context);
    if (proposed == null || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: KeepiColors.orange),
      ),
    );

    try {
      final settings =
          await SchedulingService(context.read<ApiClient>()).fetchSettings();
      await AppointmentService(context.read<ApiClient>())
          .doctorReassignCanceledAppointment(
        appointmentId: a.id,
        proposedStartAt: proposed.toUtc(),
        durationMinutes: settings.slotDurationMinutes,
      );

      if (mounted) Navigator.pop(context);
      _load();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cita confirmada. El paciente recibirá un correo informativo.'),
            backgroundColor: KeepiColors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppointmentService.messageFromDio(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _assignDate(AppointmentDto a) async {
    final proposed = await pickDoctorAppointmentSlot(context);
    if (proposed == null || !mounted) return;

    showDialog(
      context: context, 
      barrierDismissible: false, 
      builder: (_) => const Center(child: CircularProgressIndicator(color: KeepiColors.orange))
    );

    try {
      final settings =
          await SchedulingService(context.read<ApiClient>()).fetchSettings();
      await AppointmentService(context.read<ApiClient>()).doctorProposeTime(
        appointmentId: a.id,
        proposedStartAt: proposed,
        durationMinutes: settings.slotDurationMinutes,
      );
      
      if (mounted) Navigator.pop(context); 
      _load(); 
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fecha asignada y enviada al paciente.'), backgroundColor: KeepiColors.green)
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppointmentService.messageFromDio(e)), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _cancelAppointment(AppointmentDto a) async {
    final confirm = await _showPremiumActionConfirm(
      title: 'Cancelar cita',
      message: 'Esta acción cancelará la cita y no se puede deshacer.',
      primaryLabel: 'Cancelar cita',
      icon: Icons.event_busy_rounded,
      accent: const Color(0xFFE11D48),
      destructive: true,
    );

    if (confirm != true || !mounted) return;

    showDialog(
      context: context, 
      barrierDismissible: false, 
      builder: (_) => const Center(child: CircularProgressIndicator(color: KeepiColors.orange)),
    );

    try {
      final svc = AppointmentService(context.read<ApiClient>());
      await svc.cancelAppointment(appointmentId: a.id); 
      
      if (mounted) Navigator.pop(context); 
      _load(); 
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cita cancelada correctamente'), backgroundColor: KeepiColors.slate),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cancelar: ${AppointmentService.messageFromDio(e)}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _approveAppointment(AppointmentDto a) async {
    final confirm = await _showPremiumActionConfirm(
      title: 'Confirmar cita',
      message: 'La cita quedará confirmada y el paciente recibirá la actualización.',
      primaryLabel: 'Confirmar',
      icon: Icons.check_circle_outline_rounded,
      accent: KeepiColors.green,
    );
    if (confirm != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: KeepiColors.orange),
      ),
    );
    try {
      await AppointmentService(context.read<ApiClient>())
          .doctorApproveAppointment(appointmentId: a.id);
      if (mounted) Navigator.pop(context);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cita confirmada'),
            backgroundColor: KeepiColors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppointmentService.messageFromDio(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectAppointment(AppointmentDto a) async {
    final confirm = await _showPremiumActionConfirm(
      title: 'Rechazar solicitud',
      message: 'La solicitud será rechazada y el paciente deberá solicitar otra cita.',
      primaryLabel: 'Rechazar',
      icon: Icons.close_rounded,
      accent: const Color(0xFFE11D48),
      destructive: true,
    );
    if (confirm != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: KeepiColors.orange),
      ),
    );
    try {
      await AppointmentService(context.read<ApiClient>())
          .doctorRejectAppointment(appointmentId: a.id);
      if (mounted) Navigator.pop(context);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud rechazada')),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppointmentService.messageFromDio(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _scheduleGlobalAppointment() async {
    showDialog(
      context: context, 
      barrierDismissible: false, 
      builder: (_) => const Center(child: CircularProgressIndicator(color: KeepiColors.orange))
    );

    List<PatientListItem> patients = [];
    try {
      patients = await DoctorService(context.read<ApiClient>()).fetchMyPatients();
      if (mounted) Navigator.pop(context); 
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al cargar la lista de pacientes')));
      return;
    }

    if (patients.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aún no tienes pacientes registrados para agendar.')));
      return;
    }

    if (!mounted) return;
    final selectedPatient = await showModalBottomSheet<PatientListItem>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            children: [
              const Text('Selecciona un paciente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: KeepiColors.slate)),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: patients.length,
                  itemBuilder: (context, index) {
                    final p = patients[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: KeepiColors.skyBlueSoft,
                        child: Text(p.name[0].toUpperCase(), style: const TextStyle(color: KeepiColors.skyBlue, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(p.email),
                      onTap: () => Navigator.pop(ctx, p),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }
    );

    if (selectedPatient == null || !mounted) return;

    final finalDateTime = await pickDoctorAppointmentSlot(context);
    if (finalDateTime == null || !mounted) return;

    final noteCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final dateStr =
        '${_two(finalDateTime.day)}/${_two(finalDateTime.month)}/${finalDateTime.year}';
    final timeStr = formatSlotTimeLocal(finalDateTime);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: KeepiColors.cardBorder),
          ),
          backgroundColor: Colors.white,
          title: const Text(
            'Confirmar cita',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: KeepiColors.slate,
              letterSpacing: -0.3,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 14.5,
                color: KeepiColors.slate,
                height: 1.4,
              ),
              children: [
                      const TextSpan(text: '¿Asignar la cita a '),
                TextSpan(
                  text: selectedPatient.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: KeepiColors.skyBlue,
                ),
                      ),
                      const TextSpan(text: ' el '),
                TextSpan(
                  text: dateStr,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: ' a las '),
                TextSpan(
                  text: timeStr,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: '?'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ConsultationReasonField(controller: reasonCtrl),
                const SizedBox(height: 16),
                DoctorNoteField(controller: noteCtrl),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: KeepiColors.slateLight, fontWeight: FontWeight.w700),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: KeepiColors.orange,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirmar', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            ),
          ],
        );
      },
    );

    final doctorNote = noteCtrl.text.trim();
    final reason = reasonCtrl.text.trim();
    noteCtrl.dispose();
    reasonCtrl.dispose();

    if (confirm != true || !mounted) return;
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indica el motivo de la consulta.')),
      );
      return;
    }

    showDialog(
      context: context, 
      barrierDismissible: false, 
      builder: (_) => const Center(child: CircularProgressIndicator(color: KeepiColors.orange)),
    );

    try {
      await DoctorService(context.read<ApiClient>()).scheduleAppointment(
        patientId: selectedPatient.id,
        date: finalDateTime,
        reason: reason,
        doctorNote: doctorNote.isEmpty ? null : doctorNote,
      );
      if (mounted) Navigator.pop(context); 
      _load(); 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cita agendada correctamente'), backgroundColor: KeepiColors.green));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${DoctorService.messageFromDio(e)}'), backgroundColor: Colors.red));
      }
    }
  }


  Future<bool?> _showPremiumActionConfirm({
    required String title,
    required String message,
    required String primaryLabel,
    required IconData icon,
    required Color accent,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 22),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 430),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: KeepiColors.cardBorder.withValues(alpha: 0.85)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.16),
                  blurRadius: 40,
                  offset: const Offset(0, 22),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(icon, color: accent, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(
                    color: KeepiColors.slateLight,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: KeepiColors.slate,
                          side: const BorderSide(color: KeepiColors.cardBorder),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        child: const Text('Volver'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: destructive ? const Color(0xFFE11D48) : accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        child: Text(primaryLabel),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dayRows = _selectedDayRows;
    final procedureRows = _selectedDayProcedures;
    final pendingRows = _pendingRows;
    final approvalRows = _approvalPendingRows;
    final webWide = isWebWide(context);

    if (webWide) {
    return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 36),
        child: WebContentFrame(
          maxWidth: kWebContentMaxWidth,
          padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
              _buildAgendaHero(),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: _buildMainAgendaCard(
                      dayRows: dayRows,
                      procedureRows: procedureRows,
                      approvalRows: approvalRows,
                      pendingRows: pendingRows,
                      loading: _loading,
                      error: _error,
                    ),
                  ),
                  const SizedBox(width: 24),
                  SizedBox(
                    width: 390,
                    child: _buildRightRail(
                      approvalRows: approvalRows,
                      pendingRows: pendingRows,
                      loading: _loading,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAgendaHero(compact: true),
          const SizedBox(height: 16),
          _buildPrimaryScheduleButton(expanded: true),
          const SizedBox(height: 12),
          _buildProcedureScheduleButton(expanded: true),
          const SizedBox(height: 16),
          _buildMainAgendaCard(
            dayRows: dayRows,
            procedureRows: procedureRows,
            approvalRows: approvalRows,
            pendingRows: pendingRows,
            loading: _loading,
            error: _error,
            compact: true,
          ),
          const SizedBox(height: 16),
          _buildRightRail(
            approvalRows: approvalRows,
            pendingRows: pendingRows,
            loading: _loading,
            compact: true,
          ),
        ],
      ),
    );
  }

  Widget _buildAgendaHero({bool compact = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
            children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Agenda',
                style: TextStyle(
                  fontSize: 28,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.9,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Gestiona tu programación y próximas citas.',
                style: TextStyle(
                  fontSize: compact ? 13 : 15,
                  fontWeight: FontWeight.w600,
                  color: KeepiColors.slateLight,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildAgendaControls({bool compact = false}) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildTodayButton(),
        _buildDateStepper(),
        _buildSelectedDatePill(),
      ],
    );
  }

  Widget _buildTodayButton({bool compact = false}) {
    return InkWell(
      onTap: () => setState(() => _selectedDay = DateTime.now()),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: compact ? 38 : 44,
        padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: KeepiColors.cardBorder),
          boxShadow: _cardShadow(blur: 12, alpha: 0.025),
        ),
        child: const Center(
          child: Text(
            'Hoy',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: KeepiColors.slate,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateStepper() {
    return Container(
      height: 50,
      decoration: _softCardDecoration(radius: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
            onPressed: () => setState(() {
              _selectedDay = _selectedDay.subtract(Duration(days: _agendaView == _AgendaView.week ? 7 : 1));
            }),
            icon: const Icon(Icons.chevron_left_rounded),
            color: KeepiColors.slate,
            tooltip: 'Día anterior',
          ),
          Container(width: 1, height: 22, color: KeepiColors.cardBorder),
                  IconButton(
            onPressed: () => setState(() {
              _selectedDay = _selectedDay.add(Duration(days: _agendaView == _AgendaView.week ? 7 : 1));
            }),
            icon: const Icon(Icons.chevron_right_rounded),
            color: KeepiColors.slate,
            tooltip: 'Día siguiente',
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDatePill() {
    return _GlassButton(
      onTap: () {},
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _longDate(_selectedDay),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.calendar_today_outlined, size: 18, color: KeepiColors.slateLight),
        ],
      ),
    );
  }

  Widget _buildPrimaryScheduleButton({bool expanded = false}) {
    final button = InkWell(
      onTap: _scheduleGlobalAppointment,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFFFF8A1D), Color(0xFFFF5A00)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: KeepiColors.orange.withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.add_rounded, color: Colors.white, size: 30),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nueva cita',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Crear una nueva cita en el calendario',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 26),
          ],
        ),
      ),
    );
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }

  Widget _buildProcedureScheduleButton({bool expanded = false}) {
    const accent = Color(0xFF7C3AED);
    final button = InkWell(
      onTap: _scheduleProcedure,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: accent.withValues(alpha: 0.08),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.medical_services_outlined, color: accent, size: 24),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'Procedimiento',
                style: TextStyle(
                  color: accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: accent, size: 24),
          ],
        ),
      ),
    );
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }

  Widget _buildMainAgendaCard({
    required List<AppointmentDto> dayRows,
    required List<ProcedureBlockDto> procedureRows,
    required List<AppointmentDto> approvalRows,
    required List<AppointmentDto> pendingRows,
    required bool loading,
    required String? error,
    bool compact = false,
  }) {
    final showWeek = _agendaView == _AgendaView.week;
    return Container(
      decoration: _softCardDecoration(radius: 26),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(compact ? 16 : 24, compact ? 16 : 22, compact ? 16 : 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildAgendaTabs(compact: compact)),
                    if (!compact) ...[
                      const SizedBox(width: 14),
                      _buildTodayButton(),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                _buildAgendaNavigation(compact: compact),
                const SizedBox(height: 14),
                _buildAgendaSummary(dayRows, approvalRows.length + pendingRows.length, compact: compact),
              ],
            ),
          ),
          if (!showWeek) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(compact ? 12 : 24, 0, compact ? 12 : 24, compact ? 14 : 20),
              child: _buildWeekStrip(compact: compact),
            ),
            const Divider(height: 1, color: KeepiColors.cardBorder),
          ],
          Padding(
            padding: EdgeInsets.fromLTRB(compact ? 12 : 24, compact ? 14 : 22, compact ? 12 : 24, compact ? 18 : 26),
            child: showWeek
                ? _buildWeekAgenda(
                    loading: loading,
                    error: error,
                    compact: compact,
                  )
                : _buildTimelineAgenda(
                    dayRows: dayRows,
                    procedureRows: procedureRows,
                    loading: loading,
                    error: error,
                    compact: compact,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgendaTabs({bool compact = false}) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: Row(
        children: [
          _agendaTab('Hoy', _AgendaView.today, Icons.today_outlined, compact: compact),
          _agendaTab('Semana', _AgendaView.week, Icons.view_week_outlined, compact: compact),
        ],
      ),
    );
  }

  Widget _agendaTab(String label, _AgendaView view, IconData icon, {bool compact = false}) {
    final selected = _agendaView == view;
    return Expanded(
      child: InkWell(
        onTap: () {
                      setState(() {
            _agendaView = view;
            if (view == _AgendaView.today) _selectedDay = DateTime.now();
                      });
                    },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: compact ? 42 : 46,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected ? _cardShadow(blur: 12, alpha: 0.035) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: compact ? 16 : 18, color: selected ? KeepiColors.orange : KeepiColors.slateLight),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w900,
                  color: selected ? KeepiColors.slate : KeepiColors.slateLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgendaNavigation({bool compact = false}) {
    final isWeek = _agendaView == _AgendaView.week;
    final title = isWeek ? _weekRangeLabel(_selectedDay) : _longDate(_selectedDay);
    final subtitle = isWeek ? 'Vista semanal resumida' : 'Agenda del día seleccionado';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: compact ? 10 : 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: Row(
        children: [
          _roundNavButton(
            icon: Icons.chevron_left_rounded,
            tooltip: isWeek ? 'Semana anterior' : 'Día anterior',
            onTap: () => setState(() {
              _selectedDay = _selectedDay.subtract(Duration(days: isWeek ? 7 : 1));
            }),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 13 : 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: KeepiColors.slateLight,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _roundNavButton(
            icon: Icons.chevron_right_rounded,
            tooltip: isWeek ? 'Semana siguiente' : 'Día siguiente',
            onTap: () => setState(() {
              _selectedDay = _selectedDay.add(Duration(days: isWeek ? 7 : 1));
            }),
          ),
          if (compact) ...[
            const SizedBox(width: 8),
            _buildTodayButton(compact: true),
          ],
        ],
      ),
    );
  }

  Widget _roundNavButton({required IconData icon, required String tooltip, required VoidCallback onTap}) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: KeepiColors.cardBorder),
            boxShadow: _cardShadow(blur: 12, alpha: 0.025),
          ),
          child: Icon(icon, color: KeepiColors.slate, size: 22),
        ),
      ),
    );
  }

  Widget _buildAgendaSummary(List<AppointmentDto> dayRows, int pendingCount, {bool compact = false}) {
    final upcoming = _upcomingRows;
    final next = upcoming.isEmpty ? null : upcoming.first.appointmentDate!.toLocal();
    final nextLabel = next == null ? 'Sin próximas' : '${_relativeDayLabel(next)} · ${_hour(next)}';
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _summaryPill(Icons.event_note_rounded, '${dayRows.length} citas del día'),
        _summaryPill(Icons.hourglass_top_rounded, '$pendingCount pendientes'),
        _summaryPill(Icons.schedule_rounded, 'Próxima: $nextLabel'),
      ],
    );
  }

  Widget _summaryPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: KeepiColors.orange),
          const SizedBox(width: 7),
          Text(text, style: const TextStyle(color: KeepiColors.slate, fontSize: 12.5, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildWeekStrip({bool compact = false}) {
    final start = _selectedDay.subtract(Duration(days: _selectedDay.weekday - 1));
    const labels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

    return Row(
      children: List.generate(7, (index) {
        final date = DateTime(start.year, start.month, start.day + index);
        final selected = _isSameDay(date, _selectedDay);
        final available = _isWorkingDay(date);
        final appointmentsCount = _appointments.where((a) {
          if (a.appointmentDate == null) return false;
          if (!_isConfirmedAppointmentStatus(a.status)) return false;
          return _isSameDay(a.appointmentDate!.toLocal(), date);
        }).length;
        final hasAppointments = appointmentsCount > 0;

        final bgColor = selected
            ? KeepiColors.orange
            : available
                ? const Color(0xFFF8FAFC)
                : const Color(0xFFF1F5F9);
        final borderColor = selected
            ? KeepiColors.orange
            : available
                ? KeepiColors.cardBorder
                : KeepiColors.cardBorder.withValues(alpha: 0.55);
        final primaryTextColor = selected
            ? Colors.white
            : available
                ? KeepiColors.slate
                : KeepiColors.slateLight.withValues(alpha: 0.55);
        final secondaryTextColor = selected
            ? Colors.white.withValues(alpha: 0.86)
            : available
                ? KeepiColors.slateLight
                : KeepiColors.slateLight.withValues(alpha: 0.55);

        final card = AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: compact ? 82 : 94,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: KeepiColors.orange.withValues(alpha: 0.24),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                labels[index],
                style: TextStyle(
                  color: secondaryTextColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${date.day}',
                style: TextStyle(
                  color: primaryTextColor,
                  fontSize: compact ? 18 : 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              _dayAppointmentDot(
                available: available,
                hasAppointments: hasAppointments,
                selected: selected,
              ),
            ],
          ),
        );

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == 6 ? 0 : 8),
            child: available
                ? InkWell(
                    onTap: () => setState(() => _selectedDay = date),
                    borderRadius: BorderRadius.circular(16),
                    child: card,
                  )
                : Tooltip(
                    message: 'Día no disponible',
                    child: card,
                  ),
          ),
        );
      }),
    );
  }

  Widget _dayAppointmentDot({
    required bool available,
    required bool hasAppointments,
    required bool selected,
  }) {
    if (!available) {
      return Container(
        width: 18,
        height: 6,
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.45)
              : KeepiColors.cardBorder.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(999),
        ),
      );
    }

    if (!hasAppointments) {
      return const SizedBox(height: 10);
    }

    return Tooltip(
      message: 'Tiene citas confirmadas',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: selected ? 10 : 8,
        height: selected ? 10 : 8,
        decoration: BoxDecoration(
          color: KeepiColors.green,
          shape: BoxShape.circle,
          border: selected ? Border.all(color: Colors.white, width: 2) : null,
          boxShadow: [
            BoxShadow(
              color: KeepiColors.green.withValues(alpha: 0.42),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekAgenda({
    required bool loading,
    required String? error,
    bool compact = false,
  }) {
    final start = _selectedDay.subtract(Duration(days: _selectedDay.weekday - 1));
    final days = List.generate(7, (index) => DateTime(start.year, start.month, start.day + index));
    final weekRows = _appointments.where((a) {
      if (a.appointmentDate == null) return false;
      if (!_isConfirmedAppointmentStatus(a.status)) return false;      
      final local = a.appointmentDate!.toLocal();
      return !local.isBefore(days.first) && local.isBefore(days.last.add(const Duration(days: 1)));
    }).toList()
      ..sort((a, b) => a.appointmentDate!.compareTo(b.appointmentDate!));

    final total = weekRows.length;
    final busiest = days.map((day) {
      return weekRows.where((a) => _isSameDay(a.appointmentDate!.toLocal(), day)).length;
    }).fold<int>(0, (a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
            children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _weekRangeLabel(_selectedDay),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 6),
              const Text(
                    'Resumen real de la semana. Toca un día para abrir su agenda.',
                    style: TextStyle(color: KeepiColors.slateLight, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            _summaryPill(Icons.view_week_outlined, '$total citas'),
          ],
        ),
        const SizedBox(height: 18),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 38),
            child: Center(child: CircularProgressIndicator(color: KeepiColors.orange)),
          )
        else if (error != null)
          _errorCard(error)
        else
          Column(
            children: days.map((day) {
              final rows = weekRows.where((a) => _isSameDay(a.appointmentDate!.toLocal(), day)).toList();
              return _weekSummaryDayCard(day, rows, maxCount: busiest, compact: compact);
            }).toList(),
          ),
      ],
    );
  }

  Widget _weekSummaryDayCard(DateTime day, List<AppointmentDto> rows, {required int maxCount, bool compact = false}) {
    final selected = _isSameDay(day, _selectedDay);
    final preview = rows.take(2).toList();
    return InkWell(
      onTap: () => setState(() {
        _selectedDay = day;
        _agendaView = _AgendaView.today;
      }),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(compact ? 13 : 16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFFBF7) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? KeepiColors.orange.withValues(alpha: 0.38) : KeepiColors.cardBorder),
          boxShadow: selected ? _cardShadow(blur: 18, alpha: 0.04) : null,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: compact ? 54 : 62,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? KeepiColors.orange : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: selected ? KeepiColors.orange : KeepiColors.cardBorder),
                  ),
                  child: Column(
                    children: [
                      Text(_shortWeekDay(day), style: TextStyle(color: selected ? Colors.white : KeepiColors.slateLight, fontSize: 11, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 5),
                      Text('${day.day}', style: TextStyle(color: selected ? Colors.white : KeepiColors.slate, fontSize: 20, fontWeight: FontWeight.w900)),
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
                          Expanded(
                            child: Text(
                              rows.isEmpty ? 'Sin citas programadas' : '${rows.length} ${rows.length == 1 ? 'cita programada' : 'citas programadas'}',
                              style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w900, fontSize: 15),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: KeepiColors.slateLight),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _scheduleLabelForDay(day),
                        style: TextStyle(
                          color: _isWorkingDay(day) ? KeepiColors.green : KeepiColors.slateLight,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (preview.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: preview.map((a) {
                            final local = a.appointmentDate!.toLocal();
                            final name = (a.patientName ?? '').trim().isNotEmpty ? a.patientName!.trim() : 'Paciente';
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: KeepiColors.cardBorder),
                              ),
                              child: Text('${_hour(local)} · $name', style: const TextStyle(color: KeepiColors.slate, fontSize: 11.5, fontWeight: FontWeight.w800)),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyWeekCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: const Text('No hay citas programadas para esta semana.', style: TextStyle(color: KeepiColors.slateLight, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildPendingAgendaList({
    required List<AppointmentDto> approvalRows,
    required List<AppointmentDto> pendingRows,
    required bool loading,
    bool compact = false,
  }) {
    final total = approvalRows.length + pendingRows.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pendientes por resolver',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.4, color: Color(0xFF111827)),
        ),
        const SizedBox(height: 6),
        const Text(
          'Confirma o reagenda las solicitudes más importantes sin entrar a otro módulo.',
          style: TextStyle(color: KeepiColors.slateLight, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 38),
            child: Center(child: CircularProgressIndicator(color: KeepiColors.orange)),
          )
        else if (total == 0)
          _emptyPendingCard()
        else ...[
          ...approvalRows.map((a) => _buildApprovalPendingItem(a, rail: true)),
          ...pendingRows.map((a) => _buildPendingItem(a, rail: true)),
        ],
      ],
    );
  }

  Widget _buildRightRail({
    required List<AppointmentDto> approvalRows,
    required List<AppointmentDto> pendingRows,
    required bool loading,
    bool compact = false,
  }) {
    final totalPending = approvalRows.length + pendingRows.length;
    final pendingPanelHeight = _pendingPanelHeight(totalPending, compact: compact);
    final extraPending = totalPending > 2 ? totalPending - 2 : 0;
    final maxUpcomingHeight = compact ? 380.0 : 470.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact) ...[
          _buildPrimaryScheduleButton(),
          const SizedBox(height: 12),
          _buildProcedureScheduleButton(),
          const SizedBox(height: 20),
        ],
        Container(
          padding: EdgeInsets.all(compact ? 16 : 20),
          decoration: _softCardDecoration(radius: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Citas por confirmar',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  _countBadge(totalPending),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Solicitudes que requieren una decisión del doctor.',
                style: TextStyle(
                  color: KeepiColors.slateLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: CircularProgressIndicator(color: KeepiColors.orange)),
                )
              else if (totalPending == 0)
                _emptyPendingCard()
              else
                Column(
                  children: [
                    SizedBox(
                      height: pendingPanelHeight,
                      child: Scrollbar(
                        thumbVisibility: !compact && totalPending > 2,
                        child: ListView(
                          padding: EdgeInsets.zero,
                          physics: totalPending > 2
                              ? const BouncingScrollPhysics()
                              : const NeverScrollableScrollPhysics(),
                          children: [
                            ...approvalRows.map((a) => _buildApprovalPendingItem(a, rail: true)),
                            ...pendingRows.map((a) => _buildPendingItem(a, rail: true)),
                          ],
                        ),
                      ),
                    ),
                    if (extraPending > 0) ...[
                      const SizedBox(height: 10),
                      _pendingScrollHint(extraPending),
                    ],
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: EdgeInsets.all(compact ? 16 : 20),
          decoration: _softCardDecoration(radius: 24),
          child: _buildUpcomingAppointmentsPanel(
            loading: loading,
            compact: compact,
            maxHeight: maxUpcomingHeight,
          ),
        ),
      ],
    );
  }

  double _pendingPanelHeight(int totalPending, {required bool compact}) {
    final visibleItems = totalPending <= 1 ? 1 : 2;
    final estimatedCardHeight = compact ? 190.0 : 204.0;
    final spacing = visibleItems == 2 ? 14.0 : 0.0;
    return (visibleItems * estimatedCardHeight) + spacing;
  }

  Widget _pendingScrollHint(int hiddenCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.keyboard_arrow_down_rounded, color: KeepiColors.slateLight, size: 18),
          const SizedBox(width: 4),
          Text(
            'Desliza para ver $hiddenCount más',
            style: const TextStyle(
              color: KeepiColors.slateLight,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingAppointmentsPanel({
    required bool loading,
    bool compact = false,
    double maxHeight = 470,
  }) {
    final rows = _upcomingRows.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Próximas citas',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            _countBadge(rows.length),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Vista general, sin depender del día seleccionado.',
          style: TextStyle(color: KeepiColors.slateLight, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 18),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(color: KeepiColors.orange)),
          )
        else if (rows.isEmpty)
          _emptyUpcomingCard()
        else
          SizedBox(
            height: maxHeight,
            child: Scrollbar(
              thumbVisibility: !compact,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: rows.length,
                itemBuilder: (_, index) => _upcomingAppointmentTile(rows[index]),
              ),
            ),
          ),
      ],
    );
  }

  Widget _upcomingAppointmentTile(AppointmentDto a) {
    final local = a.appointmentDate!.toLocal();
    final visual = _statusVisual(a.status);
    final name = (a.patientName ?? '').trim().isNotEmpty ? a.patientName!.trim() : 'Paciente';
    return InkWell(
      onTap: () => _openAppointment(a),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: KeepiColors.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: visual.color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.event_note_rounded, color: visual.color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_relativeDayLabel(local)} · ${_hour(local)}',
                    style: const TextStyle(color: KeepiColors.slate, fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w900, fontSize: 13.5)),
                  const SizedBox(height: 3),
                  Text(a.reason.isEmpty ? visual.label : a.reason, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: KeepiColors.slateLight, fontWeight: FontWeight.w600, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyUpcomingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: const Text('No hay próximas citas programadas.', style: TextStyle(color: KeepiColors.slateLight, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildTimelineAgenda({
    required List<AppointmentDto> dayRows,
    required List<ProcedureBlockDto> procedureRows,
    required bool loading,
    required String? error,
    bool compact = false,
  }) {
    final hours = _visibleHoursFor(dayRows, procedureRows);
    final timelineItems = _buildDayTimelineItems(dayRows, procedureRows);
    final hasItems = dayRows.isNotEmpty || procedureRows.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Agenda del ${_selectedDay.day} ${_monthName(_selectedDay.month).toLowerCase()}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _scheduleDayPill(_selectedDay),
                ],
              ),
            ),
            if (compact) _buildTodayButton(),
          ],
        ),
        const SizedBox(height: 16),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 38),
            child: Center(child: CircularProgressIndicator(color: KeepiColors.orange)),
          )
        else if (error != null)
          _errorCard(error)
        else
          Stack(
            children: [
              Column(
                children: [
                  for (final h in hours) _timeGridRow(h, compact: compact),
                ],
              ),
              if (!hasItems)
                Positioned.fill(child: _emptyDayOverlay())
              else
                Column(
                  children: [
                    const SizedBox(height: 44),
                    ...timelineItems,
                  ],
                ),
            ],
          ),
      ],
    );
  }

  List<Widget> _buildDayTimelineItems(
    List<AppointmentDto> dayRows,
    List<ProcedureBlockDto> procedureRows,
  ) {
    final entries = <({DateTime start, Widget widget})>[];
    for (final appointment in dayRows) {
      final start = appointment.appointmentDate?.toLocal();
      if (start == null) continue;
      entries.add((
        start: start,
        widget: _buildAppointmentFromDto(appointment),
      ));
    }
    for (final procedure in procedureRows) {
      entries.add((
        start: procedure.startAt.toLocal(),
        widget: _buildProcedureFromDto(procedure),
      ));
    }
    entries.sort((a, b) => a.start.compareTo(b.start));
    return entries.map((entry) => entry.widget).toList();
  }

  List<int> _visibleHoursFor(
    List<AppointmentDto> rows,
    List<ProcedureBlockDto> procedures,
  ) {
    final scheduleDay = _scheduleForDay(_selectedDay);

    if (scheduleDay != null) {
      final startHour = _hourFromTime(scheduleDay.startTime, fallback: 9).clamp(0, 23) as int;
      final endHour = _hourFromTime(scheduleDay.endTime, fallback: startHour + 8).clamp(startHour + 1, 24) as int;
      return [for (var h = startHour; h <= endHour; h++) h];
    }

    final hours = <int>[
      ...rows
          .where((a) => a.appointmentDate != null)
          .map((a) => a.appointmentDate!.toLocal().hour),
      ...procedures.map((p) => p.startAt.toLocal().hour),
      ...procedures.map((p) => p.endAt.toLocal().hour),
    ];
    if (hours.isEmpty) return [8, 9, 10, 11, 12, 13, 14];
    final minHour = (hours.reduce((a, b) => a < b ? a : b) - 1).clamp(7, 21) as int;
    final maxHour = (hours.reduce((a, b) => a > b ? a : b) + 2).clamp(9, 22) as int;
    return [for (var h = minHour; h <= maxHour; h++) h];
  }

  Widget _scheduleDayPill(DateTime date) {
    final available = _isWorkingDay(date);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: available ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: available ? KeepiColors.green.withValues(alpha: 0.25) : KeepiColors.cardBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            available ? Icons.schedule_rounded : Icons.event_busy_rounded,
            size: 15,
            color: available ? KeepiColors.green : KeepiColors.slateLight,
          ),
          const SizedBox(width: 6),
          Text(
            available ? 'Horario: ${_scheduleLabelForDay(date)}' : 'Día no disponible',
            style: TextStyle(
              color: available ? KeepiColors.green : KeepiColors.slateLight,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeGridRow(int hour, {bool compact = false}) {
    return SizedBox(
      height: compact ? 52 : 58,
      child: Row(
        children: [
          SizedBox(
            width: compact ? 44 : 58,
            child: Text(
              '${hour.toString().padLeft(2, '0')}:00',
              style: const TextStyle(
                color: KeepiColors.slate,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: KeepiColors.cardBorder.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcedureFromDto(ProcedureBlockDto procedure) {
    const accent = Color(0xFF7C3AED);
    return _buildAppointmentItem(
      time: _timeRangeLabel(procedure.startAt, procedure.endAt),
      name: procedure.title,
      type: 'PROCEDIMIENTO',
      description: 'Horario bloqueado para citas',
      typeColor: accent,
      softColor: accent.withValues(alpha: 0.08),
      onTap: () => _openProcedure(procedure),
    );
  }

  Widget _buildAppointmentFromDto(AppointmentDto a) {
    final timeString = a.appointmentDate != null ? _hour(a.appointmentDate!.toLocal()) : '--:--';
    final patientName = (a.patientName ?? '').trim().isNotEmpty ? a.patientName!.trim() : 'Paciente';
    final visual = _statusVisual(a.status);
    final isCanceled = a.status == 'canceled';

    return _buildAppointmentItem(
      time: timeString,
      name: patientName,
      type: visual.label,
      description: a.reason.isEmpty ? 'Toca para abrir consulta' : a.reason,
      typeColor: visual.color,
      softColor: visual.softColor,
      isCanceled: isCanceled,
      onTap: () => _openAppointment(a),
      onReassign: isCanceled ? () => _reassignCanceled(a) : null,
      onCancel: isCanceled ? null : () => _cancelAppointment(a),
    );
  }

  Widget _buildPendingItem(AppointmentDto a, {bool rail = false}) {
    if (rail) {
      return _railAppointmentCard(
        appointment: a,
        icon: Icons.access_time_rounded,
        accent: KeepiColors.orange,
        title: (a.patientName ?? '').trim().isNotEmpty ? a.patientName!.trim() : 'Nueva solicitud',
        subtitle: a.reason.isEmpty ? 'Sin motivo específico' : a.reason,
        dateLabel: 'Por asignar',
        primaryLabel: 'Asignar',
        onPrimary: () => _assignDate(a),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: KeepiColors.orange.withValues(alpha: 0.22)),
        boxShadow: _cardShadow(),
      ),
      child: Row(
        children: [
          _softIcon(Icons.access_time_rounded, KeepiColors.orange),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nueva solicitud', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: KeepiColors.slate)),
                const SizedBox(height: 4),
                if ((a.patientName ?? '').trim().isNotEmpty)
                  Text(a.patientName!.trim(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: KeepiColors.orange)),
                Text(a.reason.isEmpty ? 'Sin motivo específico' : a.reason, style: const TextStyle(fontSize: 13, color: KeepiColors.slateLight)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: KeepiColors.orange, padding: const EdgeInsets.symmetric(horizontal: 16)),
            onPressed: () => _assignDate(a),
            child: const Text('Asignar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalPendingItem(AppointmentDto a, {bool rail = false}) {
    final local = a.appointmentDate?.toLocal();
    final when = local != null ? '${local.day} ${_monthName(local.month).substring(0, 3).toLowerCase()} · ${_hour(local)}' : 'Sin fecha';
    if (rail) {
      return _railAppointmentCard(
        appointment: a,
        icon: Icons.event_available_outlined,
        accent: KeepiColors.skyBlue,
        title: (a.patientName ?? '').trim().isNotEmpty ? a.patientName!.trim() : 'Paciente',
        subtitle: a.reason.isEmpty ? 'Consulta solicitada en línea' : a.reason,
        dateLabel: when,
        primaryLabel: 'Confirmar',
        secondaryLabel: 'Reagendar',
        dangerLabel: 'Rechazar',
        onPrimary: () => _approveAppointment(a),
        onSecondary: () => _rescheduleWebRequest(a),
        onDanger: () => _rejectAppointment(a),
        onTap: () => _openPendingReview(a),
      );
    }

    return InkWell(
      onTap: () => _openPendingReview(a),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KeepiColors.skyBlue.withValues(alpha: 0.45)),
          boxShadow: _cardShadow(),
      ),
        child: Row(
          children: [
            _softIcon(Icons.event_available_outlined, KeepiColors.skyBlue),
            const SizedBox(width: 16),
            Expanded(
      child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                  Text(when, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: KeepiColors.slate)),
                  if ((a.patientName ?? '').trim().isNotEmpty)
                    Text(a.patientName!.trim(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: KeepiColors.skyBlue)),
                  Text(a.reason.isEmpty ? 'Consulta en línea' : a.reason, style: const TextStyle(fontSize: 13, color: KeepiColors.slateLight)),
                ],
              ),
            ),
            OutlinedButton(onPressed: () => _rescheduleWebRequest(a), child: const Text('Reagendar')),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: () => _rejectAppointment(a), child: const Text('Rechazar')),
            const SizedBox(width: 8),
            FilledButton(onPressed: () => _approveAppointment(a), child: const Text('Confirmar')),
          ],
        ),
      ),
    );
  }

  Widget _railAppointmentCard({
    required AppointmentDto appointment,
    required IconData icon,
    required Color accent,
    required String title,
    required String subtitle,
    required String dateLabel,
    required String primaryLabel,
    required VoidCallback onPrimary,
    String? secondaryLabel,
    String? dangerLabel,
    VoidCallback? onSecondary,
    VoidCallback? onDanger,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: KeepiColors.cardBorder.withValues(alpha: 0.75)),
          boxShadow: _cardShadow(blur: 18, alpha: 0.035),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: accent, size: 25),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                        dateLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF1F2937)),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: KeepiColors.orange, fontWeight: FontWeight.w900, fontSize: 13.5),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: KeepiColors.slateLight, fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _railActions(
              primaryLabel: primaryLabel,
              onPrimary: onPrimary,
              accent: accent,
              secondaryLabel: secondaryLabel,
              onSecondary: onSecondary,
              dangerLabel: dangerLabel,
              onDanger: onDanger,
            ),
          ],
        ),
      ),
    );
  }

  Widget _railActions({
    required String primaryLabel,
    required VoidCallback onPrimary,
    required Color accent,
    String? secondaryLabel,
    VoidCallback? onSecondary,
    String? dangerLabel,
    VoidCallback? onDanger,
  }) {
    final hasSecondary = secondaryLabel != null && onSecondary != null;
    final hasDanger = dangerLabel != null && onDanger != null;

    if (!hasSecondary) {
      return SizedBox(
        width: double.infinity,
        height: 42,
        child: FilledButton(
          onPressed: onPrimary,
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          ),
          child: Text(primaryLabel, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 42,
          child: FilledButton(
            onPressed: onPrimary,
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
            ),
            child: Text(primaryLabel, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900)),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 42,
                child: OutlinedButton(
                  onPressed: onSecondary,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: KeepiColors.slate,
                    side: const BorderSide(color: KeepiColors.cardBorder),
                    padding: EdgeInsets.zero,
                    textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                  ),
                  child: Text(secondaryLabel!),
                ),
              ),
            ),
            if (hasDanger) ...[
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                tooltip: 'Más opciones',
                position: PopupMenuPosition.under,
                elevation: 14,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onSelected: (_) => onDanger!(),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'reject',
                    child: Row(
                      children: [
                        const Icon(Icons.close_rounded, color: Color(0xFFE11D48), size: 18),
                        const SizedBox(width: 10),
                        Text(dangerLabel!, style: const TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  width: 48,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: KeepiColors.cardBorder),
                  ),
                  child: const Icon(Icons.more_horiz_rounded, color: KeepiColors.slateLight, size: 22),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildAppointmentItem({
    required String time,
    required String name,
    required String type,
    required String description,
    required Color typeColor,
    Color? softColor,
    bool isCanceled = false,
    VoidCallback? onTap,
    VoidCallback? onReassign,
    VoidCallback? onCancel,
  }) {
    final card = Container(
      margin: const EdgeInsets.only(left: 66, bottom: 14),
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      decoration: BoxDecoration(
        color: softColor ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: typeColor, width: 4)),
        boxShadow: _cardShadow(blur: 14, alpha: 0.03),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            child: Text(
              time,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                    color: isCanceled ? Colors.grey : KeepiColors.slate,
                decoration: isCanceled ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5, color: Color(0xFF1F2937)),
                      ),
                        ),
                        const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                      child: Text(type, style: TextStyle(color: typeColor, fontSize: 9.5, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: KeepiColors.slateLight, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: card);
  }

  Widget _countBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: KeepiColors.orangeSoft, borderRadius: BorderRadius.circular(999)),
      child: Text('$count', style: const TextStyle(color: KeepiColors.orange, fontWeight: FontWeight.w900, fontSize: 12)),
    );
  }

  Widget _emptyPendingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: const Text('No hay citas pendientes por confirmar.', style: TextStyle(color: KeepiColors.slateLight, fontWeight: FontWeight.w600)),
    );
  }

  Widget _emptyDayOverlay() {
    return IgnorePointer(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: KeepiColors.cardBorder),
          ),
          child: const Text('Sin citas para este día', style: TextStyle(color: KeepiColors.slateLight, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _errorCard(String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Text(error, style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w700)),
    );
  }

  Widget _softIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), shape: BoxShape.circle),
      child: Icon(icon, color: color),
    );
  }

  BoxDecoration _softCardDecoration({double radius = 22}) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: KeepiColors.cardBorder.withValues(alpha: 0.75)),
      boxShadow: _cardShadow(blur: 26, alpha: 0.055),
    );
  }

  List<BoxShadow> _cardShadow({double blur = 22, double alpha = 0.045}) {
    return [
      BoxShadow(
        color: const Color(0xFF0F172A).withValues(alpha: alpha),
        blurRadius: blur,
        offset: const Offset(0, 12),
      ),
    ];
  }

  String _shortWeekDay(DateTime date) {
    const days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return days[date.weekday - 1];
  }

  String _longDate(DateTime date) {
    const days = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    return '${days[date.weekday - 1]}, ${date.day} de ${_monthName(date.month).toLowerCase()} de ${date.year}';
  }

  String _weekRangeLabel(DateTime date) {
    final start = date.subtract(Duration(days: date.weekday - 1));
    final end = start.add(const Duration(days: 6));
    final sameMonth = start.month == end.month;
    if (sameMonth) {
      return 'Semana del ${start.day} al ${end.day} de ${_monthName(end.month).toLowerCase()}';
    }
    return 'Semana del ${start.day} ${_monthName(start.month).substring(0, 3).toLowerCase()} al ${end.day} ${_monthName(end.month).substring(0, 3).toLowerCase()}';
  }

  String _relativeDayLabel(DateTime date) {
    final today = DateTime.now();
    final d = DateTime(date.year, date.month, date.day);
    final t = DateTime(today.year, today.month, today.day);
    final diff = d.difference(t).inDays;
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Mañana';
    if (diff == -1) return 'Ayer';
    return '${_shortWeekDay(date)} ${date.day} ${_monthName(date.month).substring(0, 3).toLowerCase()}';
  }

  _AppointmentVisual _statusVisual(String status) {
    switch (status) {
      case 'pending_patient_approval':
        return _AppointmentVisual('ESPERANDO RESPUESTA', Colors.orange, const Color(0xFFFFFBEB));
      case 'canceled':
        return _AppointmentVisual('CANCELADA', Colors.red, const Color(0xFFFFF1F2));
      case 'pending_doctor_proposal':
        return _AppointmentVisual('POR ASIGNAR', KeepiColors.slate, const Color(0xFFF8FAFC));
      case 'pending_doctor_approval':
        return _AppointmentVisual('POR CONFIRMAR', KeepiColors.orange, const Color(0xFFFFF7ED));
      default:
        return _AppointmentVisual('CONFIRMADA', KeepiColors.green, const Color(0xFFF0FDF4));
    }
  }
}

class _AppointmentVisual {
  const _AppointmentVisual(this.label, this.color, this.softColor);
  final String label;
  final Color color;
  final Color softColor;
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KeepiColors.cardBorder.withValues(alpha: 0.85)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.045),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}
