import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/care_event_style.dart';
import '../models/questionnaire_models.dart';
import '../services/api_client.dart';
import '../services/notifications_service.dart';
import '../services/questionnaire_service.dart';

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
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        initialChildSize: 0.82,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: KeepiColors.surfaceBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: FutureBuilder<QuestionnaireNotificationDetailData>(
            future: loadQuestionnaireNotificationDetail(
              api: sheetContext.read<ApiClient>(),
              notification: notification,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: KeepiColors.orange),
                );
              }

              if (snapshot.hasError) {
                return ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(24),
                  children: [
                    _sheetHandle(),
                    const SizedBox(height: 12),
                    const Text(
                      'No se pudo cargar el cuestionario',
                      style: TextStyle(
                        fontSize: 18,
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

              final accent = CareEventStyle.colorFor('questionnaire');
              final data = snapshot.data!;
              final answeredLabel = formatQuestionnaireDateTime(data.answeredAt);

              return ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                children: [
                  _sheetHandle(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.assignment_turned_in_outlined,
                          color: accent,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notification.title.isNotEmpty
                                  ? notification.title
                                  : 'Cuestionario completado',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: KeepiColors.slate,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'CUESTIONARIO COMPLETADO',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Divider(),
                  ),
                  _infoTile(
                    icon: Icons.person_outline_rounded,
                    label: 'Respondido por',
                    value: data.patientName,
                    accent: accent,
                  ),
                  if ((data.patientEmail ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _infoTile(
                      icon: Icons.email_outlined,
                      label: 'Correo',
                      value: data.patientEmail!.trim(),
                      accent: accent,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _infoTile(
                    icon: Icons.event_outlined,
                    label: 'Fecha y hora',
                    value: answeredLabel.isNotEmpty ? answeredLabel : '—',
                    accent: accent,
                  ),
                  const SizedBox(height: 12),
                  _infoTile(
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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: KeepiColors.cardBorder),
                      ),
                      child: Text(
                        notification.message.isEmpty
                            ? 'No se encontraron respuestas para este cuestionario.'
                            : notification.message,
                        style: const TextStyle(
                          fontSize: 14,
                          color: KeepiColors.slate,
                          height: 1.5,
                        ),
                      ),
                    )
                  else
                    ...data.responses.map((row) {
                      final question =
                          (row['question_text'] ?? 'Pregunta').toString();
                      final answer = formatQuestionnaireAnswerText(
                        row['answer_value'],
                      );
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
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: KeepiColors.slateLight,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accent,
                        side: BorderSide(color: accent),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cerrar',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}

Widget _sheetHandle() {
  return Center(
    child: Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

Widget _infoTile({
  required IconData icon,
  required String label,
  required String value,
  Color accent = KeepiColors.orange,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: KeepiColors.cardBorder),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: accent),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: KeepiColors.slateLight,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: KeepiColors.slate,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
