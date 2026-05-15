import 'package:emulator_device_manager/app.dart';
import 'package:emulator_device_manager/providers/avd_providers.dart';
import 'package:emulator_device_manager/providers/sdk_providers.dart';
import 'package:emulator_device_manager/services/android_sdk.dart';
import 'package:emulator_device_manager/services/emulator_service.dart';
import 'package:emulator_device_manager/services/shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const AndroidSdkPaths kFakeSdkPaths = AndroidSdkPaths(
  root: '/fake/sdk',
  emulator: '/fake/sdk/emulator/emulator',
  adb: '/fake/sdk/platform-tools/adb',
  avdmanager: '/fake/sdk/cmdline-tools/latest/bin/avdmanager',
  sdkmanager: '/fake/sdk/cmdline-tools/latest/bin/sdkmanager',
);

Future<void> pumpTestApp(
  WidgetTester tester, {
  required ShellService shellService,
  required EmulatorService emulatorService,
  required AndroidSdkPaths? sdkPaths,
  String? avdRootOverride,
}) async {
  final List<Override> overrides = <Override>[
    shellServiceProvider.overrideWithValue(shellService),
    emulatorServiceProvider.overrideWithValue(emulatorService),
    sdkPathsProvider.overrideWith((ref) async => sdkPaths),
  ];
  if (avdRootOverride != null) {
    overrides.add(avdRootOverrideProvider.overrideWithValue(avdRootOverride));
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: const EmulatorDeviceManagerApp(themeMode: ThemeMode.light),
    ),
  );
  // Avoid pumpAndSettle here: AvdListNotifier uses periodic timers.
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}
