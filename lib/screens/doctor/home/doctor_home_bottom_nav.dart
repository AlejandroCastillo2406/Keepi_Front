import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';

class DoctorHomeBottomNav extends StatelessWidget {
  const DoctorHomeBottomNav({required this.currentIndex, required this.onTap});
  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = <DoctorHomeNavItemData>[
    DoctorHomeNavItemData(icon: Icons.space_dashboard_outlined, label: 'Inicio'),
    DoctorHomeNavItemData(icon: Icons.people_alt_outlined, label: 'Pacientes'),
    DoctorHomeNavItemData(icon: Icons.calendar_month_outlined, label: 'Agenda'),
    DoctorHomeNavItemData(icon: Icons.folder_copy_outlined, label: 'Expedientes'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: KeepiColors.cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: DoctorHomeNavItem(
                    data: _items[i],
                    active: currentIndex == i,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class DoctorHomeNavItemData {
  const DoctorHomeNavItemData({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

class DoctorHomeNavItem extends StatelessWidget {
  const DoctorHomeNavItem(
      {required this.data, required this.active, required this.onTap});
  final DoctorHomeNavItemData data;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? KeepiColors.orange : KeepiColors.slateLight;
    return InkResponse(
      onTap: onTap,
      radius: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(data.icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(
              data.label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 5),
            Container(
              width: active ? 18 : 0,
              height: 2,
              decoration: BoxDecoration(
                color: KeepiColors.orange,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
