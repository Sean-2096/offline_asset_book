import 'package:flutter/material.dart';

import '../database/database_helper.dart';

enum AppThemeMode {
  system('system', '跟随系统', Icons.brightness_auto_rounded),
  light('light', '浅色', Icons.light_mode_rounded),
  dark('dark', '深色', Icons.dark_mode_rounded);

  const AppThemeMode(this.storageValue, this.label, this.icon);

  final String storageValue;
  final String label;
  final IconData icon;

  ThemeMode get themeMode {
    return switch (this) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };
  }

  static AppThemeMode fromStorage(String? value) {
    return AppThemeMode.values.firstWhere(
      (mode) => mode.storageValue == value,
      orElse: () => AppThemeMode.system,
    );
  }
}

class ThemeProvider extends ChangeNotifier {
  static const _settingKey = 'theme_mode';

  final DatabaseHelper _db = DatabaseHelper.instance;
  AppThemeMode _mode = AppThemeMode.system;
  bool _loaded = false;

  AppThemeMode get mode => _mode;
  ThemeMode get themeMode => _mode.themeMode;
  bool get loaded => _loaded;

  Future<void> loadThemeMode() async {
    final value = await _db.getSetting(_settingKey);
    _mode = AppThemeMode.fromStorage(value);
    _loaded = true;
    notifyListeners();
  }

  Future<void> setMode(AppThemeMode mode) async {
    if (_mode == mode && _loaded) return;

    _mode = mode;
    _loaded = true;
    notifyListeners();
    await _db.setSetting(_settingKey, mode.storageValue);
  }
}
