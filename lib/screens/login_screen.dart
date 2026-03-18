import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/decorative_background.dart';
import '../providers/auth_provider.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(_emailController.text.trim(), _passwordController.text);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final error = auth.error;
    final theme = Theme.of(context);

    return Scaffold(
      body: DecorativeBackground(
        blobOpacity: 0.2,
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      const SizedBox(height: 36),
                      LiquidGlassCard(
                        borderRadius: 22,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        blurSigma: 10,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.asset(
                                'assets/logo.png',
                                height: 56,
                                width: 56,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.folder_rounded,
                                  size: 56,
                                  color: KeepiColors.orange,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Keepi',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: KeepiColors.slate,
                                letterSpacing: -0.5,
                                fontSize: 28,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Organiza, clasifica y nunca pierdas un documento',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: KeepiColors.slateLight,
                          fontSize: 14,
                          height: 1.35,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Bienvenido',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: KeepiColors.slate,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Inicia sesión para acceder a tus documentos',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: KeepiColors.slateLight,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _FeatureChip(
                            icon: Icons.folder_rounded,
                            label: 'Organiza',
                          ),
                          SizedBox(width: 10),
                          _FeatureChip(
                            icon: Icons.auto_awesome_rounded,
                            label: 'Clasifica',
                          ),
                          SizedBox(width: 10),
                          _FeatureChip(
                            icon: Icons.verified_user_outlined,
                            label: 'Seguro',
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      LiquidGlassCard(
                        padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (error != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: KeepiColors.orangeSoft.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: KeepiColors.orange.withOpacity(0.35),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.info_outline_rounded,
                                        size: 20,
                                        color: KeepiColors.orange,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          error,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: KeepiColors.slate,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                autocorrect: false,
                                decoration: InputDecoration(
                                  labelText: 'Correo',
                                  hintText: 'tu@email.com',
                                  prefixIcon: const Icon(
                                    Icons.email_outlined,
                                    size: 22,
                                    color: KeepiColors.slateLight,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.6),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: KeepiColors.cardBorder.withOpacity(0.8),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: KeepiColors.skyBlue,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Ingresa tu correo';
                                  if (!v.contains('@')) return 'Correo no válido';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: 'Contraseña',
                                  prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                    size: 22,
                                    color: KeepiColors.slateLight,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                      size: 22,
                                      color: KeepiColors.slateLight,
                                    ),
                                    onPressed: () =>
                                        setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.6),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: KeepiColors.cardBorder.withOpacity(0.8),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: KeepiColors.skyBlue,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 26),
                              FilledButton(
                                onPressed: _isLoading ? null : _submit,
                                style: FilledButton.styleFrom(
                                  backgroundColor: KeepiColors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Iniciar sesión'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const RegisterScreen()),
                          );
                        },
                        child: RichText(
                          text: TextSpan(
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: KeepiColors.slateLight,
                            ),
                            children: const [
                              TextSpan(text: '¿No tienes cuenta? '),
                              TextSpan(
                                text: 'Regístrate',
                                style: TextStyle(
                                  color: KeepiColors.skyBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.7),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: KeepiColors.orange),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: KeepiColors.slate,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}
