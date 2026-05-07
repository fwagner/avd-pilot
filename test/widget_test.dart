import 'package:emulator_device_manager/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('home page smoke test renders in light mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: EmulatorDeviceManagerApp(themeMode: ThemeMode.light),
      ),
    );
    await tester.pump();
    expect(find.textContaining('AVD Pilot'), findsWidgets);
  });

  testWidgets('home page smoke test renders in dark mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: EmulatorDeviceManagerApp(themeMode: ThemeMode.dark),
      ),
    );
    await tester.pump();
    expect(find.textContaining('AVD Pilot'), findsWidgets);
  });
}
