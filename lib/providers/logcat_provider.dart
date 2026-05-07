import 'dart:async';

import 'package:emulator_device_manager/models/avd.dart';
import 'package:emulator_device_manager/models/avd_state.dart';
import 'package:emulator_device_manager/providers/avd_providers.dart';
import 'package:emulator_device_manager/providers/sdk_providers.dart';
import 'package:emulator_device_manager/services/android_sdk.dart';
import 'package:emulator_device_manager/services/logcat_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum LogcatStatus { idle, live, paused, disconnected, error }

class LogcatState {
  const LogcatState({
    this.lines = const <String>[],
    this.paused = false,
    this.status = LogcatStatus.idle,
    this.error,
  });

  final List<String> lines;
  final bool paused;
  final LogcatStatus status;
  final String? error;

  LogcatState copyWith({
    List<String>? lines,
    bool? paused,
    LogcatStatus? status,
    String? error,
    bool clearError = false,
  }) {
    return LogcatState(
      lines: lines ?? this.lines,
      paused: paused ?? this.paused,
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final logcatServiceProvider = Provider<LogcatService>((ref) {
  final LogcatService service = LogcatService();
  ref.onDispose(() => unawaited(service.stopAll()));
  return service;
});

final logcatNotifierProvider =
    StateNotifierProvider.family<LogcatNotifier, LogcatState, String>((
      ref,
      avdName,
    ) {
      return LogcatNotifier(
        ref: ref,
        avdName: avdName,
        service: ref.read(logcatServiceProvider),
      );
    });

class LogcatNotifier extends StateNotifier<LogcatState> {
  LogcatNotifier({
    required Ref ref,
    required String avdName,
    required LogcatService service,
  }) : _ref = ref,
       _avdName = avdName,
       _service = service,
       super(const LogcatState()) {
    _ref.listen<AsyncValue<List<Avd>>>(avdListProvider, (_, next) {
      _onAvdSnapshot(next.valueOrNull);
    }, fireImmediately: true);
  }

  static const int _logLimit = 5000;
  static const Duration _flushInterval = Duration(milliseconds: 80);

  final Ref _ref;
  final String _avdName;
  final LogcatService _service;

  StreamSubscription<String>? _logSubscription;
  Timer? _flushTimer;
  final List<String> _buffer = <String>[];
  bool _hasPendingFlush = false;
  String? _currentSerial;
  String? _adbPath;
  bool _intentionalDisconnect = false;

  void pause() {
    state = state.copyWith(paused: true, status: LogcatStatus.paused);
  }

  void resume() {
    final LogcatStatus nextStatus = _service.isRunning(_avdName)
        ? LogcatStatus.live
        : LogcatStatus.disconnected;
    state = state.copyWith(
      paused: false,
      status: nextStatus,
      clearError: true,
    );
  }

  void clear() {
    _buffer.clear();
    _hasPendingFlush = false;
    state = state.copyWith(lines: const <String>[]);
  }

  Future<void> reconnect() async {
    if (_currentSerial == null || _adbPath == null) {
      state = state.copyWith(
        status: LogcatStatus.error,
        error: 'No emulator connection available.',
      );
      return;
    }
    await _disconnect();
    await _connect(adbPath: _adbPath!, serial: _currentSerial!);
  }

  Future<void> _onAvdSnapshot(List<Avd>? avds) async {
    if (avds == null) {
      return;
    }
    final Avd? avd = _lookupAvd(avds);
    if (avd == null) {
      return;
    }

    if (avd.state != AvdState.running && avd.state != AvdState.booting) {
      if (_service.isRunning(_avdName)) {
        await _disconnect();
      }
      state = state.copyWith(
        status: state.paused ? LogcatStatus.paused : LogcatStatus.disconnected,
      );
      return;
    }

    final String? serial = avd.serial;
    if (serial == null || serial.isEmpty) {
      return;
    }

    if (_currentSerial != null &&
        _currentSerial != serial &&
        _service.isRunning(_avdName)) {
      await _disconnect();
      state = state.copyWith(
        status: LogcatStatus.disconnected,
        error: 'Emulator identity changed. Press play to reconnect.',
      );
      _currentSerial = serial;
      return;
    }

    _currentSerial = serial;
    if (_service.isRunning(_avdName)) {
      return;
    }
    final AndroidSdkPaths? sdkPaths = await _ref.read(sdkPathsProvider.future);
    if (sdkPaths == null) {
      state = state.copyWith(
        status: LogcatStatus.error,
        error: 'Android SDK not configured.',
      );
      return;
    }
    _adbPath = sdkPaths.adb;
    await _connect(adbPath: sdkPaths.adb, serial: serial);
  }

  Future<void> _connect({
    required String adbPath,
    required String serial,
  }) async {
    try {
      await _service.start(avdName: _avdName, adbPath: adbPath, serial: serial);
      await _logSubscription?.cancel();
      _intentionalDisconnect = false;
      _logSubscription = _service.lines(_avdName).listen(
        _onLine,
        onDone: _onStreamClosed,
        onError: (Object error, StackTrace stackTrace) {
          state = state.copyWith(
            status: LogcatStatus.error,
            error: error.toString(),
          );
        },
      );
      state = state.copyWith(
        status: state.paused ? LogcatStatus.paused : LogcatStatus.live,
        lines: List<String>.unmodifiable(_buffer),
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(status: LogcatStatus.error, error: '$error');
    }
  }

  void _onLine(String line) {
    if (state.paused) {
      return;
    }
    _buffer.add(line);
    if (_buffer.length > _logLimit) {
      _buffer.removeRange(0, _buffer.length - _logLimit);
    }
    _scheduleFlush();
  }

  void _scheduleFlush() {
    _hasPendingFlush = true;
    _flushTimer ??= Timer(_flushInterval, _flushLines);
  }

  void _flushLines() {
    _flushTimer = null;
    if (!_hasPendingFlush || state.paused) {
      return;
    }
    _hasPendingFlush = false;
    state = state.copyWith(
      lines: List<String>.unmodifiable(_buffer),
      status: LogcatStatus.live,
    );
  }

  void _onStreamClosed() {
    if (_intentionalDisconnect) {
      return;
    }
    state = state.copyWith(
      status: state.paused ? LogcatStatus.paused : LogcatStatus.disconnected,
    );
  }

  Avd? _lookupAvd(List<Avd> avds) {
    for (final Avd avd in avds) {
      if (avd.name == _avdName) {
        return avd;
      }
    }
    return null;
  }

  Future<void> _disconnect() async {
    _intentionalDisconnect = true;
    _flushTimer?.cancel();
    _flushTimer = null;
    _hasPendingFlush = false;
    await _logSubscription?.cancel();
    _logSubscription = null;
    await _service.stop(_avdName);
    _intentionalDisconnect = false;
  }

  @override
  void dispose() {
    _flushTimer?.cancel();
    unawaited(_disconnect());
    super.dispose();
  }
}
