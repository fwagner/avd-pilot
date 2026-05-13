import 'dart:convert';
import 'dart:io';

import 'package:emulator_device_manager/services/shell.dart';

typedef RunProcess =
    Future<Process> Function(
      String executable,
      List<String> arguments, {
      ProcessStartMode mode,
    });

class ProcessResolver {
  ProcessResolver({
    required String adbPath,
    required String serial,
    RunProcess? runProcess,
  }) : _adbPath = adbPath,
       _serial = serial,
       _runProcess = runProcess ?? _defaultRunProcess;

  final String _adbPath;
  final String _serial;
  final RunProcess _runProcess;

  Map<int, String> _processMap = const <int, String>{};

  static Future<Process> _defaultRunProcess(
    String executable,
    List<String> arguments, {
    ProcessStartMode mode = ProcessStartMode.normal,
  }) {
    return Process.start(executable, arguments, mode: mode);
  }

  Map<int, String> get processMap => _processMap;

  Future<void> refresh() async {
    final Process process;
    try {
      process = await _runProcess(_adbPath, <String>[
        '-s',
        _serial,
        'shell',
        'ps',
        '-A',
        '-o',
        'PID,NAME',
      ]);
    } on ProcessException {
      throw ToolNotFound(_adbPath);
    }

    final Future<String> stdoutFuture = process.stdout
        .transform(utf8.decoder)
        .join();
    final Future<String> stderrFuture = process.stderr
        .transform(utf8.decoder)
        .join();

    final int exitCode = await process.exitCode;
    final String stdout = await stdoutFuture;
    final String stderr = await stderrFuture;

    if (exitCode != 0) {
      throw ToolFailed(
        command: '$_adbPath -s $_serial shell ps -A -o PID,NAME',
        exitCode: exitCode,
        stdout: stdout,
        stderr: stderr,
      );
    }

    _processMap = _parse(stdout);
  }

  String? resolve(int pid) => _processMap[pid];

  Map<int, String> _parse(String output) {
    final Map<int, String> parsed = <int, String>{};
    final List<String> lines = const LineSplitter().convert(output);
    for (final String line in lines) {
      final String trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.toUpperCase().startsWith('PID')) {
        continue;
      }
      final List<String> parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length < 2) {
        continue;
      }
      final int? pid = int.tryParse(parts.first);
      if (pid == null) {
        continue;
      }
      final String name = parts.skip(1).join(' ').trim();
      if (name.isEmpty) {
        continue;
      }
      parsed[pid] = name;
    }
    return Map<int, String>.unmodifiable(parsed);
  }
}
