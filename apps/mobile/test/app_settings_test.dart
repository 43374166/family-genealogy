import 'package:family_tree/services/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('theme mode defaults to system and exposes Chinese labels', () async {
    final settings = AppSettings();
    addTearDown(settings.dispose);
    expect(settings.themeMode, ThemeMode.system);
    expect(settings.themeModeLabel, '跟随系统');

    await settings.setThemeMode(ThemeMode.dark);
    expect(settings.themeMode, ThemeMode.dark);
    expect(settings.themeModeLabel, '暗色');

    await settings.setThemeMode(ThemeMode.light);
    expect(settings.themeModeLabel, '亮色');
  });
}
