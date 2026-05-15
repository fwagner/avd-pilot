import 'fakes/fake_avd_filesystem.dart';
import 'fakes/fake_emulator_service.dart';
import 'fakes/fake_shell_service.dart';
import 'fakes/test_app.dart';
import 'package:emulator_device_manager/services/shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boot renders AVD list and detail pane', (tester) async {
    final FakeAvdFileSystem fakeFs = await FakeAvdFileSystem.create();
    addTearDown(fakeFs.dispose);
    await fakeFs.addAvd(name: 'Pixel_8_API_35', deviceName: 'Pixel 8');
    await fakeFs.addAvd(name: 'Nexus_5X_API_34', deviceName: 'Nexus 5X');

    final FakeShellService shell = FakeShellService(
      handler: (String executable, List<String> args) {
        final String command = <String>[executable, ...args].join(' ');
        switch (command) {
          case '/fake/sdk/platform-tools/adb devices':
            return const ToolResult(
              stdout: 'List of devices attached\nemulator-5554\tdevice\n',
              stderr: '',
              exitCode: 0,
            );
          case '/fake/sdk/platform-tools/adb -s emulator-5554 shell getprop ro.kernel.qemu.avd_name':
            return const ToolResult(
              stdout: 'Pixel_8_API_35\n',
              stderr: '',
              exitCode: 0,
            );
          case '/fake/sdk/platform-tools/adb -s emulator-5554 shell getprop sys.boot_completed':
            return const ToolResult(stdout: '1\n', stderr: '', exitCode: 0);
          default:
            return const ToolResult(stdout: '', stderr: '', exitCode: 0);
        }
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
    expect(find.text('Nexus_5X_API_34'), findsOneWidget);

    await tester.tap(find.text('Pixel_8_API_35'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Running'), findsOneWidget);
  });
}
