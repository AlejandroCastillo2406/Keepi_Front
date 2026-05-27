import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// Botón flotante inferior izquierdo (espejo del [IosFab] de añadir).
class IosExportFab extends StatefulWidget {
  const IosExportFab({
    super.key,
    required this.onPressed,
    this.loading = false,
    this.label,
    this.icon = Icons.folder_zip_outlined,
  });

  final VoidCallback? onPressed;
  final bool loading;
  final String? label;
  final IconData icon;

  @override
  State<IosExportFab> createState() => _IosExportFabState();
}

class _IosExportFabState extends State<IosExportFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1, end: 0.94).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    final enabled = widget.onPressed != null && !widget.loading;

    return GestureDetector(
      onTapDown: enabled ? (_) => _controller.forward() : null,
      onTapUp: enabled ? (_) => _controller.reverse() : null,
      onTapCancel: enabled ? () => _controller.reverse() : null,
      onTap: enabled ? widget.onPressed : null,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: KeepiColors.skyBlue.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: KeepiColors.slate.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [KeepiColors.skyBlue, KeepiColors.skyBlueLight],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: label != null ? 18 : 0,
              vertical: 0,
            ),
            child: SizedBox(
              height: 56,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (label != null) ...[
                    const SizedBox(width: 4),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: widget.loading
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Icon(widget.icon, color: Colors.white, size: 26),
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
