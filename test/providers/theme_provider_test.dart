import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchar_messaging_app/providers/theme_provider.dart';

void main() {
  group('ThemeProvider', () {
    test('initial theme mode is system', () {
      final provider = ThemeProvider();
      expect(provider.themeMode, ThemeMode.system);
    });

    test('toggleTheme switches between light and dark', () {
      final provider = ThemeProvider();
      
      // Initial is system. Toggling from system usually defaults to one or the other depending on logic, 
      // but here the logic is: _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
      // Since initial is system (not light), it should switch to light?
      // Let's check the code:
      // _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
      // If system, it's not light, so it becomes light.
      
      provider.toggleTheme();
      expect(provider.themeMode, ThemeMode.light);

      provider.toggleTheme();
      expect(provider.themeMode, ThemeMode.dark);

      provider.toggleTheme();
      expect(provider.themeMode, ThemeMode.light);
    });

    test('setSystemTheme sets theme to system', () {
      final provider = ThemeProvider();
      provider.toggleTheme(); // Set to light
      expect(provider.themeMode, ThemeMode.light);

      provider.setSystemTheme();
      expect(provider.themeMode, ThemeMode.system);
    });
  });
}
