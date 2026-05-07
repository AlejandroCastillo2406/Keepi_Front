import 'package:flutter/material.dart';
import '../../../core/app_theme.dart';

class PatientHealthSummaryWidget extends StatelessWidget {
  final Map<String, dynamic> kpiData;

  const PatientHealthSummaryWidget({super.key, required this.kpiData});

  @override
  Widget build(BuildContext context) {
    final weight = kpiData['weight']?.toStringAsFixed(1) ?? '--';
    final height = kpiData['height']?.toStringAsFixed(2) ?? '--';
    final bmi = kpiData['bmi']?.toStringAsFixed(1) ?? '--';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 18, height: 1, color: KeepiColors.slate.withOpacity(0.45)),
            const SizedBox(width: 8),
            const Text(
              'RESUMEN DE SALUD (KPIs)',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.7, color: KeepiColors.slate),
            ),
            const SizedBox(width: 8),
            Expanded(child: Container(height: 1, color: KeepiColors.slate.withOpacity(0.12))),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildCard(Icons.monitor_weight_outlined, 'PESO', '$weight kg', KeepiColors.orange),
              _buildCard(Icons.height, 'ESTATURA', '$height m', KeepiColors.skyBlue),
              _buildCard(Icons.favorite_border, 'IMC', bmi, const Color(0xFF7C3AED)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCard(IconData icon, String label, String value, Color color) {
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: KeepiColors.slateLight, letterSpacing: 1.2)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: KeepiColors.slate)),
        ],
      ),
    );
  }
}