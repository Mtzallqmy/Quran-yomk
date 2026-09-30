import 'package:flutter/material.dart';

abstract final class TarteelTokens {
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMs = 12;
  static const double spaceMd = 16;
  static const double spaceXl = 32;
  static const double radiusMedium = 12;
  static const double radiusCardLarge = 24;
  static const double spaceLg = 24;
  static const double radiusSm = 8;
  static const double radiusMd = 16;
  static const double radiusLg = 28;
}

class TarteelTheme {
  static const Color primary = Color(0xFF243B6B);
  static const Color deepGreen = Color(0xFF162746);
  static const Color emerald = Color(0xFF2E9E9E);
  static const Color secondary = Color(0xFFC77955);
  static const Color ivory = Color(0xFFF8F6F1);
  static const Color night = Color(0xFF0E1726);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: brightness,
        ).copyWith(
          primary: dark ? const Color(0xFFB4C6F0) : primary,
          secondary: dark ? const Color(0xFF83D6D4) : emerald,
          tertiary: dark ? const Color(0xFFFFB693) : secondary,
          surface: dark ? night : ivory,
        );
    final base = ThemeData(useMaterial3: true, brightness: brightness);
    final appliedTypography = base.textTheme.apply(
      fontFamilyFallback: const <String>[
        'Noto Sans Arabic',
        'Noto Sans',
        'sans-serif',
      ],
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    final typography = appliedTypography.copyWith(
      displaySmall: appliedTypography.displaySmall?.copyWith(
        height: 1.35,
        letterSpacing: 0,
      ),
      bodySmall: appliedTypography.bodySmall?.copyWith(
        height: 1.5,
        letterSpacing: 0,
      ),
      labelMedium: appliedTypography.labelMedium?.copyWith(
        height: 1.35,
        letterSpacing: 0,
      ),
      labelSmall: appliedTypography.labelSmall?.copyWith(
        height: 1.35,
        letterSpacing: 0,
      ),
      headlineSmall: appliedTypography.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
      titleLarge: appliedTypography.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
      titleMedium: appliedTypography.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      bodyLarge: appliedTypography.bodyLarge?.copyWith(height: 1.55),
      bodyMedium: appliedTypography.bodyMedium?.copyWith(height: 1.5),
      labelLarge: appliedTypography.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
    final medium = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(TarteelTokens.radiusMd),
    );
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(TarteelTokens.radiusMd),
      borderSide: BorderSide(color: scheme.outlineVariant),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: typography,
      scaffoldBackgroundColor: dark ? night : ivory,
      canvasColor: dark ? night : ivory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: TarteelPageTransitionsBuilder(),
          TargetPlatform.iOS: TarteelPageTransitionsBuilder(),
          TargetPlatform.linux: TarteelPageTransitionsBuilder(),
          TargetPlatform.macOS: TarteelPageTransitionsBuilder(),
          TargetPlatform.windows: TarteelPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: dark ? night : ivory,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: typography.titleLarge?.copyWith(
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: TarteelTokens.spaceXs),
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shadowColor: deepGreen.withValues(alpha: dark ? 0.18 : 0.10),
        shape: medium.copyWith(
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: TarteelTokens.spaceMd,
          vertical: 14,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: medium,
          textStyle: typography.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          side: BorderSide(color: scheme.outlineVariant),
          shape: medium,
          textStyle: typography.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TarteelTokens.radiusSm),
          ),
          textStyle: typography.labelLarge,
        ),
      ),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll<Size>(Size.square(48)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: scheme.surfaceContainer,
        selectedColor: scheme.secondaryContainer,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TarteelTokens.radiusSm),
        ),
        labelStyle: typography.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.secondaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TarteelTokens.radiusMd),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return typography.labelSmall?.copyWith(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
            size: selected ? 25 : 23,
          );
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 2,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: typography.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
        shape: medium,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: TarteelTokens.spaceMd,
          vertical: 4,
        ),
        shape: medium,
        iconColor: scheme.primary,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(TarteelTokens.radiusLg),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHigh,
      ),
    );
  }
}

class TarteelPageTransitionsBuilder extends PageTransitionsBuilder {
  const TarteelPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final curved = CurvedAnimation(
      parent: animation,
      curve: const Interval(0, 0.72, curve: Curves.easeOutCubic),
      reverseCurve: const Interval(0.28, 1, curve: Curves.easeInCubic),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.025),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
