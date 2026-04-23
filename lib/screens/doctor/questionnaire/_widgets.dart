import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../models/questionnaire_models.dart';

/// Resolves un ícono para la especialidad según su slug/key.
IconData iconForSpecialty(String? key) {
  switch (key) {
    case 'stethoscope':
    case 'medicina-general':
      return Icons.medical_services_outlined;
    case 'favorite':
    case 'cardiologia':
      return Icons.favorite_border;
    case 'air':
    case 'neumologia':
      return Icons.air;
    case 'female':
    case 'ginecologia':
      return Icons.female_outlined;
    case 'monitor_heart':
    case 'endocrinologia':
      return Icons.monitor_heart_outlined;
    case 'psychology':
    case 'neurologia':
      return Icons.psychology_outlined;
    case 'visibility':
    case 'oftalmologia':
      return Icons.visibility_outlined;
    default:
      return Icons.category_outlined;
  }
}

/// Tarjeta de especialidad (lista principal).
class QSpecialtyTile extends StatelessWidget {
  const QSpecialtyTile({
    super.key,
    required this.specialty,
    this.onTap,
  });

  final Specialty specialty;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: KeepiColors.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: KeepiColors.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: KeepiColors.orangeSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  iconForSpecialty(specialty.icon ?? specialty.slug),
                  color: KeepiColors.orange,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      specialty.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      specialty.description ?? 'Preguntas base por especialidad',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: KeepiColors.slateLight,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _CountChip(
                          label:
                              '${specialty.totalActive} activas · ${specialty.totalQuestions}',
                          color: KeepiColors.skyBlue,
                          background: KeepiColors.skyBlueSoft,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: KeepiColors.slateLight),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.color, required this.background});
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

/// Fila de pregunta (en la vista por especialidad/globales).
class QQuestionRow extends StatelessWidget {
  const QQuestionRow({
    super.key,
    required this.question,
    required this.onToggle,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    this.compact = false,
  });

  final Question question;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCustom = question.isCustom && question.isMine;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: KeepiColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: question.isActive
              ? KeepiColors.cardBorder
              : KeepiColors.slateSoft,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 8),
            child: Icon(
              Icons.drag_indicator_rounded,
              size: 18,
              color: KeepiColors.slateLight.withOpacity(0.6),
            ),
          ),
          Container(
            width: 34,
            height: 34,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: question.isActive
                  ? KeepiColors.orangeSoft
                  : KeepiColors.slateSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              question.responseType.icon,
              size: 18,
              color: question.isActive
                  ? KeepiColors.orange
                  : KeepiColors.slateLight,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question.text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: question.isActive
                        ? KeepiColors.slate
                        : KeepiColors.slateLight,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _TagPill(
                      label: question.responseType.label,
                      color: KeepiColors.skyBlue,
                      background: KeepiColors.skyBlueSoft,
                    ),
                    _TagPill(
                      label: isCustom ? 'Propia' : 'Base',
                      color: isCustom ? KeepiColors.orange : KeepiColors.slate,
                      background: isCustom
                          ? KeepiColors.orangeSoft
                          : KeepiColors.slateSoft,
                    ),
                    if (question.isRequired)
                      const _TagPill(
                        label: 'Obligatoria',
                        color: KeepiColors.orange,
                        background: KeepiColors.orangeSoft,
                      ),
                    if (!question.showInHistory)
                      const _TagPill(
                        label: 'Sin historial',
                        color: KeepiColors.slateLight,
                        background: KeepiColors.slateSoft,
                      ),
                    if (question.specialtyName != null)
                      _TagPill(
                        label: question.specialtyName!,
                        color: KeepiColors.slate,
                        background: KeepiColors.slateSoft,
                      )
                    else
                      const _TagPill(
                        label: 'Global',
                        color: KeepiColors.slate,
                        background: KeepiColors.slateSoft,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Transform.scale(
            scale: 0.9,
            child: Switch(
              value: question.isActive,
              onChanged: onToggle,
              activeColor: KeepiColors.orange,
              activeTrackColor: KeepiColors.orangeLight,
            ),
          ),
          PopupMenuButton<_QAction>(
            tooltip: 'Más',
            icon: const Icon(Icons.more_vert_rounded, color: KeepiColors.slateLight),
            onSelected: (a) {
              switch (a) {
                case _QAction.edit:
                  onEdit();
                  break;
                case _QAction.duplicate:
                  onDuplicate();
                  break;
                case _QAction.delete:
                  onDelete();
                  break;
              }
            },
            itemBuilder: (_) => [
              if (isCustom)
                const PopupMenuItem(
                  value: _QAction.edit,
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18, color: KeepiColors.slate),
                      SizedBox(width: 10),
                      Text('Editar'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: _QAction.duplicate,
                child: Row(
                  children: [
                    Icon(Icons.copy_all_outlined, size: 18, color: KeepiColors.slate),
                    SizedBox(width: 10),
                    Text('Duplicar'),
                  ],
                ),
              ),
              if (isCustom)
                const PopupMenuItem(
                  value: _QAction.delete,
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFD32F2F)),
                      SizedBox(width: 10),
                      Text('Eliminar', style: TextStyle(color: Color(0xFFD32F2F))),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _QAction { edit, duplicate, delete }

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label, required this.color, required this.background});
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// Card para tipo de respuesta (selector en el editor).
class QResponseTypeCard extends StatelessWidget {
  const QResponseTypeCard({
    super.key,
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final QuestionResponseType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          decoration: BoxDecoration(
            color: selected ? KeepiColors.orangeSoft : KeepiColors.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? KeepiColors.orange : KeepiColors.cardBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                type.icon,
                size: 20,
                color: selected ? KeepiColors.orange : KeepiColors.slateLight,
              ),
              const SizedBox(height: 6),
              Text(
                type.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                  color: KeepiColors.slate,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  type.shortDescription,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    color: KeepiColors.slateLight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Preview estático del tipo de respuesta (editor).
class QAnswerPreview extends StatelessWidget {
  const QAnswerPreview({
    super.key,
    required this.type,
    required this.questionText,
    this.options = const [],
  });

  final QuestionResponseType type;
  final String questionText;
  final List<String> options;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KeepiColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vista previa',
            style: theme.textTheme.labelSmall?.copyWith(
              color: KeepiColors.slateLight,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            questionText.isEmpty ? 'Escribe tu pregunta…' : questionText,
            style: theme.textTheme.titleSmall?.copyWith(
              color: questionText.isEmpty
                  ? KeepiColors.slateLight
                  : KeepiColors.slate,
            ),
          ),
          const SizedBox(height: 10),
          _buildPreview(),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    switch (type) {
      case QuestionResponseType.singleChoice:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: options
              .take(5)
              .map(
                (o) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      const Icon(Icons.radio_button_unchecked,
                          size: 18, color: KeepiColors.slateLight),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          o,
                          style: const TextStyle(color: KeepiColors.slate),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      case QuestionResponseType.multiChoice:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: options
              .take(5)
              .map(
                (o) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      const Icon(Icons.check_box_outline_blank,
                          size: 18, color: KeepiColors.slateLight),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          o,
                          style: const TextStyle(color: KeepiColors.slate),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      case QuestionResponseType.yesNo:
        return Row(
          children: [
            Expanded(
              child: _previewButton('Sí', Icons.check_circle_outline),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _previewButton('No', Icons.highlight_off),
            ),
          ],
        );
      case QuestionResponseType.numeric:
        return const TextField(
          enabled: false,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Ingresa un valor',
            prefixIcon: Icon(Icons.pin_outlined),
          ),
        );
      case QuestionResponseType.shortText:
        return const TextField(
          enabled: false,
          decoration: InputDecoration(
            hintText: 'Respuesta corta',
          ),
        );
      case QuestionResponseType.longText:
        return const TextField(
          enabled: false,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Respuesta extendida…',
          ),
        );
    }
  }

  Widget _previewButton(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: KeepiColors.slateSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: KeepiColors.slate),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: KeepiColors.slate,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class QEmptyState extends StatelessWidget {
  const QEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: KeepiColors.orangeSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: KeepiColors.orange, size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: KeepiColors.slate,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.35,
              color: KeepiColors.slateLight,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Segmented status filter: Todas / Activas / Inactivas.
class QStatusFilter extends StatelessWidget {
  const QStatusFilter({
    super.key,
    required this.value,
    required this.onChanged,
    this.totalAll = 0,
    this.totalActive = 0,
    this.totalInactive = 0,
  });

  final QuestionStatusFilter value;
  final ValueChanged<QuestionStatusFilter> onChanged;
  final int totalAll;
  final int totalActive;
  final int totalInactive;

  @override
  Widget build(BuildContext context) {
    final items = [
      (QuestionStatusFilter.all, 'Todas', totalAll),
      (QuestionStatusFilter.active, 'Activas', totalActive),
      (QuestionStatusFilter.inactive, 'Inactivas', totalInactive),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: KeepiColors.slateSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: items.map((entry) {
          final selected = entry.$1 == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(entry.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? KeepiColors.cardBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: selected
                      ? Border.all(color: KeepiColors.orange.withOpacity(0.4))
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      entry.$2,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected ? KeepiColors.orange : KeepiColors.slateLight,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${entry.$3}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? KeepiColors.orange
                            : KeepiColors.slateLight.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
