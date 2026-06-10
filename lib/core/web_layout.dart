import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Ancho mínimo para layout escritorio en navegador (Chrome, Edge, etc.).
const double kWebLayoutBreakpoint = 900;

/// Contenido centrado en formularios y detalle.
const double kWebContentMaxWidth = 1120;

/// Formularios estrechos (login, modales).
const double kWebFormMaxWidth = 440;

bool isWebWide(BuildContext context) =>
    kIsWeb && MediaQuery.sizeOf(context).width >= kWebLayoutBreakpoint;

/// Centra y limita ancho del contenido en web ancho.
class WebContentFrame extends StatelessWidget {
  const WebContentFrame({
    super.key,
    required this.child,
    this.maxWidth = kWebContentMaxWidth,
    this.padding = const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (!isWebWide(context)) return child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Botón primario compacto para sidebar web (evita FAB gigante).
class WebSidebarButton extends StatelessWidget {
  const WebSidebarButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color = KeepiColors.orange,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          minimumSize: const Size(0, 42),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

/// Contenedor para pantallas embebidas en el shell web (sin ocultar la sidebar).
class EmbeddedWebPage extends StatelessWidget {
  const EmbeddedWebPage({
    super.key,
    required this.child,
    this.title,
    this.onBack,
  });

  final Widget child;
  final String? title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: KeepiColors.surfaceBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onBack != null || (title != null && title!.trim().isNotEmpty))
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 28, 0),
              child: Row(
                children: [
                  if (onBack != null)
                    IconButton(
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: KeepiColors.slate,
                    ),
                  if (title != null && title!.trim().isNotEmpty)
                    Expanded(
                      child: Text(
                        title!,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: KeepiColors.slate,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
