import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../core/app_theme.dart';
import '../models/clinical_intake_detail.dart';
import '../models/timeline_event.dart';
import '../services/api_client.dart';
import '../services/doctor_service.dart';
import '../services/prescription_service.dart';
import '../services/questionnaire_service.dart';
import '../widgets/doctor_event_note_section.dart';

class TimelineEventDetailSheet extends StatefulWidget {
  const TimelineEventDetailSheet({
    super.key,
    required this.patientId,
    required this.event,
    this.scrollController,
    this.onNoteSaved,
  });

  final String patientId;
  final TimelineEvent event;
  final ScrollController? scrollController;
  final VoidCallback? onNoteSaved;

  static Future<void> show(
    BuildContext context, {
    required String patientId,
    required TimelineEvent event,
    VoidCallback? onNoteSaved,
  }) {
    final isAppointment = event.eventType.toLowerCase() == 'appointment';
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: isAppointment ? 0.85 : 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => TimelineEventDetailSheet(
          patientId: patientId,
          event: event,
          onNoteSaved: onNoteSaved,
          scrollController: controller,
        ),
      ),
    );
  }

  @override
  State<TimelineEventDetailSheet> createState() =>
      _TimelineEventDetailSheetState();
}

class _TimelineEventDetailSheetState extends State<TimelineEventDetailSheet> {
  String? _openingDocumentId;

  void _openDocumentView(String url, String title) {
    if (url.isEmpty) return;
    
    // Obtenemos el token para autorizar la descarga del backend
    final api = context.read<ApiClient>();
    final token = api.accessToken;
    final headers = <String, String>{
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      'Accept': '*/*',
    };

    bool isPdf = url.toLowerCase().contains('.pdf');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: KeepiColors.surfaceBg,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 1,
            title: Text(title, style: const TextStyle(color: KeepiColors.slate, fontSize: 16), overflow: TextOverflow.ellipsis),
            iconTheme: const IconThemeData(color: KeepiColors.slate),
          ),
          body: isPdf 
              ? SfPdfViewer.network(url, headers: headers)
              : InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: Center(child: Image.network(url, headers: headers)),
                ),
        ),
      ),
    );
  }

  // ==========================================
  // APERTURA EXTERNA (PARA RECETAS EN S3)
  // ==========================================
  Future<void> _openScanFromTimeline(String rawId) async {
    if (rawId.isEmpty) return;
    final svc = PrescriptionService(context.read<ApiClient>());
    try {
      String cleanId = rawId.replaceAll(RegExp(r'^pres_'), '').trim();
      final url = await svc.getScanUrl(cleanId);
      
      if (url.isNotEmpty) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          // RESTAURADO A SU VERSIÓN ORIGINAL
          await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se puede abrir el archivo.')));
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Esta receta no tiene un archivo adjunto.')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(PrescriptionService.messageFromDio(e))));
    }
  }

  String _getEventLabel(String eventType) {
    switch (eventType.toLowerCase()) {
      case 'registration': return 'Registro';
      case 'appointment': return 'Cita Médica';
      case 'prescription': return 'Receta Médica';
      case 'analysis': return 'Análisis Clínico';
      case 'analysis_request': return 'Solicitud de Análisis';
      case 'analysis_upload': return 'Estudio Subido';
      case 'questionnaire': return 'Cuestionario';
      case 'clinical_intake': return 'Antecedentes';
      case 'prior_documents': return 'Documentos previos';
      default: return eventType;
    }
  }

  Widget _buildDetailContent(BuildContext context) {
    final event = widget.event;
    bool isAppointment = event.eventType.toLowerCase() == 'appointment';
    bool isQuestionnaire = event.eventType.toLowerCase() == 'questionnaire';
    bool isClinicalIntake = event.eventType.toLowerCase() == 'clinical_intake';
    bool isAnalysis = event.eventType.toLowerCase().contains('analysis');
    
    Color eventColor;
    IconData eventIcon;

    switch (event.eventType.toLowerCase()) {
      case 'appointment':
        eventColor = KeepiColors.orange;
        eventIcon = Icons.event_note_rounded;
        break;
      case 'analysis':
      case 'analysis_request':
        eventColor = const Color(0xFF2563EB);
        eventIcon = Icons.biotech_outlined;
        break;
      case 'analysis_upload':
        eventColor = const Color(0xFF0F766E);
        eventIcon = Icons.file_present_rounded;
        break;
      case 'prescription':
        eventColor = const Color(0xFF7C3AED);
        eventIcon = Icons.receipt_long_outlined;
        break;
      case 'questionnaire':
        eventColor = KeepiColors.orange;
        eventIcon = Icons.quiz_outlined;
        break;
      case 'clinical_intake':
        eventColor = const Color(0xFF059669);
        eventIcon = Icons.assignment_turned_in_outlined;
        break;
      default:
        eventColor = KeepiColors.slate;
        eventIcon = Icons.flag_outlined;
    }

    return Container(
            decoration: const BoxDecoration(
              color: KeepiColors.surfaceBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.all(24),
              children: [
                Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                
                if (isAppointment)
                  _buildAppointmentDetailCard(event)
                else ...[
                  Row(
                    children: [
                      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: eventColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)), child: Icon(eventIcon, color: eventColor, size: 28)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(event.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: KeepiColors.slate)),
                            Text(_getEventLabel(event.eventType).toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: eventColor, letterSpacing: 1.2)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider()),

                  _buildProfessionalCalendarCard(event.occurredAt, eventColor),
                  const SizedBox(height: 16),
                  
                  _buildInfoCard([
                    _buildRow(Icons.info_outline_rounded, "Estado:", "Registrado en el historial"),
                  ]),
                  
                  // Botón S3 genérico para eventos distintos
                  if (event.s3Url != null && event.s3Url!.isNotEmpty && event.eventType.toLowerCase() != 'prescription' && !isAnalysis) ...[
                    const SizedBox(height: 16),
                    _buildS3DownloadButton(event.s3Url!),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  if (event.eventType.toLowerCase() == 'prescription')
                    _buildPremiumPrescriptionCard(event) 
                  else if (isClinicalIntake)
                    _buildClinicalIntakeDetailCard(event)
                  else if (isQuestionnaire)
                    _buildQuestionnaireDetailCard(event) 
                  else if (isAnalysis)
                    _buildAnalysisDetailCard(event)
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Detalles:", style: TextStyle(fontWeight: FontWeight.bold, color: KeepiColors.slate, fontSize: 16)),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16), 
                            border: Border.all(color: Colors.grey.shade200)
                          ),
                          child: Text(
                            (event.description == null || event.description!.isEmpty) 
                                ? "Sin contenido registrado." 
                                : event.description!, 
                            style: const TextStyle(fontSize: 14, color: KeepiColors.slate, height: 1.6, fontWeight: FontWeight.w500)
                          ),
                        ),
                      ],
                    ),
                ],
                if (!isAppointment)
                  DoctorEventNoteSection(
                    patientId: widget.patientId,
                    event: event,
                    onNoteSaved: widget.onNoteSaved,
                  ),
              ],
            ),
          );
  }

  // =======================================================================
  // DISEÑO INTELIGENTE PARA ANÁLISIS
  // =======================================================================
  Widget _buildAnalysisDetailCard(TimelineEvent event) {
    return FutureBuilder<List<dynamic>>(
      future: DoctorService(context.read<ApiClient>()).fetchPatientAnalysisRequests(widget.patientId).catchError((e) => []),
      builder: (context, snapshot) {
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(color: KeepiColors.orange)),
          );
        }

        dynamic matchedRequest;
        final targetId = (event.id ?? '').replaceAll(RegExp(r'^(ana_|req_)'), '').trim();
        final eventDesc = (event.description ?? '').trim().toLowerCase();

        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          for (var r in snapshot.data!) {
            String rId = '';
            try { rId = r.id.toString().replaceAll(RegExp(r'^(ana_|req_)'), '').trim(); } catch(e){}
            
            if (rId == targetId && targetId.isNotEmpty) {
              matchedRequest = r;
              break;
            }
            
            String rDesc = '';
            try { rDesc = (r.description ?? '').toString().trim().toLowerCase(); } catch(e){}
            if (rDesc.isNotEmpty && rDesc == eventDesc) {
              matchedRequest = r;
            }
          }
        }

        bool isCompleted = false;
        bool hasDocument = false;
        String docId = '';
        String completedAtStr = '';
        String description = event.description ?? event.title;

        if (matchedRequest != null) {
           try { isCompleted = matchedRequest.status.toString().toLowerCase() == 'completed'; } catch(e) {}
           try { docId = matchedRequest.documentId?.toString() ?? ''; } catch(e) {}
           try { hasDocument = docId.isNotEmpty; } catch(e) {}
           try { completedAtStr = matchedRequest.completedAt?.toString() ?? ''; } catch(e) {}
           try { description = matchedRequest.description?.toString() ?? description; } catch(e) {}
        }

        bool eventHasFile = event.s3Url != null && event.s3Url!.isNotEmpty;

        // LEYENDA SI NO ESTÁ COMPLETADO Y NO TIENE ARCHIVO
        if (!isCompleted && !hasDocument && !eventHasFile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Detalles del análisis:", style: TextStyle(fontWeight: FontWeight.bold, color: KeepiColors.slate, fontSize: 16)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: KeepiColors.slate.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: KeepiColors.slate.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: KeepiColors.slateLight, size: 20),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Aún no hay resultados de análisis subidos para mostrar.",
                        style: TextStyle(color: KeepiColors.slateLight, fontSize: 13.5, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        if (completedAtStr.isEmpty) {
           DateTime dt = DateTime.tryParse(event.occurredAt) ?? DateTime.now();
           completedAtStr = "${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}T${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}:00Z";
        }
        final fallbackUrl = event.s3Url;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Documento adjunto:", style: TextStyle(fontWeight: FontWeight.bold, color: KeepiColors.slate, fontSize: 16)),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                setState(() => _openingDocumentId = event.id);
                try {
                  String urlToOpen = fallbackUrl ?? '';
                  if (docId.isNotEmpty) {
                     final svc = DoctorService(context.read<ApiClient>());
                     urlToOpen = svc.getMobileDocumentUrl(docId);
                  }
                  if (urlToOpen.isNotEmpty) {
                     _openDocumentView(urlToOpen, "Archivo de análisis");
                  } else {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se encontró el archivo adjunto.')));
                  }
                } catch(e) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al abrir el documento.')));
                } finally {
                   if (mounted) setState(() => _openingDocumentId = null);
                }
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: KeepiColors.cardBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: KeepiColors.skyBlueSoft,
                        shape: BoxShape.circle,
                        border: Border.all(color: KeepiColors.skyBlue, width: 1.4),
                      ),
                      child: const Icon(
                        Icons.biotech_outlined,
                        size: 18,
                        color: KeepiColors.skyBlue,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ANÁLISIS COMPLETADO',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.3,
                              color: KeepiColors.skyBlue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: KeepiColors.slate,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Completado: $completedAtStr',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: KeepiColors.slateLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _openingDocumentId == event.id
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: KeepiColors.orange,
                            ),
                          )
                        : const Icon(
                            Icons.open_in_new_rounded,
                            size: 18,
                            color: KeepiColors.slateLight,
                          ),
                  ],
                ),
              ),
            ),
          ],
        );
      }
    );
  }

  // =======================================================================
  // FICHA CLÍNICA (ANTECEDENTES)
  // =======================================================================
  Widget _buildClinicalIntakeDetailCard(TimelineEvent event) {
    final invitationId = event.clinicalIntakeInvitationId;
    if (invitationId == null || invitationId.isEmpty) {
      return const Text(
        'No se pudo cargar la ficha clínica de este evento.',
        style: TextStyle(color: KeepiColors.slateLight),
      );
    }

    return FutureBuilder<ClinicalIntakeDetail>(
      future: DoctorService(context.read<ApiClient>())
          .fetchClinicalIntakeDetail(
            patientId: widget.patientId,
            invitationId: invitationId,
          )
          .catchError((_) => ClinicalIntakeDetail(
                invitationId: invitationId,
                patientId: widget.patientId,
                sections: const [],
              )),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(color: KeepiColors.orange),
            ),
          );
        }
        final detail = snapshot.data;
        if (detail == null || detail.sections.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Text(
              'Sin respuestas registradas en la ficha.',
              style: TextStyle(color: KeepiColors.slateLight),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Respuestas de la ficha',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: KeepiColors.slate,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            ...detail.sections.map((section) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: KeepiColors.slate,
                          fontSize: 15,
                        ),
                      ),
                      if (section.subtitle != null &&
                          section.subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          section.subtitle!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: KeepiColors.slateLight,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      ...section.fields.map(
                        (f) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                f.label,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: KeepiColors.slateLight,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                f.value,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: KeepiColors.slate,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  // =======================================================================
  // DISEÑO PARA CUESTIONARIOS
  // =======================================================================
  Widget _buildQuestionnaireDetailCard(TimelineEvent event) {
    return FutureBuilder<List<dynamic>>(
      future: QuestionnaireService(context.read<ApiClient>()).fetchPatientResponses(widget.patientId).catchError((e) => []),
      builder: (context, snapshot) {
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(color: KeepiColors.orange)),
          );
        }

        List<Map<String, dynamic>> matchingResponses = [];
        
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final eventDate = DateTime.tryParse(event.occurredAt)?.toLocal();
          
          if (eventDate != null) {
            for (var r in snapshot.data!) {
              if (r is Map) {
                final answeredAt = DateTime.tryParse((r['answered_at'] ?? '').toString())?.toLocal();
                if (answeredAt != null && answeredAt.difference(eventDate).abs() < const Duration(minutes: 15)) {
                  matchingResponses.add(Map<String, dynamic>.from(r));
                }
              }
            }
          }
        }

        if (matchingResponses.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Detalles del cuestionario:", style: TextStyle(fontWeight: FontWeight.bold, color: KeepiColors.slate, fontSize: 16)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16), 
                  border: Border.all(color: Colors.grey.shade200)
                ),
                child: Text(
                  (event.description == null || event.description!.isEmpty) 
                      ? "Sin contenido registrado o respuestas no encontradas." 
                      : event.description!, 
                  style: const TextStyle(fontSize: 14, color: KeepiColors.slate, height: 1.6, fontWeight: FontWeight.w500)
                ),
              ),
            ],
          );
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
            ]
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(color: KeepiColors.orange.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.quiz_outlined, color: KeepiColors.orange, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("RESPUESTAS GUARDADAS", style: TextStyle(color: KeepiColors.orange, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                        const SizedBox(height: 4),
                        Text("${matchingResponses.length} preguntas respondidas", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: KeepiColors.slate)),
                      ],
                    ),
                  )
                ],
              ),
              const SizedBox(height: 24),
              ...matchingResponses.map((data) {
                final question = (data['question_text'] ?? 'Pregunta').toString();
                
                String answer = (data['answer_value'] ?? 'Sin respuesta').toString();
                if (answer.contains('value:')) {
                  answer = answer.replaceAll(RegExp(r'[{}]'), '').replaceAll('value:', '').trim();
                }

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: KeepiColors.surfaceBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(question, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: KeepiColors.slate)),
                      const SizedBox(height: 6),
                      Text(answer, style: const TextStyle(fontSize: 13.5, color: KeepiColors.slateLight, height: 1.4)),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      }
    );
  }

  // =======================================================================
  // DISEÑO PARA CITA
  // =======================================================================
  Widget _buildAppointmentDetailCard(TimelineEvent event) {
    DateTime dt = DateTime.now();
    try {
      dt = DateTime.parse(event.occurredAt);
    } catch (e) {}

    String day = dt.day.toString().padLeft(2, '0');
    String monthStr = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'][dt.month - 1];
    int hour = dt.hour;
    String ampm = hour >= 12 ? 'PM' : 'AM';
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;
    String hourStr = hour.toString().padLeft(2, '0');
    String minStr = dt.minute.toString().padLeft(2, '0');
    String formattedDate = "$day $monthStr ${dt.year} - $hourStr:$minStr $ampm";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
            ]
          ),
          child: Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(color: KeepiColors.orange.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.event_available_rounded, color: KeepiColors.orange, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: KeepiColors.slate)),
                    const SizedBox(height: 4),
                    Text(formattedDate, style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 28),
        const Text("Fecha agendada:", style: TextStyle(fontWeight: FontWeight.bold, color: KeepiColors.slate, fontSize: 16)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2))
            ]
          ),
          child: IgnorePointer(
            child: Theme(
              data: ThemeData.light().copyWith(
                colorScheme: const ColorScheme.light(
                  primary: KeepiColors.orange,
                  onPrimary: Colors.white,
                  onSurface: KeepiColors.slate,
                ),
              ),
              child: CalendarDatePicker(
                initialDate: dt,
                firstDate: dt.subtract(const Duration(days: 365)),
                lastDate: dt.add(const Duration(days: 365)),
                onDateChanged: (val) {},
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        DoctorEventNoteSection(
          patientId: widget.patientId,
          event: event,
          onNoteSaved: widget.onNoteSaved,
          embeddedInAppointment: true,
        ),
      ],
    );
  }

  // =======================================================================
  // DISEÑO PREMIUM DE LA RECETA
  // =======================================================================
  Widget _buildPremiumPrescriptionCard(TimelineEvent event) {
    return FutureBuilder<List<dynamic>>(
      future: PrescriptionService(context.read<ApiClient>()).fetchMine().catchError((e) => []),
      builder: (context, snapshot) {
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED))),
          );
        }

        String doctorName = "Médico Tratante";
        String fileName = "receta_clinica.pdf";
        List<dynamic> itemsToDisplay = [];

        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final list = snapshot.data!;
          final targetId = (event.id ?? '').replaceAll(RegExp(r'^pres_'), '').trim();
          
          for (var p in list) {
            if (p.id.toString().replaceAll(RegExp(r'^pres_'), '').trim() == targetId) {
              doctorName = p.doctorName ?? doctorName;
              fileName = p.sourceFileName ?? fileName;
              itemsToDisplay = p.items ?? [];
              break;
            }
          }
        }

        if (itemsToDisplay.isEmpty) {
          if (event.description != null && event.description!.isNotEmpty) {
            itemsToDisplay = event.description!.split('\n').where((e) => e.trim().isNotEmpty).toList();
          } else {
            itemsToDisplay = ["Receta registrada en el historial"];
          }
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
            ]
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF7C3AED), width: 1.5)),
                    child: const Icon(Icons.receipt_long_outlined, color: Color(0xFF7C3AED), size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF7C3AED))),
                            const SizedBox(width: 8),
                            const Text("RECETA · REGISTRADA", style: TextStyle(color: Color(0xFF7C3AED), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                          ],
                        ),
                        Container(margin: const EdgeInsets.symmetric(vertical: 6), width: 24, height: 2, color: const Color(0xFF7C3AED)),
                        Text(doctorName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: KeepiColors.slate)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.description_outlined, size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 6),
                            Expanded(child: Text(fileName, style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                          ],
                        )
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(width: 20, height: 1, color: Colors.grey.shade300),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text("${itemsToDisplay.length.toString().padLeft(2, '0')} MEDICAMENTOS", style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ),
                  Expanded(child: Container(height: 1, color: Colors.grey.shade300)),
                ],
              ),
              const SizedBox(height: 20),
              ...itemsToDisplay.map((item) {
                String medName = "DESCONOCIDO";
                String subtitle = "Indicación registrada en consulta";

                if (item is String) {
                  medName = item.trim().toUpperCase();
                } else {
                  try {
                    medName = item.medication?.toString().toUpperCase() ?? "DESCONOCIDO";
                    String hours = item.everyHours?.toString() ?? "-";
                    String days = item.durationDays?.toString() ?? "-";
                    subtitle = "cada ${hours}h · $days días · Oral";
                  } catch(e) {}
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6, right: 12),
                        child: Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF7C3AED))),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(medName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: KeepiColors.slate)),
                            const SizedBox(height: 2),
                            Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openScanFromTimeline(event.id ?? ''), 
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4B5563), 
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.file_present_rounded, size: 20),
                  label: const Text("VER DOCUMENTO", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              )
            ],
          ),
        );
      }
    );
  }

  Widget _buildProfessionalCalendarCard(String dateStr, Color color) {
    String day = "??";
    String monthYear = "---";
    String time = "--:--";
    try {
      DateTime dt = DateTime.parse(dateStr);
      day = dt.day.toString();
      monthYear = "${['ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'][dt.month - 1]} ${dt.year}";
      time = "${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}";
    } catch (e) {}

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.5))),
            child: Column(children: [Text(monthYear, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)), Text(day, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color))]),
          ),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Fecha y Hora", style: TextStyle(fontSize: 12, color: KeepiColors.slateLight)), Text("$monthYear $day · $time", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: KeepiColors.slate))])
        ],
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(children: children),
    );
  }

  Widget _buildRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(children: [Icon(icon, size: 16, color: KeepiColors.slateLight), const SizedBox(width: 8), Text("$label ", style: const TextStyle(fontWeight: FontWeight.w600, color: KeepiColors.slateLight)), Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, color: KeepiColors.slate)))]),
    );
  }

  Widget _buildS3DownloadButton(String fileUrl) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          final Uri url = Uri.parse(fileUrl);
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          }
        },
        icon: const Icon(Icons.cloud_download_rounded),
        label: const Text("Ver documento original"),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF0F766E),
          side: const BorderSide(color: Color(0xFF0F766E)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return _buildDetailContent(context);
  }
}
