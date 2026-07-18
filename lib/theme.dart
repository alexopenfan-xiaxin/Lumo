import 'package:flutter/material.dart';

abstract final class LumoColors {
  static const clay = Color(0xFFC47F5B);
  static const actionClay = Color(0xFFA45F41);
  static const apricot = Color(0xFFE7B998);
  static const eucalyptus = Color(0xFF6F8F86);
  static const fogBlue = Color(0xFF7893A5);
  static const gold = Color(0xFFD5A759);
  static const ink = Color(0xFF2B2622);
  static const muted = Color(0xFF756E68);
  static const canvas = Color(0xFFF8F5F0);
  static const paper = Color(0xFFFFFCF8);
  static const border = Color(0xFFE8E0D8);
  static const positive = Color(0xFF4F9177);
}

ThemeData buildLumoTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: LumoColors.clay,
    brightness: brightness,
  ).copyWith(
    primary: isDark ? const Color(0xFFE0A17D) : LumoColors.actionClay,
    secondary: isDark ? const Color(0xFF8DB0A6) : LumoColors.eucalyptus,
    tertiary: isDark ? const Color(0xFF9AB6C7) : LumoColors.fogBlue,
    surface: isDark ? const Color(0xFF211E1B) : LumoColors.paper,
    error: isDark ? const Color(0xFFE68A80) : const Color(0xFFBB6258),
  );
  final foreground = isDark ? const Color(0xFFF4ECE4) : LumoColors.ink;
  final muted = isDark ? const Color(0xFFBDB3AA) : LumoColors.muted;
  final border = isDark ? const Color(0xFF39332E) : LumoColors.border;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: isDark ? const Color(0xFF171513) : LumoColors.canvas,
    fontFamilyFallback: const ['Noto Sans CJK SC', 'sans-serif'],
    textTheme: ThemeData(brightness: brightness).textTheme.apply(
      bodyColor: foreground,
      displayColor: foreground,
    ).copyWith(
      displaySmall: TextStyle(
        fontFamily: 'LumoDisplay',
        fontSize: 32,
        height: 1.2,
        color: foreground,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'LumoDisplay',
        fontSize: 26,
        height: 1.25,
        color: foreground,
      ),
      titleLarge: TextStyle(
        fontFamily: 'LumoDisplay',
        fontSize: 22,
        height: 1.3,
        color: foreground,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: foreground,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.55, color: foreground),
      bodyMedium: TextStyle(fontSize: 14, height: 1.55, color: foreground),
      bodySmall: TextStyle(fontSize: 12, height: 1.45, color: muted),
      labelLarge: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: border),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: foreground,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(44, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    listTileTheme: const ListTileThemeData(
      minTileHeight: 56,
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF292521) : const Color(0xFFF3EFEA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
    dividerColor: border,
    dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      modalBackgroundColor: scheme.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: foreground,
      contentTextStyle: TextStyle(color: isDark ? LumoColors.ink : Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
