import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/decorative_background.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../services/doctor_service.dart';

/// Panel médico: alta de pacientes (POST) y lista (GET) vía API.
class DoctorHomeScreen extends StatefulWidget {
  const DoctorHomeScreen({super.key});

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  List<PatientListItem> _patients = [];
  bool _loadingList = true;
  String? _listError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPatients());
  }

  Future<void> _loadPatients() async {
    final api = context.read<ApiClient>();
    final svc = DoctorService(api);
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

  Future<void> _openCreatePatientSheet() async {
    final api = context.read<ApiClient>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var submitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom),
          child: StatefulBuilder(
            builder: (_, setModalState) {
              return LiquidGlassCard(
                borderRadius: 22,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                blurSigma: 12,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Nuevo paciente',
                              style: Theme.of(sheetCtx).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: KeepiColors.slate,
                                  ),
                            ),
                          ),
                          IconButton(
                            onPressed: submitting ? null : () => Navigator.pop(sheetCtx),
                            icon: const Icon(Icons.close_rounded),
                            color: KeepiColors.slateLight,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Se enviará una contraseña temporal al correo del paciente.',
                        style: Theme.of(sheetCtx).textTheme.bodySmall?.copyWith(color: KeepiColors.slateLight),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: nameCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nombre completo',
                          prefixIcon: Icon(Icons.person_outline_rounded, size: 22),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                          prefixIcon: Icon(Icons.email_outlined, size: 22),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Requerido';
                          if (!v.contains('@')) return 'Correo no válido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: submitting
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setModalState(() => submitting = true);
                                final svc = DoctorService(api);
                                try {
                                  final r = await svc.createPatient(
                                    name: nameCtrl.text,
                                    email: emailCtrl.text,
                                  );
                                  if (!sheetCtx.mounted) return;
                                  Navigator.pop(sheetCtx);
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Paciente creado. Credenciales enviadas a ${r.email}',
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  await _loadPatients();
                                } catch (e) {
                                  setModalState(() => submitting = false);
                                  if (!sheetCtx.mounted) return;
                                  ScaffoldMessenger.of(sheetCtx).showSnackBar(
                                    SnackBar(
                                      content: Text(DoctorService.messageFromDio(e)),
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: Colors.red.shade800,
                                    ),
                                  );
                                }
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: KeepiColors.orange,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: submitting
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Crear y enviar acceso'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
    nameCtrl.dispose();
    emailCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel médico'),
        backgroundColor: Colors.white,
        foregroundColor: KeepiColors.slate,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Actualizar lista',
            onPressed: _loadingList ? null : _loadPatients,
            icon: _loadingList
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
          TextButton(
            onPressed: () => auth.logout(),
            child: const Text('Salir'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreatePatientSheet,
        backgroundColor: KeepiColors.orange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Nuevo paciente'),
      ),
      body: DecorativeBackground(
        blobOpacity: 0.12,
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadPatients,
            color: KeepiColors.orange,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Text(
                        'Hola, ${auth.name ?? "doctor"}',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: KeepiColors.slate,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pacientes registrados por ti. El acceso provisional llega por correo.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: KeepiColors.slateLight),
                      ),
                      const SizedBox(height: 24),
                      if (_listError != null)
                        Card(
                          elevation: 0,
                          color: Colors.red.shade50,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline_rounded, color: Colors.red.shade800),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _listError!,
                                    style: TextStyle(color: Colors.red.shade900, height: 1.35),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_loadingList && _patients.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 48),
                          child: Center(child: CircularProgressIndicator(color: KeepiColors.orange)),
                        )
                      else if (!_loadingList && _patients.isEmpty && _listError == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 48),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.people_outline_rounded, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  'Aún no hay pacientes',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: KeepiColors.slateLight,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: _openCreatePatientSheet,
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('Dar de alta al primero'),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ]),
                  ),
                ),
                if (_patients.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final p = _patients[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Card(
                              elevation: 0,
                              color: Colors.white.withOpacity(0.9),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(color: KeepiColors.cardBorder.withOpacity(0.6)),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: CircleAvatar(
                                  backgroundColor: KeepiColors.orangeSoft,
                                  child: Text(
                                    p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                                    style: const TextStyle(
                                      color: KeepiColors.orange,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  p.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600, color: KeepiColors.slate),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(p.email, style: const TextStyle(fontSize: 13)),
                                    if (p.createdAt != null)
                                      Text(
                                        p.createdAt!,
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                  ],
                                ),
                                trailing: p.mustChangePassword
                                    ? Tooltip(
                                        message: 'Debe cambiar contraseña temporal',
                                        child: Icon(Icons.mark_email_unread_outlined, color: Colors.amber.shade800),
                                      )
                                    : const Icon(Icons.check_circle_outline_rounded, color: Colors.green),
                              ),
                            ),
                          );
                        },
                        childCount: _patients.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
