import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  static const background = Color(0xFF141615);
  static const surface = Color(0xFF1D201F);
  static const surfaceAlt = Color(0xFF2A2D2B);
  static const ink = Color(0xFFF2F0E9);
  static const primary = Color(0xFFE18B7E);
  static const accent = Color(0xFFE18B7E);
  static const record = Color(0xFFDB6D5E);
  static const textMuted = Color(0xFFA4AAA5);
  static const line = Color(0xFF353A36);
  static const pink = Color(0xFFCF9B9D);
  static const teal = Color(0xFFA3B8A0);
  static const orange = Color(0xFFD5AB7B);
  static const red = Color(0xFFE18B7E);
  static const amber = Color(0xFFC2B78F);
  static const cyan = Color(0xFFA0B6BC);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Manrope',
    colorScheme: const ColorScheme.dark(
      surface: AppColors.surface,
      primary: AppColors.primary,
      secondary: AppColors.teal,
      onPrimary: AppColors.background,
      onSecondary: AppColors.background,
      onSurface: AppColors.ink,
      error: AppColors.red,
      outline: AppColors.line,
    ),
  );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 24,
      toolbarHeight: 76,
      titleTextStyle: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
        letterSpacing: -0.5,
      ),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: AppColors.line, width: 0.7),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.textMuted,
      textColor: AppColors.ink,
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      titleTextStyle: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      subtitleTextStyle: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 12,
        height: 1.6,
        color: AppColors.textMuted,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 56),
        backgroundColor: AppColors.record,
        foregroundColor: AppColors.background,
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.teal
            : AppColors.surfaceAlt,
      ),
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.background
            : AppColors.textMuted,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    sliderTheme: const SliderThemeData(
      trackHeight: 3,
      activeTrackColor: AppColors.primary,
      inactiveTrackColor: AppColors.line,
      thumbColor: AppColors.primary,
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      selectedIconTheme: IconThemeData(color: AppColors.ink, size: 22),
      unselectedIconTheme: IconThemeData(color: AppColors.textMuted, size: 22),
      selectedLabelTextStyle: TextStyle(
        fontFamily: 'Manrope',
        color: AppColors.ink,
        fontSize: 11,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontFamily: 'Manrope',
        color: AppColors.textMuted,
        fontSize: 11,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.surfaceAlt,
      height: 76,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          size: 22,
          color: s.contains(WidgetState.selected)
              ? AppColors.ink
              : AppColors.textMuted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: 'Manrope',
          fontSize: 11,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: s.contains(WidgetState.selected)
              ? AppColors.ink
              : AppColors.textMuted,
        ),
      ),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    iconTheme: const IconThemeData(color: AppColors.textMuted),
    dividerTheme: const DividerThemeData(
      color: AppColors.line,
      thickness: 0.7,
      space: 1,
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: TextStyle(
        fontFamily: 'Manrope',
        color: AppColors.background,
      ),
    ),
  );
}
