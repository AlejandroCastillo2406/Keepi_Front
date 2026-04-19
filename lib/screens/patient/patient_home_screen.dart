import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'patient_upload_analysis_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:dio/dio.dart';

// Importaciones de tu estructura core
import '../../core/app_theme.dart';
import '../../core/decorative_background.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../services/doctor_service.dart';
import '../common/notifications_screen.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  int _currentIndex = 0;

  // Estado de solicitudes y carga
  List<AnalysisRequestDto> _analysisRequests = [];
  bool _isLoadingRequests = true;

  // Estado de archivos (para subida general, no vinculada a solicitud)
  String? _selectedFileName;
  PlatformFile? _selectedFile;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAllData());
  }

  /// Carga inicial de datos desde el servidor
  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoadingRequests = true);
    
    try {
      final svc = DoctorService(context.read<ApiClient>());
      // Obtenemos solo las solicitudes "pending"
      final requests = await svc.fetchMyPendingRequests();
      
      if (mounted) {
        setState(() {
          _analysisRequests = requests;
          _isLoadingRequests = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRequests = false);
        debugPrint("Error al cargar datos: $e");
      }
    }
  }

  /// Sube un archivo y lo vincula a una solicitud específica
  Future<void> _handleRequestUpload(String requestId) async {
    try {
      // 1. Abrir selector de archivos
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );

      if (result == null || result.files.isEmpty) return; // El usuario canceló

      final file = result.files.first;
      
      // Mostrar indicador de carga global o local (aquí usamos un diálogo simple para bloquear la pantalla)
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: KeepiColors.orange)),
      );

      final api = context.read<ApiClient>();
      final svc = DoctorService(api);

      // 2. Preparar el archivo para enviar
      final formData = FormData.fromMap({
        'file': kIsWeb 
            ? MultipartFile.fromBytes(file.bytes!, filename: file.name)
            : await MultipartFile.fromFile(file.path!, filename: file.name),
      });

      // 3. Subir el documento al servidor
      final uploadRes = await api.dio.post('api/v1/documents/mobile/analyze', data: formData);
      final String documentId = uploadRes.data['id'];

      // 4. Vincular el documento a la solicitud (PATCH)
      await svc.completeAnalysisRequest(
        requestId: requestId,
        documentId: documentId,
      );

      // Cerrar el diálogo de carga
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Estudio enviado correctamente al doctor!'), backgroundColor: Colors.green),
        );
        // Recargar la lista (la solicitud completada debería desaparecer)
        _loadAllData();
      }

    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Asegurarse de cerrar el diálogo de carga en caso de error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar: ${DoctorService.messageFromDio(e)}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- Lógica para Subida General (Sin Solicitud) ---
  Future<void> _pickGeneralDocument() async {
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

  Future<void> _uploadGeneralDocument() async {
    if (_selectedFile == null) return;
    setState(() => _isUploading = true);

    try {
      final api = context.read<ApiClient>();
      
      final formData = FormData.fromMap({
        'file': kIsWeb 
            ? MultipartFile.fromBytes(_selectedFile!.bytes!, filename: _selectedFileName)
            : await MultipartFile.fromFile(_selectedFile!.path!, filename: _selectedFileName),
      });

      // Subida simple, sin vincular a solicitud
      await api.dio.post('/api/v1/documents/mobile/analyze', data: formData);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Documento subido a tu expediente!'), backgroundColor: Colors.green),
      );

      setState(() {
        _selectedFile = null;
        _selectedFileName = null;
      });

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${DoctorService.messageFromDio(e)}'), backgroundColor: Colors.red),
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
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(auth),
      body: DecorativeBackground(
        blobOpacity: 0.12,
        child: SafeArea(
          child: IndexedStack(
            index: _currentIndex == 0 ? 0 : 1,
            children: [
              _buildHomeContent(context, auth),
              const Center(child: Text("Módulo de Historial en desarrollo")),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  PreferredSizeWidget _buildAppBar(AuthProvider auth) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: const Text('Keepi', style: TextStyle(color: KeepiColors.orange, fontWeight: FontWeight.bold)),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded, color: KeepiColors.slate),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
        ),
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: KeepiColors.slate),
          onPressed: () => auth.logout(),
        ),
      ],
    );
  }

  Widget _buildHomeContent(BuildContext context, AuthProvider auth) {
    return RefreshIndicator(
      onRefresh: _loadAllData,
      color: KeepiColors.orange,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hola, ${auth.name?.split(' ').first ?? "Bienvenido"}', 
                 style: const TextStyle(fontWeight: FontWeight.w800, color: KeepiColors.slate, fontSize: 26)),
            const SizedBox(height: 4),
            const Text("Gestiona tu salud y documentos médicos.", style: TextStyle(color: KeepiColors.slateLight)),
            
            const SizedBox(height: 32),
            
            // --- UI DINÁMICA DE SOLICITUDES ---
            if (_isLoadingRequests || _analysisRequests.isNotEmpty) ...[
              const Text("Pendientes de tu Médico", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: KeepiColors.slate)),
              const SizedBox(height: 12),
              
              if (_isLoadingRequests)
                const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: KeepiColors.orange)))
              else
                ..._analysisRequests.map((req) => _buildRequestCard(req)),
                
              const SizedBox(height: 32),
            ],

            const Text("Subir Documento a tu Historial", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: KeepiColors.slate)),
            const SizedBox(height: 12),
            _buildUploadDocumentCard(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // --- TARJETA DE SOLICITUD DEL DOCTOR ---
  Widget _buildRequestCard(AnalysisRequestDto req) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: KeepiColors.orange.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KeepiColors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_late_rounded, color: KeepiColors.orange, size: 20),
              const SizedBox(width: 8),
              const Text(
                "NUEVA SOLICITUD MÉDICA", 
                style: TextStyle(color: KeepiColors.orange, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5)
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            req.description, 
            style: const TextStyle(fontWeight: FontWeight.w600, color: KeepiColors.slate, fontSize: 15)
          ),
          const SizedBox(height: 16),
          SizedBox(
  width: double.infinity,
  height: 50,
  child: ElevatedButton.icon(
    // 👇 ESTO ES LO QUE CAMBIA
    onPressed: () async {
      // Navegamos a la nueva pantalla y esperamos el resultado
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PatientUploadAnalysisScreen(
            requestId: req.id,
            description: req.description, // Pasamos la descripción al nuevo archivo
          ),
        ),
      );
      
      // Si el paciente subió el archivo con éxito (result == true), recargamos el Home
      if (result == true) {
        _loadAllData();
      }
    },
    // 👆 HASTA AQUÍ
    icon: const Icon(Icons.upload_file_rounded, size: 20),
    label: const Text("Subir documento solicitado", style: TextStyle(fontWeight: FontWeight.bold)),
    style: ElevatedButton.styleFrom(
      backgroundColor: KeepiColors.orange,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      )
        ],
      ),
    );
  }

  // --- TARJETA DE SUBIDA GENERAL ---
  Widget _buildUploadDocumentCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: KeepiColors.cardBorder.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        children: [
          _buildPreviewArea(),
          const SizedBox(height: 16),
          Text(_selectedFileName ?? "Guarda un estudio por tu cuenta", style: const TextStyle(fontWeight: FontWeight.bold, color: KeepiColors.slate)),
          const SizedBox(height: 20),
          if (_selectedFile == null)
            OutlinedButton(
              onPressed: _pickGeneralDocument, 
              style: OutlinedButton.styleFrom(
                foregroundColor: KeepiColors.slate,
                side: BorderSide(color: KeepiColors.cardBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
              child: const Text("Seleccionar Archivo")
            )
          else
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _uploadGeneralDocument,
                style: ElevatedButton.styleFrom(
                  backgroundColor: KeepiColors.slate, 
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                child: _isUploading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Text("Confirmar Subida", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewArea() {
    if (_selectedFile == null) return const Icon(Icons.cloud_upload_outlined, size: 40, color: KeepiColors.slateLight);
    
    final ext = _selectedFile!.extension?.toLowerCase();
    if (ext == 'pdf') {
      return Column(
        children: [
          const Icon(Icons.picture_as_pdf_rounded, size: 40, color: Colors.redAccent),
          TextButton(onPressed: () => _showPdfViewer(context), child: const Text("Ver PDF", style: TextStyle(color: KeepiColors.orange)))
        ],
      );
    }
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: kIsWeb ? Image.memory(_selectedFile!.bytes!, height: 80) : Image.file(File(_selectedFile!.path!), height: 80),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (i) => setState(() => _currentIndex = i),
      selectedItemColor: KeepiColors.orange,
      unselectedItemColor: KeepiColors.slateLight,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Inicio"),
        BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: "Historial"),
        BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: "Perfil"),
      ],
    );
  }
}