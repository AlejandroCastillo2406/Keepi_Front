import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/web_layout.dart';
import '../../../services/doctor_service.dart';
import '../../../widgets/doctor_patient_directory_tile.dart';
import 'doctor_home_patients_widgets.dart';
import 'doctor_home_shared_widgets.dart';

/// Listado y búsqueda de pacientes del médico.
class DoctorPatientsTab extends StatelessWidget {
  const DoctorPatientsTab({
    super.key,
    required this.patients,
    required this.filteredPatients,
    required this.loadingPatients,
    required this.patientsError,
    required this.searchController,
    required this.onSearchChanged,
    required this.onRefresh,
    required this.onRetry,
    required this.onNotifications,
    required this.onLogout,
    required this.onOpenProfile,
    required this.onDeletePatient,
    required this.onOpenActions,
  });

  final List<PatientListItem> patients;
  final List<PatientListItem> filteredPatients;
  final bool loadingPatients;
  final String? patientsError;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final VoidCallback onNotifications;
  final VoidCallback onLogout;
  final void Function(PatientListItem) onOpenProfile;
  final void Function(PatientListItem) onDeletePatient;
  final void Function(PatientListItem) onOpenActions;

  @override
  Widget build(BuildContext context) {
    if (isWebWide(context)) return _buildWeb(context);
    return _buildMobile(context);
  }

  Widget _buildMobile(BuildContext context) {
    final list = filteredPatients;
    return RefreshIndicator(
      color: KeepiColors.orange,
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: DoctorHomeTopBar(
              onNotifs: onNotifications,
              onLogout: onLogout,
            ),
          ),
          SliverToBoxAdapter(
            child: DoctorHomePatientsHero(
              total: patients.length,
              filtered: list.length,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 10),
            sliver: SliverToBoxAdapter(
              child: DoctorHomeSearchField(
                controller: searchController,
                hint: 'Buscar por nombre o correo...',
                onChanged: onSearchChanged,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate.fixed(
                _patientListSlivers(
                  context,
                  list: list,
                  compact: false,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeb(BuildContext context) {
    final list = filteredPatients;
    return RefreshIndicator(
      color: KeepiColors.orange,
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: WebContentFrame(
              maxWidth: 1280,
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DoctorHomePatientsWebHero(
                          total: patients.length,
                          filtered: list.length,
                        ),
                      ),
                      const SizedBox(width: 28),
                      SizedBox(
                        width: 340,
                        child: DoctorHomeSearchField(
                          controller: searchController,
                          hint: 'Buscar por nombre o correo...',
                          onChanged: onSearchChanged,
                          elevated: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  DoctorHomeSectionDivider(tag: 'PACIENTES', count: list.length),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 48),
            sliver: SliverToBoxAdapter(
              child: WebContentFrame(
                maxWidth: 1280,
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _patientListSlivers(
                    context,
                    list: list,
                    compact: true,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _patientListSlivers(
    BuildContext context, {
    required List<PatientListItem> list,
    required bool compact,
  }) {
    return [
      if (patientsError != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: DoctorHomeErrorBox(
            message: patientsError!,
            onRetry: onRetry,
          ),
        ),
      if (!compact) ...[
        DoctorHomeSectionDivider(tag: 'PACIENTES', count: list.length),
        const SizedBox(height: 14),
      ],
      if (loadingPatients && patients.isEmpty)
        const DoctorHomeLoadingBox()
      else if (list.isEmpty && patients.isEmpty)
        const DoctorHomeEmptyStateCard(
          tag: 'PACIENTES',
          title: 'Aún no hay pacientes',
          message:
              'Crea tu primer paciente con el botón “Nuevo paciente”. Vincularás su expediente, recetas y análisis.',
          icon: Icons.people_alt_outlined,
        )
      else if (list.isEmpty)
        const DoctorHomeInlineEmpty(
          icon: Icons.search_off_rounded,
          message: 'No encontramos pacientes con esa búsqueda.',
        )
      else
        for (final p in list)
          Padding(
            padding: EdgeInsets.only(bottom: compact ? 10 : 12),
            child: DoctorPatientDirectoryTile(
              patient: p,
              onProfileTap: () => onOpenProfile(p),
              onDeleteTap: () => onDeletePatient(p),
              onArrowTap: () => onOpenActions(p),
            ),
          ),
    ];
  }
}
