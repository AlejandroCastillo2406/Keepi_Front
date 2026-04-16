import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import '../../services/prescription_service.dart';

class PatientPrescriptionsScreen extends StatefulWidget {
  const PatientPrescriptionsScreen({super.key});

  @override
  State<PatientPrescriptionsScreen> createState() => _PatientPrescriptionsScreenState();
}

class _PatientPrescriptionsScreenState extends State<PatientPrescriptionsScreen> {
  bool _loading = true;
  String? _error;
  List<PrescriptionDto> _items = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final svc = PrescriptionService(context.read<ApiClient>());
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await svc.fetchMine();
      if (!mounted) return;
      setState(() {
        _items = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = PrescriptionService.messageFromDio(e);
        _loading = false;
      });
    }
  }

  Future<void> _openScan(PrescriptionDto p) async {
    final svc = PrescriptionService(context.read<ApiClient>());
    try {
      final url = await svc.getScanUrl(p.id);
      if (url.isEmpty) return;
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(PrescriptionService.messageFromDio(e))));
    }
  }

  Future<void> _toggleReminder(PrescriptionDto p, bool enabled) async {
    final svc = PrescriptionService(context.read<ApiClient>());
    try {
      await svc.setReminderOptIn(p.id, enabled);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(enabled ? 'Recordatorios activados' : 'Recordatorios desactivados')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(PrescriptionService.messageFromDio(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis recetas'),
        backgroundColor: Colors.white,
        foregroundColor: KeepiColors.slate,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: KeepiColors.orange))
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final p = _items[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Doctor: ${p.doctorName ?? "N/A"}', style: const TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text('Archivo: ${p.sourceFileName ?? "Sin nombre"}'),
                              const SizedBox(height: 8),
                              ...p.items.map((i) => Text('• ${i.medication} (${i.everyHours ?? "-"}h, ${i.durationDays ?? "-"} días)')),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _openScan(p),
                                    icon: const Icon(Icons.picture_as_pdf_outlined),
                                    label: const Text('Ver receta escaneada'),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: SwitchListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text('Recordatorios'),
                                      value: p.remindersEnabled,
                                      onChanged: (v) => _toggleReminder(p, v),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

