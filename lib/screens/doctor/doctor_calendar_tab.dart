import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

class DoctorCalendarTab extends StatelessWidget {
  const DoctorCalendarTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Octubre 2023',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: KeepiColors.slate),
              ),
              Row(
                children: [
                  IconButton(onPressed: () {}, icon: const Icon(Icons.chevron_left, color: KeepiColors.slate)),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.chevron_right, color: KeepiColors.slate)),
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
              const Text(
                '4 citas',
                style: TextStyle(color: KeepiColors.orange, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildAppointmentItem(
            time: '09:00',
            name: 'Elena Rodríguez',
            type: 'VIRTUAL',
            description: 'Control Post-Op',
            typeColor: Colors.cyan.shade400,
          ),
          _buildAppointmentItem(
            time: '10:30',
            name: 'Mateo Valdés',
            type: 'URGENTE',
            description: 'Dolor Abdominal',
            typeColor: Colors.red.shade400,
            isUrgent: true,
          ),
          _buildAppointmentItem(
            time: '11:45',
            name: 'Sofía Moreno',
            type: 'PRESENCIAL',
            description: 'Primera Visita',
            typeColor: Colors.grey.shade400,
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarHeader() {
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
            children: ['LU', 'MA', 'MI', 'JU', 'VI', 'SA', 'DO']
                .map((d) => Text(d, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)))
                .toList(),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _dateItem('26', false), _dateItem('27', false), _dateItem('28', false),
              _dateItem('29', false), _dateItem('30', false), _dateItem('1', true), _dateItem('2', true, hasDot: true),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _dateItem('3', true), _dateItem('4', true, hasDot: true, dotColor: Colors.orange),
              _dateItem('5', false), _dateItem('6', true), _dateItem('7', true),
              _dateItem('8', true, hasDot: true), _dateItem('9', true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateItem(String day, bool isCurrentMonth, {bool hasDot = false, Color dotColor = Colors.orange}) {
    return Column(
      children: [
        Text(
          day,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isCurrentMonth ? KeepiColors.slate : Colors.grey.shade300,
          ),
        ),
        if (hasDot) Container(margin: const EdgeInsets.only(top: 4), height: 4, width: 4, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
      ],
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