import 'package:emulator_device_manager/models/avd.dart';
import 'package:emulator_device_manager/models/avd_state.dart';
import 'package:emulator_device_manager/services/emulator_service.dart';
import 'package:emulator_device_manager/services/shell.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeShell extends ShellService {
  _FakeShell(this.map);
  final Map<String, ToolResult> map;

  @override
  Future<ToolResult> runTool(
    String executable,
    List<String> args, {
    String? stdinData,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final key = '$executable ${args.join(' ')}';
    final result = map[key];
    if (result == null) {
      throw ToolFailed(
        command: key,
        exitCode: 1,
        stdout: '',
        stderr: 'missing fixture',
      );
    }
    return result;
  }
}

void main() {
  test('maps serial to launched avd by reserved port', () async {
    final shell = _FakeShell(<String, ToolResult>{
      'adb devices': const ToolResult(
        stdout: 'List of devices attached\nemulator-5556\tdevice\n',
        stderr: '',
        exitCode: 0,
      ),
      'adb -s emulator-5556 shell getprop sys.boot_completed': const ToolResult(
        stdout: '1\n',
        stderr: '',
        exitCode: 0,
      ),
    });
    final service = EmulatorService(shell);
    service.seedLaunchPortForTesting('PIXEL_9_PRO_FOLD_API_36', 5556);
    final input = <Avd>[
      const Avd(
        name: 'PIXEL_9_PRO_FOLD_API_36',
        iniPath: '/tmp/PIXEL_9_PRO_FOLD_API_36.ini',
        avdPath: '/tmp/PIXEL_9_PRO_FOLD_API_36.avd',
        state: AvdState.stopped,
      ),
    ];
    final result = await service.deriveStates(adbPath: 'adb', avds: input);
    expect(result.single.name, 'PIXEL_9_PRO_FOLD_API_36');
    expect(result.single.state, AvdState.running);
  });

  test('derive state running from adb + boot completed', () async {
    final shell = _FakeShell(<String, ToolResult>{
      'adb devices': const ToolResult(
        stdout: 'List of devices attached\nemulator-5554\tdevice\n',
        stderr: '',
        exitCode: 0,
      ),
      'adb -s emulator-5554 shell getprop ro.kernel.qemu.avd_name':
          const ToolResult(stdout: 'Pixel_API_35\n', stderr: '', exitCode: 0),
      'adb -s emulator-5554 shell getprop sys.boot_completed': const ToolResult(
        stdout: '1\n',
        stderr: '',
        exitCode: 0,
      ),
    });
    final service = EmulatorService(shell);
    final input = <Avd>[
      const Avd(
        name: 'Pixel_API_35',
        iniPath: '/tmp/Pixel_API_35.ini',
        avdPath: '/tmp/Pixel_API_35.avd',
        state: AvdState.stopped,
      ),
    ];
    final result = await service.deriveStates(adbPath: 'adb', avds: input);
    expect(result.first.state, AvdState.running);
    expect(result.first.serial, 'emulator-5554');
  });

  test('unknown emulator row is surfaced', () async {
    final shell = _FakeShell(<String, ToolResult>{
      'adb devices': const ToolResult(
        stdout: 'List of devices attached\nemulator-5560\tdevice\n',
        stderr: '',
        exitCode: 0,
      ),
      'adb -s emulator-5560 shell getprop ro.kernel.qemu.avd_name':
          const ToolResult(stdout: '\n', stderr: '', exitCode: 0),
      'adb -s emulator-5560 emu avd name': const ToolResult(
        stdout: '\n',
        stderr: '',
        exitCode: 0,
      ),
      'adb -s emulator-5560 shell getprop sys.boot_completed': const ToolResult(
        stdout: '1\n',
        stderr: '',
        exitCode: 0,
      ),
    });
    final service = EmulatorService(shell);
    final result = await service.deriveStates(
      adbPath: 'adb',
      avds: const <Avd>[],
    );
    expect(result.single.name, contains('Unknown emulator'));
  });

  test(
    'boot_completed lookup failure keeps emulator in booting state',
    () async {
      final shell = _FakeShell(<String, ToolResult>{
        'adb devices': const ToolResult(
          stdout: 'List of devices attached\nemulator-5554\tdevice\n',
          stderr: '',
          exitCode: 0,
        ),
        'adb -s emulator-5554 shell getprop ro.kernel.qemu.avd_name':
            const ToolResult(
              stdout: 'Pixel_8_API_35\n',
              stderr: '',
              exitCode: 0,
            ),
        // intentionally missing sys.boot_completed fixture -> throws ToolFailed
      });
      final service = EmulatorService(shell);
      final input = <Avd>[
        const Avd(
          name: 'Pixel_8_API_35',
          iniPath: '/tmp/Pixel_8_API_35.ini',
          avdPath: '/tmp/Pixel_8_API_35.avd',
          state: AvdState.stopped,
        ),
      ];
      final result = await service.deriveStates(adbPath: 'adb', avds: input);
      expect(result.single.state, AvdState.booting);
    },
  );

  test('legacy emu output with OK header maps to known avd', () async {
    final shell = _FakeShell(<String, ToolResult>{
      'adb devices': const ToolResult(
        stdout: 'List of devices attached\nemulator-5554\tdevice\n',
        stderr: '',
        exitCode: 0,
      ),
      'adb -s emulator-5554 shell getprop ro.kernel.qemu.avd_name':
          const ToolResult(stdout: '\n', stderr: '', exitCode: 0),
      'adb -s emulator-5554 emu avd name': const ToolResult(
        stdout: 'OK\nPixel_8_API_35\n',
        stderr: '',
        exitCode: 0,
      ),
      'adb -s emulator-5554 shell getprop sys.boot_completed': const ToolResult(
        stdout: '1\n',
        stderr: '',
        exitCode: 0,
      ),
    });
    final service = EmulatorService(shell);
    final input = <Avd>[
      const Avd(
        name: 'Pixel_8_API_35',
        iniPath: '/tmp/Pixel_8_API_35.ini',
        avdPath: '/tmp/Pixel_8_API_35.avd',
        state: AvdState.stopped,
      ),
    ];
    final result = await service.deriveStates(adbPath: 'adb', avds: input);
    expect(result.length, 1);
    expect(result.single.name, 'Pixel_8_API_35');
    expect(result.single.state, AvdState.running);
  });

  test('case-insensitive name mapping avoids duplicate rows', () async {
    final shell = _FakeShell(<String, ToolResult>{
      'adb devices': const ToolResult(
        stdout: 'List of devices attached\nemulator-5554\tdevice\n',
        stderr: '',
        exitCode: 0,
      ),
      'adb -s emulator-5554 shell getprop ro.kernel.qemu.avd_name':
          const ToolResult(stdout: 'pixel_8_api_35\n', stderr: '', exitCode: 0),
      'adb -s emulator-5554 shell getprop sys.boot_completed': const ToolResult(
        stdout: '1\n',
        stderr: '',
        exitCode: 0,
      ),
    });
    final service = EmulatorService(shell);
    final input = <Avd>[
      const Avd(
        name: 'Pixel_8_API_35',
        iniPath: '/tmp/Pixel_8_API_35.ini',
        avdPath: '/tmp/Pixel_8_API_35.avd',
        state: AvdState.stopped,
      ),
    ];
    final result = await service.deriveStates(adbPath: 'adb', avds: input);
    expect(result.length, 1);
    expect(result.single.name, 'Pixel_8_API_35');
    expect(result.single.state, AvdState.running);
  });

  test(
    'falls back to ro.boot.qemu.avd_name when kernel prop is empty',
    () async {
      final shell = _FakeShell(<String, ToolResult>{
        'adb devices': const ToolResult(
          stdout: 'List of devices attached\nemulator-5554\tdevice\n',
          stderr: '',
          exitCode: 0,
        ),
        'adb -s emulator-5554 shell getprop ro.kernel.qemu.avd_name':
            const ToolResult(stdout: '\n', stderr: '', exitCode: 0),
        'adb -s emulator-5554 shell getprop ro.boot.qemu.avd_name':
            const ToolResult(
              stdout: 'PIXEL_9_PRO_FOLD_API_36\n',
              stderr: '',
              exitCode: 0,
            ),
        'adb -s emulator-5554 shell getprop sys.boot_completed':
            const ToolResult(stdout: '1\n', stderr: '', exitCode: 0),
      });
      final service = EmulatorService(shell);
      final input = <Avd>[
        const Avd(
          name: 'PIXEL_9_PRO_FOLD_API_36',
          iniPath: '/tmp/PIXEL_9_PRO_FOLD_API_36.ini',
          avdPath: '/tmp/PIXEL_9_PRO_FOLD_API_36.avd',
          state: AvdState.stopped,
        ),
      ];
      final result = await service.deriveStates(adbPath: 'adb', avds: input);
      expect(result.length, 1);
      expect(result.single.name, 'PIXEL_9_PRO_FOLD_API_36');
      expect(result.single.state, AvdState.running);
    },
  );
}
