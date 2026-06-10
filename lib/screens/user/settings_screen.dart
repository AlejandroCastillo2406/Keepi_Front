import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../core/decorative_background.dart';
import '../../core/roles.dart';
import '../../core/web_layout.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../services/cloud_storage_service.dart';
import '../../services/config_service.dart' as config_dto;
import '../../widgets/profile_settings_widgets.dart';
import '../doctor/doctor_scheduling_settings_screen.dart';
import '../doctor/questionnaire/questionnaire_settings_screen.dart';

enum _SettingsSubPage { main, scheduling }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.embedded = false,
  });

  /// En web shell: sin AppBar, ocupa el panel principal.
  final bool embedded;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  config_dto.UserConfigResponse? _config;
  bool _loading = true;
  String? _error;
  bool _switching = false;
  _SettingsSubPage _subPage = _SettingsSubPage.main;

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
      if (res.authorizationRequired &&
          res.authorizationUrl != null &&
          res.authorizationUrl!.isNotEmpty) {
        final uri = Uri.parse(res.authorizationUrl!);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        if (mounted) {
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

  void _openQuestionnaireSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QuestionnaireSettingsScreen()),
    );
  }

  void _openSchedulingSettings() {
    if (widget.embedded || isWebWide(context)) {
      setState(() => _subPage = _SettingsSubPage.scheduling);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const DoctorSchedulingSettingsScreen(),
      ),
    );
  }

  void _backToSettingsMain() {
    setState(() => _subPage = _SettingsSubPage.main);
  }

  String _storageSubtitle() {
    final config = _config;
    if (config == null) return 'Elige dónde guardar tus documentos.';
    if (config.isKeepiCloud) {
      return 'Keepi Cloud · Almacenamiento seguro en la nube (S3).';
    }
    if (config.isGoogleDrive) {
      return 'Google Drive · Usa tus carpetas de Google Drive.';
    }
    return 'Sin configurar · Elige Keepi Cloud o Google Drive.';
  }

  Future<void> _openStoragePicker() async {
    if (_config == null || _switching) return;

    final config = _config!;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: KeepiColors.cardBorder,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Almacenamiento',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: KeepiColors.slate,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Elige dónde se guardarán tus documentos.',
                  style: TextStyle(
                    fontSize: 13,
                    color: KeepiColors.slateLight,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                ProfileSettingsRow(
                  icon: Icons.cloud_rounded,
                  accent: KeepiColors.orange,
                  title: 'Keepi Cloud',
                  subtitle: 'Almacenamiento seguro en la nube de Keepi (S3).',
                  isActive: config.isKeepiCloud,
                  onTap: config.isKeepiCloud
                      ? null
                      : () async {
                          Navigator.pop(sheetContext);
                          await _switchToKeepiCloud();
                        },
                ),
                const SizedBox(height: 10),
                ProfileSettingsRow(
                  icon: Icons.folder_rounded,
                  accent: KeepiColors.slate,
                  title: 'Google Drive',
                  subtitle: 'Usa tus carpetas de Google Drive.',
                  isActive: config.isGoogleDrive,
                  onTap: config.isGoogleDrive
                      ? null
                      : () async {
                          Navigator.pop(sheetContext);
                          await _switchToGoogleDrive();
                        },
                ),
                if (!config.isNotConfigured) ...[
                  const SizedBox(height: 14),
                  Center(
                    child: TextButton.icon(
                      onPressed: () async {
                        Navigator.pop(sheetContext);
                        await _setNotConfigured();
                      },
                      icon: const Icon(
                        Icons.restore_rounded,
                        size: 20,
                        color: KeepiColors.slateLight,
                      ),
                      label: const Text(
                        'Restablecer a sin configurar',
                        style: TextStyle(color: KeepiColors.slateLight),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(AuthProvider auth) {
    if (_subPage == _SettingsSubPage.scheduling) {
      return DoctorSchedulingSettingsScreen(
        embedded: true,
        onBack: _backToSettingsMain,
      );
    }

    final isDoctor = auth.roleName == AppRole.doctor;
    final configCount = isDoctor ? 3 : 1;

    return RefreshIndicator(
      onRefresh: _loadConfig,
      color: KeepiColors.orange,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          isWebWide(context) ? 28 : 22,
          widget.embedded ? 8 : 8,
          isWebWide(context) ? 28 : 22,
          32,
        ),
        child: WebContentFrame(
          maxWidth: kWebContentMaxWidth,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProfileHeroCard(
                name: auth.name ?? 'Usuario',
                email: auth.email ?? '',
                namePrefix: isDoctor ? 'Dr.' : '',
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: KeepiColors.orangeSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: KeepiColors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: KeepiColors.orange,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: KeepiColors.slate),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (isDoctor) ...[
                const SizedBox(height: 26),
                ProfileSectionDivider(
                  tag: 'CONFIGURACIÓN',
                  count: configCount,
                ),
                const SizedBox(height: 14),
                ProfileSettingsRow(
                  icon: Icons.quiz_outlined,
                  accent: KeepiColors.skyBlue,
                  title: 'Cuestionarios de salud',
                  subtitle:
                      'Gestiona plantillas y preguntas por especialidad.',
                  onTap: _openQuestionnaireSettings,
                ),
                const SizedBox(height: 10),
                ProfileSettingsRow(
                  icon: Icons.schedule_rounded,
                  accent: KeepiColors.orange,
                  title: 'Horario de consulta',
                  subtitle:
                      'Días y horas en que los pacientes pueden agendar citas.',
                  onTap: _openSchedulingSettings,
                ),
                const SizedBox(height: 10),
                ProfileSettingsRow(
                  icon: Icons.storage_rounded,
                  accent: const Color(0xFF0EA5E9),
                  title: 'Almacenamiento',
                  subtitle: _loading ? 'Cargando…' : _storageSubtitle(),
                  onTap: _loading || _switching ? null : _openStoragePicker,
                ),
              ] else ...[
                const SizedBox(height: 26),
                const ProfileSectionDivider(tag: 'CONFIGURACIÓN', count: 1),
                const SizedBox(height: 14),
                ProfileSettingsRow(
                  icon: Icons.storage_rounded,
                  accent: const Color(0xFF0EA5E9),
                  title: 'Almacenamiento',
                  subtitle: _loading ? 'Cargando…' : _storageSubtitle(),
                  onTap: _loading || _switching ? null : _openStoragePicker,
                ),
              ],
              if (_switching) ...[
                const SizedBox(height: 14),
                const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: KeepiColors.orange,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 26),
              const ProfileSectionDivider(tag: 'SESIÓN', count: 1),
              const SizedBox(height: 14),
              ProfileSettingsRow(
                icon: Icons.logout_rounded,
                accent: Colors.red,
                title: 'Cerrar sesión',
                subtitle: 'Salir de Keepi en este dispositivo.',
                onTap: auth.logout,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final useEmbeddedChrome = widget.embedded || isWebWide(context);

    if (useEmbeddedChrome && widget.embedded) {
      return ColoredBox(
        color: KeepiColors.surfaceBg,
        child: _buildContent(auth),
      );
    }

    if (useEmbeddedChrome) {
      return Scaffold(
        backgroundColor: KeepiColors.surfaceBg,
        appBar: AppBar(
          title: const Text('Configuración'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: Navigator.canPop(context),
        ),
        body: _buildContent(auth),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: DecorativeBackground(
        blobOpacity: 0.2,
        child: SafeArea(child: _buildContent(auth)),
      ),
    );
  }
}
