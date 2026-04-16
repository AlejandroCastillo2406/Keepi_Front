import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/patient_medical_record_service.dart';

class DoctorPatientMedicalRecordScreen extends StatelessWidget {
  const DoctorPatientMedicalRecordScreen({
    super.key,
    required this.patientName,
    required this.record,
  });

  final String patientName;
  final MedicalRecordDto record;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Expediente de $patientName'),
        backgroundColor: Colors.white,
        foregroundColor: KeepiColors.slate,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _item('Fecha de nacimiento', record.birthDate),
          _item('Sexo', record.sex),
          _item('Tipo de sangre', record.bloodType),
          _item('Alergias', record.allergies),
          _item('Enfermedades crónicas', record.chronicConditions),
          _item('Medicación actual', record.medications),
          _item('Antecedentes quirúrgicos', record.surgicalHistory),
          _item('Antecedentes familiares', record.familyHistory),
          _item('Notas', record.notes),
          _item('Contacto emergencia (nombre)', record.emergencyContactName),
          _item('Contacto emergencia (teléfono)', record.emergencyContactPhone),
        ],
      ),
    );
  }

  Widget _item(String label, String? value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text((value == null || value.trim().isEmpty) ? 'Sin dato' : value),
      ),
    );
  }
}

