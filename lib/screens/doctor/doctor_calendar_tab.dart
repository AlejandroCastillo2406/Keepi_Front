import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import '../../services/appointment_service.dart';
import '../../services/doctor_service.dart';
import '../../widgets/doctor_note_field.dart';

class DoctorCalendarTab extends StatefulWidget {
  const DoctorCalendarTab({super.key});

  @override
  State<DoctorCalendarTab> createState() => _DoctorCalendarTabState();
}

class _DoctorCalendarTabState extends State<DoctorCalendarTab> {
  DateTime _selectedDay = DateTime.now();
  bool _loading = true;
  String? _error;
  List<AppointmentDto> _appointments = [];

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
      
      final rows = await svc.fetchDoctorCalendar(from: from, to: to); 
      
      if (!mounted) return;
      setState(() {
        _appointments = rows;
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

  String _monthName(int month) {
    const months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
    ];
    return months[month - 1];
  }

  String _hour(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  
  String _two(int v) => v.toString().padLeft(2, '0');

  // --- FILTROS DE CITAS ---

  List<AppointmentDto> get _pendingRows => _appointments
      .where((a) => a.status == 'pending_doctor_proposal' || a.appointmentDate == null)
      .toList();

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

  // --- ASIGNAR O REASIGNAR FECHA ---
  Future<void> _assignDate(AppointmentDto a) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: KeepiColors.orange)),
        child: child!,
      ),
    );
    if (date == null) return;

    if (!mounted) return;
    
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: KeepiColors.orange)),
        child: child!,
      ),
    );
    if (time == null) return;

    final proposed = DateTime(date.year, date.month, date.day, time.hour, time.minute);

    if (!mounted) return;

    showDialog(
      context: context, 
      barrierDismissible: false, 
      builder: (_) => const Center(child: CircularProgressIndicator(color: KeepiColors.orange))
    );

    try {
      await AppointmentService(context.read<ApiClient>()).doctorProposeTime(
        appointmentId: a.id,
        proposedStartAt: proposed,
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

  // --- CANCELAR CITA ---
  Future<void> _cancelAppointment(AppointmentDto a) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Cancelar cita', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('¿Estás seguro de que deseas cancelar esta cita? Esta acción no se puede deshacer.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Volver', style: TextStyle(color: KeepiColors.slateLight)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sí, Cancelar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) return;

    showDialog(
      context: context, 
      barrierDismissible: false, 
      builder: (_) => const Center(child: CircularProgressIndicator(color: KeepiColors.orange))
    );

    try {
      final svc = AppointmentService(context.read<ApiClient>());
      await svc.cancelAppointment(appointmentId: a.id); 
      
      if (mounted) Navigator.pop(context); 
      _load(); 
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cita cancelada correctamente'), backgroundColor: KeepiColors.slate)
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cancelar: ${AppointmentService.messageFromDio(e)}'), backgroundColor: Colors.red)
        );
      }
    }
  }

  // --- AGENDAR DESDE CERO (GLOBAL) ---
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

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: KeepiColors.orange)),
        child: child!,
      ),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pickedTime == null || !mounted) return;

    final finalDateTime = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);

    if (!mounted) return;

    final noteCtrl = TextEditingController();
    final dateStr =
        '${_two(pickedDate.day)}/${_two(pickedDate.month)}/${pickedDate.year}';
    final timeStr = pickedTime.format(context);

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
    noteCtrl.dispose();

    if (confirm != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: KeepiColors.orange)),
    );

    try {
      await DoctorService(context.read<ApiClient>()).scheduleAppointment(
        patientId: selectedPatient.id,
        date: finalDateTime,
        reason: 'Consulta médica',
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

  @override
  Widget build(BuildContext context) {
    final dayRows = _selectedDayRows;
    final pendingRows = _pendingRows;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
          if (pendingRows.isNotEmpty && !_loading) ...[
            const Text(
              'Solicitudes por Asignar',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: KeepiColors.slate),
            ),
            const SizedBox(height: 12),
            ...pendingRows.map(_buildPendingItem),
            const SizedBox(height: 32),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_monthName(_selectedDay.month)} ${_selectedDay.year}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: KeepiColors.slate),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedDay = DateTime(_selectedDay.year, _selectedDay.month - 1, 1);
                        _load(); 
                      });
                    },
                    icon: const Icon(Icons.chevron_left, color: KeepiColors.slate),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedDay = DateTime(_selectedDay.year, _selectedDay.month + 1, 1);
                        _load(); 
                      });
                    },
                    icon: const Icon(Icons.chevron_right, color: KeepiColors.slate),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          
          // AQUÍ SE MUESTRA EL NUEVO CALENDARIO COMPLETO
          _buildFullMonthCalendar(),
          
          const SizedBox(height: 32),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Agenda del Día',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: KeepiColors.slate),
              ),
              ElevatedButton.icon(
                onPressed: _scheduleGlobalAppointment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: KeepiColors.orangeSoft,
                  foregroundColor: KeepiColors.orange,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nueva Cita', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              )
            ],
          ),
          const SizedBox(height: 16),
          
          if (_loading)
            const Center(child: CircularProgressIndicator(color: KeepiColors.orange))
          else if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red))
          else if (dayRows.isEmpty)
            const Text('Sin citas para este día', style: TextStyle(color: KeepiColors.slateLight))
          else
            ...dayRows.map(
              (a) {
                final timeString = a.appointmentDate != null ? _hour(a.appointmentDate!.toLocal()) : '--:--';
                
                String statusLabel = 'CONFIRMADA';
                Color statusColor = Colors.green;
                bool isCanceled = false;
                
                if (a.status == 'pending_patient_approval') {
                  statusLabel = 'ESPERANDO RESPUESTA';
                  statusColor = Colors.orange;
                } else if (a.status == 'canceled') {
                  statusLabel = 'CANCELADA/RECHAZADA';
                  statusColor = Colors.red;
                  isCanceled = true;
                } else if (a.status == 'pending_doctor_proposal') {
                  statusLabel = 'POR ASIGNAR';
                  statusColor = KeepiColors.slate;
                }
                
                bool canCancel = !isCanceled;
                
                return _buildAppointmentItem(
                  time: timeString,
                  name: 'Paciente',
                  type: statusLabel,
                  description: a.reason,
                  typeColor: statusColor,
                  isCanceled: isCanceled,
                  onReassign: isCanceled ? () => _assignDate(a) : null,
                  onCancel: canCancel ? () => _cancelAppointment(a) : null,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPendingItem(AppointmentDto a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KeepiColors.orange.withValues(alpha: 0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: KeepiColors.orange.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.access_time_rounded, color: KeepiColors.orange),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nueva Solicitud', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: KeepiColors.slate)),
                const SizedBox(height: 4),
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

  // --- NUEVO WIDGET: CALENDARIO MENSUAL ---
  Widget _buildFullMonthCalendar() {
    // Calculamos el primer día del mes y cuántos días tiene
    final firstDayOfMonth = DateTime(_selectedDay.year, _selectedDay.month, 1);
    final lastDayOfMonth = DateTime(_selectedDay.year, _selectedDay.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    
    // weekday va de 1 (Lunes) a 7 (Domingo)
    final startingWeekday = firstDayOfMonth.weekday; 
    
    // Total de celdas en la cuadrícula (espacios vacíos + días del mes)
    final totalCells = (startingWeekday - 1) + daysInMonth;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
      ),
      child: Column(
        children: [
          // Días de la semana
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const ['LU', 'MA', 'MI', 'JU', 'VI', 'SA', 'DO']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d, style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          
          // Cuadrícula de días
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(), // Evita scroll interno
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7, // 7 columnas para los 7 días
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1, // Hace que las celdas sean cuadradas perfectas
            ),
            itemCount: totalCells,
            itemBuilder: (context, index) {
              // Espacios en blanco al inicio del mes
              if (index < startingWeekday - 1) {
                return const SizedBox(); 
              }
              
              // Número del día real
              final dayNumber = index - (startingWeekday - 1) + 1;
              final date = DateTime(_selectedDay.year, _selectedDay.month, dayNumber);
              
              return _dateItem(
                date,
                isCurrentMonth: true,
                isSelected: date.year == _selectedDay.year && date.month == _selectedDay.month && date.day == _selectedDay.day,
                hasDot: _appointments.any((a) {
                  if (a.appointmentDate == null) return false;
                  final ad = a.appointmentDate!.toLocal();
                  return ad.year == date.year && ad.month == date.month && ad.day == date.day;
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _dateItem(
    DateTime day, {
    required bool isCurrentMonth,
    required bool isSelected,
    bool hasDot = false,
    Color dotColor = Colors.orange,
  }) {
    return InkWell(
      onTap: () => setState(() => _selectedDay = day),
      borderRadius: BorderRadius.circular(12), // Bordes redondeados para el toque
      child: Container(
        decoration: BoxDecoration(
          // Si está seleccionado, pintamos el fondo completamente de naranja
          color: isSelected ? KeepiColors.orange : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                // Texto blanco si está seleccionado para que contraste
                color: isSelected
                    ? Colors.white
                    : isCurrentMonth
                        ? KeepiColors.slate
                        : Colors.grey.shade300,
              ),
            ),
            const SizedBox(height: 2),
            // El puntito indicador
            Container(
              height: 4,
              width: 4,
              decoration: BoxDecoration(
                // Si está seleccionado, el punto se vuelve blanco
                color: hasDot ? (isSelected ? Colors.white : dotColor) : Colors.transparent, 
                shape: BoxShape.circle
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentItem({
    required String time,
    required String name,
    required String type,
    required String description,
    required Color typeColor,
    bool isCanceled = false,
    VoidCallback? onReassign,
    VoidCallback? onCancel,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isCanceled ? Border.all(color: Colors.red.shade200, width: 1.5) : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                children: [
                  Text(time, style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 16,
                    decoration: isCanceled ? TextDecoration.lineThrough : null,
                    color: isCanceled ? Colors.grey : KeepiColors.slate,
                  )),
                ],
              ),
              const SizedBox(width: 20),
              const CircleAvatar(radius: 25, backgroundColor: KeepiColors.slateSoft, child: Icon(Icons.person, color: KeepiColors.slate)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: Text(type, style: TextStyle(color: typeColor, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(description, style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ],
                ),
              ),
              
              if (onCancel != null) 
                IconButton(
                  onPressed: onCancel,
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  tooltip: 'Cancelar Cita',
                )
            ],
          ),
          
          if (onReassign != null) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onReassign,
                icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.red),
                label: const Text('Reasignar Fecha', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red.shade200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}