import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import '../../services/cloud_storage_service.dart';
import '../../services/config_service.dart' as config_dto;

/// Evita activar Keepi Cloud más de una vez por pantalla.
class FirstRunStorageGate {
  bool shown = false;
}

/// Activa Keepi Cloud (S3) por defecto si el usuario aún no eligió almacenamiento.
Future<void> ensureDefaultKeepiCloudStorage(
  BuildContext context, {
  required config_dto.UserConfigResponse config,
  required FirstRunStorageGate gate,
  required Future<void> Function() onReloadAfterChoice,
  void Function(bool loading)? setLoading,
  void Function(Object e)? onApplyError,
}) async {
  if (gate.shown || !context.mounted) return;
  if (!config.isNotConfigured) return;
  gate.shown = true;

  await applyStorageChoice(
    context,
    'keepi_cloud',
    onReloadAfterChoice: onReloadAfterChoice,
    setLoading: setLoading,
    onApplyError: onApplyError,
  );
}

/// @deprecated Usar [ensureDefaultKeepiCloudStorage].
Future<void> maybeShowFirstRunStorageDialog(
  BuildContext context, {
  required config_dto.UserConfigResponse config,
  required FirstRunStorageGate gate,
  required Future<void> Function() onReloadAfterChoice,
  void Function(bool loading)? setLoading,
  void Function(Object e)? onApplyError,
}) =>
    ensureDefaultKeepiCloudStorage(
      context,
      config: config,
      gate: gate,
      onReloadAfterChoice: onReloadAfterChoice,
      setLoading: setLoading,
      onApplyError: onApplyError,
    );

Future<void> applyStorageChoice(
  BuildContext context,
  String storageType, {
  required Future<void> Function() onReloadAfterChoice,
  void Function(bool loading)? setLoading,
  void Function(Object e)? onApplyError,
}) async {
  setLoading?.call(true);
  try {
    final api = context.read<ApiClient>();

    if (storageType == 'google_drive') {
      final cloudService = CloudStorageService(api);
      final res = await cloudService.setupStorage('google_drive');
      if (!context.mounted) return;
      if (res.authorizationRequired &&
          res.authorizationUrl != null &&
          res.authorizationUrl!.isNotEmpty) {
        final uri = Uri.parse(res.authorizationUrl!);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Completa la autorización en el navegador y vuelve a la app.',
              ),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 4),
            ),
          );
        }
        if (context.mounted) await onReloadAfterChoice();
      } else {
        await onReloadAfterChoice();
      }
    } else {
      final cloudService = CloudStorageService(api);
      await cloudService.setupStorage(storageType);
      if (context.mounted) await onReloadAfterChoice();
    }
  } catch (e) {
    if (!context.mounted) return;
    onApplyError?.call(e);
  } finally {
    if (context.mounted) setLoading?.call(false);
  }
}

/// @deprecated Usar [applyStorageChoice].
Future<void> applyFirstRunStorageChoice(
  BuildContext context,
  String storageType, {
  required Future<void> Function() onReloadAfterChoice,
  void Function(bool loading)? setLoading,
  void Function(Object e)? onApplyError,
}) =>
    applyStorageChoice(
      context,
      storageType,
      onReloadAfterChoice: onReloadAfterChoice,
      setLoading: setLoading,
      onApplyError: onApplyError,
    );

class StorageOptionButton extends StatelessWidget {
  const StorageOptionButton({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.highlight,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool highlight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bgColor = highlight ? KeepiColors.orangeSoft : KeepiColors.slateSoft;
    final fgColor = highlight ? KeepiColors.orange : KeepiColors.slate;
    final iconBg = highlight
        ? KeepiColors.orange.withOpacity(0.2)
        : KeepiColors.slate.withOpacity(0.08);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: highlight
                  ? KeepiColors.orange.withOpacity(0.35)
                  : KeepiColors.cardBorder.withOpacity(0.6),
            ),
          ),
          child: Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: fgColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: fgColor,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: KeepiColors.slateLight,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: fgColor.withOpacity(0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
