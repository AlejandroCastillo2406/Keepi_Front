import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import '../../services/doctor_service.dart';
import '../../services/patient_medical_record_service.dart';

// CONVERTIDO A STATEFUL PARA PODER CARGAR LOS DOCUMENTOS DEL SERVIDOR
class DoctorPatientMedicalRecordScreen extends StatefulWidget {
  const DoctorPatientMedicalRecordScreen({
    super.key,
    required this.patientId, // Necesitamos el ID para buscar sus documentos
    required this.patientName,
    required this.record,
  });

  final String patientId;
  final String patientName;
  final MedicalRecordDto record;

  @override
  State<DoctorPatientMedicalRecordScreen> createState() => _DoctorPatientMedicalRecordScreenState();
}

class _DoctorPatientMedicalRecordScreenState extends State<DoctorPatientMedicalRecordScreen> {
  bool _isLoadingDocs = true;
  List<AnalysisRequestDto> _completedRequests = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPatientDocuments());
  }

  /// Trae el historial de solicitudes y filtra solo las que ya tienen archivo
  Future<void> _loadPatientDocuments() async {
    try {
      final svc = DoctorService(context.read<ApiClient>());
      final reqs = await svc.fetchPatientAnalysisRequests(widget.patientId);
      
      if (mounted) {
        setState(() {
          // Filtramos solo las solicitudes que ya fueron completadas por el paciente
          _completedRequests = reqs.where((r) => r.status == 'completed' && r.documentId != null).toList();
          _isLoadingDocs = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingDocs = false);
        debugPrint("Error cargando documentos: $e");
      }
    }
  }

  /// Descarga los bytes del archivo y abre un visor en pantalla completa
  Future<void> _viewDocument(String documentId, String description) async {
    // 1. Pantalla de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: KeepiColors.orange)),
    );

    try {
      final api = context.read<ApiClient>();
      
      // 2. Descargamos el archivo a la memoria RAM (ResponseType.bytes)
      final res = await api.dio.get(
        '/api/v1/documents/mobile/download/$documentId',
        options: Options(responseType: ResponseType.bytes),
      );

      if (!mounted) return;
      Navigator.pop(context); // Quitamos la pantalla de carga

      final bytes = res.data;
      final contentType = res.headers.value('content-type') ?? '';

      // 3. Abrimos el Visor Integrado
      showDialog(
        context: context,
        builder: (context) => Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(
              title: Text(description, style: const TextStyle(color: KeepiColors.slate, fontSize: 14)),
              backgroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.close, color: KeepiColors.slate),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            // Si el servidor dice que es PDF lo abre con Syncfusion, si no, asume que es una Foto
            body: contentType.contains('pdf')
                ? SfPdfViewer.memory(bytes)
                : InteractiveViewer(child: Center(child: Image.memory(bytes))),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir archivo: ${DoctorService.messageFromDio(e)}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KeepiColors.surfaceBg,
      appBar: AppBar(
        title: Text(
          'Expediente de ${widget.patientName}',
          style: const TextStyle(color: KeepiColors.slate, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: KeepiColors.slate),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // --- SECCIÓN 1: DATOS MÉDICOS ---
          const Text(
            'INFORMACIÓN GENERAL',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: KeepiColors.orange, letterSpacing: 1.2),
          ),
          const SizedBox(height: 12),
          _item('Fecha de nacimiento', widget.record.birthDate, Icons.cake_rounded),
          _item('Sexo', widget.record.sex, Icons.person_outline_rounded),
          _item('Tipo de sangre', widget.record.bloodType, Icons.bloodtype_rounded),
          _item('Alergias', widget.record.allergies, Icons.warning_amber_rounded),
          _item('Enfermedades crónicas', widget.record.chronicConditions, Icons.medical_services_rounded),
          _item('Medicación actual', widget.record.medications, Icons.medication_rounded),
          _item('Antecedentes quirúrgicos', widget.record.surgicalHistory, Icons.healing_rounded),
          _item('Antecedentes familiares', widget.record.familyHistory, Icons.family_restroom_rounded),
          _item('Notas adicionales', widget.record.notes, Icons.description_rounded),
          
          const SizedBox(height: 24),

          // --- SECCIÓN 2: CONTACTO ---
          const Text(
            'CONTACTO DE EMERGENCIA',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: KeepiColors.orange, letterSpacing: 1.2),
          ),
          const SizedBox(height: 12),
          _item('Nombre de contacto', widget.record.emergencyContactName, Icons.contact_phone_rounded),
          _item('Teléfono de emergencia', widget.record.emergencyContactPhone, Icons.phone_android_rounded),
          
          const SizedBox(height: 32),

          // --- SECCIÓN 3: ARCHIVOS DEL PACIENTE ---
          const Text(
            'DOCUMENTOS ENTREGADOS',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: KeepiColors.orange, letterSpacing: 1.2),
          ),
          const SizedBox(height: 12),
          
          if (_isLoadingDocs)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: KeepiColors.orange)))
          else if (_completedRequests.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: KeepiColors.cardBorder.withOpacity(0.3))),
              child: const Text('El paciente no ha subido ningún estudio todavía.', style: TextStyle(color: KeepiColors.slateLight)),
            )
          else
            ..._completedRequests.map((req) => _buildDocumentCard(req)),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // --- WIDGETS DE APOYO ---

  Widget _item(String label, String? value, IconData icon) {
    final bool isEmpty = value == null || value.trim().isEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KeepiColors.cardBorder.withOpacity(0.3)),
      ),
      child: ListTile(
        leading: Icon(icon, color: KeepiColors.orange.withOpacity(0.6), size: 20),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: KeepiColors.slateLight)),
        subtitle: Text(
          isEmpty ? 'Sin dato registrado' : value,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: isEmpty ? Colors.grey.shade400 : KeepiColors.slate),
        ),
      ),
    );
  }

  Widget _buildDocumentCard(AnalysisRequestDto req) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KeepiColors.orange.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: KeepiColors.orange.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: KeepiColors.orangeSoft, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.insert_drive_file_rounded, color: KeepiColors.orange),
        ),
        title: Text(req.description, style: const TextStyle(fontWeight: FontWeight.w800, color: KeepiColors.slate, fontSize: 14)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            'Entregado: ${req.completedAt?.split('T').first ?? 'Reciente'}', 
            style: const TextStyle(color: KeepiColors.slateLight, fontSize: 12, fontWeight: FontWeight.w600)
          ),
        ),
        trailing: ElevatedButton(
          onPressed: () => _viewDocument(req.documentId!, req.description),
          style: ElevatedButton.styleFrom(
            backgroundColor: KeepiColors.orange,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Ver Archivo'),
        ),
      ),
    );
  }
}