import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Asegúrate de que estas rutas coincidan con la estructura de tu proyecto
import '../../services/api_client.dart';
import '../../services/doctor_service.dart';
import '../../core/app_theme.dart';

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
            Icon(Icons.history_rounded, size: 64, color: KeepiColors.slateLight.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text(
              'Aún no hay eventos en el historial', 
              style: TextStyle(color: KeepiColors.slateLight, fontWeight: FontWeight.w600, fontSize: 16)
            ),
          ],
        )
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _events.length,
      itemBuilder: (context, index) {
        final event = _events[index];
        final isLast = index == _events.length - 1;
        return _buildTimelineNode(event, isLast);
      },
    );
  }

  Widget _buildTimelineNode(TimelineEvent event, bool isLast) {
    // Definimos el color y el icono dependiendo del tipo de evento que manda tu API
    IconData icon;
    Color nodeColor;

    switch (event.eventType) {
      case 'appointment':
        icon = Icons.calendar_month_rounded;
        nodeColor = KeepiColors.orange;
        break;
      case 'registration':
        icon = Icons.person_add_rounded;
        nodeColor = Colors.green;
        break;
      case 'prescription':
        icon = Icons.medication_rounded;
        nodeColor = Colors.purple;
        break;
      case 'analysis':
        icon = Icons.science_rounded;
        nodeColor = KeepiColors.skyBlue;
        break;
      default:
        icon = Icons.event_note_rounded;
        nodeColor = KeepiColors.slate;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Lado Izquierdo: Icono y Línea conectora
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: nodeColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: nodeColor, width: 2),
                  ),
                  child: Icon(icon, size: 18, color: nodeColor),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: KeepiColors.slateLight.withOpacity(0.3),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Lado Derecho: Tarjeta de Contenido
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: KeepiColors.slateLight.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: KeepiColors.slate.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            event.title, 
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: KeepiColors.slate)
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              event.date, 
                              style: const TextStyle(color: KeepiColors.slateLight, fontSize: 12, fontWeight: FontWeight.bold)
                            ),
                            Text(
                              event.time, 
                              style: const TextStyle(color: KeepiColors.slateLight, fontSize: 11)
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      event.description, 
                      style: const TextStyle(color: KeepiColors.slate, fontSize: 14, height: 1.4)
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: KeepiColors.skyBlueSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person_outline_rounded, size: 14, color: KeepiColors.skyBlue),
                          const SizedBox(width: 6),
                          Text(
                            event.actor, 
                            style: const TextStyle(fontSize: 12, color: KeepiColors.skyBlue, fontWeight: FontWeight.bold)
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Modelo de datos para parsear el JSON de la API
class TimelineEvent {
  final String id;
  final String date;
  final String time;
  final String title;
  final String actor;
  final String eventType;
  final String description;

  TimelineEvent({
    required this.id,
    required this.date,
    required this.time,
    required this.title,
    required this.actor,
    required this.eventType,
    required this.description,
  });

  factory TimelineEvent.fromJson(Map<String, dynamic> json) {
    return TimelineEvent(
      id: json['id'] ?? '',
      date: json['date'] ?? '',
      time: json['time'] ?? '',
      title: json['title'] ?? '',
      actor: json['actor'] ?? '',
      eventType: json['event_type'] ?? '',
      description: json['description'] ?? '',
    );
  }
}