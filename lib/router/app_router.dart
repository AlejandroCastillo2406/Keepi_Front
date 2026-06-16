import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/roles.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/auth.dart';
import '../screens/common/global_search_screen.dart';
import '../screens/common/notifications_screen.dart';
import '../screens/common/prior_documents_screen.dart';
import '../screens/doctor/analysis_document_viewer_screen.dart';
import '../screens/doctor/doctor.dart';
import '../screens/doctor/doctor_scheduling_settings_screen.dart';
import '../screens/doctor/questionnaire/question_editor_screen.dart';
import '../screens/doctor/questionnaire/questionnaire_settings_screen.dart';
import '../screens/doctor/questionnaire/specialty_questions_screen.dart';
import '../screens/doctor/questionnaire/template_editor_screen.dart';
import '../screens/patient/patient.dart';
import '../screens/patient/patient_upload_analysis_screen.dart';
import '../screens/user/google_drive_auth_screen.dart';
import '../screens/user/home_screen.dart';
import '../screens/user/folder_contents_screen.dart';
import '../screens/user/settings_screen.dart';
import '../screens/user/user.dart';
import 'app_paths.dart';
import 'doctor_route_pages.dart';
import 'patient_route_pages.dart';
import 'router_extras.dart';

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

GoRouter createAppRouter(AuthProvider auth) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppPaths.login,
    refreshListenable: auth,
    redirect: (BuildContext context, GoRouterState state) {
      if (auth.isLoading) return null;

      final loc = state.matchedLocation;
      final isAuthRoute =
          loc == AppPaths.login || loc == AppPaths.register;

      if (!auth.isLoggedIn) {
        if (loc == AppPaths.documentViewer) return null;
        return isAuthRoute ? null : AppPaths.login;
      }

      if (auth.mustChangePassword) {
        return loc == AppPaths.forcePassword ? null : AppPaths.forcePassword;
      }

      if (loc == AppPaths.documentViewer) return null;

      if (isAuthRoute || loc == AppPaths.forcePassword) {
        return _homeForRole(auth.roleName);
      }

      final role = auth.roleName ?? AppRole.user;
      if (role == AppRole.doctor && !loc.startsWith(AppPaths.doctor)) {
        return AppPaths.doctorInicio;
      }
      if (role == AppRole.patient && !loc.startsWith(AppPaths.patientHome)) {
        return AppPaths.patientHome;
      }
      if (role == AppRole.user && !loc.startsWith(AppPaths.userHome)) {
        return AppPaths.userHome;
      }

      if (loc == AppPaths.doctor) return AppPaths.doctorInicio;
      if (loc == AppPaths.patientHome) return AppPaths.patientInicio;

      return null;
    },
    routes: [
      GoRoute(
        path: AppPaths.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppPaths.register,
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppPaths.forcePassword,
        builder: (_, __) => const ForcePasswordChangeScreen(),
      ),
      GoRoute(
        path: AppPaths.documentViewer,
        builder: (context, state) {
          final extra = state.extra as DocumentViewerExtra?;
          if (extra == null) {
            return const Scaffold(
              body: Center(child: Text('Documento no disponible')),
            );
          }
          return AnalysisDocumentViewerScreen(
            url: extra.url,
            title: extra.title,
            headers: extra.headers,
            mimeType: extra.mimeType,
            s3Path: extra.s3Path,
          );
        },
      ),
      GoRoute(
        path: AppPaths.userHome,
        builder: (_, __) => const HomeScreen(),
        routes: [
          GoRoute(
            path: 'configuracion',
            builder: (_, __) => const SettingsScreen(),
          ),
          GoRoute(
            path: 'busqueda',
            builder: (context, state) {
              final extra = state.extra as GlobalSearchExtra?;
              return GlobalSearchScreen(
                patients: extra?.patients,
                onDoctorOpenAgenda: extra?.onDoctorOpenAgenda,
              );
            },
          ),
          GoRoute(
            path: 'notificaciones',
            builder: (_, __) => const NotificationsScreen(),
          ),
          GoRoute(
            path: 'google-drive',
            builder: (context, state) {
              final url = state.uri.queryParameters['url'];
              if (url == null || url.isEmpty) {
                return const Scaffold(
                  body: Center(
                    child: Text('Enlace de autorización no válido'),
                  ),
                );
              }
              return GoogleDriveAuthScreen(authorizationUrl: url);
            },
          ),
          GoRoute(
            path: 'carpeta/:folderId',
            builder: (context, state) => FolderContentsScreen(
              folderId: state.pathParameters['folderId']!,
              folderName: state.uri.queryParameters['name'] ?? 'Carpeta',
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppPaths.patientHome,
        redirect: (context, state) =>
            state.uri.path == AppPaths.patientHome
                ? AppPaths.patientInicio
                : null,
        routes: [
          ShellRoute(
            builder: (context, state, child) {
              return PatientHomeScreen(shellChild: child);
            },
            routes: [
              GoRoute(
                path: 'inicio',
                pageBuilder: (_, __) => const NoTransitionPage(
                  child: PatientTabPlaceholder(),
                ),
              ),
              GoRoute(
                path: 'recetas',
                pageBuilder: (_, __) => const NoTransitionPage(
                  child: PatientTabPlaceholder(),
                ),
              ),
              GoRoute(
                path: 'consultas',
                pageBuilder: (_, __) => const NoTransitionPage(
                  child: PatientTabPlaceholder(),
                ),
              ),
              GoRoute(
                path: 'perfil',
                pageBuilder: (_, __) => const NoTransitionPage(
                  child: PatientTabPlaceholder(),
                ),
              ),
              GoRoute(
                path: 'notificaciones',
                pageBuilder: (context, _) => NoTransitionPage(
                  child: NotificationsScreen(
                    embedded: true,
                    onBack: () => context.pop(),
                  ),
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'documentos-previos',
            builder: (context, state) {
              final auth = context.read<AuthProvider>();
              return PriorDocumentsScreen(
                patientId: auth.userId ?? '',
                patientName: auth.name ?? 'Paciente',
                forPatientView: true,
              );
            },
          ),
          GoRoute(
            path: 'subir-analisis/:requestId',
            builder: (context, state) => PatientUploadAnalysisScreen(
              requestId: state.pathParameters['requestId']!,
              description: state.uri.queryParameters['desc'] ?? '',
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppPaths.doctor,
        redirect: (context, state) =>
            state.uri.path == AppPaths.doctor ? AppPaths.doctorInicio : null,
        routes: [
          ShellRoute(
            builder: (context, state, child) {
              return DoctorHomeScreen(shellChild: child);
            },
            routes: [
              GoRoute(
                path: 'inicio',
                pageBuilder: (_, __) => const NoTransitionPage(
                  child: DoctorTabPlaceholder(),
                ),
              ),
              GoRoute(
                path: 'pacientes',
                pageBuilder: (_, __) => const NoTransitionPage(
                  child: DoctorTabPlaceholder(),
                ),
              ),
              GoRoute(
                path: 'agenda',
                pageBuilder: (_, __) => const NoTransitionPage(
                  child: DoctorTabPlaceholder(),
                ),
              ),
              GoRoute(
                path: 'expedientes',
                pageBuilder: (_, __) => const NoTransitionPage(
                  child: DoctorTabPlaceholder(),
                ),
              ),
              GoRoute(
                path: 'expedientes/carpeta',
                pageBuilder: (context, state) {
                  final folderId = state.uri.queryParameters['id'];
                  if (folderId == null || folderId.isEmpty) {
                    return const NoTransitionPage(child: _RouteExtraMissing());
                  }
                  return NoTransitionPage(
                    child: FolderContentsScreen(
                      folderId: folderId,
                      folderName:
                          state.uri.queryParameters['name'] ?? 'Carpeta',
                      embedded: true,
                    ),
                  );
                },
              ),
              GoRoute(
                path: 'busqueda',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: Builder(
                    builder: (ctx) {
                      final extra = state.extra as GlobalSearchExtra?;
                      return GlobalSearchScreen(
                        patients: extra?.patients,
                        onDoctorOpenAgenda: extra?.onDoctorOpenAgenda,
                        embedded: true,
                      );
                    },
                  ),
                ),
              ),
              GoRoute(
                path: 'cuestionarios',
                pageBuilder: (_, __) => const NoTransitionPage(
                  child: QuestionnaireSettingsScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'pregunta/editor',
                    builder: (context, state) {
                      final extra = state.extra as QuestionEditorExtra?;
                      if (extra == null) {
                        return const _RouteExtraMissing();
                      }
                      return QuestionEditorScreen(
                        service: extra.service,
                        specialties: extra.specialties,
                        initial: extra.initial,
                        presetSpecialtyId: extra.presetSpecialtyId,
                        presetGlobal: extra.presetGlobal,
                        forceDuplicate: extra.forceDuplicate,
                      );
                    },
                  ),
                  GoRoute(
                    path: 'pregunta/picker',
                    builder: (context, state) {
                      final extra = state.extra as QuestionPickerExtra?;
                      if (extra == null) {
                        return const _RouteExtraMissing();
                      }
                      return QuestionPickerScreen(
                        service: extra.service,
                        specialties: extra.specialties,
                        initiallySelected:
                            extra.initialSelection.map((q) => q.id).toSet(),
                        initialSpecialtyId: extra.initialSpecialtyId,
                      );
                    },
                  ),
                  GoRoute(
                    path: 'plantilla/editor',
                    builder: (context, state) {
                      final extra = state.extra as TemplateEditorExtra?;
                      if (extra == null) {
                        return const _RouteExtraMissing();
                      }
                      return TemplateEditorScreen(
                        service: extra.service,
                        specialties: extra.specialties,
                        existing: extra.existing,
                      );
                    },
                  ),
                  GoRoute(
                    path: 'especialidad',
                    builder: (context, state) {
                      final extra = state.extra as SpecialtyQuestionsExtra?;
                      if (extra == null) {
                        return const _RouteExtraMissing();
                      }
                      return SpecialtyQuestionsScreen(
                        specialty: extra.specialty,
                        service: extra.service,
                        specialties: extra.specialties,
                      );
                    },
                  ),
                ],
              ),
              GoRoute(
                path: 'agenda/configuracion',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: DoctorSchedulingSettingsScreen(
                    canSkip: state.uri.queryParameters['canSkip'] == 'true',
                  ),
                ),
              ),
              GoRoute(
                path: 'configuracion',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: Builder(
                    builder: (ctx) => buildDoctorOverlayPage(ctx, state),
                  ),
                ),
              ),
              GoRoute(
                path: 'notificaciones',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: Builder(
                    builder: (ctx) => buildDoctorOverlayPage(ctx, state),
                  ),
                ),
              ),
              GoRoute(
                path: 'nuevo-paciente',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: Builder(
                    builder: (ctx) => buildDoctorOverlayPage(ctx, state),
                  ),
                ),
              ),
              GoRoute(
                path: 'consulta/:appointmentId',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: Builder(
                    builder: (ctx) => buildDoctorOverlayPage(ctx, state),
                  ),
                ),
              ),
              GoRoute(
                path: 'paciente/:patientId',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: Builder(
                    builder: (ctx) => buildDoctorOverlayPage(ctx, state),
                  ),
                ),
              ),
              GoRoute(
                path: 'paciente/:patientId/historial',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: Builder(
                    builder: (ctx) => buildDoctorOverlayPage(ctx, state),
                  ),
                ),
              ),
              GoRoute(
                path: 'paciente/:patientId/solicitar-analisis',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: Builder(
                    builder: (ctx) => buildDoctorOverlayPage(ctx, state),
                  ),
                ),
              ),
              GoRoute(
                path: 'paciente/:patientId/receta',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: Builder(
                    builder: (ctx) => buildDoctorOverlayPage(ctx, state),
                  ),
                ),
              ),
              GoRoute(
                path: 'paciente/:patientId/cuestionario',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: Builder(
                    builder: (ctx) => buildDoctorOverlayPage(ctx, state),
                  ),
                ),
              ),
              GoRoute(
                path: 'paciente/:patientId/documentos-previos',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: Builder(
                    builder: (ctx) => buildDoctorOverlayPage(ctx, state),
                  ),
                ),
              ),
              GoRoute(
                path: 'paciente/:patientId/subir-analisis/:requestId',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: Builder(
                    builder: (ctx) => buildDoctorOverlayPage(ctx, state),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Ruta no encontrada: ${state.uri}'),
      ),
    ),
  );
}

String _homeForRole(String? role) {
  switch (role) {
    case AppRole.doctor:
      return AppPaths.doctorInicio;
    case AppRole.patient:
      return AppPaths.patientInicio;
    default:
      return AppPaths.userHome;
  }
}

class _RouteExtraMissing extends StatelessWidget {
  const _RouteExtraMissing();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Keepi')),
      body: Center(
        child: FilledButton(
          onPressed: () => context.pop(),
          child: const Text('Volver'),
        ),
      ),
    );
  }
}
