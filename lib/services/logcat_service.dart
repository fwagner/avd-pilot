import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:emulator_device_manager/services/shell.dart';

typedef StartProcess =
    Future<Process> Function(
      String executable,
      List<String> arguments, {
      ProcessStartMode mode,
    });

class LogcatService {
  LogcatService({StartProcess? startProcess})
    : _startProcess = startProcess ?? _defaultStartProcess;

  final StartProcess _startProcess;
  final Map<String, _LogcatSession> _sessions = <String, _LogcatSession>{};

  static Future<Process> _defaultStartProcess(
    String executable,
    List<String> arguments, {
    ProcessStartMode mode = ProcessStartMode.normal,
  }) {
    return Process.start(executable, arguments, mode: mode);
  }

  bool isRunning(String avdName) => _sessions.containsKey(avdName);

  Stream<String> lines(String avdName) {
    final _LogcatSession? session = _sessions[avdName];
    if (session == null) {
      return const Stream<String>.empty();
    }
    return session.controller.stream;
  }

  Future<void> start({
    required String avdName,
    required String adbPath,
    required String serial,
  }) async {
    if (_sessions.containsKey(avdName)) {
      return;
    }

    final StreamController<String> controller =
        StreamController<String>.broadcast();
    try {
      final Process process = await _startProcess(adbPath, <String>[
        '-s',
        serial,
        'logcat',
        '-v',
        'threadtime',
      ]);

      final StreamSubscription<String> stdoutSub = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(controller.add);
      final StreamSubscription<String> stderrSub = process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => controller.add('[adb] $line'));

      final Future<void> exitWatcher = process.exitCode.then((_) async {
        await stdoutSub.cancel();
        await stderrSub.cancel();
        if (!controller.isClosed) {
          await controller.close();
        }
        _sessions.remove(avdName);
      });

      _sessions[avdName] = _LogcatSession(
        process: process,
        controller: controller,
        stdoutSub: stdoutSub,
        stderrSub: stderrSub,
        exitWatcher: exitWatcher,
      );
    } on ProcessException {
      await controller.close();
      throw ToolNotFound(adbPath);
    } catch (_) {
      await controller.close();
      rethrow;
    }
  }

  Future<void> stop(String avdName) async {
    final _LogcatSession? session = _sessions.remove(avdName);
    if (session == null) {
      return;
    }

    session.process.kill();
    await session.stdoutSub.cancel();
    await session.stderrSub.cancel();
    if (!session.controller.isClosed) {
      await session.controller.close();
    }
    await session.exitWatcher;
  }

  Future<void> stopAll() async {
    final List<String> names = _sessions.keys.toList(growable: false);
    for (final String name in names) {
      await stop(name);
    }
  }
}

class _LogcatSession {
  _LogcatSession({
    required this.process,
    required this.controller,
    required this.stdoutSub,
    required this.stderrSub,
    required this.exitWatcher,
  });

  final Process process;
  final StreamController<String> controller;
  final StreamSubscription<String> stdoutSub;
  final StreamSubscription<String> stderrSub;
  final Future<void> exitWatcher;
}
