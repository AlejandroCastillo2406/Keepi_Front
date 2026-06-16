import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/consultation_bootstrap_provider.dart';
import '../providers/expedientes_cache_provider.dart';
import '../providers/patients_cache_provider.dart';
import 'app_paths.dart';

/// Cierre de sesión unificado para todos los roles.
abstract final class AppAuthActions {
  static Future<void> logout(BuildContext context) async {
    context.read<ConsultationBootstrapProvider>().clear();
    context.read<ExpedientesCacheProvider>().clear();
    context.read<PatientsCacheProvider>().clear();
    await context.read<AuthProvider>().logout();
    if (context.mounted) context.go(AppPaths.login);
  }
}
