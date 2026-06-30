import 'package:flutter/material.dart';

import '../../../services/appointment_service.dart';
import '../doctor_calendar_tab.dart';
import 'doctor_home_shared_widgets.dart';

/// Pestaña de agenda del home del médico.
class DoctorHomeAgendaTab extends StatelessWidget {
  const DoctorHomeAgendaTab({
    super.key,
    required this.onNotifications,
    required this.onLogout,
    required this.onOpenConsultation,
  });

  final VoidCallback onNotifications;
  final VoidCallback onLogout;
  final void Function(AppointmentDto) onOpenConsultation;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DoctorHomeTopBar(onNotifs: onNotifications, onLogout: onLogout),
        Expanded(
          child: DoctorCalendarTab(onOpenConsultation: onOpenConsultation),
        ),
      ],
    );
  }
}
