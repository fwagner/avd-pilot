import 'package:emulator_device_manager/services/sdkmanager_service.dart';
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
    final match = responses[key];
    if (match == null) {
      throw ToolFailed(
        command: key,
        exitCode: 1,
        stdout: '',
        stderr: 'missing fixture',
      );
    }
    return match;
  }
}

void main() {
  test('parse system images', () async {
    final shell = _FakeShell(<String, ToolResult>{
      'sdk --list_installed': const ToolResult(
        stdout: 'system-images;android-35;google_apis;arm64-v8a | 1\n',
        stderr: '',
        exitCode: 0,
      ),
      'sdk --list': const ToolResult(
        stdout: '''
system-images;android-35;google_apis;arm64-v8a | 1
system-images;android-34;default;x86_64 | 1
''',
        stderr: '',
        exitCode: 0,
      ),
    });
    final service = SdkManagerService(shell);
    final images = await service.listSystemImages('sdk');
    expect(images.length, 2);
    expect(images.first.apiLevel, 35);
    expect(images.first.installed, true);
  });

  test('parse pending license count', () async {
    final shell = _FakeShell(<String, ToolResult>{
      'sdk --licenses': const ToolResult(
        stdout: '2 of 7 SDK package licenses not accepted.',
        stderr: '',
        exitCode: 0,
      ),
    });
    final service = SdkManagerService(shell);
    final status = await service.checkLicenses('sdk');
    expect(status.pendingCount, 2);
  });

  test('parse packages with leading whitespace and metadata columns', () async {
    final shell = _FakeShell(<String, ToolResult>{
      'sdk --list_installed': const ToolResult(
        stdout: '''
Installed packages:
  Path                              | Version | Description
  -------                           | ------- | -------
  system-images;android-34;default;x86_64 | 10 | Android SDK System Image
''',
        stderr: '',
        exitCode: 0,
      ),
      'sdk --list': const ToolResult(
        stdout: '''
Available Packages:
  Path                                                  | Version | Description
  -------                                               | ------- | -------
  system-images;android-35;google_apis;arm64-v8a       | 12      | Android SDK System Image
  system-images;android-34;default;x86_64              | 10      | Android SDK System Image
''',
        stderr: '',
        exitCode: 0,
      ),
    });
    final service = SdkManagerService(shell);
    final images = await service.listSystemImages('sdk');
    expect(images.length, 2);
    expect(
      images.any(
        (i) =>
            i.packageId == 'system-images;android-34;default;x86_64' &&
            i.installed,
      ),
      true,
    );
  });
}
