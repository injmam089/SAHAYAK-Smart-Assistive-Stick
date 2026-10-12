import 'package:flutter/material.dart';

/// Accessible High-Contrast Theme for SAHAYAK.
/// Prioritizes WCAG AAA contrast ratios, clear typography, and tactile affordances.
class AppTheme {
  AppTheme._();

  static ThemeData get highContrastTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFF00E5FF),
        onPrimary: Colors.black,
        secondary: Color(0xFFFFD600),
        onSecondary: Colors.black,
        error: Color(0xFFFF1744),
        onError: Colors.black,
        surface: Color(0xFF121212),
        onSurface: Colors.white,
      ),
      scaffoldBackgroundColor: Colors.black,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        bodyLarge: TextStyle(
          fontSize: 18,
          color: Colors.white,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 16,
          color: Color(0xFFE0E0E0),
        ),
      ),
    );
  }
}
