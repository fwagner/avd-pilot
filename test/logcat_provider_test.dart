import 'dart:async';

import 'package:emulator_device_manager/models/avd.dart';
import 'package:emulator_device_manager/models/avd_state.dart';
import 'package:emulator_device_manager/providers/avd_providers.dart';
import 'package:emulator_device_manager/providers/logcat_provider.dart';
import 'package:emulator_device_manager/providers/sdk_providers.dart';
import 'package:emulator_device_manager/services/android_sdk.dart';
import 'package:emulator_device_manager/services/logcat_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLogcatService implements LogcatService {
  final Map<String, StreamController<String>> _controllers =
      <String, StreamController<String>>{};
  final Set<String> _running = <String>{};
  int startCalls = 0;

  @override
  bool isRunning(String avdName) => _running.contains(avdName);

  @override
  Stream<String> lines(String avdName) =>
      _controllers[avdName]?.stream ?? const Stream<String>.empty();

  @override
  Future<void> start({
    required String avdName,
    required String adbPath,
    required String serial,
  }) async {
    startCalls++;
    _running.add(avdName);
    _controllers.putIfAbsent(
      avdName,
      () => StreamController<String>.broadcast(),
    );
  }

  @override
  Future<void> stop(String avdName) async {
    _running.remove(avdName);
    final StreamController<String>? controller = _controllers.remove(avdName);
    await controller?.close();
  }

  @override
  Future<void> stopAll() async {
    final List<String> names = _running.toList();
    for (final String name in names) {
      await stop(name);
    }
  }

  void emit(String avdName, String line) {
    _controllers[avdName]?.add(line);
  }

  Future<void> close(String avdName) async {
    _running.remove(avdName);
    await _controllers[avdName]?.close();
  }
}

class _StaticAvdListNotifier extends AvdListNotifier {
  @override
  Future<List<Avd>> build() async => _currentAvds;

  @override
  Future<void> refresh() async {
    state = AsyncValue<List<Avd>>.data(_currentAvds);
  }
}

List<Avd> _currentAvds = const <Avd>[];

Future<void> _settle() async {
  await Future<void>.delayed(const Duration(milliseconds: 120));
}

void main() {
  test('pause/resume/clear and disconnect behavior', () async {
    _currentAvds = const <Avd>[
      Avd(
        name: 'Pixel_API_35',
        iniPath: '/tmp/Pixel_API_35.ini',
        avdPath: '/tmp/Pixel_API_35.avd',
        state: AvdState.running,
        serial: 'emulator-5554',
      ),
    ];
    final _FakeLogcatService fakeService = _FakeLogcatService();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        logcatServiceProvider.overrideWithValue(fakeService),
        sdkPathsProvider.overrideWith(
          (ref) async => const AndroidSdkPaths(
            root: '/tmp/sdk',
            emulator: '/tmp/sdk/emulator',
            adb: '/tmp/sdk/adb',
            avdmanager: '/tmp/sdk/avdmanager',
            sdkmanager: '/tmp/sdk/sdkmanager',
          ),
        ),
        avdListProvider.overrideWith(_StaticAvdListNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    final LogcatNotifier notifier = container.read(
      logcatNotifierProvider('Pixel_API_35').notifier,
    );
    await _settle();
    expect(fakeService.startCalls, 1);

    fakeService.emit('Pixel_API_35', 'line-1');
    await _settle();
    expect(
      container
          .read(logcatNotifierProvider('Pixel_API_35'))
          .lines
          .map((line) => line.raw)
          .toList(),
      <String>['line-1'],
    );

    notifier.pause();
    fakeService.emit('Pixel_API_35', 'line-2');
    await _settle();
    expect(
      container
          .read(logcatNotifierProvider('Pixel_API_35'))
          .lines
          .map((line) => line.raw)
          .toList(),
      <String>['line-1'],
    );
    expect(
      container.read(logcatNotifierProvider('Pixel_API_35')).status,
      LogcatStatus.paused,
    );

    notifier.resume();
    fakeService.emit('Pixel_API_35', 'line-3');
    await _settle();
    expect(
      container
          .read(logcatNotifierProvider('Pixel_API_35'))
          .lines
          .map((line) => line.raw)
          .toList(),
      <String>['line-1', 'line-3'],
    );
    expect(
      container.read(logcatNotifierProvider('Pixel_API_35')).status,
      LogcatStatus.live,
    );

    notifier.clear();
    expect(
      container.read(logcatNotifierProvider('Pixel_API_35')).lines,
      isEmpty,
    );

    await fakeService.close('Pixel_API_35');
    await _settle();
    expect(
      container.read(logcatNotifierProvider('Pixel_API_35')).status,
      LogcatStatus.disconnected,
    );
  });

  test('keeps capped buffer of latest 5000 lines', () async {
    _currentAvds = const <Avd>[
      Avd(
        name: 'Pixel_API_36',
        iniPath: '/tmp/Pixel_API_36.ini',
        avdPath: '/tmp/Pixel_API_36.avd',
        state: AvdState.running,
        serial: 'emulator-5560',
      ),
    ];
    final _FakeLogcatService fakeService = _FakeLogcatService();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        logcatServiceProvider.overrideWithValue(fakeService),
        sdkPathsProvider.overrideWith(
          (ref) async => const AndroidSdkPaths(
            root: '/tmp/sdk',
            emulator: '/tmp/sdk/emulator',
            adb: '/tmp/sdk/adb',
            avdmanager: '/tmp/sdk/avdmanager',
            sdkmanager: '/tmp/sdk/sdkmanager',
          ),
        ),
        avdListProvider.overrideWith(_StaticAvdListNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    container.read(logcatNotifierProvider('Pixel_API_36').notifier);
    await _settle();
    for (int i = 0; i < 5100; i++) {
      fakeService.emit('Pixel_API_36', 'line-$i');
    }
    await _settle();

    final List<String> lines = container
        .read(logcatNotifierProvider('Pixel_API_36'))
        .lines
        .map((line) => line.raw)
        .toList();
    expect(lines.length, 5000);
    expect(lines.first, 'line-100');
    expect(lines.last, 'line-5099');
  });
}
