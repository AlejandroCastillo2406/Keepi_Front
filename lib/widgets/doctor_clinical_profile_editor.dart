import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/consultation_context.dart';
import '../services/api_client.dart';
import '../services/doctor_service.dart';

class ClinicalProfileFormData {
  const ClinicalProfileFormData({
    required this.name,
    required this.email,
    required this.phone,
    required this.sex,
    this.ageYears,
    this.bloodType,
    this.weightKg,
    this.allergies,
  });

  final String name;
  final String email;
  final String phone;
  final String sex;
  final int? ageYears;
  final String? bloodType;
  final double? weightKg;
  final String? allergies;
}

/// Diálogo para editar datos clínicos (solo captura; el guardado va en el caller).
Future<ClinicalProfileFormData?> showDoctorClinicalProfileEditor(
  BuildContext context, {
  ConsultationContext? initial,
  required String fallbackName,
  required String fallbackEmail,
}) async {
  final nameCtrl = TextEditingController(
    text: initial?.patientName ?? fallbackName,
  );
  final emailCtrl = TextEditingController(
    text: initial?.patientEmail ?? fallbackEmail,
  );
  final phoneCtrl = TextEditingController(text: initial?.phone ?? '');
  final ageCtrl = TextEditingController(text: initial?.ageYears?.toString() ?? '');
  final bloodCtrl = TextEditingController(text: initial?.bloodType ?? '');
  final weightCtrl = TextEditingController(text: initial?.weightKg?.toString() ?? '');
  final allergiesCtrl = TextEditingController(text: initial?.allergies ?? '');
  var selectedSex = (initial?.sex ?? '').trim();
  if (selectedSex.isEmpty) selectedSex = 'Masculino';

  const sexOptions = [
    'Femenino',
    'Masculino',
    'Otro',
    'Prefiero no decir',
  ];

  ClinicalProfileFormData? result;

  await showDialog<void>(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (dialogCtx, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Editar perfil',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue:
                      sexOptions.contains(selectedSex) ? selectedSex : 'Masculino',
                  decoration: const InputDecoration(
                    labelText: 'Sexo',
                    border: OutlineInputBorder(),
                  ),
                  items: sexOptions
                      .map(
                        (option) => DropdownMenuItem(
                          value: option,
                          child: Text(option),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => selectedSex = value);
                  },
                ),
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 12),
                TextField(
                  controller: ageCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Edad (años)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bloodCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de sangre',
                    hintText: 'Ej. O+',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: weightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Peso (kg)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: allergiesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Alergias',
                    hintText: 'Ej. Penicilina',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final email = emailCtrl.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(dialogCtx).showSnackBar(
                  const SnackBar(content: Text('El nombre es obligatorio')),
                );
                return;
              }
              if (email.isEmpty) {
                ScaffoldMessenger.of(dialogCtx).showSnackBar(
                  const SnackBar(content: Text('El correo es obligatorio')),
                );
                return;
              }

              final ageRaw = ageCtrl.text.trim();
              final weightRaw = weightCtrl.text.trim();
              int? ageYears;
              double? weightKg;
              if (ageRaw.isNotEmpty) {
                ageYears = int.tryParse(ageRaw.replaceAll(RegExp(r'[^0-9]'), ''));
                if (ageYears == null) {
                  ScaffoldMessenger.of(dialogCtx).showSnackBar(
                    const SnackBar(content: Text('Edad inválida')),
                  );
                  return;
                }
              }
              if (weightRaw.isNotEmpty) {
                weightKg = double.tryParse(
                  weightRaw.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), ''),
                );
                if (weightKg == null) {
                  ScaffoldMessenger.of(dialogCtx).showSnackBar(
                    const SnackBar(content: Text('Peso inválido')),
                  );
                  return;
                }
              }

              final bloodType = bloodCtrl.text.trim();
              final allergiesText = allergiesCtrl.text.trim();
              result = ClinicalProfileFormData(
                name: name,
                email: email,
                phone: phoneCtrl.text.trim(),
                sex: selectedSex,
                ageYears: ageYears,
                bloodType: bloodType.isEmpty ? null : bloodType,
                weightKg: weightKg,
                allergies: allergiesText.isEmpty ? null : allergiesText,
              );
              Navigator.pop(dialogCtx);
            },
            style: FilledButton.styleFrom(backgroundColor: KeepiColors.orange),
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );

  nameCtrl.dispose();
  emailCtrl.dispose();
  phoneCtrl.dispose();
  ageCtrl.dispose();
  bloodCtrl.dispose();
  weightCtrl.dispose();
  allergiesCtrl.dispose();

  return result;
}

Future<ConsultationContext?> saveClinicalProfileForm({
  required ApiClient api,
  required String patientId,
  required ClinicalProfileFormData form,
}) async {
  return DoctorService(api).upsertClinicalProfile(
    patientId: patientId,
    name: form.name,
    email: form.email,
    phone: form.phone.isEmpty ? null : form.phone,
    sex: form.sex,
    ageYears: form.ageYears,
    bloodType: form.bloodType,
    weightKg: form.weightKg,
    allergies: form.allergies,
  );
}
