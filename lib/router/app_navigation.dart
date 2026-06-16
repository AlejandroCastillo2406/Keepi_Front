import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/app_theme.dart';
import 'app_paths.dart';
import 'router_extras.dart';

/// API única de navegación — siempre go_router.
abstract final class AppNavigation {
  static void go(BuildContext context, String path) => context.go(path);

  static Future<T?> push<T>(BuildContext context, String path, {Object? extra}) =>
      context.push<T>(path, extra: extra);

  static void pop<T>(BuildContext context, [T? result]) =>
      context.pop(result);

  static bool canPop(BuildContext context) => context.canPop();

  static Future<T?> pushDocumentViewer<T>(
    BuildContext context, {
    required String url,
    required String title,
    Map<String, String> headers = const {},
    String? mimeType,
    String? s3Path,
  }) =>
      push<T>(
        context,
        AppPaths.documentViewer,
        extra: DocumentViewerExtra(
          url: url,
          title: title,
          headers: headers,
          mimeType: mimeType,
          s3Path: s3Path,
        ),
      );

  static Future<T?> pushGlobalSearch<T>(
    BuildContext context, {
    GlobalSearchExtra? extra,
  }) =>
      push<T>(context, AppPaths.userSearch, extra: extra);

  static Future<T?> pushDoctorGlobalSearch<T>(
    BuildContext context, {
    GlobalSearchExtra? extra,
  }) =>
      push<T>(context, AppPaths.doctorSearch, extra: extra);

  /// Diálogo de carga sobre el navigator raíz (no cierra rutas del shell).
  static void showLoadingOverlay(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(
          child: CircularProgressIndicator(color: KeepiColors.orange),
        ),
      ),
    );
  }

  static void hideLoadingOverlay(BuildContext context) {
    final nav = Navigator.of(context, rootNavigator: true);
    if (nav.canPop()) nav.pop();
  }
}
