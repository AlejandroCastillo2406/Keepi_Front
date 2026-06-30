import 'package:flutter/material.dart';

import '../documentos_screen.dart';
import 'doctor_home_shared_widgets.dart';

/// Pestaña de expedientes embebida en el home del médico.
class DoctorHomeExpedientesTab extends StatelessWidget {
  const DoctorHomeExpedientesTab({
    super.key,
    required this.onNotifications,
    required this.onLogout,
  });

  final VoidCallback onNotifications;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DoctorHomeTopBar(onNotifs: onNotifications, onLogout: onLogout),
        const Expanded(
          child: DocumentosScreen(embedded: true),
        ),
      ],
    );
  }
}
