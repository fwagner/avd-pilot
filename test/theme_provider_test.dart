import 'package:emulator_device_manager/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('theme preference service defaults to system', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final ThemePreferenceService service = ThemePreferenceService();

    final ThemeMode mode = await service.loadThemeMode();

    expect(mode, ThemeMode.system);
  });

  test('theme preference service persists dark mode', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final ThemePreferenceService writer = ThemePreferenceService();
    await writer.saveThemeMode(ThemeMode.dark);

    final ThemePreferenceService reader = ThemePreferenceService();
    final ThemeMode mode = await reader.loadThemeMode();

    expect(mode, ThemeMode.dark);
  });
}
