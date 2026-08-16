import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color lightCanvas = Color(0xFFF7F7F5);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSubtle = Color(0xFFF1F1EF);
  static const Color lightSelected = Color(0xFFE9E8FF);
  static const Color lightText = Color(0xFF242424);
  static const Color lightSecondary = Color(0xFF686868);
  static const Color lightBorder = Color(0xFFE2E2DE);
  static const Color lightAccent = Color(0xFF5B57D9);
  static const Color lightDanger = Color(0xFFC73E3A);

  static const Color darkCanvas = Color(0xFF191919);
  static const Color darkSurface = Color(0xFF222222);
  static const Color darkSubtle = Color(0xFF2C2C2C);
  static const Color darkSelected = Color(0xFF34305D);
  static const Color darkText = Color(0xFFF2F2F0);
  static const Color darkSecondary = Color(0xFFB8B8B3);
  static const Color darkBorder = Color(0xFF383836);
  static const Color darkAccent = Color(0xFF918DFF);
  static const Color darkDanger = Color(0xFFEF7772);

  // Status colors
  static const Color success = Color(0xFF2E7D32);
  static const Color successContainerLight = Color(0xFFE8F5E9);
  static const Color successContainerDark = Color(0xFF1B3820);
  static const Color onSuccessContainerLight = Color(0xFF1B5E20);
  static const Color onSuccessContainerDark = Color(0xFFA5D6A7);

  static const Color warning = Color(0xFFE65100);
  static const Color warningContainerLight = Color(0xFFFFF3E0);
  static const Color warningContainerDark = Color(0xFF3E2713);
  static const Color onWarningContainerLight = Color(0xFFBF360C);
  static const Color onWarningContainerDark = Color(0xFFFFCC80);

  static const Color info = Color(0xFF0277BD);
  static const Color infoContainerLight = Color(0xFFE1F5FE);
  static const Color infoContainerDark = Color(0xFF0D2D42);
  static const Color onInfoContainerLight = Color(0xFF01579B);
  static const Color onInfoContainerDark = Color(0xFF81D4FA);

  static const Color error = Color(0xFFC73E3A);
  static const Color errorContainerLight = Color(0xFFFFEBEE);
  static const Color errorContainerDark = Color(0xFF3E1C1A);
  static const Color onErrorContainerLight = Color(0xFFB71C1C);
  static const Color onErrorContainerDark = Color(0xFFFFCDD2);

  /// Calculates relative luminance according to WCAG 2.1 specs
  static double getRelativeLuminance(Color color) {
    double transformComponent(double c) {
      return c <= 0.03928
          ? c / 12.92
          : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    }

    final double r = transformComponent(
      ((color.toARGB32() >> 16) & 0xFF) / 255.0,
    );
    final double g = transformComponent(
      ((color.toARGB32() >> 8) & 0xFF) / 255.0,
    );
    final double b = transformComponent((color.toARGB32() & 0xFF) / 255.0);

    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// Calculates WCAG 2.1 contrast ratio between two colors (returns value between 1.0 and 21.0)
  static double getContrastRatio(Color foreground, Color background) {
    final double lum1 = getRelativeLuminance(foreground);
    final double lum2 = getRelativeLuminance(background);
    final double brighter = math.max(lum1, lum2);
    final double darker = math.min(lum1, lum2);
    return (brighter + 0.05) / (darker + 0.05);
  }
}

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

abstract final class AppBreakpoints {
  static const double compact = 600;
  static const double expanded = 1024;
}

abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool dark = brightness == Brightness.dark;
    final Color canvas = dark ? AppColors.darkCanvas : AppColors.lightCanvas;
    final Color surface = dark ? AppColors.darkSurface : AppColors.lightSurface;
    final Color text = dark ? AppColors.darkText : AppColors.lightText;
    final Color secondary = dark
        ? AppColors.darkSecondary
        : AppColors.lightSecondary;
    final Color accent = dark ? AppColors.darkAccent : AppColors.lightAccent;
    final Color border = dark ? AppColors.darkBorder : AppColors.lightBorder;
    final Color danger = dark ? AppColors.darkDanger : AppColors.lightDanger;
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      surface: surface,
      error: danger,
    );
    final TextTheme typography = Typography.material2021(
      platform: TargetPlatform.android,
    ).black.apply(bodyColor: text, displayColor: text);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      dividerColor: border,
      focusColor: accent.withValues(alpha: 0.12),
      hoverColor: (dark ? Colors.white : Colors.black).withValues(alpha: 0.04),
      highlightColor: accent.withValues(alpha: 0.08),
      textTheme: typography.copyWith(
        headlineLarge: typography.headlineLarge?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          height: 1.28,
        ),
        headlineMedium: typography.headlineMedium?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          height: 1.36,
        ),
        titleLarge: typography.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: typography.bodyLarge?.copyWith(fontSize: 16, height: 1.56),
        bodyMedium: typography.bodyMedium?.copyWith(fontSize: 14, height: 1.5),
        labelLarge: typography.labelLarge?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        bodySmall: typography.bodySmall?.copyWith(
          fontSize: 12,
          color: secondary,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: accent, width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: danger, width: 2.0),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
