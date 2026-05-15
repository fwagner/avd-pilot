import 'dart:async';

import 'package:emulator_device_manager/services/shell.dart';

typedef FakeToolHandler =
    FutureOr<ToolResult> Function(String executable, List<String> args);

class ToolInvocation {
  const ToolInvocation({required this.executable, required this.args});

  final String executable;
  final List<String> args;

  String get command => <String>[executable, ...args].join(' ');
}

class FakeShellService extends ShellService {
  FakeShellService({required FakeToolHandler handler}) : _handler = handler;

  final FakeToolHandler _handler;
  final List<ToolInvocation> calls = <ToolInvocation>[];

  @override
  Future<ToolResult> runTool(
    String executable,
    List<String> args, {
    String? stdinData,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    calls.add(
      ToolInvocation(executable: executable, args: List<String>.from(args)),
    );
    return await _handler(executable, args);
  }
}
