import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

// Rutas de tu proyecto
import '../../core/app_theme.dart';
import '../../models/timeline_event.dart';
import '../../services/api_client.dart';
import '../../services/doctor_service.dart';
import '../../widgets/patient_care_timeline.dart';

class DoctorPatientTimelineScreen extends StatefulWidget {
  final String patientId;
  final String patientName;

  const DoctorPatientTimelineScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<DoctorPatientTimelineScreen> createState() => _DoctorPatientTimelineScreenState();
}

class _DoctorPatientTimelineScreenState extends State<DoctorPatientTimelineScreen> {
  List<TimelineEvent> _events = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTimeline();
  }

  Future<void> _loadTimeline() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final svc = DoctorService(context.read<ApiClient>());
      final events = await svc.fetchPatientTimeline(widget.patientId);
      
      if (!mounted) return;
      setState(() {
        _events = events;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = DoctorService.messageFromDio(e);
        _isLoading = false;
      });
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
      default: return eventType;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KeepiColors.surfaceBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Historial: ${widget.patientName}', 
          style: const TextStyle(color: KeepiColors.slate, fontWeight: FontWeight.bold, fontSize: 18)
        ),
        iconTheme: const IconThemeData(color: KeepiColors.slate),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: KeepiColors.orange));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: KeepiColors.slate)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadTimeline,
                style: ElevatedButton.styleFrom(
                  backgroundColor: KeepiColors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar', style: TextStyle(fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      );
    }

    if (_events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 64, color: KeepiColors.slateLight.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text(
              'Aún no hay eventos en el historial', 
              style: TextStyle(color: KeepiColors.slateLight, fontWeight: FontWeight.w600, fontSize: 16)
            ),
          ],
        )
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: PatientCareTimeline(
        events: _events,
        title: 'Línea de tiempo clínica',
        subtitle: '${_events.length} eventos registrados para ${widget.patientName}',
        onEventTap: (event) => _showEventDetail(context, event),
      ),
    );
  }

  void _showEventDetail(BuildContext context, TimelineEvent event) {
    Color eventColor;
    IconData eventIcon;

    switch (event.eventType) {
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
      default:
        eventColor = KeepiColors.slate;
        eventIcon = Icons.flag_outlined;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.all(24),
              children: [
                Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                
                // HEADER
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

                // FECHA ESTILO CALENDARIO (UNIFICADO)
                _buildProfessionalCalendarCard(event.occurredAt, eventColor),
                
                const SizedBox(height: 16),
                
                // INFORMACIÓN ESTADO
                _buildInfoCard([
                   _buildRow(Icons.info_outline_rounded, "Estado:", "Registrado"),
                ]),
                
                // BOTÓN S3 (Documento)
                if (event.s3Url != null && event.s3Url!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildS3DownloadButton(event.s3Url!),
                ],
                
                const SizedBox(height: 24),
                
                // CONTENIDO (Detalles o Receta)
                Text(
                  event.eventType == 'prescription' ? "Indicaciones de la receta:" : "Detalles:", 
                  style: const TextStyle(fontWeight: FontWeight.bold, color: KeepiColors.slate, fontSize: 16)
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: KeepiColors.slate.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(16), border: Border.all(color: KeepiColors.slate.withValues(alpha: 0.1))),
                  child: Text(
                    (event.description == null || event.description!.isEmpty) 
                        ? "Sin contenido registrado." 
                        : event.description!, 
                    style: const TextStyle(fontSize: 14, color: KeepiColors.slate, height: 1.5)
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.5))),
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: KeepiColors.slate.withValues(alpha: 0.1))),
      child: Column(children: children),
    );
  }

  Widget _buildRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(children: [Icon(icon, size: 16, color: KeepiColors.slateLight), const SizedBox(width: 8), Text("$label ", style: const TextStyle(fontWeight: FontWeight.w600, color: KeepiColors.slateLight)), Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, color: KeepiColors.slate)))]),
    );
  }
}