import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

// Importaciones basadas en tu estructura de carpetas
import '../../core/app_theme.dart';
import '../../core/decorative_background.dart';
import '../../providers/auth_provider.dart';
import 'patient_prescriptions_screen.dart';
import '../common/notifications_screen.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  int _currentIndex = 0; 
  
  // Variables de estado para la subida
  String? _selectedFileName;
  PlatformFile? _selectedFile;
  bool _isUploading = false;

  // Función para seleccionar el archivo
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
      debugPrint("Error al seleccionar archivo: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al abrir el selector de archivos')),
      );
    }
  }

  // Función simulada para subir a AWS S3 / Backend
  Future<void> _uploadDocument() async {
    if (_selectedFile == null) return;
    setState(() => _isUploading = true);

    try {
      // TODO: Aquí va tu lógica de subida a tu backend
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estudio subido exitosamente'), backgroundColor: Colors.green),
      );

      setState(() {
        _selectedFile = null;
        _selectedFileName = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // Abre el PDF en un modal de pantalla completa
  void _showPdfViewer(BuildContext context) {
    if (_selectedFile == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 1,
            title: Text(
              _selectedFileName ?? "Documento",
              style: const TextStyle(color: KeepiColors.slate, fontSize: 16),
            ),
            leading: IconButton(
              icon: const Icon(Icons.close_rounded, color: KeepiColors.slate),
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
      appBar: AppBar(
        leadingWidth: 0, 
        leading: const SizedBox.shrink(),
        title: Row(
          children: [
            Image.network(
              'https://raw.githubusercontent.com/AlejandroCastillo2406/Keepi_Front/master/assets/images/logo.png',
              height: 28, 
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2));
              },
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey),
            ),
            const SizedBox(width: 10),
            const Text(
              'Keepi',
              style: TextStyle(color: Color(0xFFD17842), fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: KeepiColors.slate),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
            },
          ),
          TextButton.icon(
            onPressed: () => auth.logout(),
            icon: const Icon(Icons.logout_rounded, size: 18, color: KeepiColors.slate),
            label: const Text('Salir', style: TextStyle(color: KeepiColors.slate)),
          ),
        ],
      ),
      body: DecorativeBackground(
        blobOpacity: 0.12,
        child: SafeArea(
          child: IndexedStack(
            index: _currentIndex, 
            children: [
              _buildHomeContent(context, auth), 
              const SizedBox.shrink(),          
              _buildConsultasContent(),         
              const Center(child: Text("Perfil en construcción")), 
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // --- SECCIÓN HISTORY (INICIO) ACTUALIZADA (VACÍA) ---
  Widget _buildHomeContent(BuildContext context, AuthProvider auth) {
    // TODO: CONECTAR CON TU BACKEND
    // La lista está vacía simulando que no hay estudios aún
    final List<Map<String, String>> historialEstudios = [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hola, ${auth.name ?? "Thistan"}', 
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: KeepiColors.slate,
                ),
          ),
          const SizedBox(height: 8),
          const Text("Tu salud es nuestra prioridad hoy.", style: TextStyle(color: KeepiColors.slateLight, fontSize: 16)),
          
          const SizedBox(height: 32),
          const Text("Historial de Estudios", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: KeepiColors.slate)),
          const SizedBox(height: 12),
          
          // Generar la lista de estudios o el estado vacío
          if (historialEstudios.isNotEmpty)
            ...historialEstudios.map((estudio) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildStudyHistoryItem(
                nombre: estudio["nombre"]!, 
                fecha: estudio["fecha"]!, 
                estado: estudio["estado"]!
              ),
            ))
          else
            // MENSAJE ACTUALIZADO
            _buildEmptyStateCard("No has subido ningún estudio y tu médico no ha solicitado ninguno.", Icons.history_rounded),
          
          const SizedBox(height: 80), 
        ],
      ),
    );
  }

  Widget _buildStudyHistoryItem({required String nombre, required String fecha, required String estado}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12.withOpacity(0.05)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: Color(0xFFF8FAFC), shape: BoxShape.circle),
            child: const Icon(Icons.description_rounded, color: KeepiColors.slateLight, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: KeepiColors.slate)),
                const SizedBox(height: 4),
                Text(fecha, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const SizedBox(height: 4),
                Text(estado, style: const TextStyle(color: Color(0xFFD35400), fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
        ],
      ),
    );
  }

  // --- SECCIÓN DE CONSULTAS ---
  Widget _buildConsultasContent() {
    // CONDICIÓN: Al ser FALSE, muestra que el médico no ha solicitado nada
    bool estudioRequerido = false; 

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Consultas', 
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: KeepiColors.slate),
          ),
          const SizedBox(height: 8),
          const Text("Gestiona tus citas médicas y estudios solicitados.", style: TextStyle(color: KeepiColors.slateLight, fontSize: 16)),
          
          const SizedBox(height: 32),
          const Text("Documentos Pendientes", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: KeepiColors.slate)),
          const SizedBox(height: 12),

          if (estudioRequerido)
            _buildUploadDocumentCard()
          else
            _buildEmptyStateCard("Tu médico no ha solicitado ningún estudio.", Icons.check_circle_outline_rounded),
            
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildUploadDocumentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black12.withOpacity(0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          _buildPreviewArea(),
          
          const SizedBox(height: 16),
          Text(
            _selectedFileName != null ? "Archivo listo" : "Estudio Solicitado",
            style: const TextStyle(color: KeepiColors.slate, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFileName ?? "Tu médico ha solicitado que subas un PDF, imagen o fotografía de tus resultados médicos recientes.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _selectedFileName != null ? const Color(0xFFD35400) : Colors.grey.shade600,
              fontSize: 14, height: 1.5,
              fontWeight: _selectedFileName != null ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity, 
            child: _selectedFileName == null 
              ? ElevatedButton.icon(
                  onPressed: _pickDocument,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9), 
                    foregroundColor: KeepiColors.slate,
                    elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.attach_file, size: 20),
                  label: const Text("Seleccionar Documento", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                )
              : ElevatedButton.icon(
                  onPressed: _isUploading ? null : _uploadDocument,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD35400),
                    foregroundColor: Colors.white,
                    elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _isUploading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.cloud_upload_rounded, size: 20),
                  label: Text(
                    _isUploading ? "Subiendo..." : "Confirmar y Subir",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
          ),
          
          if (_selectedFileName != null && !_isUploading) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedFile = null;
                  _selectedFileName = null;
                });
              },
              child: const Text("Elegir otro archivo", style: TextStyle(color: Colors.grey)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewArea() {
    final isImage = _selectedFile != null && ['jpg', 'jpeg', 'png'].contains(_selectedFile!.extension?.toLowerCase());
    final isPdf = _selectedFile != null && _selectedFile!.extension?.toLowerCase() == 'pdf';

    if (_selectedFile == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(color: Color(0xFFFFF4ED), shape: BoxShape.circle),
        child: const Icon(Icons.cloud_upload_outlined, color: Color(0xFFD35400), size: 40),
      );
    }
    
    if (isImage) {
      return ClipRRect( 
        borderRadius: BorderRadius.circular(16),
        child: kIsWeb 
            ? Image.memory(_selectedFile!.bytes!, height: 120, width: 120, fit: BoxFit.cover)
            : Image.file(File(_selectedFile!.path!), height: 120, width: 120, fit: BoxFit.cover),
      );
    }
    
    if (isPdf) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: Color(0xFFFFF4ED), shape: BoxShape.circle),
            child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFD35400), size: 40),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _showPdfViewer(context),
            icon: const Icon(Icons.fullscreen_rounded, size: 18),
            label: const Text("Ver Documento"),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFD35400),
              side: const BorderSide(color: Color(0xFFD35400)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          )
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: Color(0xFFFFF4ED), shape: BoxShape.circle),
      child: const Icon(Icons.insert_drive_file, color: Color(0xFFD35400), size: 40),
    );
  }

  Widget _buildEmptyStateCard(String message, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black12.withOpacity(0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: Color(0xFFF8FAFC), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.grey.shade400, size: 40),
          ),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 15, height: 1.5, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(0, Icons.history, "History"),
          _navItem(1, Icons.medical_services_outlined, "Recetas"),
          _navItem(2, Icons.videocam, "Consultas"),
          _navItem(3, Icons.person_outline, "Perfil"),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    bool isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        if (index == 1) {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PatientPrescriptionsScreen()));
          return;
        }
        setState(() => _currentIndex = index);
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFFFF4ED) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: isActive ? const Color(0xFFD35400) : Colors.grey),
          ),
          Text(label, style: TextStyle(color: isActive ? const Color(0xFFD35400) : Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}