import 'package:flutter/material.dart';
import 'dart:ui' show FontFeature;

import '../core/app_theme.dart';
import '../models/timeline_event.dart';

/// Timeline estilo "dossier clínico-editorial":
/// - Sello de fecha al lado izquierdo (día / mes / hora en tabulares).
/// - Rail fino con marcador circular (icono del tipo + anillo del estado).
/// - Separadores por mes.
/// - Meta line con TAG · ESTADO en mayúsculas con tracking.
/// - Acento corto (barra) de color de evento bajo la meta.
/// - Byline con em-dash para el actor.
///
/// Pensado para NO verse "auto-generado" sino trabajado a detalle.
class PatientCareTimeline extends StatelessWidget {
  const PatientCareTimeline({
    super.key,
    required this.events,
    this.showSectionHeader = true,
    this.title = 'Historial y próximos pasos',
    this.subtitle,
  });

  final List<TimelineEvent> events;
  final bool showSectionHeader;
  final String title;
  final String? subtitle;

  static const _green = Color(0xFF15803D);
  static const _orange = Color(0xFFC2410C);
  static const _grey = Color(0xFF94A3B8);

  static const _monthsEs = <String>[
    'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
    'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC',
  ];

  Color _stateColor(String s) {
    switch (s) {
      case 'current':
        return _orange;
      case 'future':
        return _grey;
      default:
        return _green;
    }
  }

  Color _eventColor(String t) {
    switch (t) {
      case 'registration':
        return const Color(0xFF0F766E);
      case 'appointment':
        return KeepiColors.orange;
      case 'prescription':
        return const Color(0xFF7C3AED);
      case 'analysis_upload':
        return const Color(0xFF0284C7);
      case 'analysis':
      case 'analysis_request':
        return const Color(0xFF2563EB);
      default:
        return KeepiColors.slate;
    }
  }

  IconData _eventIcon(String t) {
    switch (t) {
      case 'registration':
        return Icons.verified_user_outlined;
      case 'appointment':
        return Icons.event_available_outlined;
      case 'prescription':
        return Icons.receipt_long_outlined;
      case 'analysis_upload':
        return Icons.attach_file_rounded;
      case 'analysis':
      case 'analysis_request':
        return Icons.biotech_outlined;
      default:
        return Icons.flag_outlined;
    }
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'registration':
        return 'CUENTA';
      case 'appointment':
        return 'CITA';
      case 'prescription':
        return 'RECETA';
      case 'analysis_upload':
        return 'ARCHIVO';
      case 'analysis':
      case 'analysis_request':
        return 'ANÁLISIS';
      default:
        return 'EVENTO';
    }
  }

  String _stateLabel(String s) {
    switch (s) {
      case 'current':
        return 'EN CURSO';
      case 'future':
        return 'PRÓXIMO';
      default:
        return 'COMPLETADO';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();

    final widgets = <Widget>[];
    for (var i = 0; i < events.length; i++) {
      final e = events[i];
      final dt = DateTime.tryParse(e.occurredAt) ?? DateTime.now();

      final prev = i > 0 ? (DateTime.tryParse(events[i - 1].occurredAt) ?? dt) : null;
      final next = i < events.length - 1 ? (DateTime.tryParse(events[i + 1].occurredAt) ?? dt) : null;

      final isFirstInMonth = prev == null || prev.month != dt.month || prev.year != dt.year;
      final isLastInMonth = next == null || next.month != dt.month || next.year != dt.year;

      if (isFirstInMonth) {
        widgets.add(_MonthDivider(
          label: '${_monthsEs[dt.month - 1]} · ${dt.year}',
          isFirst: i == 0,
        ));
      }

      widgets.add(_Entry(
        event: e,
        day: dt.day,
        monthAbbr: _monthsEs[dt.month - 1],
        isFirstInMonth: isFirstInMonth,
        isLastInMonth: isLastInMonth,
        stateColor: _stateColor(e.visualState),
        eventColor: _eventColor(e.eventType),
        icon: _eventIcon(e.eventType),
        typeLabel: _typeLabel(e.eventType),
        stateLabel: _stateLabel(e.visualState),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showSectionHeader) _Header(title: title, subtitle: subtitle, count: events.length),
        if (showSectionHeader) const SizedBox(height: 10),
        ...widgets,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// HEADER

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.count, this.subtitle});

  final String title;
  final int count;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 2,
              color: KeepiColors.slate,
            ),
            const SizedBox(width: 8),
            const Text(
              'HISTORIAL',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.0,
                color: KeepiColors.slate,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: KeepiColors.slate,
                  letterSpacing: -0.5,
                  height: 1.15,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  count.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: KeepiColors.slate,
                    height: 1,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  count == 1 ? 'EVENTO' : 'EVENTOS',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: KeepiColors.slateLight,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ],
        ),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: const TextStyle(fontSize: 12.5, color: KeepiColors.slateLight, height: 1.35),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// SEPARADOR DE MES

class _MonthDivider extends StatelessWidget {
  const _MonthDivider({required this.label, required this.isFirst});

  final String label;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 14 : 6, bottom: 10),
      child: Row(
        children: [
          // Alineación con el bloque del sello de fecha
          const SizedBox(width: 52),
          const SizedBox(width: 10),
          Container(
            width: 24,
            height: 1,
            color: KeepiColors.slate.withValues(alpha: 0.35),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
              color: KeepiColors.slate,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              color: KeepiColors.slate.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// ENTRADA INDIVIDUAL

class _Entry extends StatelessWidget {
  const _Entry({
    required this.event,
    required this.day,
    required this.monthAbbr,
    required this.isFirstInMonth,
    required this.isLastInMonth,
    required this.stateColor,
    required this.eventColor,
    required this.icon,
    required this.typeLabel,
    required this.stateLabel,
  });

  final TimelineEvent event;
  final int day;
  final String monthAbbr;
  final bool isFirstInMonth;
  final bool isLastInMonth;
  final Color stateColor;
  final Color eventColor;
  final IconData icon;
  final String typeLabel;
  final String stateLabel;

  String get _detail {
    final s = (event.subtitle ?? '').trim();
    final d = event.description.trim();
    if (s.isNotEmpty) return s;
    return d;
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final isCurrent = event.visualState == 'current';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Sello de fecha (DAY / MES / HORA) ──
          SizedBox(
            width: 52,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    day.toString().padLeft(2, '0'),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: KeepiColors.slate,
                      height: 1,
                      letterSpacing: -1.0,
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
                  if (event.time.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      event.time.trim(),
                      style: const TextStyle(
                        fontSize: 10,
                        color: KeepiColors.slateLight,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()],
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // ── Rail con marcador ──
          SizedBox(
            width: 34,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _RailPainter(
                      color: stateColor.withValues(alpha: 0.45),
                      skipTop: isFirstInMonth,
                      skipBottom: isLastInMonth,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: _Marker(
                    icon: icon,
                    ringColor: stateColor,
                    iconColor: eventColor,
                    isCurrent: isCurrent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // ── Contenido ──
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 2, bottom: isLastInMonth ? 18 : 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meta line: ● TIPO / ESTADO
                  Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(color: stateColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        typeLabel,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                          color: eventColor,
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
                      Text(
                        stateLabel,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: KeepiColors.slateLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 2,
                    width: 20,
                    decoration: BoxDecoration(
                      color: eventColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: KeepiColors.slate,
                      height: 1.25,
                      letterSpacing: -0.25,
                    ),
                  ),
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      style: const TextStyle(
                        fontSize: 13,
                        color: KeepiColors.slateLight,
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (event.actor.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 1,
                          color: KeepiColors.slate.withValues(alpha: 0.55),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            event.actor.trim(),
                            style: TextStyle(
                              fontSize: 12,
                              color: KeepiColors.slate.withValues(alpha: 0.85),
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// MARCADOR CIRCULAR (dot con icono + anillo de estado)

class _Marker extends StatelessWidget {
  const _Marker({
    required this.icon,
    required this.ringColor,
    required this.iconColor,
    required this.isCurrent,
  });

  final IconData icon;
  final Color ringColor;
  final Color iconColor;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: ringColor, width: 1.8),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: ringColor.withValues(alpha: 0.22),
                  blurRadius: 0,
                  spreadRadius: 3,
                ),
              ]
            : null,
      ),
      child: Icon(icon, size: 18, color: iconColor),
    );
  }
}

// ─────────────────────────────────────────────────────────
// PAINTER DEL RAIL (línea continua fina, se interrumpe en inicio/fin de mes)

class _RailPainter extends CustomPainter {
  _RailPainter({
    required this.color,
    required this.skipTop,
    required this.skipBottom,
  });

  final Color color;
  final bool skipTop;
  final bool skipBottom;

  // Debe coincidir con la geometría del Marker
  static const _markerTop = 2.0;
  static const _markerSize = 32.0;
  static const _centerY = _markerTop + _markerSize / 2; // 18
  static const _half = _markerSize / 2; // 16

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    if (!skipTop) {
      canvas.drawLine(Offset(cx, 0), Offset(cx, _centerY - _half), paint);
    }
    if (!skipBottom) {
      canvas.drawLine(Offset(cx, _centerY + _half), Offset(cx, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RailPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.skipTop != skipTop ||
        oldDelegate.skipBottom != skipBottom;
  }
}
