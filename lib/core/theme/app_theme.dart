import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  const AppTheme._();

  static const Color colorPrimary = Color(0xFF7A2BC4);
  static const Color colorPrimaryDark = Color(0xFF4C177C);
  static const Color colorBackground = Color(0xFF0C0716);
  static const Color colorBackgroundAccent = Color(0xFF1A0E2E);
  static const Color colorHighlight = Color(0xFFF3C617);
  static const Color colorGlass = Color(0x1AFFFFFF);
  static const Color colorGlassBorder = Color(0x22FFFFFF);
  static const Color colorMuted = Color(0xFF8D95AD);

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: colorBackground,
      colorScheme: const ColorScheme.dark(
        primary: colorPrimary,
        secondary: colorHighlight,
        surface: Color(0xFF1B1229),
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        hintStyle: const TextStyle(color: colorMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: colorPrimary),
        ),
      ),
    );
  }
}
