import 'dart:async';
import 'dart:convert';
import 'dart:io';

class ToolNotFound implements Exception {
  ToolNotFound(this.executable);
  final String executable;
  @override
  String toString() => 'Tool not found: $executable';
}

class ToolTimeout implements Exception {
  ToolTimeout(this.command);
  final String command;
  @override
  String toString() => 'Tool timed out: $command';
}

class ToolFailed implements Exception {
  ToolFailed({
    required this.command,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });
  final String command;
  final int exitCode;
  final String stdout;
  final String stderr;
  @override
  String toString() => 'Tool failed ($exitCode): $command';
}

class ToolResult {
  const ToolResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });
  final String stdout;
  final String stderr;
  final int exitCode;
}

class ToolLogEntry {
  const ToolLogEntry({
    required this.command,
    required this.exitCode,
    required this.duration,
    required this.at,
  });
  final String command;
  final int exitCode;
  final Duration duration;
  final DateTime at;
}

class ShellService {
  final List<ToolLogEntry> _history = <ToolLogEntry>[];

  List<ToolLogEntry> get history => List.unmodifiable(_history);

  Future<ToolResult> runTool(
    String executable,
    List<String> args, {
    String? stdinData,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final Stopwatch sw = Stopwatch()..start();
    final String command = ([executable, ...args]).join(' ');
    Process process;
    try {
      process = await Process.start(executable, args);
    } on ProcessException {
      throw ToolNotFound(executable);
    }

    if (stdinData != null) {
      process.stdin.write(stdinData);
    }
    await process.stdin.close();

    final Future<String> outFuture = process.stdout
        .transform(utf8.decoder)
        .join();
    final Future<String> errFuture = process.stderr
        .transform(utf8.decoder)
        .join();
    late final int code;
    try {
      code = await process.exitCode.timeout(timeout);
    } on TimeoutException {
      process.kill();
      throw ToolTimeout(command);
    }
    final String out = await outFuture;
    final String err = await errFuture;
    sw.stop();
    _history.insert(
      0,
      ToolLogEntry(
        command: command,
        exitCode: code,
        duration: sw.elapsed,
        at: DateTime.now(),
      ),
    );
    if (_history.length > 200) {
      _history.removeRange(200, _history.length);
    }
    if (code != 0) {
      throw ToolFailed(
        command: command,
        exitCode: code,
        stdout: out,
        stderr: err,
      );
    }
    return ToolResult(stdout: out, stderr: err, exitCode: code);
  }
}
