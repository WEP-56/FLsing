import 'package:flutter/material.dart';

import '../data/services/app_settings.dart';

/// 主题模式状态，持久化到 [AppSettings]。
class ThemeProvider extends ChangeNotifier {
  ThemeProvider() {
    // 存储不可用（如非 Android 平台调试）时保持默认跟随系统。
    try {
      _mode = _fromStored(AppSettings().themeMode);
    } catch (_) {}
  }

  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  void setMode(ThemeMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    try {
      AppSettings().themeMode = switch (mode) {
        ThemeMode.light => ThemeModeOption.light,
        ThemeMode.dark => ThemeModeOption.dark,
        ThemeMode.system => ThemeModeOption.system,
      };
    } catch (_) {}
    notifyListeners();
  }

  static ThemeMode _fromStored(String value) => switch (value) {
    ThemeModeOption.light => ThemeMode.light,
    ThemeModeOption.dark => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}
