import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/consultation_bootstrap_provider.dart';
import 'providers/expedientes_cache_provider.dart';
import 'providers/patients_cache_provider.dart';
import 'router/app_router.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/push_notification_service.dart';

/// Alias para notificaciones push (misma key que go_router).
final GlobalKey<NavigatorState> appNavigatorKey = rootNavigatorKey;

/// En web: controles más compactos (menos botones/FAB gigantes).
Widget _webAwareBuilder(BuildContext context, Widget? child) {
  if (!kIsWeb || child == null) return child ?? const SizedBox.shrink();
  final theme = Theme.of(context);
  return Theme(
    data: theme.copyWith(
      visualDensity: VisualDensity.compact,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 42),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(64, 42),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
    ),
    child: child,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await PushNotificationService.initializeFirebaseSafely();
  await PushNotificationService.configureTapHandlers(appNavigatorKey);
  final prefs = await SharedPreferences.getInstance();
  runApp(KeepiApp(prefs: prefs));
}

class KeepiApp extends StatelessWidget {
  const KeepiApp({super.key, required this.prefs});

  final SharedPreferences prefs;

  @override
  Widget build(BuildContext context) {
    final api = ApiClient();
    final authService = AuthService(api);
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) {
            final auth = AuthProvider(prefs, api, authService);
            api.bindAuthHandlers(
              refreshToken: auth.tryRefreshToken,
              onSessionExpired: auth.logout,
            );
            return auth;
          },
        ),
        ChangeNotifierProvider<ConsultationBootstrapProvider>(
          create: (_) => ConsultationBootstrapProvider(),
        ),
        ChangeNotifierProvider<ExpedientesCacheProvider>(
          create: (_) => ExpedientesCacheProvider(),
        ),
        ChangeNotifierProvider<PatientsCacheProvider>(
          create: (_) => PatientsCacheProvider(),
        ),
      ],
      child: const _KeepiRouterApp(),
    );
  }
}

class _KeepiRouterApp extends StatefulWidget {
  const _KeepiRouterApp();

  @override
  State<_KeepiRouterApp> createState() => _KeepiRouterAppState();
}

class _KeepiRouterAppState extends State<_KeepiRouterApp> {
  static const _minSplashDuration = Duration(milliseconds: 1500);
  GoRouter? _router;
  bool _minTimeElapsed = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(_minSplashDuration, () {
      if (mounted) setState(() => _minTimeElapsed = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _router ??= createAppRouter(context.read<AuthProvider>());
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final showSplash = auth.isLoading || !_minTimeElapsed;

    return MaterialApp.router(
      title: 'Keepi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      routerConfig: _router!,
      builder: (context, child) {
        if (showSplash) return const _SplashScreen();
        final content = _webAwareBuilder(context, child);
        if (!auth.isRefreshingToken) return content;
        return Stack(
          children: [
            content,
            ModalBarrier(
              dismissible: false,
              color: Colors.black.withValues(alpha: 0.18),
            ),
            const Center(
              child: SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: KeepiColors.orange,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset(
                  'assets/logo.png',
                  height: 96,
                  width: 96,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.folder_rounded,
                    size: 96,
                    color: KeepiColors.orange,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'Keepi',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: KeepiColors.slate,
                      letterSpacing: -0.5,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                'Organiza, clasifica y nunca pierdas un documento',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: KeepiColors.slateLight,
                    ),
              ),
              const SizedBox(height: 44),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: KeepiColors.orange,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
