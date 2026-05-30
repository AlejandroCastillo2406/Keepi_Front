import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

// Rutas de tu proyecto
import '../../core/app_theme.dart';
import '../../models/timeline_event.dart';
import '../../services/api_client.dart';
import '../../services/doctor_service.dart';
import '../../services/prescription_service.dart';
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

  Future<void> _openScanFromTimeline(String rawId) async {
    if (rawId.isEmpty) return;
    final svc = PrescriptionService(context.read<ApiClient>());
    try {
      String cleanId = rawId.replaceAll(RegExp(r'^pres_'), '').trim();
      final url = await svc.getScanUrl(cleanId);
      
      if (url.isNotEmpty) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
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
    bool isAppointment = event.eventType.toLowerCase() == 'appointment';
    
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
          initialChildSize: isAppointment ? 0.85 : 0.65, // El calendario necesita más espacio
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) => Container(
            decoration: const BoxDecoration(
              color: KeepiColors.surfaceBg, // Fondo gris claro para resaltar tarjetas blancas
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.all(24),
              children: [
                Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                
                // CONDICIONAL: CITA MÉDICA VS OTROS EVENTOS
                if (isAppointment)
                  _buildAppointmentDetailCard(event)
                else ...[
                  // HEADER GENÉRICO PARA LOS DEMÁS EVENTOS
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
                  
                  if (event.s3Url != null && event.s3Url!.isNotEmpty && event.eventType.toLowerCase() != 'prescription') ...[
                    const SizedBox(height: 16),
                    _buildS3DownloadButton(event.s3Url!),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  event.eventType.toLowerCase() == 'prescription' 
                    ? _buildPremiumPrescriptionCard(event) 
                    : Column(
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
                ]
              ],
            ),
          ),
        );
      },
    );
  }

  // =======================================================================
  // NUEVO DISEÑO PARA LA CITA (IDÉNTICO A TU IMAGEN)
  // =======================================================================
  Widget _buildAppointmentDetailCard(TimelineEvent event) {
    DateTime dt = DateTime.now();
    try {
      dt = DateTime.parse(event.occurredAt);
    } catch (e) {}

    // Formatear la fecha
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
        // 1. TARJETA HEADER (APPOINTMENT)
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
                decoration: BoxDecoration(
                  color: KeepiColors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.event_available_rounded, color: KeepiColors.orange, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    
                    const SizedBox(height: 4),
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

        // 2. CALENDARIO
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
          // IgnorePointer bloquea los toques para que sea solo de lectura
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

        // 3. MOTIVO DE CONSULTA
        const Text("Motivo de consulta:", style: TextStyle(fontWeight: FontWeight.bold, color: KeepiColors.slate, fontSize: 16)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Text(
            (event.description == null || event.description!.isEmpty)
                ? "Sin motivo registrado."
                : event.description!,
            style: const TextStyle(fontSize: 15, color: KeepiColors.slate, height: 1.5)
          ),
        )
      ],
    );
  }

  // =======================================================================
  // DISEÑO PREMIUM DE LA RECETA (MANTIENE SU LÓGICA ANTERIOR)
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

  Widget _buildS3DownloadButton(String fileUrl) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          final Uri url = Uri.parse(fileUrl);
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.inAppBrowserView);
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
}