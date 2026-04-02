import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  const AppTheme._();

  static const Color colorPrimary = Color(0xFF8B5CF6);
  static const Color colorPrimaryLight = Color(0xFFA78BFA);
  static const Color colorPrimaryDark = Color(0xFF6D28D9);
  static const Color colorPrimarySoft = Color(0x33241B4B);
  static const Color colorPrimaryGlow = Color(0x408B5CF6);

  static const Color colorHighlight = Color(0xFFEAB308);
  static const Color colorHighlightSoft = Color(0x33EAB308);

  static const Color colorBackground = Color(0xFF07111F);
  static const Color colorBackgroundAccent = Color(0xFF0B172A);
  static const Color colorBackgroundAlt = Color(0xFF111C30);

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0, 0.2, 0.55, 0.86, 1],
    colors: [
      Color(0xFF050B16),
      Color(0xFF091223),
      Color(0xFF0E1A31),
      Color(0xFF11182A),
      Color(0xFF07111F),
    ],
  );

  static const Color colorGlass = Color.fromRGBO(255, 255, 255, 0.10);
  static const Color colorGlassHigh = Color.fromRGBO(255, 255, 255, 0.16);
  static const Color colorGlassBorder = Color.fromRGBO(255, 255, 255, 0.22);
  static const Color colorGlassDarkSoft = Color.fromRGBO(13, 23, 42, 0.72);
  static const Color colorGlassInputSoft = Color.fromRGBO(7, 17, 31, 0.82);
  static const Color colorGlassBorderSoft = Color.fromRGBO(255, 255, 255, 0.12);

  static const Color colorMuted = Color(0xFF9FB0C6);
  static const Color colorText = Color(0xFFF8FAFC);
  static const Color colorTextOnPurple = Colors.white;
  static const Color colorSurfaceSoft = Color(0xFF182235);

  static const Color colorSuccess = Color(0xFF22C55E);
  static const Color colorSuccessSoft = Color(0x3322C55E);
  static const Color colorError = Color(0xFFF97373);
  static const Color colorErrorSoft = Color(0x33F97373);
  static const Color colorWarningSoft = Color(0x33F59E0B);

  static const List<BoxShadow> shadowSm = [
    BoxShadow(color: Color(0x33040A14), blurRadius: 10, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> shadowMd = [
    BoxShadow(color: Color(0x4D020617), blurRadius: 28, offset: Offset(0, 10)),
  ];

  static const List<BoxShadow> shadowLg = [
    BoxShadow(color: Color(0x66020617), blurRadius: 42, offset: Offset(0, 16)),
  ];

  static const List<BoxShadow> shadowYellow = [
    BoxShadow(color: Color(0x40EAB308), blurRadius: 24, offset: Offset(0, 10)),
  ];

  static BoxDecoration glassContainerDecoration({
    double radius = 24,
    Color? backgroundColor,
  }) {
    return BoxDecoration(
      color: backgroundColor ?? colorGlassDarkSoft,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: colorGlassBorderSoft),
      boxShadow: shadowLg,
    );
  }

  static InputDecoration glassInputDecoration({
    required String labelText,
    required IconData icon,
  }) {
    const subtleDarkBorder = Color.fromRGBO(255, 255, 255, 0.12);
    const focusedDarkBorder = Color.fromRGBO(139, 92, 246, 0.85);

    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: colorMuted),
      floatingLabelStyle: const TextStyle(color: colorPrimaryLight),
      hintStyle: const TextStyle(color: colorMuted),
      prefixIcon: Icon(icon, color: colorMuted),
      filled: true,
      fillColor: colorGlassInputSoft,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: subtleDarkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: subtleDarkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: focusedDarkBorder, width: 1.4),
      ),
    );
  }

  static ThemeData light() {
    return dark();
  }

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);

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
      colorScheme: const ColorScheme.dark(
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
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorBackgroundAlt.withValues(alpha: 0.96),
        contentTextStyle: const TextStyle(color: colorText),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorText,
          side: const BorderSide(color: colorGlassBorderSoft, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colorPrimaryLight),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: colorPrimarySoft,
        selectedColor: colorPrimary,
        side: const BorderSide(color: colorGlassBorderSoft),
        labelStyle: const TextStyle(color: colorText),
        secondaryLabelStyle: const TextStyle(color: colorTextOnPurple),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorGlassInputSoft,
        hintStyle: const TextStyle(color: colorMuted, fontSize: 15),
        labelStyle: const TextStyle(color: colorMuted),
        floatingLabelStyle: const TextStyle(color: colorPrimaryLight),
        prefixIconColor: colorMuted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: colorGlassBorderSoft, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: colorGlassBorderSoft, width: 1.2),
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
