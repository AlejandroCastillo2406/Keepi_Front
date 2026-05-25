import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../screens/common/global_search_screen.dart';
import '../services/doctor_service.dart';

/// Barra de búsqueda en Home: al pulsar abre la pantalla dedicada de búsqueda.
class HomeAddedSearchSection extends StatelessWidget {
  const HomeAddedSearchSection({
    super.key,
    this.patients,
    this.onDoctorOpenAgenda,
  });

  final List<PatientListItem>? patients;
  final VoidCallback? onDoctorOpenAgenda;

  void _openSearch(BuildContext context) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => GlobalSearchScreen(
          patients: patients,
          onDoctorOpenAgenda: onDoctorOpenAgenda,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openSearch(context),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: KeepiColors.cardBorder.withValues(alpha: 0.8),
            ),
            boxShadow: [
              BoxShadow(
                color: KeepiColors.slate.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                size: 22,
                color: KeepiColors.slateLight.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Buscar citas, documentos y análisis…',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: KeepiColors.slateLight,
                      ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: KeepiColors.slateLight.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
