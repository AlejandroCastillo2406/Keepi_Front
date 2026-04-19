import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/decorative_background.dart';
import '../../providers/auth_provider.dart';
import '../user/settings_screen.dart';
import 'create_patient_screen.dart';
import '../../services/api_client.dart';
import '../../services/doctor_service.dart';

// Importaciones existentes
import 'doctor_calendar_tab.dart'; 
import 'documentos_screen.dart';
import 'doctor_assign_prescription_screen.dart';
import 'doctor_patient_medical_record_screen.dart';
import '../common/notifications_screen.dart';

// ¡IMPORTACIÓN CLAVE PARA USAR LA PANTALLA REAL QUE SÍ TIENE LA API!
import 'doctor_request_analysis_screen.dart'; 

class DoctorHomeScreen extends StatefulWidget {
  const DoctorHomeScreen({super.key});

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  int _currentTabIndex = 2;
  List<PatientListItem> _patients = [];
  bool _loadingList = true;
  String? _listError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPatients());
  }

  Future<void> _loadPatients() async {
    final svc = DoctorService(context.read<ApiClient>());
    setState(() {
      _loadingList = true;
      _listError = null;
    });

    try {
      final list = await svc.fetchMyPatients();
      if (!mounted) return;
      setState(() {
        _patients = list;
        _loadingList = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _listError = DoctorService.messageFromDio(e);
        _loadingList = false;
      });
    }
  }

  Future<void> _handleScheduleAppointment(PatientListItem patient) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: KeepiColors.orange),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null || !mounted) return;

    TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (pickedTime == null || !mounted) return;

    final finalDateTime = DateTime(
      pickedDate.year, pickedDate.month, pickedDate.day,
      pickedTime.hour, pickedTime.minute,
    );

    try {
      final svc = DoctorService(context.read<ApiClient>());
      await svc.scheduleAppointment(
        patientId: patient.id,
        date: finalDateTime,
        reason: "Consulta Médica",
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cita agendada correctamente'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${DoctorService.messageFromDio(e)}'), backgroundColor: Colors.red),
      );
    }
  }

  void _navigateToSettings() {
    Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const SettingsScreen()));
  }

  Future<void> _openCreatePatientSheet() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CreatePatientScreen(api: context.read<ApiClient>())),
    );
    if (created == true && mounted) await _loadPatients();
  }

  // --- NAVEGACIÓN A TUS 3 BOTONES DEL MENÚ ---
  
  // 1. SOLICITAR ANÁLISIS (ESTE AHORA ABRE EL ARCHIVO REAL)
  Future<void> _openRequestAnalysis(PatientListItem patient) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DoctorRequestAnalysisScreen(
          patientId: patient.id,
          patientName: patient.name,
        ),
      ),
    );
  }

  // 2. VER EXPEDIENTE MÉDICO
  Future<void> _openMedicalRecord(PatientListItem patient) async {
    final svc = DoctorService(context.read<ApiClient>());
    try {
      final record = await svc.fetchPatientMedicalRecord(patient.id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DoctorPatientMedicalRecordScreen( 
            patientName: patient.name,
            patientId: patient.id,
            record: record,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DoctorService.messageFromDio(e))),
      );
    }
  }

  // 3. ASIGNAR RECETA
  Future<void> _openAssignPrescription(PatientListItem patient) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DoctorAssignPrescriptionScreen(
          patientId: patient.id,
          patientName: patient.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: KeepiColors.surfaceBg,
      appBar: _buildAppBar(),
      floatingActionButton: _buildDynamicFAB(),
      bottomNavigationBar: _buildBottomNav(),
      body: DecorativeBackground(
        blobOpacity: 0.08,
        child: SafeArea(
          child: IndexedStack(
            index: _currentTabIndex,
            children: [
              _buildPlaceholderTab('Pacientes'),
              const DocumentosScreen(),
              _buildDashboard(auth),
              const DoctorCalendarTab(),
              _buildPlaceholderTab('Reportes'),
              _buildPlaceholderTab('Pacientes'),
              const DocumentosScreen(),
              _buildDashboard(auth),
              const DoctorCalendarTab(),
              _buildPlaceholderTab('Reportes'),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white.withOpacity(0.9),
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Row(
        children: [
          _LogoIcon(),
          const SizedBox(width: 12),
          const Text('Keepi', style: TextStyle(fontWeight: FontWeight.w800, color: KeepiColors.orange, letterSpacing: -0.5)),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded, color: KeepiColors.slate),
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
          },
        ),
        IconButton(icon: const Icon(Icons.settings_rounded, color: KeepiColors.slate), onPressed: _navigateToSettings),
        TextButton.icon(
          onPressed: () => context.read<AuthProvider>().logout(),
          icon: const Icon(Icons.logout_rounded, size: 18, color: KeepiColors.slate),
          label: const Text('Salir', style: TextStyle(color: KeepiColors.slate)),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget? _buildDynamicFAB() {
    if (_currentTabIndex == 2) {
      return FloatingActionButton.extended(
        onPressed: _openCreatePatientSheet,
        backgroundColor: KeepiColors.orange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Nuevo paciente', style: TextStyle(fontWeight: FontWeight.w600)),
      );
    } else if (_currentTabIndex == 1) {
      return FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: KeepiColors.orange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.upload_file_rounded),
        label: const Text('Subir documento', style: TextStyle(fontWeight: FontWeight.w600)),
      );
    }
    return null;
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [BoxShadow(color: KeepiColors.slate.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BottomNavigationBar(
          currentIndex: _currentTabIndex,
          onTap: (index) => setState(() => _currentTabIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: KeepiColors.orange,
          unselectedItemColor: KeepiColors.slateLight,
          items: _navItems,
        ),
      ),
    );
  }

  Widget _buildDashboard(AuthProvider auth) {
    return RefreshIndicator(
      onRefresh: _loadPatients,
      color: KeepiColors.orange,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(auth),
            const SizedBox(height: 28),
            if (_listError != null) _ErrorCard(message: _listError!),
            _buildStats(),
            const SizedBox(height: 36),
            Text('Tus Pacientes', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: KeepiColors.slate)),
            const SizedBox(height: 16),
            _buildPatientList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AuthProvider auth) {
    final firstName = auth.name?.split(' ').first ?? "";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Panel del Dr. $firstName', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: KeepiColors.slate)),
        const SizedBox(height: 6),
        const Text('Gestiona tus pacientes y citas registradas.', style: TextStyle(color: KeepiColors.slateLight, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildStats() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.group_rounded,
            iconColor: KeepiColors.orange,
            bgColor: KeepiColors.orangeSoft,
            title: 'Pacientes Registrados',
            value: _loadingList ? '...' : _patients.length.toString(),
          ),
        ),
        const Expanded(child: SizedBox()),
      ],
    );
  }

  Widget _buildPatientList() {
    if (_loadingList && _patients.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 32), child: CircularProgressIndicator(color: KeepiColors.orange)));
    }
    if (_patients.isEmpty) return const _EmptyPatientsView();

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _patients.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _PatientTile(
        patient: _patients[index],
        onViewMedicalRecord: () => _openMedicalRecord(_patients[index]),
        onAssignPrescription: () => _openAssignPrescription(_patients[index]),
        onRequestAnalysis: () => _openRequestAnalysis(_patients[index]),
      ),
    );
  }

  Widget _buildPlaceholderTab(String title) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.construction_rounded, size: 64, color: KeepiColors.slateLight.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: KeepiColors.slate)),
          const Text('Próximamente', style: TextStyle(color: KeepiColors.slateLight)),
        ],
      ),
    );
  }

  static const _navItems = [
    BottomNavigationBarItem(icon: Icon(Icons.people_alt_outlined), activeIcon: Icon(Icons.people_alt_rounded), label: 'Pacientes'),
    BottomNavigationBarItem(icon: Icon(Icons.description_outlined), activeIcon: Icon(Icons.description_rounded), label: 'Documentos'),
    BottomNavigationBarItem(icon: Padding(padding: EdgeInsets.only(bottom: 4), child: Icon(Icons.home_rounded, size: 28)), label: 'Inicio'),
    BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), activeIcon: Icon(Icons.calendar_month_rounded), label: 'Calendario'),
    BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), activeIcon: Icon(Icons.analytics_rounded), label: 'Reportes'),
  ];
}

// --- Supporting Specialized Widgets ---

class _LogoIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.asset(
        'assets/logo.png',
        height: 32, width: 32, fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(Icons.folder_rounded, size: 32, color: KeepiColors.orange),
      ),
    );
  }
}

class _PatientTile extends StatelessWidget {
  final PatientListItem patient;
  final VoidCallback onViewMedicalRecord;
  final VoidCallback onAssignPrescription;
  final VoidCallback onRequestAnalysis;

  const _PatientTile({
    required this.patient,
    required this.onViewMedicalRecord,
    required this.onAssignPrescription,
    required this.onRequestAnalysis,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: KeepiColors.skyBlueSoft,
          child: Text(patient.name.isNotEmpty ? patient.name[0].toUpperCase() : '?', style: const TextStyle(color: KeepiColors.skyBlue, fontWeight: FontWeight.w800)),
        ),
        title: Text(patient.name, style: const TextStyle(fontWeight: FontWeight.w700, color: KeepiColors.slate)),
        subtitle: Text(patient.email, style: const TextStyle(color: KeepiColors.slateLight, fontSize: 13)),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: KeepiColors.slateLight),
          onSelected: (value) {
            if (value == 'medical_record') onViewMedicalRecord();
            if (value == 'assign_prescription') onAssignPrescription();
            if (value == 'request_analysis') onRequestAnalysis();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'medical_record', child: Text('Ver expediente médico')),
            PopupMenuItem(value: 'assign_prescription', child: Text('Asignar receta')),
            PopupMenuItem(value: 'request_analysis', child: Text('Solicitar análisis')),
          ],
        ),
      ),
    );
  }
}


class _EmptyPatientsView extends StatelessWidget {
  const _EmptyPatientsView();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      decoration: _cardDecoration,
      child: Column(
        children: [
          Icon(Icons.people_outline_rounded, size: 48, color: KeepiColors.slateLight.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text('Aún no hay pacientes', style: TextStyle(color: KeepiColors.slateLight, fontWeight: FontWeight.w600, fontSize: 16)),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.red.shade100)),
      child: Row(children: [const Icon(Icons.error_outline_rounded, color: Colors.red), const SizedBox(width: 12), Expanded(child: Text(message))]),
    );
  }
}

final _cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: KeepiColors.cardBorder.withOpacity(0.5)),
  boxShadow: [BoxShadow(color: KeepiColors.slate.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
);

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.iconColor, required this.bgColor, required this.title, required this.value});
  final IconData icon; final Color iconColor; final Color bgColor; final String title; final String value;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration.copyWith(borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: iconColor, size: 24)),
          const SizedBox(height: 16),
          Text(title.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: KeepiColors.slateLight)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: KeepiColors.slate)),
        ],
      ),
    );
  }
}