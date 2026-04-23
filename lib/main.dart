import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/app_theme.dart';
import 'core/decorative_background.dart';
import 'providers/auth_provider.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/push_notification_service.dart';
import 'core/roles.dart';
import 'screens/auth/auth.dart';
import 'screens/doctor/doctor.dart';
import 'screens/user/user.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await PushNotificationService.initializeFirebaseSafely();
  await PushNotificationService.configureTapHandlers(appNavigatorKey);
  runApp(const KeepiApp());
}

class KeepiApp extends StatelessWidget {
  const KeepiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return MaterialApp(
            title: 'Keepi',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.theme,
            home: const _SplashScreen(),
          );
        }
        final prefs = snapshot.data!;
        final api = ApiClient();
        final authService = AuthService(api);
        return MultiProvider(
          providers: [
            Provider<ApiClient>.value(value: api),
            ChangeNotifierProvider<AuthProvider>(
              create: (_) => AuthProvider(prefs, api, authService),
            ),
          ],
          child: MaterialApp(
            navigatorKey: appNavigatorKey,
            title: 'Keepi',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.theme,
            home: const _AuthWrapper(),
          ),
        );
      },
    );
  }
}

class _AuthWrapper extends StatefulWidget {
  const _AuthWrapper();

  @override
  State<_AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<_AuthWrapper> {
  static const _minSplashDuration = Duration(milliseconds: 1500);
  bool _minTimeElapsed = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(_minSplashDuration, () {
      if (mounted) setState(() => _minTimeElapsed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final showSplash = auth.isLoading || !_minTimeElapsed;
    if (showSplash) {
      return const _SplashScreen();
    }
    if (auth.isLoggedIn) {
      if (auth.mustChangePassword) {
        return const ForcePasswordChangeScreen();
      }
      final role = auth.roleName ?? AppRole.user;
      if (role == AppRole.doctor) {
        return const DoctorHomeScreen();
      }
      // Vista de paciente temporalmente deshabilitada por negocio.
      // Para reactivarla, restaurar PatientHomeScreen aquí.
      if (role == AppRole.patient) {
        return const _PatientViewDisabledScreen();
      }
      return const HomeScreen();
    }
    return const LoginScreen();
  }
}

class _PatientViewDisabledScreen extends StatelessWidget {
  const _PatientViewDisabledScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecorativeBackground(
        blobOpacity: 0.2,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: KeepiColors.orangeSoft,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.visibility_off_rounded,
                      size: 38,
                      color: KeepiColors.orange,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Vista de paciente deshabilitada',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: KeepiColors.slate,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Temporalmente esta sección no está disponible.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: KeepiColors.slateLight,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecorativeBackground(
        blobOpacity: 0.2,
        child: SafeArea(
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
      ),
    );
  }
}

