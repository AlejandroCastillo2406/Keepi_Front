import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Fondo limpio: gradiente suave y formas orgánicas (sin círculos).
class DecorativeBackground extends StatelessWidget {
  const DecorativeBackground({
    super.key,
    required this.child,
    this.blobOpacity = 0.22,
  });

  final Widget child;
  final double blobOpacity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                KeepiColors.surfaceBg,
                KeepiColors.skyBlueSoft.withOpacity(0.5),
                KeepiColors.orangeSoft.withOpacity(0.25),
                KeepiColors.slateSoft.withOpacity(0.15),
                KeepiColors.surfaceBg,
              ],
              stops: const [0.0, 0.2, 0.5, 0.75, 1.0],
            ),
          ),
        ),
        CustomPaint(painter: _BlobPainter(opacity: blobOpacity)),
        child,
      ],
    );
  }
}

/// Formas orgánicas suaves (solo paths, sin círculos).
class _BlobPainter extends CustomPainter {
  _BlobPainter({this.opacity = 0.22});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final blob1 = Path()
      ..moveTo(w * 0.85, 0)
      ..quadraticBezierTo(w * 1.2, h * 0.08, w * 0.95, h * 0.22)
      ..quadraticBezierTo(w * 0.7, h * 0.32, w * 0.6, h * 0.12)
      ..quadraticBezierTo(w * 0.75, -h * 0.05, w * 0.85, 0)
      ..close();
    canvas.drawPath(
      blob1,
      Paint()
        ..shader = RadialGradient(
          colors: [
            KeepiColors.skyBlue.withOpacity(opacity),
            KeepiColors.skyBlueLight.withOpacity(opacity * 0.5),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    final blob2 = Path()
      ..moveTo(0, h * 0.88)
      ..quadraticBezierTo(-w * 0.15, h * 0.7, w * 0.12, h * 0.75)
      ..quadraticBezierTo(w * 0.35, h * 0.82, w * 0.2, h * 1.1)
      ..quadraticBezierTo(0, h * 1.05, 0, h * 0.88)
      ..close();
    canvas.drawPath(
      blob2,
      Paint()
        ..shader = RadialGradient(
          colors: [
            KeepiColors.orange.withOpacity(opacity),
            KeepiColors.orangeLight.withOpacity(opacity * 0.4),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
  }

  @override
  bool shouldRepaint(covariant _BlobPainter old) => old.opacity != opacity;
}

/// Tarjeta estilo "liquid glass": blur + superficie translúcida.
class LiquidGlassCard extends StatelessWidget {
  const LiquidGlassCard({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.padding = const EdgeInsets.all(24),
    this.blurSigma = 12,
    this.borderWidth = 1,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double blurSigma;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.72),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withOpacity(0.85),
              width: borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: KeepiColors.slate.withOpacity(0.06),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: KeepiColors.skyBlue.withOpacity(0.04),
                blurRadius: 32,
                offset: const Offset(-2, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Fondo mínimo para listas: solo gradiente vertical.
class SubtleDecorativeBackground extends StatelessWidget {
  const SubtleDecorativeBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            KeepiColors.skyBlueSoft.withOpacity(0.2),
            KeepiColors.surfaceBg,
            KeepiColors.orangeSoft.withOpacity(0.08),
          ],
          stops: const [0.0, 0.4, 1.0],
        ),
      ),
      child: child,
    );
  }
}
