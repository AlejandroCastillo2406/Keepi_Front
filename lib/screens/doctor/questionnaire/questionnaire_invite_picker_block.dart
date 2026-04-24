import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../models/questionnaire_models.dart';

/// Selector de plantillas y preguntas globales para armar un envío por link (invitación).
class QuestionnaireInvitePickerBlock extends StatelessWidget {
  const QuestionnaireInvitePickerBlock({
    super.key,
    required this.loading,
    required this.error,
    required this.templates,
    required this.globalQuestions,
    required this.selectedTemplateIds,
    required this.selectedQuestionIds,
    required this.onRetry,
    required this.onToggleTemplate,
    required this.onToggleQuestion,
    this.title = 'Cuestionario por link',
    this.description =
        'Selecciona plantillas y/o preguntas globales para incluir en el link que recibirá el paciente por correo.',
  });

  final bool loading;
  final String? error;
  final List<TemplateSummary> templates;
  final List<Question> globalQuestions;
  final Set<String> selectedTemplateIds;
  final Set<String> selectedQuestionIds;
  final VoidCallback onRetry;
  final void Function(String id, bool value) onToggleTemplate;
  final void Function(String id, bool value) onToggleQuestion;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, color: KeepiColors.slate),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(fontSize: 12.5, color: KeepiColors.slateLight),
          ),
          const SizedBox(height: 12),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(color: KeepiColors.orange),
              ),
            )
          else if (error != null)
            Row(
              children: [
                Expanded(child: Text(error!, style: const TextStyle(color: Colors.red))),
                TextButton(onPressed: onRetry, child: const Text('Reintentar')),
              ],
            )
          else ...[
            const Text('Plantillas', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            for (final t in templates)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(t.name),
                subtitle: Text('${t.totalQuestions} preguntas'),
                value: selectedTemplateIds.contains(t.id),
                onChanged: (v) => onToggleTemplate(t.id, v ?? false),
              ),
            const SizedBox(height: 8),
            const Text('Preguntas adicionales', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            for (final q in globalQuestions)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(q.text, maxLines: 2, overflow: TextOverflow.ellipsis),
                value: selectedQuestionIds.contains(q.id),
                onChanged: (v) => onToggleQuestion(q.id, v ?? false),
              ),
            const SizedBox(height: 10),
            Text(
              'El enlace del correo vence a las 24 horas.',
              style: TextStyle(fontSize: 12, color: KeepiColors.slateLight.withValues(alpha: 0.95)),
            ),
          ],
        ],
      ),
    );
  }
}
