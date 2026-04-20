import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../services/api_client.dart';
import '../../services/cloud_storage_service.dart';
import '../../services/config_service.dart' as config_dto;
import '../../services/subscription_service.dart';

/// Evita mostrar el diálogo de primera vez más de una vez por pantalla.
class FirstRunStorageGate {
  bool shown = false;
}

/// Misma UI y comportamiento que el flujo de [HomeScreen] para elegir almacenamiento.
Future<void> maybeShowFirstRunStorageDialog(
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

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: KeepiColors.slate.withOpacity(0.12),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: KeepiColors.skyBlueSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/logo.png',
                      height: 52,
                      width: 52,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.folder_rounded,
                        size: 52,
                        color: KeepiColors.orange,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '¿Dónde quieres guardar tus documentos?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: KeepiColors.slate,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Elige tu proveedor de almacenamiento principal. '
                'Podrás cambiarlo más adelante.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: KeepiColors.slateLight,
                    ),
              ),
              const SizedBox(height: 24),
              StorageOptionButton(
                icon: Icons.cloud_rounded,
                title: 'Keepi Cloud',
                subtitle: 'Almacenamiento seguro optimizado para Keepi.',
                highlight: true,
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  applyFirstRunStorageChoice(
                    context,
                    'keepi_cloud',
                    onReloadAfterChoice: onReloadAfterChoice,
                    setLoading: setLoading,
                    onApplyError: onApplyError,
                  );
                },
              ),
              const SizedBox(height: 12),
              StorageOptionButton(
                icon: Icons.folder_rounded,
                title: 'Google Drive',
                subtitle: 'Conecta tu Google Drive para usar tus carpetas.',
                highlight: false,
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  applyFirstRunStorageChoice(
                    context,
                    'google_drive',
                    onReloadAfterChoice: onReloadAfterChoice,
                    setLoading: setLoading,
                    onApplyError: onApplyError,
                  );
                },
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text(
                  'Ahora no',
                  style: TextStyle(color: KeepiColors.slateLight),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Misma lógica que `_applyStorageChoice` en [HomeScreen].
Future<void> applyFirstRunStorageChoice(
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
      if (context.mounted) setLoading?.call(false);
    } else {
      final cloudService = CloudStorageService(api);
      try {
        await cloudService.setupStorage(storageType);
        if (context.mounted) await onReloadAfterChoice();
      } on DioException catch (e) {
        if (e.response?.statusCode == 402) {
          final checkoutService = SubscriptionCheckoutService(api);
          try {
            final session = await checkoutService.createCheckoutSession();
            if (!context.mounted) return;
            final url = session.checkoutUrl;
            if (url.isNotEmpty) {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Completa el pago en el navegador. Al terminar vuelve a la app.',
                    ),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 5),
                  ),
                );
              }
            }
          } on DioException catch (e2) {
            if (context.mounted) {
              final detail = e2.response?.data is Map
                  ? (e2.response?.data as Map)['detail']
                  : null;
              final msg =
                  detail is String ? detail : 'Error al obtener la URL de pago.';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(msg),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
          if (context.mounted) await onReloadAfterChoice();
        } else {
          rethrow;
        }
      }
    }
  } catch (e) {
    if (!context.mounted) return;
    onApplyError?.call(e);
    setLoading?.call(false);
  } finally {
    if (context.mounted) setLoading?.call(false);
  }
}

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
