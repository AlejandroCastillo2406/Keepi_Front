import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Asegúrate de que estas rutas coincidan con la estructura de tu proyecto
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
      ),
    );
  }
}
