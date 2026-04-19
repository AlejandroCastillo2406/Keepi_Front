import 'package:http_parser/http_parser.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:dio/dio.dart';

import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import '../../services/doctor_service.dart';

class PatientUploadAnalysisScreen extends StatefulWidget {
  final String requestId;
  final String description; // Para mostrarle al paciente qué le pidieron

  const PatientUploadAnalysisScreen({
    super.key,
    required this.requestId,
    required this.description,
  });

  @override
  State<PatientUploadAnalysisScreen> createState() => _PatientUploadAnalysisScreenState();
}

class _PatientUploadAnalysisScreenState extends State<PatientUploadAnalysisScreen> {
  String? _selectedFileName;
  PlatformFile? _selectedFile;
  bool _isUploading = false;

  /// Abre el selector de archivos del celular
  Future<void> _pickDocument() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );

      if (result != null) {
        setState(() {
          _selectedFile = result.files.first;
          _selectedFileName = _selectedFile!.name;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al seleccionar el archivo')),
      );
    }
  }

  /// Sube el archivo y completa la solicitud en la base de datos
  Future<void> _uploadDocument() async {
    if (_selectedFile == null) return;
    setState(() => _isUploading = true);

    try {
      final api = context.read<ApiClient>();
      final svc = DoctorService(api);

      // 1. Preparamos el archivo
      final formData = FormData.fromMap({
        'file': kIsWeb 
            ? MultipartFile.fromBytes(_selectedFile!.bytes!, filename: _selectedFileName)
            : await MultipartFile.fromFile(_selectedFile!.path!, filename: _selectedFileName),
      });

      // 2. Subimos el archivo
      // Francotirazo directo: Usamos la URL completa para que Dio no intente adivinar la ruta ni agregar barras extra.
      final uploadRes = await api.dio.post(
        '/api/v1/documents/mobile/patient-upload', 
        data: formData
      );
      
      // --- EL BLINDAJE COMIENZA AQUÍ ---
      print("RESPUESTA DEL SERVIDOR (UPLOAD): ${uploadRes.data}");
      
      // Extraemos el ID buscando 'document_id' o 'id' y lo convertimos a String sí o sí
      final responseData = uploadRes.data;
      final String? documentId = responseData['document_id']?.toString() ?? responseData['id']?.toString();

      if (documentId == null) {
        // Si sigue siendo nulo, lanzamos un error claro en lugar de romper la app
        throw Exception('El servidor no envió el ID. Respuesta: $responseData');
      }
      // --- FIN DEL BLINDAJE ---

      // 3. Vinculamos el documento
      await svc.completeAnalysisRequest(
        requestId: widget.requestId,
        documentId: documentId,
      );

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Estudio enviado con éxito al doctor!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true); 

    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de red/servidor: ${DoctorService.messageFromDio(e)}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error inesperado: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  /// Visor de PDF integrado
  void _showPdfViewer(BuildContext context) {
    if (_selectedFile == null) return;
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            title: Text(_selectedFileName ?? "Vista Previa", style: const TextStyle(color: KeepiColors.slate, fontSize: 14)),
            leading: IconButton(
              icon: const Icon(Icons.close, color: KeepiColors.slate),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: kIsWeb
              ? SfPdfViewer.memory(_selectedFile!.bytes!)
              : SfPdfViewer.file(File(_selectedFile!.path!)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KeepiColors.surfaceBg,
      appBar: AppBar(
        title: const Text('Entregar Estudio', style: TextStyle(color: KeepiColors.slate, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: KeepiColors.slate),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- TARJETA DE INSTRUCCIONES ---
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: KeepiColors.orangeSoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: KeepiColors.orange.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.assignment_ind_rounded, color: KeepiColors.orange, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          "INSTRUCCIONES DEL DOCTOR", 
                          style: TextStyle(color: KeepiColors.orange, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5)
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.description, 
                      style: const TextStyle(fontWeight: FontWeight.w700, color: KeepiColors.slate, fontSize: 15, height: 1.4)
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              const Text("Tu Archivo", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: KeepiColors.slate)),
              const SizedBox(height: 16),

              // --- ZONA DE SUBIDA ---
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: KeepiColors.cardBorder.withOpacity(0.5)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_selectedFile == null) ...[
                        Icon(Icons.cloud_upload_outlined, size: 60, color: KeepiColors.slateLight.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        const Text("Sube una foto o PDF con tus resultados", style: TextStyle(color: KeepiColors.slateLight)),
                        const SizedBox(height: 24),
                        OutlinedButton.icon(
                          onPressed: _pickDocument, 
                          icon: const Icon(Icons.folder_open_rounded),
                          label: const Text("Buscar en el dispositivo"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: KeepiColors.slate,
                            side: BorderSide(color: KeepiColors.cardBorder),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                          ),
                        ),
                      ] else ...[
                        _buildPreviewArea(),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            _selectedFileName!, 
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: KeepiColors.slate)
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextButton.icon(
                          onPressed: _pickDocument, 
                          icon: const Icon(Icons.autorenew_rounded),
                          label: const Text("Elegir otro archivo"),
                          style: TextButton.styleFrom(foregroundColor: KeepiColors.orange),
                        )
                      ]
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // --- BOTÓN FINAL DE ENVÍO ---
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: (_selectedFile == null || _isUploading) ? null : _uploadDocument,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KeepiColors.orange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isUploading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                      : const Text('Enviar Estudio al Doctor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewArea() {
    final ext = _selectedFile!.extension?.toLowerCase();
    if (ext == 'pdf') {
      return Column(
        children: [
          const Icon(Icons.picture_as_pdf_rounded, size: 60, color: Colors.redAccent),
          TextButton(onPressed: () => _showPdfViewer(context), child: const Text("Ver PDF", style: TextStyle(color: KeepiColors.orange)))
        ],
      );
    }
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: kIsWeb ? Image.memory(_selectedFile!.bytes!, height: 120) : Image.file(File(_selectedFile!.path!), height: 120),
    );
  }
}