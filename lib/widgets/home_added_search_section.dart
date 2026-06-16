import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/roles.dart';
import '../providers/auth_provider.dart';
import '../router/app_paths.dart';
import '../router/router_extras.dart';
import '../services/doctor_service.dart';

/// Barra de búsqueda en Home: al pulsar abre la pantalla dedicada de búsqueda.
class HomeAddedSearchSection extends StatelessWidget {
  const HomeAddedSearchSection({
    super.key,
    this.patients,
    this.onDoctorOpenAgenda,
    this.compact = false,
  });

  final List<PatientListItem>? patients;
  final VoidCallback? onDoctorOpenAgenda;
  /// Versión baja para el header web (mejor área de clic).
  final bool compact;

  void _openSearch(BuildContext context) {
    final role = context.read<AuthProvider>().roleName;
    final path =
        role == AppRole.doctor ? AppPaths.doctorSearch : AppPaths.userSearch;
    context.push(
      path,
      extra: GlobalSearchExtra(
        patients: patients,
        onDoctorOpenAgenda: onDoctorOpenAgenda,
      ),
    );
  }

  InputDecoration _decoration() {
    return InputDecoration(
      hintText: 'Buscar citas, documentos, análisis…',
      hintStyle: TextStyle(
        color: KeepiColors.slateLight.withValues(alpha: 0.9),
        fontSize: compact ? 14 : 15,
        fontWeight: FontWeight.w500,
      ),
      isDense: compact,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: compact ? 11 : 14,
      ),
      filled: true,
      fillColor: Colors.white,
      prefixIcon: Icon(
        Icons.search_rounded,
        color: KeepiColors.slateLight.withValues(alpha: 0.8),
        size: compact ? 20 : 22,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        borderSide: const BorderSide(color: KeepiColors.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        borderSide: const BorderSide(color: KeepiColors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        borderSide: const BorderSide(color: KeepiColors.skyBlue, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      readOnly: true,
      showCursor: false,
      enableInteractiveSelection: false,
      mouseCursor: SystemMouseCursors.click,
      onTap: () => _openSearch(context),
      onSubmitted: (_) => _openSearch(context),
      decoration: _decoration(),
    );

    if (compact) {
      return field;
    }

    return Material(
      color: Colors.transparent,
      child: field,
    );
  }
}
