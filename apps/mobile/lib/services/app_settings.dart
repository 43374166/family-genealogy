import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  static const _textScaleKey = 'app_text_scale';
  static const _themeModeKey = 'app_theme_mode';

  double textScale = 1.0;
  ThemeMode themeMode = ThemeMode.system;

  bool get isDarkMode =>
      themeMode == ThemeMode.dark ||
      (themeMode == ThemeMode.system &&
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark);

  bool isDarkFor(BuildContext context) => switch (themeMode) {
    ThemeMode.dark => true,
    ThemeMode.light => false,
    ThemeMode.system =>
      MediaQuery.platformBrightnessOf(context) == Brightness.dark,
  };

  String get themeModeLabel => switch (themeMode) {
    ThemeMode.light => '亮色',
    ThemeMode.dark => '暗色',
    ThemeMode.system => '跟随系统',
  };

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var changed = false;
      final value = prefs.getDouble(_textScaleKey);
      if (value != null && value >= 0.85 && value <= 1.35) {
        textScale = value;
        changed = true;
      }
      final savedTheme = prefs.getString(_themeModeKey);
      themeMode = switch (savedTheme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      if (savedTheme != null) changed = true;
      if (changed) notifyListeners();
    } catch (_) {
      // Settings are a local preference; failure should never block startup.
    }
  }

  Future<void> setTextScale(double value) async {
    if ((textScale - value).abs() < 0.001) return;
    textScale = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_textScaleKey, value);
    } catch (_) {
      // Keep the in-memory choice even if persistence is unavailable.
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (themeMode == mode) return;
    themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, mode.name);
    } catch (_) {
      // Keep the in-memory choice even if persistence is unavailable.
    }
  }
}

class SettingsScope extends InheritedNotifier<AppSettings> {
  const SettingsScope({
    super.key,
    required AppSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static AppSettings of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'SettingsScope is missing above this context');
    return scope!.notifier!;
  }
}
