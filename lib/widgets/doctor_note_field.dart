import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// Campo opcional de nota clínica al crear eventos (cita, análisis, receta).
class DoctorNoteField extends StatelessWidget {
  const DoctorNoteField({
    super.key,
    required this.controller,
    this.enabled = true,
  });

  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notas del médico (opcional)',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: KeepiColors.slate,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Se guardan en el S3 del médico, en la carpeta del paciente '
          '(NombrePaciente/Notas), vinculadas al evento del timeline. '
          'El paciente no las ve.',
          style: TextStyle(
            fontSize: 12,
            color: KeepiColors.slateLight.withValues(alpha: 0.95),
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          enabled: enabled,
          maxLines: 4,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Ej. antecedentes relevantes, plan de seguimiento…',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: KeepiColors.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: KeepiColors.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: KeepiColors.orange.withValues(alpha: 0.7),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
