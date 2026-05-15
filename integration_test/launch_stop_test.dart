import 'fakes/fake_avd_filesystem.dart';
import 'fakes/fake_emulator_service.dart';
import 'fakes/fake_shell_service.dart';
import 'fakes/test_app.dart';
import 'package:emulator_device_manager/models/avd.dart';
import 'package:emulator_device_manager/models/avd_state.dart';
import 'package:emulator_device_manager/services/shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('launch and stop lifecycle calls expected commands', (
    tester,
  ) async {
    final FakeAvdFileSystem fakeFs = await FakeAvdFileSystem.create();
    addTearDown(fakeFs.dispose);
    await fakeFs.addAvd(name: 'Pixel_8_API_35', deviceName: 'Pixel 8');

    bool launched = false;
    final FakeShellService shell = FakeShellService(
      handler: (String executable, List<String> args) {
        final String command = <String>[executable, ...args].join(' ');
        if (command == '/fake/sdk/platform-tools/adb devices') {
          final String stdout = launched
              ? 'List of devices attached\nemulator-5554\tdevice\n'
              : 'List of devices attached\n';
          return ToolResult(stdout: stdout, stderr: '', exitCode: 0);
        }
        if (command ==
            '/fake/sdk/platform-tools/adb -s emulator-5554 shell getprop ro.kernel.qemu.avd_name') {
          return const ToolResult(
            stdout: 'Pixel_8_API_35\n',
            stderr: '',
            exitCode: 0,
          );
        }
        if (command ==
            '/fake/sdk/platform-tools/adb -s emulator-5554 shell getprop sys.boot_completed') {
          return const ToolResult(stdout: '1\n', stderr: '', exitCode: 0);
        }
        if (command ==
            '/fake/sdk/platform-tools/adb -s emulator-5554 emu kill') {
          launched = false;
          return const ToolResult(stdout: '', stderr: '', exitCode: 0);
        }
        return const ToolResult(stdout: '', stderr: '', exitCode: 0);
      },
    );
    final FakeEmulatorService emulator = FakeEmulatorService(
      shell,
      onStart: (_, _) {
        launched = true;
      },
    );

    await pumpTestApp(
      tester,
      shellService: shell,
      emulatorService: emulator,
      sdkPaths: kFakeSdkPaths,
      avdRootOverride: fakeFs.avdRootPath,
    );

    await tester.tap(find.text('Pixel_8_API_35'));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.widgetWithText(FilledButton, 'Launch').first);
    await tester.pump(const Duration(milliseconds: 200));

    expect(emulator.startCalls, hasLength(1));
    expect(emulator.startCalls.first.executable, kFakeSdkPaths.emulator);
    expect(
      emulator.startCalls.first.args,
      containsAll(<String>['-avd', 'Pixel_8_API_35']),
    );

    expect(find.text('Stop'), findsWidgets);
    await emulator.stop(
      adbPath: kFakeSdkPaths.adb,
      avd: const Avd(
        name: 'Pixel_8_API_35',
        iniPath: '',
        avdPath: '',
        state: AvdState.running,
        serial: 'emulator-5554',
      ),
    );

    expect(
      shell.calls
          .map((call) => call.command)
          .where((command) => command.contains('emu kill')),
      isNotEmpty,
    );
  });
}
