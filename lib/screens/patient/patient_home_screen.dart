import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/decorative_background.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../services/config_service.dart' as config_dto;
import '../../services/doctor_service.dart';
import '../common/notifications_screen.dart';
import '../common/storage_choice_flow.dart';
import 'patient_prescriptions_screen.dart';
import 'patient_upload_analysis_screen.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  int _currentIndex = 0;

  final FirstRunStorageGate _storageGate = FirstRunStorageGate();
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri?>? _linkSubscription;

  List<AnalysisRequestDto> _pendingAnalysisRequests = [];
  bool _loadingConsultas = false;
  String? _consultasError;

  @override
  void initState() {
    super.initState();
    _listenForStorageDeepLinks();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserConfigForStorage();
      _loadPendingAnalysisRequests();
    });
  }

  Future<void> _loadPendingAnalysisRequests() async {
    setState(() {
      _loadingConsultas = true;
      _consultasError = null;
    });
    try {
      final api = context.read<ApiClient>();
      final list = await DoctorService(api).fetchMyPendingRequests();
      if (!mounted) return;
      setState(() {
        _pendingAnalysisRequests = list;
        _loadingConsultas = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _consultasError = DoctorService.messageFromDio(e);
        _loadingConsultas = false;
      });
    }
  }

  Future<void> _openUploadForRequest(AnalysisRequestDto req) async {
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PatientUploadAnalysisScreen(
          requestId: req.id,
          description: req.description,
        ),
      ),
    );
    if (done == true && mounted) await _loadPendingAnalysisRequests();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _listenForStorageDeepLinks() {
    _appLinks.getInitialLink().then(_onStorageDeepLink);
    _linkSubscription = _appLinks.uriLinkStream.listen(_onStorageDeepLink);
  }

  void _onStorageDeepLink(Uri? uri) {
    if (uri == null) return;
    final s = uri.toString();
    if (s.contains('oauth2redirect') && uri.queryParameters['success'] == '1' && mounted) {
      _loadUserConfigForStorage();
      return;
    }
    if (s.contains('stripe-success') && mounted) {
      _loadUserConfigForStorage();
    }
  }

  Future<void> _loadUserConfigForStorage() async {
    try {
      final api = context.read<ApiClient>();
      final config = await config_dto.ConfigService(api).getUserConfig();
      if (!mounted) return;
      await maybeShowFirstRunStorageDialog(
        context,
        config: config,
        gate: _storageGate,
        onReloadAfterChoice: _loadUserConfigForStorage,
      );
    } catch (_) {}
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

  // --- SECCIÓN DE CONSULTAS (solicitudes de análisis del doctor) ---
  Widget _buildConsultasContent() {
    return RefreshIndicator(
      color: const Color(0xFFD35400),
      onRefresh: _loadPendingAnalysisRequests,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Consultas',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: KeepiColors.slate),
            ),
            const SizedBox(height: 8),
            const Text(
              'Gestiona tus citas médicas y estudios solicitados.',
              style: TextStyle(color: KeepiColors.slateLight, fontSize: 16),
            ),
            const SizedBox(height: 32),
            const Text(
              'Documentos pendientes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: KeepiColors.slate),
            ),
            const SizedBox(height: 12),
            if (_loadingConsultas)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(color: Color(0xFFD35400))),
              )
            else if (_consultasError != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(_consultasError!, style: TextStyle(color: Colors.red.shade900, fontSize: 14)),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _loadPendingAnalysisRequests,
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              )
            else if (_pendingAnalysisRequests.isEmpty)
              _buildEmptyStateCard(
                'Tu médico no ha solicitado ningún estudio pendiente.',
                Icons.check_circle_outline_rounded,
              )
            else
              ..._pendingAnalysisRequests.map(_buildPendingRequestCard),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingRequestCard(AnalysisRequestDto req) {
    final fecha = _formatRequestDate(req.createdAt);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black12.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(color: Color(0xFFFFF4ED), shape: BoxShape.circle),
                  child: const Icon(Icons.science_outlined, color: Color(0xFFD35400), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Solicitud de tu médico',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: KeepiColors.slate),
                      ),
                      const SizedBox(height: 2),
                      Text(fecha, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              req.description,
              style: const TextStyle(color: KeepiColors.slate, fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openUploadForRequest(req),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD35400),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.cloud_upload_rounded, size: 20),
                label: const Text('Subir estudio', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRequestDate(String iso) {
    if (iso.isEmpty) return '—';
    try {
      final d = DateTime.tryParse(iso);
      if (d == null) return iso;
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return iso;
    }
  }

  Widget _buildEmptyStateCard(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(24),
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
        if (index == 2) {
          _loadPendingAnalysisRequests();
        }
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