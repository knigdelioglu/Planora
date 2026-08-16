import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color lightCanvas = Color(0xFFF8F8F6);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSubtle = Color(0xFFF1F1EE);
  static const Color lightSelected = Color(0xFFECEBFA);
  static const Color lightText = Color(0xFF252522);
  static const Color lightSecondary = Color(0xFF6E6E68);
  static const Color lightTertiary = Color(0xFF96968F);
  static const Color lightBorder = Color(0xFFE4E4DF);
  static const Color lightAccent = Color(0xFF5753C8);
  static const Color lightDanger = Color(0xFFB83B38);

  static const Color darkCanvas = Color(0xFF181817);
  static const Color darkSurface = Color(0xFF222220);
  static const Color darkSubtle = Color(0xFF2B2B29);
  static const Color darkSelected = Color(0xFF343250);
  static const Color darkText = Color(0xFFF1F1ED);
  static const Color darkSecondary = Color(0xFFB7B7B0);
  static const Color darkTertiary = Color(0xFF85857E);
  static const Color darkBorder = Color(0xFF393936);
  static const Color darkAccent = Color(0xFF9692F2);
  static const Color darkDanger = Color(0xFFE07470);

  static const Color success = Color(0xFF357A50);
  static const Color successContainerLight = Color(0xFFEAF4ED);
  static const Color successContainerDark = Color(0xFF20382A);
  static const Color onSuccessContainerLight = Color(0xFF235E3A);
  static const Color onSuccessContainerDark = Color(0xFFACD8B9);

  static const Color warning = Color(0xFF9B6500);
  static const Color warningContainerLight = Color(0xFFFFF4DD);
  static const Color warningContainerDark = Color(0xFF3A2D17);
  static const Color onWarningContainerLight = Color(0xFF754B00);
  static const Color onWarningContainerDark = Color(0xFFF2C56E);

  static const Color info = Color(0xFF356B9A);
  static const Color infoContainerLight = Color(0xFFEAF2F8);
  static const Color infoContainerDark = Color(0xFF1E3040);
  static const Color onInfoContainerLight = Color(0xFF24557E);
  static const Color onInfoContainerDark = Color(0xFFA7CCE8);

  static const Color error = lightDanger;
  static const Color errorContainerLight = Color(0xFFFBECEB);
  static const Color errorContainerDark = Color(0xFF402220);
  static const Color onErrorContainerLight = Color(0xFF8F2926);
  static const Color onErrorContainerDark = Color(0xFFF1B1AE);

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

abstract final class AppRadius {
  static const double control = 8;
  static const double surface = 10;
  static const double floating = 14;
}

abstract final class AppBreakpoints {
  static const double compact = 600;
  static const double expanded = 1024;
}

abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static bool get _desktopPlatform =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;

  static ThemeData _build(Brightness brightness) {
    final bool dark = brightness == Brightness.dark;
    final Color canvas = dark ? AppColors.darkCanvas : AppColors.lightCanvas;
    final Color surface = dark ? AppColors.darkSurface : AppColors.lightSurface;
    final Color subtle = dark ? AppColors.darkSubtle : AppColors.lightSubtle;
    final Color text = dark ? AppColors.darkText : AppColors.lightText;
    final Color secondary =
        dark ? AppColors.darkSecondary : AppColors.lightSecondary;
    final Color accent = dark ? AppColors.darkAccent : AppColors.lightAccent;
    final Color border = dark ? AppColors.darkBorder : AppColors.lightBorder;
    final Color danger = dark ? AppColors.darkDanger : AppColors.lightDanger;

    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      surface: surface,
      error: danger,
    ).copyWith(
      primary: accent,
      surfaceContainerLowest: canvas,
      surfaceContainerLow: surface,
      surfaceContainer: subtle,
      outline: border,
      outlineVariant: border.withValues(alpha: 0.72),
    );

    final TextTheme baseTypography = Typography.material2021(
      platform: defaultTargetPlatform,
    ).black.apply(bodyColor: text, displayColor: text);

    final TextTheme typography = baseTypography.copyWith(
      headlineLarge: baseTypography.headlineLarge?.copyWith(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        height: 1.24,
        letterSpacing: -0.35,
      ),
      headlineMedium: baseTypography.headlineMedium?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.28,
        letterSpacing: -0.15,
      ),
      headlineSmall: baseTypography.headlineSmall?.copyWith(
        fontSize: 19,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      titleLarge: baseTypography.titleLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      titleMedium: baseTypography.titleMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: baseTypography.bodyLarge?.copyWith(
        fontSize: 16,
        height: 1.55,
      ),
      bodyMedium: baseTypography.bodyMedium?.copyWith(
        fontSize: 14,
        height: 1.45,
      ),
      labelLarge: baseTypography.labelLarge?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      bodySmall: baseTypography.bodySmall?.copyWith(
        fontSize: 12,
        height: 1.35,
        color: secondary,
      ),
      labelSmall: baseTypography.labelSmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: secondary,
      ),
    );

    final VisualDensity density = _desktopPlatform
        ? const VisualDensity(horizontal: -1, vertical: -1)
        : VisualDensity.standard;

    return ThemeData(
      useMaterial3: true,
      platform: defaultTargetPlatform,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      dividerColor: border,
      visualDensity: density,
      splashFactory: InkSparkle.splashFactory,
      focusColor: accent.withValues(alpha: 0.12),
      hoverColor:
          (dark ? Colors.white : Colors.black).withValues(alpha: 0.035),
      highlightColor: accent.withValues(alpha: 0.07),
      textTheme: typography,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: canvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: text,
        centerTitle: false,
        toolbarHeight: _desktopPlatform ? 54 : 56,
        titleTextStyle: typography.titleLarge?.copyWith(color: text),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.surface),
          side: BorderSide(color: border.withValues(alpha: 0.85)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        isDense: _desktopPlatform,
        hintStyle: typography.bodyMedium?.copyWith(
          color: dark ? AppColors.darkTertiary : AppColors.lightTertiary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: danger, width: 1.25),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: BorderSide(color: danger, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 13,
          vertical: _desktopPlatform ? 10 : 13,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          iconSize: 20,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: density,
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          side: WidgetStatePropertyAll(BorderSide(color: border)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        elevation: 0,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor:
            dark ? AppColors.darkSelected : AppColors.lightSelected,
        labelTextStyle: WidgetStatePropertyAll(typography.labelSmall),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        elevation: 0,
        minWidth: 68,
        indicatorColor:
            dark ? AppColors.darkSelected : AppColors.lightSelected,
        selectedIconTheme: IconThemeData(color: accent, size: 21),
        unselectedIconTheme: IconThemeData(color: secondary, size: 20),
        selectedLabelTextStyle: typography.labelSmall?.copyWith(
          color: text,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: typography.labelSmall,
      ),
      dividerTheme: DividerThemeData(
        color: border.withValues(alpha: 0.75),
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        backgroundColor: subtle,
        labelStyle: typography.labelSmall,
        padding: const EdgeInsets.symmetric(horizontal: 6),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.floating),
          side: BorderSide(color: border),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.surface),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.floating),
          side: BorderSide(color: border),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.floating),
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 450),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFFEEEEEA) : const Color(0xFF30302E),
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: TextStyle(
          color: dark ? const Color(0xFF262624) : Colors.white,
          fontSize: 12,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
