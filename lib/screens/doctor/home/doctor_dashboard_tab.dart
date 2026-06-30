import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_theme.dart';
import '../../../core/decorative_background.dart';
import '../../../core/web_layout.dart';
import '../../../providers/auth_provider.dart';
import '../../../router/app_paths.dart';
import '../../../services/appointment_service.dart';
import '../../../services/doctor_service.dart';
import '../../../utils/attendance_kpi.dart';
import '../../../widgets/doctor_patient_web_blocks.dart';
import '../../../widgets/home_added_search_section.dart';
import 'doctor_home_dashboard_widgets.dart';
import 'doctor_home_helpers.dart';
import 'doctor_home_shared_widgets.dart';

/// Dashboard principal del médico (móvil y web).
class DoctorDashboardTab extends StatelessWidget {
  const DoctorDashboardTab({
    super.key,
    required this.auth,
    required this.patients,
    required this.agenda,
    required this.loadingAgenda,
    required this.agendaError,
    required this.patientsError,
    required this.slotDurationMinutes,
    required this.markingAttendanceIds,
    required this.attendanceStats,
    required this.loadingAttendanceStats,
    required this.nextAppointment,
    required this.dashboardUpcoming,
    required this.featuredNextAppointmentInRange,
    required this.todayAndTomorrowAppointments,
    required this.todaysAppointments,
    required this.pendingConfirmCount,
    required this.onRefresh,
    required this.onRetryAgenda,
    required this.onRetryPatients,
    required this.onNotifications,
    required this.onLogout,
    required this.onCreatePatient,
    required this.onScheduleAppointment,
    required this.onOpenProfile,
    required this.onOpenConsultation,
    required this.onMarkAttendance,
    required this.onOpenAgendaAppointment,
    required this.onOpenExpedientes,
    required this.onOpenQuestionnaires,
    required this.patientForAppointment,
  });

  final AuthProvider auth;
  final List<PatientListItem> patients;
  final List<AppointmentDto> agenda;
  final bool loadingAgenda;
  final String? agendaError;
  final String? patientsError;
  final int slotDurationMinutes;
  final Set<String> markingAttendanceIds;
  final AttendanceStatsData? attendanceStats;
  final bool loadingAttendanceStats;
  final AppointmentDto? nextAppointment;
  final List<AppointmentDto> dashboardUpcoming;
  final AppointmentDto? featuredNextAppointmentInRange;
  final List<AppointmentDto> todayAndTomorrowAppointments;
  final List<AppointmentDto> todaysAppointments;
  final int pendingConfirmCount;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetryAgenda;
  final VoidCallback onRetryPatients;
  final VoidCallback onNotifications;
  final VoidCallback onLogout;
  final VoidCallback onCreatePatient;
  final VoidCallback onScheduleAppointment;
  final void Function(AppointmentDto) onOpenProfile;
  final void Function(AppointmentDto) onOpenConsultation;
  final Future<void> Function(AppointmentDto, String) onMarkAttendance;
  final void Function(AppointmentDto) onOpenAgendaAppointment;
  final VoidCallback onOpenExpedientes;
  final VoidCallback onOpenQuestionnaires;
  final PatientListItem? Function(AppointmentDto) patientForAppointment;

  @override
  Widget build(BuildContext context) {
    if (isWebWide(context)) return _buildWeb(context);
    return _buildMobile(context);
  }

  Widget _buildMobile(BuildContext context) {
    final dashboard = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DoctorHomeGreeting(
          greeting: doctorHomeGreetingForNow(),
          name: auth.name ?? 'Doctor',
        ),
        const SizedBox(height: 12),
        HomeAddedSearchSection(
          patients: patients,
          onDoctorOpenAgenda: () => context.go(AppPaths.doctorAgenda),
        ),
        const SizedBox(height: 20),
        if (loadingAgenda && agenda.isEmpty)
          const DoctorHomeLoadingBox()
        else if (agendaError != null)
          DoctorHomeErrorBox(message: agendaError!, onRetry: onRetryAgenda)
        else if (nextAppointment != null)
          DoctorHomeNextAppointmentHero(
            appointment: nextAppointment!,
            patient: patientForAppointment(nextAppointment!),
            onOpenProfile: () => onOpenProfile(nextAppointment!),
            onOpenConsultation: () => onOpenConsultation(nextAppointment!),
          )
        else
          const DoctorHomeEmptyNextAppointmentCard(
            message: doctorHomeNoScheduledAppointmentsMessage,
          ),
        const SizedBox(height: 18),
        DoctorHomeTopActionsStrip(
          onNewPatient: onCreatePatient,
          onScheduleAppointment: onScheduleAppointment,
        ),
        const SizedBox(height: 22),
        if (patientsError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: DoctorHomeErrorBox(
              message: patientsError!,
              onRetry: onRetryPatients,
            ),
          ),
        if (dashboardUpcoming.isNotEmpty) ...[
          DoctorHomeSectionDivider(
            tag: 'PRÓXIMAS CITAS',
            count: dashboardUpcoming.length,
          ),
          const SizedBox(height: 14),
          for (final a in dashboardUpcoming.take(6))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DoctorHomeAgendaCard(
                appointment: a,
                patients: patients,
                slotDurationMinutes: slotDurationMinutes,
                markingAttendance: markingAttendanceIds.contains(a.id),
                onMarkAttendance: onMarkAttendance,
                onTap: () => onOpenAgendaAppointment(a),
              ),
            ),
        ],
        const SizedBox(height: 20),
        const DoctorHomeSectionDivider(tag: 'ATAJOS', count: 4),
        const SizedBox(height: 14),
        DoctorHomeShortcutsStrip(
          onPatients: () => context.go(AppPaths.doctorPacientes),
          onDocuments: onOpenExpedientes,
          onQuestionnaires: onOpenQuestionnaires,
          onAgenda: () => context.go(AppPaths.doctorAgenda),
        ),
        const SizedBox(height: 120),
      ],
    );

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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: dashboard,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeb(BuildContext context) {
    final featured = featuredNextAppointmentInRange;
    final allInRange = todayAndTomorrowAppointments;
    final restInRange = featured == null
        ? allInRange
        : allInRange.where((a) => a.id != featured.id).toList();
    final pendingList = agenda
        .where(
          (a) =>
              a.status == 'pending_patient_approval' ||
              a.status == 'pending_doctor_proposal' ||
              a.status == 'pending_doctor_approval',
        )
        .toList()
      ..sort((a, b) {
        final da = a.appointmentDate;
        final db = b.appointmentDate;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });
    final loadingFirst = loadingAgenda && agenda.isEmpty;
    final pending = pendingConfirmCount;

    return RefreshIndicator(
      color: KeepiColors.orange,
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: SubtleDecorativeBackground(
              child: WebContentFrame(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DoctorHomeGreeting(
                      greeting: doctorHomeGreetingForNow(),
                      name: auth.name ?? 'Doctor',
                    ),
                    const SizedBox(height: 20),
                    DoctorHomeTopActionsStrip(
                      onNewPatient: onCreatePatient,
                      onScheduleAppointment: onScheduleAppointment,
                    ),
                    const SizedBox(height: 28),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: DoctorHomeSectionDivider(
                                      tag: 'AGENDA',
                                      count: allInRange.length,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        context.go(AppPaths.doctorAgenda),
                                    child: const Text('Ver agenda'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              if (loadingFirst)
                                const DoctorHomeLoadingBox()
                              else if (agendaError != null)
                                DoctorHomeErrorBox(
                                  message: agendaError!,
                                  onRetry: onRetryAgenda,
                                )
                              else if (featured == null && allInRange.isEmpty)
                                const DoctorHomeInlineEmpty(
                                  icon: Icons.event_available_outlined,
                                  message:
                                      'No hay citas agendadas. Revisa la agenda o crea una nueva.',
                                )
                              else ...[
                                if (featured != null)
                                  DoctorHomeNextAppointmentHero(
                                    compact: true,
                                    featured: true,
                                    appointment: featured,
                                    patient: patientForAppointment(featured),
                                    slotDurationMinutes: slotDurationMinutes,
                                    markingAttendance:
                                        markingAttendanceIds.contains(featured.id),
                                    onMarkAttendance: onMarkAttendance,
                                    onOpenProfile: () => onOpenProfile(featured),
                                    onOpenConsultation: () =>
                                        onOpenConsultation(featured),
                                  )
                                else
                                  const DoctorHomeEmptyNextAppointmentCard(
                                    message: doctorHomeNoScheduledAppointmentsMessage,
                                    featured: true,
                                  ),
                                if (restInRange.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  const DoctorHomeAgendaDivider(),
                                  const SizedBox(height: 14),
                                  for (final a in restInRange)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: DoctorHomeAgendaCard(
                                        appointment: a,
                                        patients: patients,
                                        slotDurationMinutes: slotDurationMinutes,
                                        markingAttendance:
                                            markingAttendanceIds.contains(a.id),
                                        onMarkAttendance: onMarkAttendance,
                                        onTap: () => onOpenAgendaAppointment(a),
                                      ),
                                    ),
                                ],
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 28),
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const DoctorHomeSectionDivider(
                                tag: 'ASISTENCIA GENERAL',
                                count: 0,
                              ),
                              const SizedBox(height: 14),
                              if (loadingFirst || loadingAttendanceStats)
                                const DoctorHomeLoadingBox()
                              else if (agendaError != null)
                                const SizedBox.shrink()
                              else
                                DoctorAttendanceOverviewStrip(
                                  attended: attendanceStats?.attended ?? 0,
                                  noShow: attendanceStats?.noShow ?? 0,
                                  pending: attendanceStats?.pending ?? 0,
                                  ratePercent: attendanceStats?.ratePercent,
                                  onAttendedTap: () => context.push(
                                    AppPaths.doctorAttendanceDetailPath(
                                      'attended',
                                    ),
                                  ),
                                  onNoShowTap: () => context.push(
                                    AppPaths.doctorAttendanceDetailPath(
                                      'no_show',
                                    ),
                                  ),
                                  onPendingTap: () => context.push(
                                    AppPaths.doctorAttendanceDetailPath(
                                      'pending',
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 20),
                              const DoctorHomeSectionDivider(
                                tag: 'RESUMEN DE ACTIVIDAD',
                                count: 0,
                              ),
                              const SizedBox(height: 14),
                              if (loadingFirst)
                                const DoctorHomeLoadingBox()
                              else if (agendaError != null)
                                const SizedBox.shrink()
                              else
                                DoctorHomeStatsStrip(
                                  items: [
                                    DoctorHomeStatItem(
                                      value: todaysAppointments.length,
                                      label: 'CITAS HOY',
                                    ),
                                    DoctorHomeStatItem(
                                      value: pending,
                                      label: 'POR CONFIRMAR',
                                      accent: pending > 0,
                                    ),
                                    DoctorHomeStatItem(
                                      value: patients.length,
                                      label: 'PACIENTES',
                                    ),
                                  ],
                                ),
                              if (pendingList.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                DoctorHomeWebPendingCard(
                                  pending: pendingList,
                                  patients: patients,
                                  onOpen: onOpenAgendaAppointment,
                                  onViewAll: () =>
                                      context.go(AppPaths.doctorAgenda),
                                ),
                              ],
                              const SizedBox(height: 24),
                              const DoctorHomeSectionDivider(tag: 'ATAJOS', count: 4),
                              const SizedBox(height: 14),
                              DoctorHomeShortcutsStrip(
                                onPatients: () =>
                                    context.go(AppPaths.doctorPacientes),
                                onDocuments: onOpenExpedientes,
                                onQuestionnaires: onOpenQuestionnaires,
                                onAgenda: () => context.go(AppPaths.doctorAgenda),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
