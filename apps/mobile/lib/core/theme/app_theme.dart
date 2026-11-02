import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static const String serifFamily = 'NotoSerifSC';

  /// Invert + hue-rotate(180°) keeps the light palette's accents while
  /// flipping paper and ink. The same filter is re-applied inside
  /// `PreserveColors` to keep photos, QR codes and the crop editor natural.
  static const List<double> darkModeMatrix = [
    0.574,
    -1.430,
    -0.144,
    0,
    255,
    -0.426,
    -0.430,
    -0.144,
    0,
    255,
    -0.426,
    -1.430,
    0.856,
    0,
    255,
    0,
    0,
    0,
    1,
    0,
  ];

  static const ColorFilter darkModeFilter = ColorFilter.matrix(darkModeMatrix);

  static ThemeData get light => _light(lightStatusBarIcons: false);

  /// A light ThemeData whose status/navigation bars are ready for the filtered
  /// dark surface. Widget colours stay light because the global filter
  /// transforms them at paint time.
  static ThemeData get lightForDarkMode => _light(lightStatusBarIcons: true);

  static ThemeData _light({required bool lightStatusBarIcons}) {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.jade,
      onSecondary: Colors.white,
      error: AppColors.cinnabar,
      onError: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      fontFamilyFallback: const [
        'Noto Sans SC',
        'PingFang SC',
        'Microsoft YaHei',
      ],
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.ink, size: 22),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: lightStatusBarIcons
              ? Brightness.light
              : Brightness.dark,
          statusBarBrightness: lightStatusBarIcons
              ? Brightness.dark
              : Brightness.light,
          systemNavigationBarColor: lightStatusBarIcons
              ? const Color(0xFF111716)
              : Colors.white,
          systemNavigationBarIconBrightness: lightStatusBarIcons
              ? Brightness.light
              : Brightness.dark,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF7F9FA),
        hintStyle: const TextStyle(color: AppColors.inkMuted, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        prefixIconColor: AppColors.inkMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13.5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      dialogTheme: DialogThemeData(
        barrierColor: lightStatusBarIcons ? Colors.white70 : null,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
        modalBarrierColor: lightStatusBarIcons ? Colors.white70 : null,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static TextStyle serif({
    double fontSize = 20,
    FontWeight fontWeight = FontWeight.w600,
    Color color = AppColors.ink,
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: serifFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static const TextStyle eyebrow = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
    color: AppColors.inkMuted,
  );
}
