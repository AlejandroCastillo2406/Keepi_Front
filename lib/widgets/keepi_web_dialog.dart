import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/web_layout.dart';

/// Shell visual unificado para modales web (cabecera oscura + cuerpo en tarjeta).
class KeepiWebDialogShell extends StatelessWidget {
  const KeepiWebDialogShell({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
    this.tag,
    this.footer,
    this.maxWidth = 560,
    this.maxHeightFactor = 0.88,
    this.onClose,
    this.canClose = true,
    this.iconAccent,
  });

  final String title;
  final String? subtitle;
  final String? tag;
  final IconData icon;
  final Color? iconAccent;
  final Widget child;
  final Widget? footer;
  final double maxWidth;
  final double maxHeightFactor;
  final VoidCallback? onClose;
  final bool canClose;

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
    String? subtitle,
    String? tag,
    Widget? footer,
    double maxWidth = 560,
    double maxHeightFactor = 0.88,
    bool canClose = true,
    VoidCallback? onClose,
    Color? iconAccent,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: canClose && barrierDismissible,
      barrierColor: KeepiColors.slate.withValues(alpha: 0.48),
      builder: (ctx) => KeepiWebDialogShell(
        title: title,
        subtitle: subtitle,
        tag: tag,
        icon: icon,
        iconAccent: iconAccent,
        footer: footer,
        maxWidth: maxWidth,
        maxHeightFactor: maxHeightFactor,
        canClose: canClose,
        onClose: onClose ?? () => Navigator.of(ctx).pop(),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = iconAccent ?? KeepiColors.orange;
    final maxH = MediaQuery.sizeOf(context).height * maxHeightFactor;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxH),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 60,
                offset: const Offset(0, 24),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _KeepiDialogHeroHeader(
                title: title,
                subtitle: subtitle,
                tag: tag,
                icon: icon,
                iconAccent: accent,
                canClose: canClose,
                onClose: onClose ?? () => Navigator.of(context).pop(),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: child,
                ),
              ),
              if (footer != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: footer!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeepiDialogHeroHeader extends StatelessWidget {
  const _KeepiDialogHeroHeader({
    required this.title,
    required this.icon,
    required this.iconAccent,
    required this.onClose,
    this.subtitle,
    this.tag,
    this.canClose = true,
  });

  final String title;
  final String? subtitle;
  final String? tag;
  final IconData icon;
  final Color iconAccent;
  final VoidCallback onClose;
  final bool canClose;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: tag != null || (subtitle != null && subtitle!.isNotEmpty)
              ? 118
              : 96,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2D3F4C), Color(0xFF46555F)],
            ),
          ),
        ),
        Positioned(
          right: -24,
          top: -24,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
        ),
        Positioned(
          right: 48,
          bottom: -18,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconAccent.withValues(alpha: 0.18),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 16, 0),
          child: SizedBox(
            height: tag != null || (subtitle != null && subtitle!.isNotEmpty)
                ? 118
                : 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: iconAccent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: iconAccent.withValues(alpha: 0.42),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: Color.lerp(iconAccent, Colors.white, 0.45),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (tag != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Text(
                            tag!,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.35,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (canClose)
                  GestureDetector(
                    onTap: onClose,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Diálogo de confirmación con diseño Keepi (web y móvil).
class KeepiConfirmDialog {
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Cancelar',
    IconData icon = Icons.help_outline_rounded,
    Color accent = KeepiColors.orange,
    bool destructive = false,
    bool barrierDismissible = true,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: KeepiColors.slate.withValues(alpha: 0.48),
      builder: (ctx) => KeepiWebDialogShell(
        title: title,
        icon: icon,
        iconAccent: accent,
        maxWidth: 440,
        maxHeightFactor: 0.55,
        child: Text(
          message,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: KeepiColors.slateLight,
            height: 1.45,
          ),
        ),
        footer: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: KeepiColors.slateLight,
                  side: const BorderSide(color: KeepiColors.cardBorder),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  cancelLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      destructive ? const Color(0xFFDC2626) : accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  confirmLabel,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Loading centrado con estilo Keepi.
void showKeepiLoadingDialog(BuildContext context, {String message = 'Cargando…'}) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: KeepiColors.slate.withValues(alpha: 0.35),
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: KeepiColors.orange,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: KeepiColors.slate,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// En web: dialog Keepi. En móvil: bottom sheet (o dialog si [forceDialog]).
Future<T?> showKeepiAdaptiveSurface<T>(
  BuildContext context, {
  required Widget Function(BuildContext ctx) builder,
  bool forceDialog = false,
}) {
  if (isWebWide(context) || forceDialog) {
    return showDialog<T>(
      context: context,
      barrierColor: KeepiColors.slate.withValues(alpha: 0.48),
      builder: builder,
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: builder,
  );
}

/// Tarjeta blanca para contenido de formularios dentro de modales.
Widget keepiDialogFormCard({required Widget child}) {
  return Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: KeepiColors.cardBorder),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}

/// Footer estándar Cancelar + acción principal.
Widget keepiDialogFooter({
  required VoidCallback onCancel,
  required VoidCallback onConfirm,
  String cancelLabel = 'Cancelar',
  required String confirmLabel,
  IconData? confirmIcon,
  bool confirmEnabled = true,
}) {
  return Row(
    children: [
      Expanded(
        child: OutlinedButton(
          onPressed: onCancel,
          style: OutlinedButton.styleFrom(
            foregroundColor: KeepiColors.slateLight,
            side: const BorderSide(color: KeepiColors.cardBorder),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            cancelLabel,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        flex: 2,
        child: FilledButton.icon(
          onPressed: confirmEnabled ? onConfirm : null,
          style: FilledButton.styleFrom(
            backgroundColor: KeepiColors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: Icon(confirmIcon ?? Icons.check_rounded, size: 18),
          label: Text(
            confirmLabel,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    ],
  );
}
