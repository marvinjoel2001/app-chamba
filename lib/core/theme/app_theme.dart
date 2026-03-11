import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  const AppTheme._();

  static const Color colorPrimary = Color(0xFF6B21A8);
  static const Color colorPrimaryLight = Color(0xFF7C3AED);
  static const Color colorPrimaryDark = Color(0xFF5B1C97);
  static const Color colorPrimarySoft = Color(0xFFEDE9FE);
  static const Color colorPrimaryGlow = Color(0x266B21A8);

  static const Color colorHighlight = Color(0xFFEAB308);
  static const Color colorHighlightSoft = Color(0xFFFEF9C3);

  static const Color colorBackground = Color(0xFFF3F0FF);
  static const Color colorBackgroundAccent = Color(0xFFEDE9FE);
  static const Color colorBackgroundAlt = Color(0xFFFAF8FF);

  static const Color colorGlass = Color(0x8CFFFFFF);
  static const Color colorGlassHigh = Color(0xB3FFFFFF);
  static const Color colorGlassBorder = Color(0xBFFFFFFF);

  static const Color colorMuted = Color(0xFF6B7280);
  static const Color colorText = Color(0xFF1E1030);
  static const Color colorTextOnPurple = Colors.white;
  static const Color colorSurfaceSoft = Color(0xFFFAF8FF);

  static const Color colorSuccess = Color(0xFF10B981);
  static const Color colorError = Color(0xFFEF4444);

  static const List<BoxShadow> shadowSm = [
    BoxShadow(color: Color(0x146B21A8), blurRadius: 8, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> shadowMd = [
    BoxShadow(color: Color(0x1F6B21A8), blurRadius: 24, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> shadowLg = [
    BoxShadow(color: Color(0x296B21A8), blurRadius: 40, offset: Offset(0, 8)),
  ];

  static const List<BoxShadow> shadowYellow = [
    BoxShadow(color: Color(0x59EAB308), blurRadius: 20, offset: Offset(0, 4)),
  ];

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);

    final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme)
        .copyWith(
          displayLarge: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: colorText,
          ),
          headlineLarge: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: colorText,
          ),
          headlineMedium: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: colorText,
          ),
          headlineSmall: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: colorText,
          ),
          bodyLarge: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            height: 1.5,
            color: colorMuted,
          ),
          bodyMedium: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: colorText,
          ),
          bodySmall: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
            color: colorMuted,
          ),
        )
        .apply(bodyColor: colorText, displayColor: colorText);

    return base.copyWith(
      scaffoldBackgroundColor: colorBackground,
      colorScheme: const ColorScheme.light(
        primary: colorPrimary,
        secondary: colorHighlight,
        surface: colorBackgroundAlt,
        onPrimary: colorTextOnPurple,
        onSurface: colorText,
        error: colorError,
      ),
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colorText,
        centerTitle: true,
        elevation: 0,
      ),
      dividerColor: colorPrimaryGlow,
      splashColor: colorPrimaryGlow,
      highlightColor: Colors.transparent,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0x99FFFFFF),
        hintStyle: const TextStyle(color: Color(0xFFA78BCA), fontSize: 15),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x266B21A8), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0x266B21A8), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: colorPrimaryLight, width: 1.5),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadeUpPageTransitionBuilder(),
          TargetPlatform.iOS: _FadeUpPageTransitionBuilder(),
          TargetPlatform.macOS: _FadeUpPageTransitionBuilder(),
        },
      ),
    );
  }
}

class _FadeUpPageTransitionBuilder extends PageTransitionsBuilder {
  const _FadeUpPageTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
