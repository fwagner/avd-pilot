import 'dart:io';

import 'package:emulator_device_manager/services/shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_avd_filesystem.dart';
import 'fakes/fake_emulator_service.dart';
import 'fakes/fake_shell_service.dart';
import 'fakes/test_app.dart';

void main() {
  testWidgets('overview config save writes config.ini', (tester) async {
    final FakeAvdFileSystem fakeFs = await FakeAvdFileSystem.create();
    addTearDown(fakeFs.dispose);
    await fakeFs.addAvd(
      name: 'Pixel_8_API_35',
      deviceName: 'Pixel 8',
      extraConfig: <String, String>{'hw.ramSize': '2048'},
    );

    final FakeShellService shell = FakeShellService(
      handler: (String executable, List<String> args) {
        final String command = <String>[executable, ...args].join(' ');
        if (command == '/fake/sdk/platform-tools/adb devices') {
          return const ToolResult(
            stdout: 'List of devices attached\n',
            stderr: '',
            exitCode: 0,
          );
        }
        return const ToolResult(stdout: '', stderr: '', exitCode: 0);
      },
    );
    final FakeEmulatorService emulator = FakeEmulatorService(shell);

    await pumpTestApp(
      tester,
      shellService: shell,
      emulatorService: emulator,
      sdkPaths: kFakeSdkPaths,
      avdRootOverride: fakeFs.avdRootPath,
    );

    await tester.tap(find.text('Pixel_8_API_35'));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(find.widgetWithText(TextField, 'RAM (MB)'), '4096');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump(const Duration(milliseconds: 200));

    final String config = await File(
      fakeFs.configPathFor('Pixel_8_API_35'),
    ).readAsString();
    expect(config, contains('hw.ramSize=4096'));
  });
}
