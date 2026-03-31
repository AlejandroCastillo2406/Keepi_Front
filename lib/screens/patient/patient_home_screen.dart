import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/decorative_background.dart';
import '../../providers/auth_provider.dart';

/// Vista principal para rol PACIENTE.
class PatientHomeScreen extends StatelessWidget {
  const PatientHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi espacio'),
        backgroundColor: Colors.white,
        foregroundColor: KeepiColors.slate,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => auth.logout(),
            child: const Text('Salir'),
          ),
        ],
      ),
      body: DecorativeBackground(
        blobOpacity: 0.12,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hola, ${auth.name ?? "paciente"}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: KeepiColors.slate,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Vista simplificada para pacientes. Puedes ampliar con documentos compartidos por tu médico, citas, etc.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: KeepiColors.slateLight),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
