import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import '../../services/appointment_service.dart';

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

  // --- FILTROS DE CITAS ---

  // 1. Citas que NO tienen fecha (Solicitudes iniciales del paciente)
  List<AppointmentDto> get _pendingRows => _appointments
      .where((a) => a.status == 'pending_doctor_proposal' || a.appointmentDate == null)
      .toList();

  // 2. Citas del día seleccionado en el calendario
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
      
      if (mounted) Navigator.pop(context); // Cerrar loading
      _load(); // Recargar datos
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fecha asignada y enviada al paciente.'))
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Cerrar loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppointmentService.messageFromDio(e))));
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
          _buildCalendarHeader(),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Agenda de Hoy',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: KeepiColors.slate),
              ),
              Text(
                '${dayRows.length} citas',
                style: const TextStyle(color: KeepiColors.orange, fontWeight: FontWeight.w600),
              ),
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
                
                // LÓGICA DE ESTADOS CORREGIDA
                String statusLabel = 'CONFIRMADA';
                Color statusColor = Colors.green;
                
                if (a.status == 'pending_patient_approval') {
                  statusLabel = 'ESPERANDO RESPUESTA';
                  statusColor = Colors.orange;
                } else if (a.status == 'canceled') {
                  statusLabel = 'RECHAZADA';
                  statusColor = Colors.red;
                }
                
                return _buildAppointmentItem(
                  time: timeString,
                  name: 'Paciente',
                  type: statusLabel,
                  description: a.reason,
                  typeColor: statusColor,
                  isCanceled: a.status == 'canceled',
                  onReassign: a.status == 'canceled' ? () => _assignDate(a) : null,
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

  Widget _buildCalendarHeader() {
    final start = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day - 3);
    final days = List.generate(7, (index) => DateTime(start.year, start.month, start.day + index));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const ['LU', 'MA', 'MI', 'JU', 'VI', 'SA', 'DO']
                .map((d) => Text(d, style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)))
                .toList(),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: days
                .map(
                  (d) => _dateItem(
                    d,
                    isCurrentMonth: d.month == _selectedDay.month,
                    isSelected: d.year == _selectedDay.year && d.month == _selectedDay.month && d.day == _selectedDay.day,
                    hasDot: _appointments.any((a) {
                      if (a.appointmentDate == null) return false;
                      final ad = a.appointmentDate!.toLocal();
                      return ad.year == d.year && ad.month == d.month && ad.day == d.day;
                    }),
                  ),
                )
                .toList(),
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
      borderRadius: BorderRadius.circular(10),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected ? KeepiColors.orange.withValues(alpha: 0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? KeepiColors.orange
                    : isCurrentMonth
                        ? KeepiColors.slate
                        : Colors.grey.shade300,
              ),
            ),
          ),
          if (hasDot)
            Container(
              margin: const EdgeInsets.only(top: 4),
              height: 4,
              width: 4,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
        ],
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
            ],
          ),
          
          // BOTÓN DE REASIGNAR (Solo aparece si la cita está cancelada)
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