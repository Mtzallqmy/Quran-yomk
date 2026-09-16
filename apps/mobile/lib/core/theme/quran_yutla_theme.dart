import 'package:flutter/material.dart';

/// Central Design System tokens for Quran Yutla (قرآن يتلى)
class QuranYutlaTheme {
  // Brand Palette Tokens
  static const Color primary = Color(0xFF243B6B);       // Deep Indigo
  static const Color primaryDark = Color(0xFF162746);   // Dark Indigo
  static const Color teal = Color(0xFF2E9E9E);          // Acoustic Teal
  static const Color copper = Color(0xFFC77955);        // Warm Rihal Copper
  static const Color pearl = Color(0xFFF8F6F1);         // Pearl light canvas
  static const Color night = Color(0xFF0E1726);         // Night dark canvas
  static const Color lightSurface = Color(0xFFFFFFFF);  // Pure White Surface
  static const Color darkSurface = Color(0xFF172235);   // Dark Card Surface
  static const Color textPrimaryLight = Color(0xFF141C2B);
  static const Color textSecondaryLight = Color(0xFF5B677A);
  static const Color textPrimaryDark = Color(0xFFF4F6FB);
  static const Color textSecondaryDark = Color(0xFF9DAEC6);

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: pearl,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFD6E2FB),
        onPrimaryContainer: primaryDark,
        secondary: teal,
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFFB9EAEA),
        onSecondaryContainer: Color(0xFF0D3D3D),
        tertiary: copper,
        onTertiary: Colors.white,
        error: Color(0xFFBA1A1A),
        onError: Colors.white,
        surface: lightSurface,
        onSurface: textPrimaryLight,
        surfaceVariant: Color(0xFFE5E2DC),
        onSurfaceVariant: textSecondaryLight,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardTheme(
        color: lightSurface,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: night,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: teal,
        onPrimary: primaryDark,
        primaryContainer: primary,
        onPrimaryContainer: Colors.white,
        secondary: copper,
        onSecondary: Colors.white,
        tertiary: Color(0xFFE3A368),
        onTertiary: Colors.black,
        error: Color(0xFFFFB4AB),
        onError: Color(0xFF690005),
        surface: darkSurface,
        onSurface: textPrimaryDark,
        surfaceVariant: Color(0xFF1D2C42),
        onSurfaceVariant: textSecondaryDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardTheme(
        color: darkSurface,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
