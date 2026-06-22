import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/attendance_kpi.dart';

class AttendanceKpiPanel extends StatelessWidget {
  const AttendanceKpiPanel({
    super.key,
    required this.kpi,
    this.compact = false,
    this.showTitle = true,
  });

  final AttendanceKpi kpi;
  final bool compact;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    if (!kpi.hasData) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(compact ? 12 : 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: KeepiColors.cardBorder),
        ),
        child: Text(
          'Sin citas pasadas con registro de asistencia.',
          style: TextStyle(
            fontSize: compact ? 12.5 : 13.5,
            color: KeepiColors.slateLight.withValues(alpha: 0.95),
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showTitle) ...[
            Text(
              'ASISTENCIA A CITAS',
              style: TextStyle(
                fontSize: compact ? 9.5 : 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: KeepiColors.slateLight.withValues(alpha: 0.95),
              ),
            ),
            SizedBox(height: compact ? 10 : 12),
          ],
          Row(
            children: [
              Expanded(
                child: _KpiCell(
                  value: kpi.attended,
                  label: 'ASISTIÓ',
                  percent: kpi.recorded > 0 ? kpi.attendedPercent : null,
                  color: KeepiColors.green,
                  compact: compact,
                ),
              ),
              SizedBox(width: compact ? 8 : 10),
              Expanded(
                child: _KpiCell(
                  value: kpi.noShow,
                  label: 'NO ASISTIÓ',
                  percent: kpi.recorded > 0 ? kpi.noShowPercent : null,
                  color: const Color(0xFFDC2626),
                  compact: compact,
                ),
              ),
              if (kpi.pendingMark > 0) ...[
                SizedBox(width: compact ? 8 : 10),
                Expanded(
                  child: _KpiCell(
                    value: kpi.pendingMark,
                    label: 'SIN MARCAR',
                    color: KeepiColors.orange,
                    compact: compact,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiCell extends StatelessWidget {
  const _KpiCell({
    required this.value,
    required this.label,
    required this.color,
    this.percent,
    this.compact = false,
  });

  final int value;
  final String label;
  final Color color;
  final double? percent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value.toString().padLeft(2, '0'),
            style: TextStyle(
              fontSize: compact ? 20 : 24,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1,
              letterSpacing: -0.6,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          SizedBox(height: compact ? 4 : 6),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 8.5 : 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: KeepiColors.slateLight,
            ),
          ),
          if (percent != null) ...[
            const SizedBox(height: 2),
            Text(
              formatAttendancePercent(percent!),
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w700,
                color: color.withValues(alpha: 0.9),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
