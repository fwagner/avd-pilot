import 'package:emulator_device_manager/services/avd_service.dart';
import 'package:emulator_device_manager/services/shell.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeShell extends ShellService {
  _FakeShell(this.responses);
  final Map<String, ToolResult> responses;

  @override
  Future<ToolResult> runTool(
    String executable,
    List<String> args, {
    String? stdinData,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final key = '$executable ${args.join(' ')}';
    final ToolResult? res = responses[key];
    if (res == null) {
      throw ToolFailed(
        command: key,
        exitCode: 1,
        stdout: '',
        stderr: 'missing fixture',
      );
    }
    return res;
  }
}

void main() {
  test('parse multiline avdmanager device output', () async {
    final shell = _FakeShell(<String, ToolResult>{
      'avdmanager list device': const ToolResult(
        stdout: '''
Available devices definitions:
id: 0 or "pixel_8"
    Name: Pixel 8
    OEM : Google
---------
id: 1 or "pixel_8_pro"
    Name: Pixel 8 Pro
    OEM : Google
''',
        stderr: '',
        exitCode: 0,
      ),
    });
    final service = AvdService(shell);
    final devices = await service.listDeviceProfiles('avdmanager');
    expect(devices.length, 2);
    expect(devices.first.id, 'pixel_8');
    expect(devices.first.name, 'Pixel 8');
  });
}
