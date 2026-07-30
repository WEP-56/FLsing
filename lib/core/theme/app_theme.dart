import 'package:flutter/material.dart';

import 'flsing_theme.dart';

export 'flsing_theme.dart';

/// 深浅双主题，所有取色统一走 [FlsingColors] 令牌。
abstract final class AppTheme {
  static ThemeData get dark => _build(FlsingColors.dark, Brightness.dark);
  static ThemeData get light => _build(FlsingColors.light, Brightness.light);

  static ThemeData _build(FlsingColors c, Brightness brightness) {
    final scheme =
        ColorScheme.fromSeed(seedColor: c.accent, brightness: brightness)
            .copyWith(
              primary: c.text1,
              onPrimary: c.inverseFg,
              secondary: c.accent,
              surface: c.sheet,
              onSurface: c.text1,
              outline: c.border2,
              error: c.danger,
            );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.page,
      extensions: [c],
      fontFamilyFallback: const ['Noto Sans CJK SC', 'Microsoft YaHei'],
      splashFactory: InkSparkle.splashFactory,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(fontSize: 16),
        bodyMedium: TextStyle(fontSize: 14),
      ).apply(bodyColor: c.text1, displayColor: c.text1),
      iconTheme: IconThemeData(color: c.text1),
      dividerTheme: DividerThemeData(color: c.border1, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface1,
        hintStyle: TextStyle(color: c.text5),
        labelStyle: TextStyle(color: c.text3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border3),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.dialog,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(color: c.border2),
        ),
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: c.text1,
        ),
        contentTextStyle: TextStyle(fontSize: 14, height: 1.5, color: c.text2),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.menu,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.border2),
        ),
        textStyle: TextStyle(fontSize: 13.5, color: c.text1),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? c.inverseFg : c.text4,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? c.inverseBg : c.surface3,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : c.border2,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.dialog,
        contentTextStyle: TextStyle(color: c.text1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
