import 'package:flutter/material.dart';

class TarteelTheme {
  static const Color primary = Color(0xFF0F5C4D);
  static const Color secondary = Color(0xFFD6B25E);

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: primary, brightness: Brightness.light, secondary: secondary),
        scaffoldBackgroundColor: const Color(0xFFF6F7F5),
        cardTheme: const CardThemeData(margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: primary, brightness: Brightness.dark, secondary: secondary),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      );
}
