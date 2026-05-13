import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:emulator_device_manager/services/process_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeProcess implements Process {
  _FakeProcess({
    required String stdoutData,
    required String stderrData,
    required int exitCode,
  }) : _stdout = Stream<List<int>>.value(utf8.encode(stdoutData)),
       _stderr = Stream<List<int>>.value(utf8.encode(stderrData)),
       _exitCode = Future<int>.value(exitCode);

  final Stream<List<int>> _stdout;
  final Stream<List<int>> _stderr;
  final Future<int> _exitCode;
  final IOSink _stdin = IOSink(StreamController<List<int>>().sink);

  @override
  Future<int> get exitCode => _exitCode;

  @override
  int get pid => 42;

  @override
  IOSink get stdin => _stdin;

  @override
  Stream<List<int>> get stderr => _stderr;

  @override
  Stream<List<int>> get stdout => _stdout;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => true;
}

void main() {
  test('Parses ps output correctly', () async {
    final ProcessResolver resolver = ProcessResolver(
      adbPath: '/tmp/adb',
      serial: 'emulator-5554',
      runProcess:
          (
            String executable,
            List<String> arguments, {
            ProcessStartMode mode = ProcessStartMode.normal,
          }) async {
            return _FakeProcess(
              stdoutData: 'PID NAME\n123 system_server\n456 com.example.app\n',
              stderrData: '',
              exitCode: 0,
            );
          },
    );

    await resolver.refresh();

    expect(resolver.resolve(123), 'system_server');
    expect(resolver.resolve(456), 'com.example.app');
  });

  test('Handles malformed output', () async {
    final ProcessResolver resolver = ProcessResolver(
      adbPath: '/tmp/adb',
      serial: 'emulator-5554',
      runProcess:
          (
            String executable,
            List<String> arguments, {
            ProcessStartMode mode = ProcessStartMode.normal,
          }) async {
            return _FakeProcess(
              stdoutData:
                  'PID NAME\ninvalid line\nx42 not-a-pid\n789 good.process\n999\n',
              stderrData: '',
              exitCode: 0,
            );
          },
    );

    await resolver.refresh();

    expect(resolver.resolve(789), 'good.process');
    expect(resolver.resolve(999), isNull);
  });

  test('Returns null for unknown PIDs', () async {
    final ProcessResolver resolver = ProcessResolver(
      adbPath: '/tmp/adb',
      serial: 'emulator-5554',
      runProcess:
          (
            String executable,
            List<String> arguments, {
            ProcessStartMode mode = ProcessStartMode.normal,
          }) async {
            return _FakeProcess(
              stdoutData: 'PID NAME\n123 one.process\n',
              stderrData: '',
              exitCode: 0,
            );
          },
    );

    await resolver.refresh();

    expect(resolver.resolve(9876), isNull);
  });
}
