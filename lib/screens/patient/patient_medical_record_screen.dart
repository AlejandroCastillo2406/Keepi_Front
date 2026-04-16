import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/decorative_background.dart';
import '../../services/api_client.dart';
import '../../services/patient_medical_record_service.dart';

/// El paciente consulta y edita su expediente (GET/PATCH `/me/medical-record`).
class PatientMedicalRecordScreen extends StatefulWidget {
  const PatientMedicalRecordScreen({super.key});

  @override
  State<PatientMedicalRecordScreen> createState() => _PatientMedicalRecordScreenState();
}

class _PatientMedicalRecordScreenState extends State<PatientMedicalRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _birthCtrl;
  late final TextEditingController _sexCtrl;
  late final TextEditingController _bloodCtrl;
  late final TextEditingController _allergiesCtrl;
  late final TextEditingController _chronicCtrl;
  late final TextEditingController _medsCtrl;
  late final TextEditingController _surgicalCtrl;
  late final TextEditingController _familyCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _emergNameCtrl;
  late final TextEditingController _emergPhoneCtrl;

  MedicalRecordDto? _initial;
  bool _loading = true;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _birthCtrl = TextEditingController();
    _sexCtrl = TextEditingController();
    _bloodCtrl = TextEditingController();
    _allergiesCtrl = TextEditingController();
    _chronicCtrl = TextEditingController();
    _medsCtrl = TextEditingController();
    _surgicalCtrl = TextEditingController();
    _familyCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
    _emergNameCtrl = TextEditingController();
    _emergPhoneCtrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _applyDto(MedicalRecordDto d) {
    _birthCtrl.text = d.birthDate ?? '';
    _sexCtrl.text = d.sex ?? '';
    _bloodCtrl.text = d.bloodType ?? '';
    _allergiesCtrl.text = d.allergies ?? '';
    _chronicCtrl.text = d.chronicConditions ?? '';
    _medsCtrl.text = d.medications ?? '';
    _surgicalCtrl.text = d.surgicalHistory ?? '';
    _familyCtrl.text = d.familyHistory ?? '';
    _notesCtrl.text = d.notes ?? '';
    _emergNameCtrl.text = d.emergencyContactName ?? '';
    _emergPhoneCtrl.text = d.emergencyContactPhone ?? '';
  }

  Future<void> _load() async {
    final api = context.read<ApiClient>();
    final svc = PatientMedicalRecordService(api);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await svc.fetchMine();
      if (!mounted) return;
      _applyDto(d);
      setState(() {
        _initial = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = PatientMedicalRecordService.messageFromDio(e);
        _loading = false;
      });
    }
  }

  Map<String, dynamic> _buildPatch() {
    final i = _initial;
    if (i == null) return {};
    String z(String? x) => x ?? '';

    final patch = <String, dynamic>{};
    void diff(String key, String now, String was) {
      final n = now.trim();
      final w = was.trim();
      if (n != w) {
        patch[key] = n.isEmpty ? null : n;
      }
    }

    diff('birth_date', _birthCtrl.text, z(i.birthDate));
    diff('sex', _sexCtrl.text, z(i.sex));
    diff('blood_type', _bloodCtrl.text, z(i.bloodType));
    diff('allergies', _allergiesCtrl.text, z(i.allergies));
    diff('chronic_conditions', _chronicCtrl.text, z(i.chronicConditions));
    diff('medications', _medsCtrl.text, z(i.medications));
    diff('surgical_history', _surgicalCtrl.text, z(i.surgicalHistory));
    diff('family_history', _familyCtrl.text, z(i.familyHistory));
    diff('notes', _notesCtrl.text, z(i.notes));
    diff('emergency_contact_name', _emergNameCtrl.text, z(i.emergencyContactName));
    diff('emergency_contact_phone', _emergPhoneCtrl.text, z(i.emergencyContactPhone));
    return patch;
  }

  Future<void> _save() async {
    final patch = _buildPatch();
    if (patch.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay cambios para guardar')),
      );
      return;
    }
    final api = context.read<ApiClient>();
    final svc = PatientMedicalRecordService(api);
    setState(() => _saving = true);
    try {
      final updated = await svc.patchMine(patch);
      if (!mounted) return;
      setState(() {
        _initial = updated;
        _saving = false;
      });
      _applyDto(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expediente actualizado')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(PatientMedicalRecordService.messageFromDio(e))),
      );
    }
  }

  @override
  void dispose() {
    _birthCtrl.dispose();
    _sexCtrl.dispose();
    _bloodCtrl.dispose();
    _allergiesCtrl.dispose();
    _chronicCtrl.dispose();
    _medsCtrl.dispose();
    _surgicalCtrl.dispose();
    _familyCtrl.dispose();
    _notesCtrl.dispose();
    _emergNameCtrl.dispose();
    _emergPhoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi expediente médico'),
        backgroundColor: Colors.white,
        foregroundColor: KeepiColors.slate,
        elevation: 0,
        actions: [
          if (!_loading && _error == null)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar'),
            ),
        ],
      ),
      body: DecorativeBackground(
        blobOpacity: 0.1,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: KeepiColors.orange))
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _load,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  )
                : SafeArea(
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          Text(
                            'Puedes corregir o completar la información. Tu médico verá los datos iniciales que registró al darte de alta.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: KeepiColors.slateLight,
                                ),
                          ),
                          const SizedBox(height: 20),
                          _field(_birthCtrl, 'Fecha de nacimiento (AAAA-MM-DD)', Icons.cake_outlined),
                          _field(_sexCtrl, 'Sexo', Icons.wc_outlined),
                          _field(_bloodCtrl, 'Tipo de sangre', Icons.bloodtype_outlined),
                          _area(_allergiesCtrl, 'Alergias'),
                          _area(_chronicCtrl, 'Enfermedades crónicas'),
                          _area(_medsCtrl, 'Medicación actual'),
                          _area(_surgicalCtrl, 'Antecedentes quirúrgicos'),
                          _area(_familyCtrl, 'Antecedentes familiares'),
                          _area(_notesCtrl, 'Notas'),
                          _field(_emergNameCtrl, 'Contacto de emergencia — nombre', Icons.contact_emergency_outlined),
                          _field(_emergPhoneCtrl, 'Contacto de emergencia — teléfono', Icons.phone_outlined),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 22)),
      ),
    );
  }

  Widget _area(TextEditingController c, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: label,
          alignLabelWithHint: true,
        ),
      ),
    );
  }
}
