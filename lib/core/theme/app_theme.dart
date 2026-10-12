import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta y tema de Chamba (modo claro).
///
/// Los nombres de las constantes vienen de la versión oscura original y se
/// mantienen para no romper las pantallas: `colorGlass*` ahora son superficies
/// blancas, `colorText` es tinta oscura y `colorMuted` gris lavanda.
class AppTheme {
  const AppTheme._();

  // ── Marca ────────────────────────────────────────────────────────────────
  static const Color colorPrimary = Color(0xFF7C3AED);
  static const Color colorPrimaryLight = Color(0xFF8B5CF6);
  static const Color colorPrimaryDark = Color(0xFF6D28D9);
  static const Color colorPrimarySoft = Color(0x1A7C3AED);
  static const Color colorPrimaryGlow = Color(0x2E7C3AED);
  static const Color colorPrimaryTint = Color(0xFFF1EBFF);

  /// Amarillo de marca para rellenos (botón amarillo, badges, estrellas).
  static const Color colorHighlight = Color(0xFFF5B301);
  static const Color colorHighlightSoft = Color(0x29F5B301);

  /// Amarillo oscurecido para texto e íconos sobre fondo claro (contraste AA).
  static const Color colorHighlightInk = Color(0xFFB45309);

  // ── Fondos ───────────────────────────────────────────────────────────────
  static const Color colorBackground = Color(0xFFF7F6FC);
  static const Color colorBackgroundAccent = Color(0xFFF1EEFB);
  static const Color colorBackgroundAlt = Color(0xFFFFFFFF);

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0, 0.35, 0.7, 1],
    colors: [
      Color(0xFFFBFAFF),
      Color(0xFFF7F6FC),
      Color(0xFFF4F1FD),
      Color(0xFFF8F7FC),
    ],
  );

  // ── Superficies (antes "glass") ─────────────────────────────────────────
  static const Color colorGlass = Color(0xFFFFFFFF);
  static const Color colorGlassHigh = Color(0xFFFFFFFF);
  static const Color colorGlassBorder = Color(0xFFE9E5F3);
  static const Color colorGlassDarkSoft = Color(0xF7FFFFFF);
  static const Color colorGlassInputSoft = Color(0xFFF5F3FA);
  static const Color colorGlassBorderSoft = Color(0xFFE6E2F0);

  // ── Texto ────────────────────────────────────────────────────────────────
  static const Color colorMuted = Color(0xFF6B6584);
  static const Color colorText = Color(0xFF17132D);
  static const Color colorTextOnPurple = Colors.white;
  static const Color colorSurfaceSoft = Color(0xFFF2EFF8);

  // ── Estados ──────────────────────────────────────────────────────────────
  static const Color colorSuccess = Color(0xFF16A34A);
  static const Color colorSuccessSoft = Color(0x1F16A34A);
  static const Color colorError = Color(0xFFE5484D);
  static const Color colorErrorSoft = Color(0x1FE5484D);
  static const Color colorWarning = Color(0xFFD97706);
  static const Color colorWarningSoft = Color(0x1FD97706);
  static const Color colorInfo = Color(0xFF2563EB);

  // ── Sombras (suaves, tinte lavanda) ─────────────────────────────────────
  static const List<BoxShadow> shadowSm = [
    BoxShadow(color: Color(0x0F1E1B4B), blurRadius: 10, offset: Offset(0, 3)),
  ];

  static const List<BoxShadow> shadowMd = [
    BoxShadow(color: Color(0x141E1B4B), blurRadius: 22, offset: Offset(0, 8)),
  ];

  static const List<BoxShadow> shadowLg = [
    BoxShadow(color: Color(0x1C1E1B4B), blurRadius: 34, offset: Offset(0, 14)),
  ];

  static const List<BoxShadow> shadowYellow = [
    BoxShadow(color: Color(0x33F5B301), blurRadius: 20, offset: Offset(0, 8)),
  ];

  static const List<BoxShadow> shadowPrimary = [
    BoxShadow(color: Color(0x407C3AED), blurRadius: 18, offset: Offset(0, 8)),
  ];

  /// Barra de estado con íconos oscuros (fondo claro).
  static const SystemUiOverlayStyle systemOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: colorBackground,
    systemNavigationBarIconBrightness: Brightness.dark,
  );

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
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: colorMuted),
      floatingLabelStyle: const TextStyle(color: colorPrimary),
      hintStyle: const TextStyle(color: colorMuted),
      prefixIcon: Icon(icon, color: colorMuted),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: colorGlassInputSoft,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: colorGlassBorderSoft),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: colorGlassBorderSoft),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: colorPrimary, width: 1.5),
      ),
    );
  }

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

    final colorScheme = ColorScheme.fromSeed(
      seedColor: colorPrimary,
      brightness: Brightness.light,
    ).copyWith(
      primary: colorPrimary,
      onPrimary: colorTextOnPurple,
      primaryContainer: colorPrimaryTint,
      onPrimaryContainer: colorPrimaryDark,
      secondary: colorHighlight,
      onSecondary: colorText,
      surface: colorBackgroundAlt,
      onSurface: colorText,
      onSurfaceVariant: colorMuted,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFFBFAFE),
      surfaceContainer: colorBackground,
      surfaceContainerHigh: colorSurfaceSoft,
      surfaceContainerHighest: const Color(0xFFECE8F5),
      outline: const Color(0xFFD9D4E6),
      outlineVariant: colorGlassBorderSoft,
      error: colorError,
      onError: Colors.white,
      surfaceTint: Colors.transparent,
    );

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );

    return base.copyWith(
      brightness: Brightness.light,
      scaffoldBackgroundColor: colorBackground,
      colorScheme: colorScheme,
      textTheme: textTheme,
      primaryColor: colorPrimary,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: colorText,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: systemOverlay,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: colorText,
        ),
        iconTheme: const IconThemeData(color: colorText),
      ),
      iconTheme: const IconThemeData(color: colorText),
      dividerColor: colorGlassBorderSoft,
      dividerTheme: const DividerThemeData(
        color: colorGlassBorderSoft,
        thickness: 1,
        space: 1,
      ),
      splashColor: colorPrimary.withValues(alpha: 0.08),
      highlightColor: colorPrimary.withValues(alpha: 0.04),
      hoverColor: colorPrimary.withValues(alpha: 0.04),
      splashFactory: InkSparkle.splashFactory,
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: colorGlassBorder),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: colorMuted,
        textColor: colorText,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: colorText,
        ),
        contentTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          height: 1.5,
          color: colorMuted,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: Colors.white,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.plusJakartaSans(color: colorText, fontSize: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorText,
        contentTextStyle: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: const Color(0xFFC4B5FD),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: colorPrimary,
        linearTrackColor: colorPrimaryTint,
        circularTrackColor: Colors.transparent,
        refreshBackgroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorPrimary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE4E0EE),
          disabledForegroundColor: colorMuted,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: buttonShape,
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorPrimary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE4E0EE),
          disabledForegroundColor: colorMuted,
          minimumSize: const Size(0, 48),
          shape: buttonShape,
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorText,
          backgroundColor: Colors.white,
          overlayColor: colorPrimary,
          side: const BorderSide(color: colorGlassBorderSoft, width: 1.2),
          minimumSize: const Size(0, 48),
          shape: buttonShape,
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorPrimary,
          overlayColor: colorPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colorText,
          overlayColor: colorPrimary,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: colorPrimary,
        foregroundColor: Colors.white,
        elevation: 2,
        highlightElevation: 4,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : const Color(0xFF9C96B2),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorPrimary
              : const Color(0xFFE7E3F0),
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorPrimary
              : const Color(0xFFD9D4E6),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorPrimary
              : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: const BorderSide(color: Color(0xFFBDB6CF), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorPrimary
              : const Color(0xFFBDB6CF),
        ),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: colorPrimary,
        inactiveTrackColor: colorPrimaryTint,
        thumbColor: colorPrimary,
        overlayColor: colorPrimary.withValues(alpha: 0.12),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: colorPrimary,
        unselectedLabelColor: colorMuted,
        indicatorColor: colorPrimary,
        dividerColor: colorGlassBorderSoft,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: colorPrimaryTint,
        selectedColor: colorPrimary,
        side: const BorderSide(color: colorGlassBorderSoft),
        labelStyle: const TextStyle(color: colorText),
        secondaryLabelStyle: const TextStyle(color: colorTextOnPurple),
        checkmarkColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        iconColor: colorPrimary,
        collapsedIconColor: colorMuted,
        textColor: colorText,
        collapsedTextColor: colorText,
        shape: Border(),
        collapsedShape: Border(),
      ),
      badgeTheme: const BadgeThemeData(
        backgroundColor: colorError,
        textColor: Colors.white,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colorText,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: colorPrimary,
        headerForegroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: Colors.white,
        dialBackgroundColor: colorPrimaryTint,
        hourMinuteColor: colorPrimaryTint,
        hourMinuteTextColor: colorText,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colorPrimary,
        selectionColor: colorPrimary.withValues(alpha: 0.22),
        selectionHandleColor: colorPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorGlassInputSoft,
        hintStyle: const TextStyle(color: colorMuted, fontSize: 15),
        labelStyle: const TextStyle(color: colorMuted),
        floatingLabelStyle: const TextStyle(color: colorPrimary),
        prefixIconColor: colorMuted,
        suffixIconColor: colorMuted,
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
          borderSide: const BorderSide(color: colorPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: colorError, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: colorError, width: 1.5),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: colorPrimary,
        unselectedItemColor: colorMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
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
