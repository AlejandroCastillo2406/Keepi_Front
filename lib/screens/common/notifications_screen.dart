import 'package:flutter/material.dart';
import 'package:keepi/screens/doctor/analysis_document_viewer_screen.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart'; 

import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import '../../services/appointment_service.dart';
import '../../services/notification_navigation.dart';
import '../../services/notifications_service.dart';
import '../../services/prescription_service.dart';
import '../../services/questionnaire_service.dart';
import '../../services/doctor_service.dart'; 
import '../../providers/auth_provider.dart';

const _monthsEsUpper = <String>[
  'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
  'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC',
];

String _two(int v) => v.toString().padLeft(2, '0');

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    this.embedded = false,
    this.onBack,
  });

  final bool embedded;
  final VoidCallback? onBack;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  String? _error;
  List<AppNotificationDto> _items = [];
  String? _openingDocumentId; 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final svc = NotificationsService(context.read<ApiClient>());
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await svc.fetchNotifications();
      if (!mounted) return;
      setState(() {
        _items = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = NotificationsService.messageFromDio(e);
        _loading = false;
      });
    }
  }

  // ==========================================
  // APERTURA DE DOCUMENTOS Y ENLACES EXTERNOS
  // ==========================================
  void _openBackendDocument(String url, String title) {
    if (url.isEmpty) return;
    final api = context.read<ApiClient>();
    final token = api.accessToken;
    final headers = <String, String>{
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      'Accept': '*/*',
    };

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AnalysisDocumentViewerScreen(
          url: url,
          title: title,
          headers: headers,
        ),
      ),
    );
  }

  Future<void> _launchExternalUrl(String url) async {
    if (url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se puede abrir el archivo en el navegador.')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ocurrió un error al intentar abrir el enlace.')));
    }
  }

  Future<void> _openScanFromTimeline(String rawId) async {
    if (rawId.isEmpty) return;
    final svc = PrescriptionService(context.read<ApiClient>());
    try {
      String cleanId = rawId.replaceAll(RegExp(r'^pres_'), '').trim();
      final url = await svc.getScanUrl(cleanId);
      
      if (url.isNotEmpty) {
        await _launchExternalUrl(url);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Esta receta no tiene un archivo adjunto.')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(PrescriptionService.messageFromDio(e))));
    }
  }

  // ── Acciones originales de notificaciones ─────────────────────────
  Future<void> _openAnalysisDocument(AppNotificationDto n) async {
    final data = NotificationNavigation.dataFromNotification(n);
    if (!NotificationNavigation.isAnalysisRequestCompleted(data)) return;
    await NotificationNavigation.openAnalysisDocument(
      context,
      data: data,
      title: n.title,
    );
  }

  Future<void> _openDocumentReplacement(AppNotificationDto n) async {
    final data = NotificationNavigation.dataFromNotification(n);
    if (!NotificationNavigation.isDocumentReplaced(data)) return;
    await NotificationNavigation.openDocumentReplacement(context, data: data);
  }

  Future<void> _openReminderPrompt(AppNotificationDto n) async {
    final prescriptionId = n.prescriptionId;
    if (prescriptionId == null || prescriptionId.isEmpty) return;
    final api = context.read<ApiClient>();
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(n.title),
        content: Text(n.reminderQuestion),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('No', style: TextStyle(color: KeepiColors.slateLight))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
            onPressed: () => Navigator.of(context).pop(true), 
            child: const Text('Sí', style: TextStyle(fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
    if (answer == null) return;
    try {
      await PrescriptionService(api).setReminderOptIn(prescriptionId, answer);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            answer ? 'Recordatorios activados' : 'Recordatorios desactivados',
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(PrescriptionService.messageFromDio(e))),
      );
    }
  }

  // ── Acciones de citas (FLUJO NUEVO) ─────────────────────────────
  Future<void> _openAppointmentPrompt(AppNotificationDto n) async {
    final appointmentId = n.appointmentId; 
    if (appointmentId == null || appointmentId.isEmpty) return;

    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final isDoctor = authProv.roleName == 'DOCTOR';
    final appointmentSvc = Provider.of<AppointmentService>(context, listen: false);

    if (isDoctor) {
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.edit_calendar_outlined, color: KeepiColors.orange),
              SizedBox(width: 8),
              Text('Solicitud de Cita', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Text('${n.message}\n\n¿Deseas asignar una fecha ahora?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Después', style: TextStyle(color: KeepiColors.slateLight))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: KeepiColors.orange),
              onPressed: () => Navigator.of(ctx).pop(true), 
              child: const Text('Asignar Fecha', style: TextStyle(fontWeight: FontWeight.bold))
            ),
          ],
        ),
      );

      if (confirm == true) {
        try {
          final dt = await _pickDateTime();
          if (dt == null) return;
          
          if (!mounted) return;
          showDialog(
            context: context, 
            barrierDismissible: false, 
            builder: (_) => const Center(child: CircularProgressIndicator(color: KeepiColors.orange))
          );

          await appointmentSvc.doctorProposeTime(
            appointmentId: appointmentId,
            proposedStartAt: dt,
            durationMinutes: 30, 
          );
          
          if (!mounted) return;
          Navigator.pop(context); 

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fecha propuesta enviada al paciente.')),
          );
          await _load();
        } catch (e) {
          if (!mounted) return;
          Navigator.pop(context); 
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppointmentService.messageFromDio(e))),
          );
        }
      }
    } else {
      final String? action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.event_available_outlined, color: KeepiColors.skyBlue),
              SizedBox(width: 8),
              Text('Propuesta de Cita', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Text(n.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('reject'), 
              child: const Text('Rechazar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: KeepiColors.skyBlue),
              onPressed: () => Navigator.of(ctx).pop('accept'), 
              child: const Text('Aceptar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (action != null) {
        try {
          if (!mounted) return;
          showDialog(
            context: context, 
            barrierDismissible: false, 
            builder: (_) => const Center(child: CircularProgressIndicator(color: KeepiColors.skyBlue))
          );

          await appointmentSvc.patientRespondProposal(
            appointmentId: appointmentId,
            action: action,
          );
          
          if (!mounted) return;
          Navigator.pop(context);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(action == 'accept' ? 'Cita confirmada exitosamente' : 'Cita rechazada')),
          );
          await _load();
        } catch (e) {
          if (!mounted) return;
          Navigator.pop(context); 
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppointmentService.messageFromDio(e))),
          );
        }
      }
    }
  }

  Future<DateTime?> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: KeepiColors.orange)),
        child: child!,
      ),
    );
    if (date == null || !mounted) return null;
    
    final time = await showTimePicker(
      context: context, 
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: KeepiColors.orange)),
        child: child!,
      ),
    );
    if (time == null) return null;
    
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  // =======================================================================
  // DISEÑOS GENÉRICOS (PORTADOS EXACTAMENTE DE TIMELINE)
  // =======================================================================
  Widget _buildProfessionalCalendarCard(String dateStr, Color color) {
    String day = "??";
    String monthYear = "---";
    String time = "--:--";
    try {
      DateTime dt = DateTime.tryParse(dateStr) ?? DateTime.now();
      day = dt.day.toString().padLeft(2, '0');
      monthYear = "${_monthsEsUpper[dt.month - 1]} ${dt.year}";
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

  // =======================================================================
  // DISEÑO PREMIUM DE LA RECETA
  // =======================================================================
  Widget _buildPremiumPrescriptionCard(AppNotificationDto n) {
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
          final targetId = (n.prescriptionId ?? '').replaceAll(RegExp(r'^pres_'), '').trim();
          
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
          if (n.message.isNotEmpty) {
            itemsToDisplay = n.message.split('\n').where((e) => e.trim().isNotEmpty).toList();
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
                  onPressed: () => _openScanFromTimeline(n.prescriptionId ?? ''), 
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

  // =======================================================================
  // DISEÑO PARA CITA 
  // =======================================================================
  Widget _buildAppointmentDetailCard(AppNotificationDto n) {
    DateTime dt = DateTime.now();
    try {
      if (n.createdAt != null && n.createdAt!.isNotEmpty) {
        dt = DateTime.parse(n.createdAt!);
      }
    } catch (e) {}

    String day = dt.day.toString().padLeft(2, '0');
    String monthStr = _monthsEsUpper[dt.month - 1];
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
                    Text(n.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: KeepiColors.slate)),
                    const SizedBox(height: 4),
                    Text(formattedDate, style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 28),
        const Text("Fecha agendada / Propuesta:", style: TextStyle(fontWeight: FontWeight.bold, color: KeepiColors.slate, fontSize: 16)),
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
            (n.message.isEmpty) ? "Sin motivo registrado." : n.message,
            style: const TextStyle(fontSize: 15, color: KeepiColors.slate, height: 1.5)
          ),
        )
      ],
    );
  }

  // =======================================================================
  // DISEÑO INTELIGENTE PARA ANÁLISIS 
  // =======================================================================
  Widget _buildAnalysisDetailCard(BuildContext context, AppNotificationDto n, String patientId) {
    if (patientId.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Detalles del análisis:", style: TextStyle(fontWeight: FontWeight.bold, color: KeepiColors.slate, fontSize: 16)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
            child: Text(n.message.isEmpty ? "Sin contenido registrado." : n.message, style: const TextStyle(fontSize: 14, color: KeepiColors.slate, height: 1.6, fontWeight: FontWeight.w500)),
          ),
        ],
      );
    }

    return FutureBuilder<List<dynamic>>(
      future: DoctorService(context.read<ApiClient>()).fetchPatientAnalysisRequests(patientId).catchError((e) => []),
      builder: (context, snapshot) {
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(color: KeepiColors.orange)),
          );
        }

        final payloadData = NotificationNavigation.dataFromNotification(n);
        final targetId = (payloadData['requestId']?.toString() ?? payloadData['analysisId']?.toString() ?? n.id ?? '').replaceAll(RegExp(r'^(ana_|req_)'), '').trim();
        
        bool isCompleted = false;
        bool hasDocument = false;
        String docId = '';
        String completedAtStr = '';
        String description = n.message.isNotEmpty ? n.message : n.title;

        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final eventDesc = description.trim().toLowerCase();

          for (var r in snapshot.data!) {
            String rId = '';
            String rDesc = '';
            String rStatus = '';
            String rDocId = '';
            String rCompleted = '';

            if (r is Map) {
              rId = (r['id'] ?? '').toString();
              rDesc = (r['description'] ?? '').toString();
              rStatus = (r['status'] ?? '').toString();
              rDocId = (r['document_id'] ?? r['documentId'] ?? '').toString();
              rCompleted = (r['completed_at'] ?? r['completedAt'] ?? '').toString();
            } else {
              try { rId = r.id?.toString() ?? ''; } catch(_) {}
              try { rDesc = r.description?.toString() ?? ''; } catch(_) {}
              try { rStatus = r.status?.toString() ?? ''; } catch(_) {}
              try { rDocId = r.documentId?.toString() ?? ''; } catch(_) {}
              try { rCompleted = r.completedAt?.toString() ?? ''; } catch(_) {}
            }

            rId = rId.replaceAll(RegExp(r'^(ana_|req_)'), '').trim();
            String cleanRDesc = rDesc.trim().toLowerCase();

            bool matchById = targetId.isNotEmpty && rId == targetId;
            bool matchByDesc = eventDesc.isNotEmpty && (cleanRDesc == eventDesc || cleanRDesc.contains(eventDesc) || eventDesc.contains(cleanRDesc));

            if (matchById || matchByDesc) {
              isCompleted = rStatus.toLowerCase() == 'completed' || rDocId.isNotEmpty;
              docId = rDocId;
              completedAtStr = rCompleted;
              if (rDesc.isNotEmpty) description = rDesc;
              hasDocument = docId.isNotEmpty;

              if (hasDocument) break;
            }
          }
        }

        if (!isCompleted && !hasDocument) {
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
                    Expanded(
                      child: Text(
                        hasDocument ? description : "Aún no hay resultados de análisis subidos para mostrar. ${n.message}",
                        style: const TextStyle(color: KeepiColors.slateLight, fontSize: 13.5, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        if (completedAtStr.isEmpty) {
           DateTime dt = DateTime.tryParse(n.createdAt ?? '') ?? DateTime.now();
           completedAtStr = "${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}T${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}:00Z";
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Documento adjunto:", style: TextStyle(fontWeight: FontWeight.bold, color: KeepiColors.slate, fontSize: 16)),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                setState(() => _openingDocumentId = targetId);
                try {
                  if (docId.isNotEmpty) {
                     final api = context.read<ApiClient>();
                     final svc = DoctorService(api);
                     String backendUrl = svc.getMobileDocumentUrl(docId);
                     
                     if (!mounted) return;
                     _openBackendDocument(backendUrl, "Archivo de análisis");
                  } else {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se encontró el archivo adjunto en el servidor.')));
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
                    _openingDocumentId == targetId
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

  // ── LÓGICA DE UI PARA RESPUESTAS DE CUESTIONARIOS ──────────────────────
  Widget _buildQuestionnaireDetailCard(BuildContext context, AppNotificationDto n, String patientId) {
    if (patientId.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Detalles del cuestionario:", style: TextStyle(fontWeight: FontWeight.bold, color: KeepiColors.slate, fontSize: 16)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
            child: Text(n.message.isEmpty ? "Sin contenido registrado." : n.message, style: const TextStyle(fontSize: 14, color: KeepiColors.slate, height: 1.6, fontWeight: FontWeight.w500)),
          ),
        ],
      );
    }

    return FutureBuilder<List<dynamic>>(
      future: QuestionnaireService(context.read<ApiClient>()).fetchPatientResponses(patientId).catchError((e) => []),
      builder: (context, snapshot) {
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(color: KeepiColors.orange)),
          );
        }

        List<Map<String, dynamic>> matchingResponses = [];
        
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          final notifDate = DateTime.tryParse(n.createdAt ?? '')?.toLocal();
          
          for (var r in snapshot.data!) {
            if (r is Map) {
              final answeredAt = DateTime.tryParse((r['answered_at'] ?? '').toString())?.toLocal();
              // Ampliamos un poco más el rango de tiempo de búsqueda por seguridad (24 horas)
              if (answeredAt != null && notifDate != null && answeredAt.difference(notifDate).abs() < const Duration(hours: 24)) {
                matchingResponses.add(Map<String, dynamic>.from(r));
              } else if (notifDate == null) {
                matchingResponses.add(Map<String, dynamic>.from(r));
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
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                child: Text(n.message.isEmpty ? "Sin contenido registrado o respuestas no encontradas." : n.message, style: const TextStyle(fontSize: 14, color: KeepiColors.slate, height: 1.6, fontWeight: FontWeight.w500)),
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

  // ── Orquestador de Interfaz: Muestra el BottomSheet Detallado ───────────
  void _showNotificationDetail(BuildContext context, AppNotificationDto n) {
    bool isAppointment = n.appointmentId != null;
    bool isPrescription = n.prescriptionId != null;
    bool isAnalysis = n.isAnalysisRequestCompleted;
    bool isQuestionnaire = n.isQuestionnaireCompleted;
    bool isReplaced = n.isDocumentReplaced;
    
    // Extracción de ID robusta:
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final payloadData = NotificationNavigation.dataFromNotification(n);
    String patientId = payloadData['patientId']?.toString() 
                    ?? payloadData['patient_id']?.toString() 
                    ?? payloadData['userId']?.toString() 
                    ?? payloadData['user_id']?.toString() 
                    ?? '';
    
    // Fallback: Si no hay ID en la data y el usuario no es DOCTOR, inferimos que es el paciente actual.
    if (patientId.isEmpty && authProv.roleName != 'DOCTOR') {
      try { patientId = (authProv as dynamic).userId?.toString() ?? ''; } catch(_) {}
    }

    Color eventColor = KeepiColors.slate;
    IconData eventIcon = Icons.info_outline_rounded;
    String tag = 'AVISO';

    if (isAppointment) {
      eventColor = KeepiColors.skyBlue;
      eventIcon = Icons.event_available_outlined;
      tag = 'CITA MÉDICA';
    } else if (isPrescription) {
      eventColor = const Color(0xFF7C3AED);
      eventIcon = Icons.medication_outlined;
      tag = 'RECETA MÉDICA';
    } else if (isAnalysis) {
      eventColor = KeepiColors.orange;
      eventIcon = Icons.biotech_outlined;
      tag = 'ANÁLISIS CLÍNICO';
    } else if (isQuestionnaire) {
      eventColor = KeepiColors.orange;
      eventIcon = Icons.assignment_turned_in_outlined;
      tag = 'CUESTIONARIO COMPLETADO';
    } else if (isReplaced) {
      eventColor = KeepiColors.slate;
      eventIcon = Icons.find_replace_rounded;
      tag = 'DOCUMENTO ACTUALIZADO';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: isAppointment ? 0.85 : 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) => Container(
            decoration: const BoxDecoration(
              color: KeepiColors.surfaceBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4, 
                    margin: const EdgeInsets.only(bottom: 20), 
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))
                  )
                ),
                
                // Si es cita médica, usamos directamente el diseño completo
                if (isAppointment)
                  _buildAppointmentDetailCard(n)
                else ...[
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12), 
                        decoration: BoxDecoration(color: eventColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)), 
                        child: Icon(eventIcon, color: eventColor, size: 28)
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: KeepiColors.slate)),
                            Text(tag, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: eventColor, letterSpacing: 1.2)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider()),

                  // ==========================================
                  // DISEÑOS GENÉRICOS (AÑADIDOS DEL TIMELINE)
                  // ==========================================
                  _buildProfessionalCalendarCard(n.createdAt ?? DateTime.now().toIso8601String(), eventColor),
                  const SizedBox(height: 16),
                  
                  _buildInfoCard([
                    _buildRow(Icons.info_outline_rounded, "Estado:", "Notificación recibida en historial"),
                  ]),
                  const SizedBox(height: 24),

                  // ==========================================
                  // CONTENIDO CONDICIONAL POR EVENTO (TARJETAS TIMELINE)
                  // ==========================================
                  if (isQuestionnaire)
                    _buildQuestionnaireDetailCard(context, n, patientId)
                  else if (isPrescription)
                    _buildPremiumPrescriptionCard(n)
                  else if (isAnalysis)
                    _buildAnalysisDetailCard(context, n, patientId)
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Detalles:", style: TextStyle(fontWeight: FontWeight.bold, color: KeepiColors.slate, fontSize: 16)),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                          child: Text(n.message.isEmpty ? "Sin contenido registrado." : n.message, style: const TextStyle(fontSize: 14, color: KeepiColors.slate, height: 1.6, fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                ],

                // ==========================================
                // BOTONES EXTRAS DE NOTIFICACIONES
                // ==========================================
                if (isAnalysis) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openAnalysisDocument(n); 
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: KeepiColors.orange, 
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.file_present_rounded),
                      label: const Text("VER DOCUMENTO RÁPIDO", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  )
                ],

                if (isPrescription) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openReminderPrompt(n); 
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED), 
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: const Text("GESTIONAR RECORDATORIOS", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  )
                ],

                if (isReplaced) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openDocumentReplacement(n); 
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: KeepiColors.slate, 
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.find_replace_rounded),
                      label: const Text("VER REEMPLAZO", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  )
                ],

                if (isQuestionnaire) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: KeepiColors.orange,
                        side: const BorderSide(color: KeepiColors.orange),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text("ENTENDIDO", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
                
                if (isAppointment) ...[
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openAppointmentPrompt(n);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: KeepiColors.skyBlue, 
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.calendar_month_rounded),
                      label: const Text("GESTIONAR CITA", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  )
                ],

              ],
            ),
          ),
        );
      },
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────
  void _handleBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Widget _buildScrollContent() {
    final unread = _items.where((n) => !n.read).length;

    return RefreshIndicator(
      color: KeepiColors.orange,
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _NotifTopBar(onBack: _handleBack)),
          SliverToBoxAdapter(child: _NotifHero(total: _items.length, unread: unread)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 40),
            sliver: SliverToBoxAdapter(child: _bodyBlock()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return ColoredBox(
        color: KeepiColors.surfaceBg,
        child: SafeArea(bottom: false, child: _buildScrollContent()),
      );
    }

    return Scaffold(
      backgroundColor: KeepiColors.surfaceBg,
      body: SafeArea(
        bottom: false,
        child: _buildScrollContent(),
      ),
    );
  }

  Widget _bodyBlock() {
    if (_loading) return const _NotifLoadingBox();
    if (_error != null) return _NotifErrorBox(message: _error!, onRetry: _load);
    if (_items.isEmpty) {
      return const _NotifEmptyCard(
        tag: 'NOTIFICACIONES',
        title: 'Todo al día',
        message: 'No tienes avisos pendientes.',
        icon: Icons.mark_email_read_outlined,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NotifSectionDivider(tag: 'RECIENTES', count: _items.length),
        const SizedBox(height: 14),
        for (final n in _items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _NotifCard(
              data: n,
              onTap: () => _showNotificationDetail(context, n), 
            ),
          ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
//   TOP BAR
// ──────────────────────────────────────────────────────────────────────────

class _NotifTopBar extends StatelessWidget {
  const _NotifTopBar({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Row(
        children: [
          _IconPill(icon: Icons.arrow_back_rounded, onTap: onBack),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/logo.png',
              width: 34,
              height: 34,
              fit: BoxFit.cover,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _IconPill extends StatelessWidget {
  const _IconPill({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: KeepiColors.cardBorder),
        ),
        child: Icon(icon, size: 19, color: KeepiColors.slate),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
//   HERO
// ──────────────────────────────────────────────────────────────────────────

class _NotifHero extends StatelessWidget {
  const _NotifHero({required this.total, required this.unread});
  final int total;
  final int unread;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 22, height: 2, color: KeepiColors.slate),
              const SizedBox(width: 8),
              const Text(
                'BANDEJA',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                  color: KeepiColors.slate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Notificaciones.',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: KeepiColors.slate,
              height: 1.1,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Recordatorios de tus recetas y cambios en tus citas.',
            style: TextStyle(fontSize: 13.5, color: KeepiColors.slateLight, height: 1.4),
          ),
          const SizedBox(height: 18),
          _NotifStatsStrip(
            items: [
              _NotifStat(value: total, label: 'TOTAL'),
              _NotifStat(value: unread, label: 'SIN LEER', accent: unread > 0),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotifStat {
  const _NotifStat({required this.value, required this.label, this.accent = false});
  final int value;
  final String label;
  final bool accent;
}

class _NotifStatsStrip extends StatelessWidget {
  const _NotifStatsStrip({required this.items});
  final List<_NotifStat> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              Expanded(child: _NotifStatCell(item: items[i])),
              if (i < items.length - 1)
                Container(width: 1, color: KeepiColors.cardBorder),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotifStatCell extends StatelessWidget {
  const _NotifStatCell({required this.item});
  final _NotifStat item;

  @override
  Widget build(BuildContext context) {
    final color = item.accent ? KeepiColors.orange : KeepiColors.slate;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _two(item.value),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1,
              letterSpacing: -1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              item.label,
              maxLines: 2,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: KeepiColors.slateLight,
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
//   DIVIDER
// ──────────────────────────────────────────────────────────────────────────

class _NotifSectionDivider extends StatelessWidget {
  const _NotifSectionDivider({required this.tag, required this.count});
  final String tag;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 18, height: 1, color: KeepiColors.slate.withValues(alpha: 0.45)),
        const SizedBox(width: 10),
        Text(
          tag,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
            color: KeepiColors.slate,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: KeepiColors.slateSoft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _two(count),
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: KeepiColors.slate,
              letterSpacing: 0.3,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(height: 1, color: KeepiColors.slate.withValues(alpha: 0.12)),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
//   CARD
// ──────────────────────────────────────────────────────────────────────────

class _NotifCard extends StatelessWidget {
  const _NotifCard({required this.data, required this.onTap});
  final AppNotificationDto data;
  final VoidCallback onTap;

  ({String tag, Color color, IconData icon, String actionHint}) _meta() {
    if (data.isAnalysisRequestCompleted) {
      return (
        tag: 'ANÁLISIS',
        color: KeepiColors.orange,
        icon: Icons.biotech_outlined,
        actionHint: 'Toca para ver detalles',
      );
    }
    if (data.isQuestionnaireCompleted) {
      return (
        tag: 'CUESTIONARIO',
        color: KeepiColors.orange,
        icon: Icons.assignment_turned_in_outlined,
        actionHint: 'Completado por paciente',
      );
    }
    if (data.appointmentId != null) {
      return (
        tag: 'CITA',
        color: KeepiColors.skyBlue,
        icon: Icons.event_available_outlined,
        actionHint: 'Toca para gestionar',
      );
    }
    if (data.prescriptionId != null) {
      return (
        tag: 'RECETA',
        color: const Color(0xFF7C3AED),
        icon: Icons.medication_outlined,
        actionHint: 'Toca para opciones',
      );
    }
    return (
      tag: 'AVISO',
      color: KeepiColors.slate,
      icon: Icons.info_outline_rounded,
      actionHint: 'Ver más',
    );
  }

  String get _dateStamp {
    final raw = data.createdAt;
    if (raw == null || raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return '';
    return '${_two(dt.day)} ${_monthsEsUpper[dt.month - 1]} · ${_two(dt.hour)}:${_two(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final m = _meta();
    final stateColor = data.read ? KeepiColors.slateLight : KeepiColors.orange;
    final stateLabel = data.read ? 'LEÍDA' : 'NUEVA';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: data.read
                ? KeepiColors.cardBorder
                : KeepiColors.orange.withValues(alpha: 0.45),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: m.color, width: 1.6),
                ),
                child: Icon(m.icon, size: 19, color: m.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(color: stateColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          m.tag,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                            color: m.color,
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
                        Flexible(
                          child: Text(
                            stateLabel,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: stateColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 2,
                      width: 20,
                      decoration: BoxDecoration(
                        color: m.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data.title,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: KeepiColors.slate,
                        height: 1.25,
                        letterSpacing: -0.25,
                      ),
                    ),
                    if (data.message.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        data.message.trim(),
                        style: const TextStyle(
                          fontSize: 13,
                          color: KeepiColors.slateLight,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (_dateStamp.isNotEmpty) ...[
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
                              _dateStamp,
                              style: TextStyle(
                                fontSize: 12,
                                color: KeepiColors.slate.withValues(alpha: 0.85),
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w500,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (m.actionHint.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            m.actionHint.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                              color: KeepiColors.slate,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: KeepiColors.slate,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
//   STATE WIDGETS
// ──────────────────────────────────────────────────────────────────────────

class _NotifLoadingBox extends StatelessWidget {
  const _NotifLoadingBox();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: SizedBox(
          width: 22, height: 22,
          child: CircularProgressIndicator(color: KeepiColors.orange, strokeWidth: 2.4),
        ),
      ),
    );
  }
}

class _NotifErrorBox extends StatelessWidget {
  const _NotifErrorBox({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KeepiColors.orange.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: KeepiColors.orange, size: 18),
              SizedBox(width: 8),
              Text(
                'NO PUDIMOS CARGAR',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: KeepiColors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(fontSize: 13.5, color: KeepiColors.slate, height: 1.4),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: onRetry,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: KeepiColors.slate),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, size: 16, color: KeepiColors.slate),
                  SizedBox(width: 6),
                  Text(
                    'REINTENTAR',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: KeepiColors.slate,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotifEmptyCard extends StatelessWidget {
  const _NotifEmptyCard({
    required this.tag,
    required this.title,
    required this.message,
    required this.icon,
  });

  final String tag;
  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KeepiColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 18, height: 1, color: KeepiColors.slate.withValues(alpha: 0.45)),
              const SizedBox(width: 8),
              Text(
                tag,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.8,
                  color: KeepiColors.slate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: KeepiColors.slateLight, width: 1.4),
            ),
            child: Icon(icon, size: 26, color: KeepiColors.slateLight),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: KeepiColors.slate,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13.5,
              color: KeepiColors.slateLight,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}