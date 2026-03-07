import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  const AppTheme._();

  static const Color colorPrimary = Color(0xFF6B2BBE);
  static const Color colorPrimaryDark = Color(0xFF4F2191);
  static const Color colorBackground = Color(0xFFF6F7FC);
  static const Color colorBackgroundAccent = Color(0xFFEEF2FF);
  static const Color colorHighlight = Color(0xFFE8B50A);
  static const Color colorGlass = Color(0xE6FFFFFF);
  static const Color colorGlassBorder = Color(0x1A1A2A4A);
  static const Color colorMuted = Color(0xFF5D6784);
  static const Color colorText = Color(0xFF171C2D);
  static const Color colorSurfaceSoft = Color(0xFFF0F3FB);

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: colorBackground,
      colorScheme: const ColorScheme.light(
        primary: colorPrimary,
        secondary: colorHighlight,
        surface: Colors.white,
        onPrimary: Colors.white,
        onSurface: colorText,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
        bodyColor: colorText,
        displayColor: colorText,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colorText,
        centerTitle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorSurfaceSoft,
        hintStyle: const TextStyle(color: colorMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0x1F1A2A4A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0x1F1A2A4A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: colorPrimary),
        ),
      ),
    );
  }
}
