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
    final first = DateTime(_selectedDay.year, _selectedDay.month, 1);
    final next = DateTime(_selectedDay.year, _selectedDay.month + 1, 1);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = AppointmentService(context.read<ApiClient>());
      final rows = await svc.fetchDoctorCalendar(from: first, to: next);
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

  List<AppointmentDto> get _selectedDayRows => _appointments.where((a) {
        final d = a.currentStartAt.toLocal();
        return d.year == _selectedDay.year && d.month == _selectedDay.month && d.day == _selectedDay.day;
      }).toList()..sort((a, b) => a.currentStartAt.compareTo(b.currentStartAt));

  @override
  Widget build(BuildContext context) {
    final dayRows = _selectedDayRows;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      setState(() => _selectedDay = DateTime(_selectedDay.year, _selectedDay.month - 1, 1));
                      _load();
                    },
                    icon: const Icon(Icons.chevron_left, color: KeepiColors.slate),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() => _selectedDay = DateTime(_selectedDay.year, _selectedDay.month + 1, 1));
                      _load();
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
                style: TextStyle(color: KeepiColors.orange, fontWeight: FontWeight.w600),
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
              (a) => _buildAppointmentItem(
                time: _hour(a.currentStartAt.toLocal()),
                name: 'Paciente',
                type: a.status,
                description: a.reason,
                typeColor: a.status == 'confirmed' ? Colors.green : Colors.orange,
              ),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
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
                      final at = a.currentStartAt.toLocal();
                      return at.year == d.year && at.month == d.month && at.day == d.day;
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
              color: isSelected ? KeepiColors.orange.withOpacity(0.1) : Colors.transparent,
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
    bool isUrgent = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isUrgent ? Border(left: BorderSide(color: Colors.red.shade400, width: 4)) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Column(
            children: [
              Text(time, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Text('AM', style: TextStyle(fontSize: 10, color: Colors.grey)),
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
                      decoration: BoxDecoration(color: typeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
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
    );
  }
}