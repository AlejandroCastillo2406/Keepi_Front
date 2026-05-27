import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// Barra inferior: botón Exportar (modo normal) o Cancelar + confirmar (modo selección).
class DocumentExportBar extends StatelessWidget {
  const DocumentExportBar({
    super.key,
    required this.selectionMode,
    required this.selectedCount,
    required this.onStartSelection,
    required this.onCancelSelection,
    required this.onConfirmExport,
    this.exporting = false,
    this.enabled = true,
  });

  final bool selectionMode;
  final int selectedCount;
  final VoidCallback onStartSelection;
  final VoidCallback onCancelSelection;
  final VoidCallback onConfirmExport;
  final bool exporting;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Material(
          elevation: 8,
          shadowColor: KeepiColors.slate.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: selectionMode ? _selectionBar() : _exportButton(),
          ),
        ),
      ),
    );
  }

  Widget _exportButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: FilledButton.tonalIcon(
        onPressed: enabled && !exporting ? onStartSelection : null,
        icon: const Icon(Icons.folder_zip_outlined, size: 22),
        label: const Text(
          'Exportar expedientes',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: KeepiColors.orangeSoft,
          foregroundColor: KeepiColors.orange,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
    );
  }

  Widget _selectionBar() {
    return Row(
      children: [
        TextButton(
          onPressed: exporting ? null : onCancelSelection,
          child: const Text('Cancelar'),
        ),
        const Spacer(),
        FilledButton.icon(
          onPressed: exporting || selectedCount == 0 ? null : onConfirmExport,
          icon: exporting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.folder_zip_outlined, size: 20),
          label: Text(
            exporting
                ? 'Exportando…'
                : 'Exportar${selectedCount > 0 ? ' ($selectedCount)' : ''}',
          ),
          style: FilledButton.styleFrom(
            backgroundColor: KeepiColors.orange,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
