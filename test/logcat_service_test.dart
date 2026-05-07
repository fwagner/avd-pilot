import 'dart:io';

import 'package:emulator_device_manager/services/logcat_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts adb logcat with expected arguments and streams lines', () async {
    String? executable;
    List<String>? arguments;
    final LogcatService service = LogcatService(
      startProcess: (exe, args, {mode = ProcessStartMode.normal}) async {
        executable = exe;
        arguments = args;
        return Process.start('/bin/sh', <String>[
          '-c',
          'sleep 0.05; echo "line-1"; sleep 0.05; echo "line-2"',
        ]);
      },
    );

    await service.start(
      avdName: 'Pixel_API_35',
      adbPath: '/tmp/fake-adb',
      serial: 'emulator-5554',
    );
    final List<String> lines = await service
        .lines('Pixel_API_35')
        .where((line) => !line.startsWith('[adb]'))
        .take(2)
        .toList();

    expect(executable, '/tmp/fake-adb');
    expect(
      arguments,
      <String>[
        '-s',
        'emulator-5554',
        'logcat',
        '-v',
        'threadtime',
      ],
    );
    expect(lines, <String>['line-1', 'line-2']);
    await service.stop('Pixel_API_35');
  });

  test('stop tears down running session', () async {
    final LogcatService service = LogcatService(
      startProcess: (exe, args, {mode = ProcessStartMode.normal}) async {
        return Process.start('/bin/sh', <String>[
          '-c',
          'while true; do echo "tick"; sleep 1; done',
        ]);
      },
    );

    await service.start(
      avdName: 'Pixel_API_34',
      adbPath: '/tmp/fake-adb',
      serial: 'emulator-5556',
    );
    expect(service.isRunning('Pixel_API_34'), isTrue);

    await service.stop('Pixel_API_34');
    expect(service.isRunning('Pixel_API_34'), isFalse);
  });
}
