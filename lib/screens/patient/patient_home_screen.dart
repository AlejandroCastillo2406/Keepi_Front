import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  int _currentIndex = 0; // Control de navegación inferior

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        // QUITAMOS el leading (avatar) para que el título se pegue a la izquierda
        leadingWidth: 0, 
        leading: const SizedBox.shrink(),
        // Usamos un Row en el title para poner logo y texto juntos
        title: Row(
          children: [
            // --- NUEVO LOGO DESDE GITHUB ---
            Image.network(
              // Usamos la URL 'raw' para que Flutter pueda descargar la imagen
              'https://raw.githubusercontent.com/AlejandroCastillo2406/Keepi_Front/master/assets/images/logo.png',
              height: 28, // Ajusta la altura según lo necesites
              fit: BoxFit.contain,
              // Muestra un indicador de carga mientras baja la imagen
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2));
              },
              // Manejo de error si no hay internet o la URL falla
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey),
            ),
            const SizedBox(width: 10), // Espacio entre logo y texto
            // --- TEXTO MODIFICADO (SOLO KEEPI) ---
            const Text(
              'Keepi',
              style: TextStyle(
                color: Color(0xFFD17842), // Naranja original
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: KeepiColors.slate),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
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
            index: _currentIndex == 0 ? 0 : 1, // Cambia entre Home y otras secciones
            children: [
              _buildHomeContent(context, auth),
              const Center(child: Text("Sección en construcción")),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFFD35400), // Naranja del FAB
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
    );
  }

  Widget _buildHomeContent(BuildContext context, AuthProvider auth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hola, ${auth.name ?? "Thistan"}', // Usamos el nombre del Provider o Thistan por defecto
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: KeepiColors.slate,
                ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Tu salud es nuestra prioridad hoy.",
            style: TextStyle(color: KeepiColors.slateLight, fontSize: 16),
          ),
          
          const SizedBox(height: 32),
          const Text("Próxima Cita", 
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: KeepiColors.slate)),
          const SizedBox(height: 12),

          // --- ESTADO: REQUIERE MÉDICO ASIGNADO ---
          _buildEmptyStateCard(
            "Para acceder a esta función debes de estar asignado a un médico.",
            Icons.lock_outline_rounded,
          ),

          const SizedBox(height: 32),
          const Text("Documentos Recientes", 
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: KeepiColors.slate)),
          const SizedBox(height: 12),

          // --- ESTADO: SIN DOCUMENTOS ---
          _buildEmptyStateCard(
            "Aún no tienes documentos o recetas registradas.",
            Icons.folder_off_outlined,
          ),
          
          const SizedBox(height: 80), // Espacio para el FAB
        ],
      ),
    );
  }

  // Widget genérico para estados vacíos o bloqueados
  Widget _buildEmptyStateCard(String message, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black12.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.grey.shade400, size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600, 
              fontSize: 15, 
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Navegación inferior funcional
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
          _navItem(1, Icons.medical_services_outlined, "Prescriptions"),
          _navItem(2, Icons.videocam, "Consults"),
          _navItem(3, Icons.person_outline, "Profile"),
        ],
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    bool isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        if (index == 1) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PatientPrescriptionsScreen()),
          );
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