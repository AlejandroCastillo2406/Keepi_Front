import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import '../../services/doctor_service.dart';

/// Alta de paciente en pantalla completa: el teclado redimensiona el [Scaffold]
/// (sin bottom sheet + blur, que en Android/MIUI provoca jank y comportamientos raros).
class CreatePatientScreen extends StatefulWidget {
  const CreatePatientScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<CreatePatientScreen> createState() => _CreatePatientScreenState();
}

class _CreatePatientScreenState extends State<CreatePatientScreen> {
  final _formIdentity = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _birthCtrl = TextEditingController();
  final _sexCtrl = TextEditingController();
  final _bloodCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  final _chronicCtrl = TextEditingController();
  final _medsCtrl = TextEditingController();
  final _surgicalCtrl = TextEditingController();
  final _familyCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _emergNameCtrl = TextEditingController();
  final _emergPhoneCtrl = TextEditingController();

  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();

  var _step = 0;
  var _submitting = false;

  static const _scrollPadding = EdgeInsets.only(bottom: 120);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
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
    _nameFocus.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  static Map<String, dynamic> _medicalPayload({
    required String birthDate,
    required String sex,
    required String bloodType,
    required String allergies,
    required String chronic,
    required String medications,
    required String surgical,
    required String family,
    required String notes,
    required String emergName,
    required String emergPhone,
  }) {
    void put(Map<String, dynamic> m, String k, String v) {
      final t = v.trim();
      if (t.isNotEmpty) m[k] = t;
    }

    final m = <String, dynamic>{};
    put(m, 'birth_date', birthDate);
    put(m, 'sex', sex);
    put(m, 'blood_type', bloodType);
    put(m, 'allergies', allergies);
    put(m, 'chronic_conditions', chronic);
    put(m, 'medications', medications);
    put(m, 'surgical_history', surgical);
    put(m, 'family_history', family);
    put(m, 'notes', notes);
    put(m, 'emergency_contact_name', emergName);
    put(m, 'emergency_contact_phone', emergPhone);
    return m;
  }

  bool _identityOk() {
    final n = _nameCtrl.text.trim();
    final e = _emailCtrl.text.trim();
    return n.isNotEmpty && e.isNotEmpty && e.contains('@');
  }

  void _goToMedicalStep() {
    if (!_formIdentity.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _step = 1);
  }

  Future<void> _submit() async {
    if (!_identityOk()) {
      setState(() => _step = 0);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Revisa nombre y correo en el paso 1'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final medical = _medicalPayload(
      birthDate: _birthCtrl.text,
      sex: _sexCtrl.text,
      bloodType: _bloodCtrl.text,
      allergies: _allergiesCtrl.text,
      chronic: _chronicCtrl.text,
      medications: _medsCtrl.text,
      surgical: _surgicalCtrl.text,
      family: _familyCtrl.text,
      notes: _notesCtrl.text,
      emergName: _emergNameCtrl.text,
      emergPhone: _emergPhoneCtrl.text,
    );
    if (medical.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa al menos un campo del expediente médico'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    final svc = DoctorService(widget.api);
    try {
      final r = await svc.createPatient(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        medicalRecord: medical,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Paciente creado. Credenciales enviadas a ${r.email}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(DoctorService.messageFromDio(e)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: KeepiColors.surfaceBg,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          tooltip: 'Cerrar',
        ),
        title: const Text('Nuevo paciente'),
        actions: [
          if (_step == 1)
            TextButton(
              onPressed: _submitting
                  ? null
                  : () {
                      FocusScope.of(context).unfocus();
                      setState(() => _step = 0);
                    },
              child: const Text('Paso 1'),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _StepHeader(step: _step),
          ),
          Expanded(
            child: _step == 0 ? _buildIdentityStep(theme) : _buildMedicalStep(theme),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: _step == 0
                ? FilledButton(
                    onPressed: _submitting ? null : _goToMedicalStep,
                    child: const Text('Continuar al expediente'),
                  )
                : FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
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
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityStep(ThemeData theme) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Form(
        key: _formIdentity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Datos de contacto',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: KeepiColors.slate,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'El paciente recibirá un correo con acceso provisional.',
              style: theme.textTheme.bodySmall?.copyWith(color: KeepiColors.slateLight),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameCtrl,
              focusNode: _nameFocus,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              scrollPadding: _scrollPadding,
              onFieldSubmitted: (_) => _emailFocus.requestFocus(),
              decoration: const InputDecoration(
                labelText: 'Nombre completo',
                hintText: 'Como aparecerá en la app',
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailCtrl,
              focusNode: _emailFocus,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              scrollPadding: _scrollPadding,
              onFieldSubmitted: (_) {
                if (_formIdentity.currentState!.validate()) {
                  _goToMedicalStep();
                }
              },
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                hintText: 'ejemplo@correo.com',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Requerido';
                if (!v.contains('@')) return 'Correo no válido';
                return null;
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalStep(ThemeData theme) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Expediente clínico',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: KeepiColors.slate,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Completa al menos un campo. Puedes ampliar después desde el perfil del paciente.',
            style: theme.textTheme.bodySmall?.copyWith(color: KeepiColors.slateLight),
          ),
          const SizedBox(height: 20),
          _field(
            controller: _birthCtrl,
            label: 'Fecha de nacimiento',
            hint: 'AAAA-MM-DD',
            icon: Icons.cake_outlined,
          ),
          const SizedBox(height: 14),
          _field(controller: _sexCtrl, label: 'Sexo', icon: Icons.wc_outlined),
          const SizedBox(height: 14),
          _field(controller: _bloodCtrl, label: 'Tipo de sangre', icon: Icons.bloodtype_outlined),
          const SizedBox(height: 14),
          _multiline(_allergiesCtrl, 'Alergias'),
          const SizedBox(height: 14),
          _multiline(_chronicCtrl, 'Enfermedades crónicas'),
          const SizedBox(height: 14),
          _multiline(_medsCtrl, 'Medicación actual'),
          const SizedBox(height: 14),
          _multiline(_surgicalCtrl, 'Antecedentes quirúrgicos'),
          const SizedBox(height: 14),
          _multiline(_familyCtrl, 'Antecedentes familiares'),
          const SizedBox(height: 14),
          _multiline(_notesCtrl, 'Notas clínicas', maxLines: 3),
          const SizedBox(height: 14),
          _field(
            controller: _emergNameCtrl,
            label: 'Contacto de emergencia — nombre',
            icon: Icons.contact_emergency_outlined,
          ),
          const SizedBox(height: 14),
          _field(
            controller: _emergPhoneCtrl,
            label: 'Contacto de emergencia — teléfono',
            keyboardType: TextInputType.phone,
            icon: Icons.phone_outlined,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      scrollPadding: _scrollPadding,
      minLines: 1,
      maxLines: 1,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, size: 22) : null,
      ),
    );
  }

  Widget _multiline(TextEditingController c, String label, {int maxLines = 2}) {
    return TextFormField(
      controller: c,
      minLines: 1,
      maxLines: maxLines,
      scrollPadding: _scrollPadding,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: true,
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _chip(context, 0, 'Contacto', step >= 0, step == 0),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.chevron_right_rounded, size: 20, color: KeepiColors.slateLight),
        ),
        _chip(context, 1, 'Expediente', step >= 1, step == 1),
      ],
    );
  }

  Widget _chip(BuildContext context, int index, String label, bool filled, bool active) {
    final bg = active
        ? KeepiColors.orangeSoft
        : filled
            ? KeepiColors.skyBlueSoft
            : KeepiColors.slateSoft;
    final fg = active ? KeepiColors.orange : KeepiColors.slateLight;
    return Expanded(
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${index + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: fg,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: KeepiColors.slate,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
