import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../models/questionnaire_models.dart';
import '../services/api_client.dart';
import '../services/notifications_service.dart';
import '../services/questionnaire_service.dart';
import 'notification_web_dialog.dart';

class QuestionnaireNotificationDetailData {
  const QuestionnaireNotificationDetailData({
    required this.patientName,
    required this.answeredAt,
    required this.questionnaireName,
    required this.responses,
    this.patientEmail,
  });

  final String patientName;
  final String? patientEmail;
  final DateTime? answeredAt;
  final String questionnaireName;
  final List<Map<String, dynamic>> responses;
}

String formatQuestionnaireAnswerText(dynamic raw) {
  var answer = (raw ?? 'Sin respuesta').toString();
  if (answer.contains('value:')) {
    answer = answer.replaceAll(RegExp(r'[{}]'), '').replaceAll('value:', '').trim();
  }
  return answer.isEmpty ? 'Sin respuesta' : answer;
}

String formatQuestionnaireDateTime(DateTime? dt) {
  if (dt == null) return '';
  final d = dt.day.toString().padLeft(2, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final y = dt.year;
  final h = dt.hour.toString().padLeft(2, '0');
  final min = dt.minute.toString().padLeft(2, '0');
  return '$d/$m/$y · $h:$min';
}

String _patientNameFromMessage(String message) {
  final trimmed = message.trim();
  final match = RegExp(r'^(.+?)\s+completó', caseSensitive: false).firstMatch(trimmed);
  if (match != null) {
    final name = match.group(1)?.trim();
    if (name != null && name.isNotEmpty) return name;
  }
  return '';
}

Future<QuestionnaireNotificationDetailData> loadQuestionnaireNotificationDetail({
  required ApiClient api,
  required AppNotificationDto notification,
}) async {
  final invitationId = notification.questionnaireInvitationId?.trim();
  final patientId = notification.patientIdFromPayload?.trim() ?? '';

  InvitationSummary? invitation;
  if (invitationId != null && invitationId.isNotEmpty) {
    try {
      invitation = await QuestionnaireService(api).getInvitationStatus(invitationId);
    } catch (_) {}
  }

  final effectivePatientId =
      (invitation?.patientId.trim().isNotEmpty == true ? invitation!.patientId : patientId);

  final responses = <Map<String, dynamic>>[];
  if (effectivePatientId.isNotEmpty) {
    final raw =
        await QuestionnaireService(api).fetchPatientResponses(effectivePatientId);
    final notifDate = DateTime.tryParse(notification.createdAt ?? '')?.toLocal();

    for (final row in raw) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(row);
      if (invitationId != null && invitationId.isNotEmpty) {
        if (map['invitation_id']?.toString() != invitationId) continue;
      } else if (notifDate != null) {
        final answeredAt =
            DateTime.tryParse((map['answered_at'] ?? '').toString())?.toLocal();
        if (answeredAt == null ||
            answeredAt.difference(notifDate).abs() > const Duration(hours: 24)) {
          continue;
        }
      }
      responses.add(map);
    }

    responses.sort((a, b) {
      final ad = DateTime.tryParse((a['answered_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bd = DateTime.tryParse((b['answered_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return ad.compareTo(bd);
    });
  }

  DateTime? answeredAt = invitation?.completedAt?.toLocal();
  if (answeredAt == null && responses.isNotEmpty) {
    answeredAt = DateTime.tryParse(
      (responses.last['answered_at'] ?? '').toString(),
    )?.toLocal();
  }
  answeredAt ??= DateTime.tryParse(notification.createdAt ?? '')?.toLocal();

  var questionnaireName = '';
  for (final row in responses) {
    final name = (row['questionnaire_name'] ?? '').toString().trim();
    if (name.isNotEmpty) {
      questionnaireName = name;
      break;
    }
  }
  if (questionnaireName.isEmpty) {
    questionnaireName = 'Cuestionario de salud';
  }

  final fromMessage = _patientNameFromMessage(notification.message);
  final patientName = invitation?.patientName.trim().isNotEmpty == true
      ? invitation!.patientName
      : (fromMessage.isNotEmpty ? fromMessage : 'Paciente');

  return QuestionnaireNotificationDetailData(
    patientName: patientName,
    patientEmail: invitation?.patientEmail,
    answeredAt: answeredAt,
    questionnaireName: questionnaireName,
    responses: responses,
  );
}

Future<void> showQuestionnaireNotificationDetailSheet(
  BuildContext context, {
  required AppNotificationDto notification,
}) {
  final theme = NotificationDialogTheme.questionnaire();

  return NotificationWebDialog.show(
    context,
    title: notification.title.isNotEmpty
        ? notification.title
        : theme.titleFallback,
    tag: theme.tag,
    accent: theme.accent,
    icon: theme.icon,
    maxWidth: 620,
    maxHeightFactor: 0.9,
    child: FutureBuilder<QuestionnaireNotificationDetailData>(
      future: loadQuestionnaireNotificationDetail(
        api: context.read<ApiClient>(),
        notification: notification,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: CircularProgressIndicator(color: KeepiColors.orange),
            ),
          );
        }

        if (snapshot.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'No se pudo cargar el cuestionario',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: KeepiColors.slate,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                notification.message,
                style: const TextStyle(color: KeepiColors.slateLight),
              ),
            ],
          );
        }

        final accent = theme.accent;
        final data = snapshot.data!;
        final answeredLabel = formatQuestionnaireDateTime(data.answeredAt);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NotificationInfoTile(
              icon: Icons.person_outline_rounded,
              label: 'Respondido por',
              value: data.patientName,
              accent: accent,
            ),
            if ((data.patientEmail ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              NotificationInfoTile(
                icon: Icons.email_outlined,
                label: 'Correo',
                value: data.patientEmail!.trim(),
                accent: accent,
              ),
            ],
            const SizedBox(height: 12),
            NotificationInfoTile(
              icon: Icons.event_outlined,
              label: 'Fecha y hora',
              value: answeredLabel.isNotEmpty ? answeredLabel : '—',
              accent: accent,
            ),
            const SizedBox(height: 12),
            NotificationInfoTile(
              icon: Icons.quiz_outlined,
              label: 'Cuestionario',
              value: data.questionnaireName,
              accent: accent,
            ),
            const SizedBox(height: 24),
            Text(
              data.responses.isEmpty
                  ? 'PREGUNTAS Y RESPUESTAS'
                  : 'PREGUNTAS Y RESPUESTAS (${data.responses.length})',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.3,
                color: KeepiColors.slateLight,
              ),
            ),
            const SizedBox(height: 12),
            if (data.responses.isEmpty)
              NotificationInfoTile(
                icon: Icons.info_outline_rounded,
                label: 'Sin respuestas',
                value: notification.message.isEmpty
                    ? 'No se encontraron respuestas para este cuestionario.'
                    : notification.message,
                accent: accent,
              )
            else
              ...data.responses.map((row) {
                final question =
                    (row['question_text'] ?? 'Pregunta').toString();
                final answer =
                    formatQuestionnaireAnswerText(row['answer_value']);
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
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
                        question,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: KeepiColors.slate,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        answer,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: accent.withValues(alpha: 0.95),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        );
      },
    ),
  );
}
