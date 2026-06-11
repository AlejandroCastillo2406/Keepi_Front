import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// Colores del avatar/etiqueta según sexo del paciente.
class PatientAvatarTheme {
  const PatientAvatarTheme({
    required this.accent,
    required this.soft,
  });

  final Color accent;
  final Color soft;

  static PatientAvatarTheme fromSex(String? sex) {
    final normalized = (sex ?? '').trim().toLowerCase();
    final isFemale = normalized.contains('fem') || normalized == 'f';
    if (isFemale) {
      return const PatientAvatarTheme(
        accent: KeepiColors.patientPink,
        soft: KeepiColors.patientPinkSoft,
      );
    }
    return const PatientAvatarTheme(
      accent: KeepiColors.skyBlue,
      soft: KeepiColors.skyBlueSoft,
    );
  }
}

class ConsultationPatientHeader extends StatelessWidget {
  const ConsultationPatientHeader({
    super.key,
    required this.name,
    required this.email,
    this.sex,
    this.ageYears,
    this.bloodType,
    this.weightKg,
    this.subtitle,
    this.onEditAge,
    this.onEditBloodType,
    this.onEditWeight,
    this.onEditProfile,
    this.onExport,
    this.exporting = false,
  });

  final String name;
  final String email;
  final String? sex;
  final int? ageYears;
  final String? bloodType;
  final double? weightKg;
  final String? subtitle;
  final VoidCallback? onEditAge;
  final VoidCallback? onEditBloodType;
  final VoidCallback? onEditWeight;
  final VoidCallback? onEditProfile;
  final VoidCallback? onExport;
  final bool exporting;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final theme = PatientAvatarTheme.fromSex(sex);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: theme.soft,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.accent, width: 1.8),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: TextStyle(
                    color: theme.accent,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: KeepiColors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PACIENTE',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: theme.accent,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: KeepiColors.slate,
                    letterSpacing: -0.3,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.8,
                      color: KeepiColors.slateLight,
                    ),
                  ),
                ],
                if ((subtitle ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: KeepiColors.slateLight,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                IntrinsicHeight(
                  child: Row(
                    children: [
                      _MetricChip(
                        label: 'EDAD',
                        value: ageYears != null ? '$ageYears años' : '—',
                        onTap: onEditAge,
                      ),
                      const _HeaderDivider(),
                      _MetricChip(
                        label: 'SANGRE',
                        value: (bloodType ?? '').isEmpty ? '—' : bloodType!,
                        onTap: onEditBloodType,
                      ),
                      const _HeaderDivider(),
                      _MetricChip(
                        label: 'PESO',
                        value: weightKg != null
                            ? '${weightKg!.toStringAsFixed(weightKg! % 1 == 0 ? 0 : 1)} kg'
                            : '—',
                        onTap: onEditWeight,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (onEditProfile != null && onExport != null) ...[
            const SizedBox(width: 16),
            DoctorPatientHeaderActions(
              onEditProfile: onEditProfile!,
              onExport: onExport!,
              exporting: exporting,
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderDivider extends StatelessWidget {
  const _HeaderDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      color: KeepiColors.cardBorder,
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final empty = value == '—';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.3,
                color: KeepiColors.slateLight,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: empty ? KeepiColors.slateLight : KeepiColors.slate,
                  ),
                ),
                if (empty && onTap != null) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.edit_outlined,
                    size: 13,
                    color: KeepiColors.orange,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class DoctorPatientStatsGrid extends StatelessWidget {
  const DoctorPatientStatsGrid({
    super.key,
    required this.totalAnalysis,
    required this.uploadedAnalysis,
    required this.pendingAnalysis,
    required this.timelineEvents,
  });

  final int totalAnalysis;
  final int uploadedAnalysis;
  final int pendingAnalysis;
  final int timelineEvents;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatGridCard(
                value: totalAnalysis,
                label: 'SOLICITADOS',
                valueColor: KeepiColors.skyBlue,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatGridCard(
                value: uploadedAnalysis,
                label: 'SUBIDOS',
                valueColor: KeepiColors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatGridCard(
                value: pendingAnalysis,
                label: 'PENDIENTES',
                valueColor: const Color(0xFFDC2626),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatGridCard(
                value: timelineEvents,
                label: 'EVENTOS',
                valueColor: KeepiColors.slate,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatGridCard extends StatelessWidget {
  const _StatGridCard({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  final int value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value.toString().padLeft(2, '0'),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: valueColor,
              height: 1,
              letterSpacing: -0.8,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.3,
              color: KeepiColors.slateLight,
            ),
          ),
        ],
      ),
    );
  }
}

class DoctorPatientHeaderActions extends StatelessWidget {
  const DoctorPatientHeaderActions({
    super.key,
    required this.onEditProfile,
    required this.onExport,
    this.exporting = false,
  });

  final VoidCallback onEditProfile;
  final VoidCallback onExport;
  final bool exporting;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 168,
          child: FilledButton.icon(
            onPressed: onEditProfile,
            style: FilledButton.styleFrom(
              backgroundColor: KeepiColors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text(
              'Editar Perfil',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 168,
          child: OutlinedButton.icon(
            onPressed: exporting ? null : onExport,
            style: OutlinedButton.styleFrom(
              foregroundColor: KeepiColors.slate,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              side: const BorderSide(color: KeepiColors.cardBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_rounded, size: 18),
            label: Text(
              exporting ? 'Exportando…' : 'Exportar',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            ),
          ),
        ),
      ],
    );
  }
}

class DoctorWebQuickActionsRow extends StatelessWidget {
  const DoctorWebQuickActionsRow({
    super.key,
    required this.hasPendingUpload,
    required this.onOpenTimeline,
    required this.onOpenRequestAnalysis,
    required this.onOpenUpload,
    required this.onOpenAssignPrescription,
    required this.onOpenSchedule,
    required this.onOpenQuestionnaire,
  });

  final bool hasPendingUpload;
  final VoidCallback onOpenTimeline;
  final VoidCallback onOpenRequestAnalysis;
  final VoidCallback? onOpenUpload;
  final VoidCallback onOpenAssignPrescription;
  final VoidCallback onOpenSchedule;
  final VoidCallback onOpenQuestionnaire;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      _WebQuickActionTile(
        icon: Icons.history_rounded,
        label: 'Ver historial',
        accent: KeepiColors.slate,
        onTap: onOpenTimeline,
      ),
      _WebQuickActionTile(
        icon: Icons.biotech_outlined,
        label: 'Solicitar análisis',
        accent: KeepiColors.orange,
        onTap: onOpenRequestAnalysis,
      ),
      _WebQuickActionTile(
        icon: Icons.upload_file_rounded,
        label: 'Subir reporte',
        accent: const Color(0xFFD97706),
        onTap: onOpenUpload,
        enabled: hasPendingUpload,
      ),
      _WebQuickActionTile(
        icon: Icons.medication_outlined,
        label: 'Asignar receta',
        accent: const Color(0xFF7C3AED),
        onTap: onOpenAssignPrescription,
      ),
      _WebQuickActionTile(
        icon: Icons.event_available_outlined,
        label: 'Programar cita',
        accent: KeepiColors.skyBlue,
        onTap: onOpenSchedule,
      ),
      _WebQuickActionTile(
        icon: Icons.quiz_outlined,
        label: 'Enviar cuestionario',
        accent: KeepiColors.skyBlue,
        onTap: onOpenQuestionnaire,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return Row(
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: tiles[i]),
              ],
            ],
          );
        }
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: tiles
              .map(
                (tile) => SizedBox(
                  width: (constraints.maxWidth - 10) / 2,
                  child: tile,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _WebQuickActionTile extends StatelessWidget {
  const _WebQuickActionTile({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final opacity = enabled ? 1.0 : 0.45;
    return Opacity(
      opacity: opacity,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: KeepiColors.cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: accent, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: KeepiColors.slate,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DoctorPatientTabBar extends StatelessWidget {
  const DoctorPatientTabBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.accentColor = KeepiColors.orange,
    this.includeConsultationTab = false,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Color accentColor;
  /// Solo visible al abrir desde el dashboard (HOY) en [DoctorConsultationScreen].
  final bool includeConsultationTab;

  static const _baseLabels = [
    'Resumen',
    'Análisis',
    'Cuestionarios',
    'Historial',
  ];

  List<String> get _labels => includeConsultationTab
      ? [..._baseLabels, 'Consulta']
      : _baseLabels;

  @override
  Widget build(BuildContext context) {
    final labels = _labels;
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: KeepiColors.cardBorder),
        ),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final selected = index == selectedIndex;
          return Padding(
            padding: EdgeInsets.only(right: index == labels.length - 1 ? 0 : 28),
            child: InkWell(
              onTap: () => onSelected(index),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      labels[index],
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        color: selected
                            ? KeepiColors.slate
                            : KeepiColors.slateLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 3,
                      width: selected ? 56 : 0,
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class DoctorSectionTitle extends StatelessWidget {
  const DoctorSectionTitle({
    super.key,
    required this.tag,
    this.count,
  });

  final String tag;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          tag,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
            color: KeepiColors.slateLight,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 6),
          Text(
            '(${count!.toString().padLeft(2, '0')})',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: KeepiColors.slateLight,
            ),
          ),
        ],
      ],
    );
  }
}
