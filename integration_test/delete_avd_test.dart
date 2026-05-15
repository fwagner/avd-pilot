import 'package:emulator_device_manager/services/shell.dart';
import 'package:emulator_device_manager/ui/widgets/app_shortcuts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_avd_filesystem.dart';
import 'fakes/fake_emulator_service.dart';
import 'fakes/fake_shell_service.dart';
import 'fakes/test_app.dart';

void main() {
  testWidgets('delete AVD flow calls avdmanager and updates list', (
    tester,
  ) async {
    final FakeAvdFileSystem fakeFs = await FakeAvdFileSystem.create();
    addTearDown(fakeFs.dispose);
    await fakeFs.addAvd(name: 'Pixel_8_API_35', deviceName: 'Pixel 8');

    final FakeShellService shell = FakeShellService(
      handler: (String executable, List<String> args) async {
        final String command = <String>[executable, ...args].join(' ');
        if (command ==
            '/fake/sdk/cmdline-tools/latest/bin/avdmanager delete avd -n Pixel_8_API_35') {
          await fakeFs.removeAvd('Pixel_8_API_35');
        }
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

    expect(find.text('Pixel_8_API_35'), findsOneWidget);
    await tester.tap(find.text('Pixel_8_API_35'));
    await tester.pump(const Duration(milliseconds: 100));

    // ignore: use_build_context_synchronously
    final BuildContext context = tester.element(
      find.text('Pixel_8_API_35').first,
    );
    // ignore: use_build_context_synchronously
    DeleteRequestedNotification().dispatch(context);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      shell.calls
          .map((call) => call.command)
          .where((command) => command.contains('delete avd -n Pixel_8_API_35')),
      isNotEmpty,
    );
    expect(find.text('Pixel_8_API_35'), findsNothing);
  });
}
