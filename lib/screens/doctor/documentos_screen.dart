import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import 'documentos_service.dart';

class DocumentosScreen extends StatefulWidget {
  const DocumentosScreen({Key? key}) : super(key: key);

  @override
  State<DocumentosScreen> createState() => _DocumentosScreenState();
}

class _DocumentosScreenState extends State<DocumentosScreen> {
  late Future<Map<String, dynamic>> _dashboardFuture;
  late DocumentosService _documentosService;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final api = context.read<ApiClient>();
      _documentosService = DocumentosService(api);
      _dashboardFuture = _documentosService.fetchDashboard(limit: 10);
      _initialized = true;
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _dashboardFuture = _documentosService.fetchDashboard(limit: 10);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Retornamos directamente el contenido para que DoctorHomeScreen lo maneje
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: KeepiColors.orange,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: KeepiColors.orange),
            );
          }
          
          if (snapshot.hasError) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: Colors.red.shade800),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Error al cargar documentos:\n${snapshot.error}',
                        style: TextStyle(color: Colors.red.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;
          final int totalKeepi = data['total_keepi'] ?? 0;
          final int expiringCount = data['expiring_soon_count'] ?? 0;
          final List<dynamic> folders = data['folders'] ?? []; 

          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // Título de la sección (ya que quitamos el AppBar interno)
              Text(
                'Gestión Documental',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: KeepiColors.slate,
                ),
              ),
              const SizedBox(height: 20),

              // Tarjetas de resumen
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      title: 'Total Archivos',
                      count: totalKeepi.toString(),
                      bgColor: KeepiColors.skyBlueSoft,
                      iconColor: KeepiColors.skyBlue,
                      icon: Icons.folder_rounded,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSummaryCard(
                      title: 'Vencimientos',
                      count: expiringCount.toString(),
                      bgColor: Colors.red.shade50,
                      iconColor: Colors.red.shade400,
                      icon: Icons.warning_amber_rounded,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 36),
              
              Text(
                'Carpetas Recientes',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: KeepiColors.slate,
                ),
              ),
              const SizedBox(height: 16),
              
              if (folders.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: KeepiColors.cardBorder.withOpacity(0.5)),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.folder_open_rounded, 
                          size: 48, 
                          color: KeepiColors.slateLight.withOpacity(0.5)
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No hay documentos activos', 
                          style: TextStyle(
                            color: KeepiColors.slateLight, 
                            fontWeight: FontWeight.w600, 
                            fontSize: 16
                          )
                        ),
                      ],
                    ),
                  ),
                )
              else
                Text(
                  'Tienes ${folders.length} carpetas disponibles.', 
                  style: const TextStyle(color: KeepiColors.slate)
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title, 
    required String count, 
    required Color bgColor, 
    required Color iconColor, 
    required IconData icon
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KeepiColors.cardBorder.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: KeepiColors.slate.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: KeepiColors.slateLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: KeepiColors.slate,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}