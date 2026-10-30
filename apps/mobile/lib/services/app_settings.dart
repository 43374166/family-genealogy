import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  static const _textScaleKey = 'app_text_scale';
  double textScale = 1.0;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getDouble(_textScaleKey);
      if (value != null && value >= 0.85 && value <= 1.35) {
        textScale = value;
        notifyListeners();
      }
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
