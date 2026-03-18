import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_theme.dart';
import '../core/decorative_background.dart';
import '../services/api_client.dart';
import '../services/cloud_storage_service.dart';
import '../services/config_service.dart' as config_dto;
import '../services/subscription_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  config_dto.UserConfigResponse? _config;
  bool _loading = true;
  String? _error;
  bool _switching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadConfig();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadConfig();
    }
  }

  Future<void> _loadConfig() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiClient>();
      final configService = config_dto.ConfigService(api);
      final config = await configService.getUserConfig();
      if (!mounted) return;
      setState(() {
        _config = config;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _switchToGoogleDrive() async {
    setState(() {
      _switching = true;
      _error = null;
    });
    try {
      final api = context.read<ApiClient>();
      final cloudService = CloudStorageService(api);
      final res = await cloudService.setupStorage('google_drive');
      if (!mounted) return;
      if (res.authorizationRequired && res.authorizationUrl != null && res.authorizationUrl!.isNotEmpty) {
        final uri = Uri.parse(res.authorizationUrl!);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Completa la autorización en el navegador y vuelve a la app.'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 4),
            ),
          );
        }
        await _loadConfig();
      } else {
        await _loadConfig();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Almacenamiento actualizado a Google Drive'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  Future<void> _switchToKeepiCloud() async {
    setState(() {
      _switching = true;
      _error = null;
    });
    try {
      final api = context.read<ApiClient>();
      final cloudService = CloudStorageService(api);
      try {
        await cloudService.setupStorage('keepi_cloud');
        if (!mounted) return;
        await _loadConfig();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Almacenamiento actualizado a Keepi Cloud'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } on DioException catch (e) {
        if (e.response?.statusCode == 402) {
          // Pago requerido: abrir Stripe Checkout en navegador externo
          final checkoutService = SubscriptionCheckoutService(api);
          try {
            final session = await checkoutService.createCheckoutSession();
            if (!mounted) return;
            final url = session.checkoutUrl;
            if (url.isEmpty) {
              setState(() => _error = 'No se pudo obtener la URL de pago. Revisa la configuración del servidor.');
              return;
            }
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } else {
              setState(() => _error = 'No se pudo abrir el navegador. URL: $url');
            }
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Completa el pago en el navegador. Al terminar vuelve a la app. Si cancelas, elige "Sin configurar".'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 5),
                ),
              );
            }
          } on DioException catch (e2) {
            if (e2.response?.statusCode == 400) {
              final detail = e2.response?.data is Map ? (e2.response?.data as Map)['detail'] : null;
              final msg = detail is String ? detail : 'Error al crear la sesión de pago. Intenta de nuevo.';
              setState(() => _error = msg.toString());
            } else {
              setState(() => _error = e2.response?.data?.toString() ?? e2.message ?? 'Error al obtener URL de pago.');
            }
          }
        } else {
          rethrow;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  Future<void> _setNotConfigured() async {
    setState(() {
      _switching = true;
      _error = null;
    });
    try {
      final api = context.read<ApiClient>();
      final cloudService = CloudStorageService(api);
      await cloudService.setupStorage('not_configured');
      if (!mounted) return;
      await _loadConfig();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Almacenamiento restablecido a sin configurar'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: DecorativeBackground(
        blobOpacity: 0.2,
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadConfig,
            color: KeepiColors.orange,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: KeepiColors.orangeSoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: KeepiColors.orange.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: KeepiColors.orange, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: theme.textTheme.bodySmall?.copyWith(color: KeepiColors.slate),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'Almacenamiento',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: KeepiColors.slate,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: KeepiColors.orange),
                        ),
                      ),
                    )
                  else if (_config != null) ...[
                    if (_switching)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: KeepiColors.orange,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Cargando…',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: KeepiColors.slateLight,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      _StorageTile(
                        icon: Icons.folder_rounded,
                        title: 'Google Drive',
                        subtitle: 'Usa tus carpetas de Google Drive.',
                        isCurrent: _config!.isGoogleDrive,
                        isDisabled: _switching,
                        onTap: _config!.isGoogleDrive ? null : _switchToGoogleDrive,
                      ),
                      const SizedBox(height: 10),
                      _StorageTile(
                        icon: Icons.cloud_rounded,
                        title: 'Keepi Cloud',
                        subtitle: 'Almacenamiento Keepi (requiere plan Premium por Stripe).',
                        isCurrent: _config!.isKeepiCloud,
                        isDisabled: _switching,
                        onTap: _config!.isKeepiCloud ? null : _switchToKeepiCloud,
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (!_config!.isNotConfigured)
                      TextButton.icon(
                        onPressed: _switching ? null : _setNotConfigured,
                        icon: const Icon(Icons.restore_rounded, size: 20, color: KeepiColors.slateLight),
                        label: Text(
                          'Restablecer a sin configurar',
                          style: theme.textTheme.bodyMedium?.copyWith(color: KeepiColors.slateLight),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StorageTile extends StatelessWidget {
  const _StorageTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isCurrent,
    required this.isDisabled,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isCurrent;
  final bool isDisabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDisabled || onTap == null ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: KeepiColors.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCurrent ? KeepiColors.orange : KeepiColors.cardBorder,
              width: isCurrent ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: KeepiColors.slate.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (isCurrent ? KeepiColors.orange : KeepiColors.slateLight).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 26,
                  color: isCurrent ? KeepiColors.orange : KeepiColors.slateLight,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: KeepiColors.slate,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: KeepiColors.slateLight,
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Activo',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: KeepiColors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!isCurrent && onTap != null && !isDisabled)
                const Icon(Icons.chevron_right_rounded, color: KeepiColors.slateLight, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
