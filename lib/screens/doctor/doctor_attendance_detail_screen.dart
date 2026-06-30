import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/decorative_background.dart';
import '../../core/web_layout.dart';
import '../../router/app_paths.dart';
import '../../services/api_client.dart';
import '../../services/doctor_service.dart';
import '../../services/appointment_service.dart';

class DoctorAttendanceDetailScreen extends StatefulWidget {
  const DoctorAttendanceDetailScreen({
    super.key,
    required this.status,
    this.embedded = false,
    this.onBack,
  });

  final String status;
  final bool embedded;
  final VoidCallback? onBack;


  @override
  State<DoctorAttendanceDetailScreen> createState() =>
      _DoctorAttendanceDetailScreenState();
}

class _DoctorAttendanceDetailScreenState extends State<DoctorAttendanceDetailScreen> {
  final Set<String> _markingAttendanceIds = {};
  AttendanceDetailResponse? _data;
  bool _loading = true;
  String? _error;

  String get _status => _normalizeStatus(widget.status);

  @override
  void initState() {
    super.initState();
    _load();
  }

  static String _normalizeStatus(String value) {
    switch (value) {
      case 'attended':
      case 'no_show':
      case 'pending':
        return value;
      default:
        return 'pending';
    }
  }

  Future<void> _markAttendance(
  AttendanceDetailItem item,
  String status,
) async {
  if (_markingAttendanceIds.contains(item.appointmentId)) return;

  setState(() => _markingAttendanceIds.add(item.appointmentId));

  try {
    await AppointmentService(context.read<ApiClient>()).recordAttendance(
      appointmentId: item.appointmentId,
      status: status,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          status == 'attended'
              ? 'Asistencia confirmada'
              : 'Cita marcada como no asistida',
        ),
        backgroundColor:
            status == 'attended' ? KeepiColors.green : KeepiColors.slate,
      ),
    );

    await _load();
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppointmentService.messageFromDio(e)),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    if (mounted) {
      setState(() => _markingAttendanceIds.remove(item.appointmentId));
    }
  }
}

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await DoctorService(context.read<ApiClient>())
          .fetchDoctorAttendanceDetail(status: _status);

      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = DoctorService.messageFromDio(e);
        _loading = false;
      });
    }
  }

  void _back() {
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppPaths.doctorInicio);
    }
  }

  String get _title {
    switch (_status) {
      case 'attended':
        return 'Pacientes que asistieron';
      case 'no_show':
        return 'Pacientes que no asistieron';
      default:
        return 'Asistencia pendiente';
    }
  }

  String get _subtitle {
    switch (_status) {
      case 'attended':
        return 'Citas finalizadas con asistencia confirmada.';
      case 'no_show':
        return 'Citas marcadas como no asistidas.';
      default:
        return 'Citas que todavía no tienen asistencia registrada.';
    }
  }

  String get _tag {
    switch (_status) {
      case 'attended':
        return 'ASISTIÓ';
      case 'no_show':
        return 'NO ASISTIÓ';
      default:
        return 'PENDIENTE';
    }
  }

  Color get _accent {
    switch (_status) {
      case 'attended':
        return KeepiColors.green;
      case 'no_show':
        return KeepiColors.slate;
      default:
        return KeepiColors.orange;
    }
  }

  IconData get _icon {
    switch (_status) {
      case 'attended':
        return Icons.check_circle_outline_rounded;
      case 'no_show':
        return Icons.person_off_outlined;
      default:
        return Icons.pending_actions_rounded;
    }
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  String _dateLabel(DateTime? value) {
    if (value == null) return 'Sin fecha';
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }

  String _timeRange(AttendanceDetailItem item) {
    final start = item.appointmentDate;
    final end = item.endDate;
    if (start == null) return 'Sin hora';
    final s = '${_two(start.hour)}:${_two(start.minute)}';
    if (end == null) return s;
    return '$s - ${_two(end.hour)}:${_two(end.minute)}';
  }

  void _openConsultation(AttendanceDetailItem item) {
    if (item.appointmentId.isEmpty) return;
    context.push(
      AppPaths.doctorConsultation(
        item.appointmentId,
        patientId: item.patientId,
        name: item.patientName,
        email: item.patientEmail,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = RefreshIndicator(
      color: KeepiColors.orange,
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isWebWide(context) ? 28 : 20,
                isWebWide(context) ? 24 : 12,
                isWebWide(context) ? 28 : 20,
                24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AttendanceHeader(
                    title: _title,
                    subtitle: _subtitle,
                    total: _data?.total ?? 0,
                    tag: _tag,
                    accent: _accent,
                    icon: _icon,
                    onBack: _back,
                  ),
                  const SizedBox(height: 18),
                  if (_loading)
                    const _AttendanceLoading()
                  else if (_error != null)
                    _AttendanceError(message: _error!, onRetry: _load)
                  else if ((_data?.items ?? const []).isEmpty)
                    _AttendanceEmpty(accent: _accent, title: _title)
                  else
                    for (final item in _data!.items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _AttendanceDetailCard(
                            item: item,
                            tag: _tag,
                            accent: _accent,
                            icon: _icon,
                            dateLabel: _dateLabel(item.appointmentDate),
                            timeRange: _timeRange(item),
                            showAttendanceActions: _status == 'pending',
                            markingAttendance: _markingAttendanceIds.contains(item.appointmentId),
                            onTap: () => _openConsultation(item),
                            onMarkAttended: () => _markAttendance(item, 'attended'),
                            onMarkNoShow: () => _markAttendance(item, 'no_show'),
                            ),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    final body = SubtleDecorativeBackground(
      child: isWebWide(context)
          ? WebContentFrame(
              padding: EdgeInsets.zero,
              child: content,
            )
          : content,
    );

    if (widget.embedded) return body;

    return Scaffold(
      backgroundColor: KeepiColors.surfaceBg,
      body: SafeArea(child: body),
    );
  }
}

class _AttendanceHeader extends StatelessWidget {
  const _AttendanceHeader({
    required this.title,
    required this.subtitle,
    required this.total,
    required this.tag,
    required this.accent,
    required this.icon,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final int total;
  final String tag;
  final Color accent;
  final IconData icon;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isWebWide(context) ? 26 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: KeepiColors.slate.withValues(alpha: 0.07),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: KeepiColors.slateSoft,
                shape: BoxShape.circle,
                border: Border.all(color: KeepiColors.cardBorder),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: KeepiColors.slate,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              shape: BoxShape.circle,
              border: Border.all(color: accent.withValues(alpha: 0.32)),
            ),
            child: Icon(icon, color: accent, size: 25),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tag,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: KeepiColors.slate,
                    letterSpacing: -0.8,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: KeepiColors.slateLight,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                total.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: accent,
                  height: 1,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'TOTAL',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: KeepiColors.slateLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttendanceDetailCard extends StatelessWidget {
  const _AttendanceDetailCard({
    required this.item,
    required this.tag,
    required this.accent,
    required this.icon,
    required this.dateLabel,
    required this.timeRange,
    required this.onTap,
    this.showAttendanceActions = false,
    this.markingAttendance = false,
    this.onMarkAttended,
    this.onMarkNoShow,
  });

  final AttendanceDetailItem item;
  final String tag;
  final Color accent;
  final IconData icon;
  final String dateLabel;
  final String timeRange;
  final VoidCallback onTap;
  final bool showAttendanceActions;
  final bool markingAttendance;
  final VoidCallback? onMarkAttended;
  final VoidCallback? onMarkNoShow;

  @override
  Widget build(BuildContext context) {
    final initial = item.patientName.trim().isEmpty
        ? '?'
        : item.patientName.trim()[0].toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: showAttendanceActions
              ? KeepiColors.orange.withValues(alpha: 0.34)
              : KeepiColors.cardBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: KeepiColors.slate.withValues(alpha: 0.055),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(22),
                bottom: Radius.circular(showAttendanceActions ? 0 : 22),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 16, 16),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.09),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accent.withValues(alpha: 0.35),
                          width: 1.4,
                        ),
                      ),
                      child: Text(
                        initial,
                        style: TextStyle(
                          color: accent,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _MiniBadge(
                                label: tag,
                                color: accent,
                                icon: icon,
                              ),
                              _MiniBadge(
                                label: timeRange,
                                color: KeepiColors.skyBlue,
                                icon: Icons.schedule_rounded,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            item.patientName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w900,
                              color: KeepiColors.slate,
                              letterSpacing: -0.35,
                            ),
                          ),
                          if (item.patientEmail.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              item.patientEmail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: KeepiColors.slateLight,
                              ),
                            ),
                          ],
                          const SizedBox(height: 9),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 14,
                                color: KeepiColors.slateLight,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                dateLabel,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: KeepiColors.slate,
                                ),
                              ),
                            ],
                          ),
                          if (item.reason.trim().isNotEmpty) ...[
                            const SizedBox(height: 7),
                            Text(
                              item.reason.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: KeepiColors.slateLight,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: KeepiColors.slateLight,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (showAttendanceActions) ...[
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 18),
              color: KeepiColors.cardBorder,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              child: markingAttendance
                  ? const SizedBox(
                      height: 42,
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: KeepiColors.orange,
                          ),
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.fact_check_outlined,
                              size: 16,
                              color: KeepiColors.orange,
                            ),
                            SizedBox(width: 7),
                            Text(
                              'CONFIRMAR ASISTENCIA',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                                color: KeepiColors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _PremiumAttendanceButton(
                                icon: Icons.check_rounded,
                                label: 'Asistió',
                                color: KeepiColors.green,
                                filled: true,
                                onTap: onMarkAttended,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _PremiumAttendanceButton(
                                icon: Icons.person_off_outlined,
                                label: 'No asistió',
                                color: KeepiColors.slate,
                                filled: false,
                                onTap: onMarkNoShow,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PremiumAttendanceButton extends StatelessWidget {
  const _PremiumAttendanceButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = filled ? color : Colors.white;
    final fg = filled ? Colors.white : color;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withValues(alpha: filled ? 0.0 : 0.35),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: fg,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceLoading extends StatelessWidget {
  const _AttendanceLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 80),
      child: Center(
        child: CircularProgressIndicator(
          color: KeepiColors.orange,
          strokeWidth: 2.5,
        ),
      ),
    );
  }
}

class _AttendanceError extends StatelessWidget {
  const _AttendanceError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: KeepiColors.orange.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: KeepiColors.orange,
            size: 30,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: KeepiColors.slate,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

class _AttendanceEmpty extends StatelessWidget {
  const _AttendanceEmpty({
    required this.accent,
    required this.title,
  });

  final Color accent;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, color: accent, size: 34),
          const SizedBox(height: 12),
          Text(
            'Sin registros',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No hay citas en "$title" por ahora.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: KeepiColors.slateLight,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}