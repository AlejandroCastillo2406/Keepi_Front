import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Colores inspirados en el logo Keepi: naranja, azul cielo, gris pizarra.
class KeepiColors {
  KeepiColors._();

  static const Color orange = Color(0xFFE37400);
  static const Color orangeLight = Color(0xFFFF9A3D);
  static const Color orangeSoft = Color(0xFFFFF0E6);

  static const Color skyBlue = Color(0xFF64B4E6);
  static const Color skyBlueLight = Color(0xFF9DD4F5);
  static const Color skyBlueSoft = Color(0xFFE8F4FC);

  static const Color slate = Color(0xFF46555F);
  static const Color slateLight = Color(0xFF6B7C87);
  static const Color slateSoft = Color(0xFFF0F2F4);

  static const Color surfaceBg = Color(0xFFF8FAFC);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE8ECF0);

  /// Verde para éxito y badge "verificado por Keepi"
  static const Color green = Color(0xFF22C55E);
}

class AppTheme {
  AppTheme._();

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: KeepiColors.orange,
        onPrimary: Colors.white,
        primaryContainer: KeepiColors.orangeSoft,
        onPrimaryContainer: KeepiColors.slate,
        secondary: KeepiColors.skyBlue,
        onSecondary: Colors.white,
        secondaryContainer: KeepiColors.skyBlueSoft,
        onSecondaryContainer: KeepiColors.slate,
        tertiary: KeepiColors.slate,
        onTertiary: Colors.white,
        surface: KeepiColors.surfaceBg,
        onSurface: KeepiColors.slate,
        onSurfaceVariant: KeepiColors.slateLight,
        outline: KeepiColors.cardBorder,
        outlineVariant: KeepiColors.slateSoft,
        error: const Color(0xFFD32F2F),
        onError: Colors.white,
        errorContainer: const Color(0xFFFFEBEE),
        onErrorContainer: const Color(0xFFB71C1C),
        surfaceContainerLow: KeepiColors.cardBg,
        shadow: KeepiColors.slate.withOpacity(0.12),
      ),
      scaffoldBackgroundColor: KeepiColors.surfaceBg,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        backgroundColor: KeepiColors.surfaceBg,
        foregroundColor: KeepiColors.slate,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: KeepiColors.slate,
        ),
        iconTheme: IconThemeData(color: KeepiColors.slate, size: 24),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: KeepiColors.cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: KeepiColors.cardBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: KeepiColors.cardBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: KeepiColors.skyBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD32F2F)),
        ),
        labelStyle: const TextStyle(
          color: KeepiColors.slateLight,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        hintStyle: TextStyle(
          color: KeepiColors.slateLight.withOpacity(0.8),
          fontSize: 15,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: KeepiColors.orange,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: KeepiColors.skyBlue,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: KeepiColors.slate,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: KeepiColors.cardBorder.withOpacity(0.8),
        thickness: 1,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: KeepiColors.slate,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: KeepiColors.slate,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: KeepiColors.slate,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.1,
          color: KeepiColors.slate,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.1,
          color: KeepiColors.slate,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.1,
          color: KeepiColors.slate,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.2,
          color: KeepiColors.slateLight,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}
