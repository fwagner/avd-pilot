import 'dart:async';

import 'package:emulator_device_manager/models/avd.dart';
import 'package:emulator_device_manager/providers/avd_providers.dart';
import 'package:emulator_device_manager/providers/logcat_provider.dart';
import 'package:emulator_device_manager/providers/sdk_providers.dart';
import 'package:emulator_device_manager/services/android_sdk.dart';
import 'package:emulator_device_manager/services/process_resolver.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final processMapProvider =
    StateNotifierProvider.family<ProcessMapNotifier, Map<int, String>, String>((
      ref,
      avdName,
    ) {
      return ProcessMapNotifier(ref: ref, avdName: avdName);
    });

class ProcessMapNotifier extends StateNotifier<Map<int, String>> {
  ProcessMapNotifier({required Ref ref, required String avdName})
    : _ref = ref,
      _avdName = avdName,
      super(const <int, String>{}) {
    _ref.listen<AsyncValue<List<Avd>>>(avdListProvider, (_, next) {
      unawaited(_handleAvdSnapshot(next.valueOrNull));
    }, fireImmediately: true);
    _ref.listen<LogcatState>(logcatNotifierProvider(_avdName), (_, next) {
      _handleLogcatState(next.status);
    }, fireImmediately: true);
  }

  static const Duration _refreshInterval = Duration(seconds: 10);

  final Ref _ref;
  final String _avdName;

  ProcessResolver? _resolver;
  Timer? _refreshTimer;
  String? _serial;
  String? _adbPath;
  bool _isLogcatLive = false;

  Future<void> _handleAvdSnapshot(List<Avd>? avds) async {
    final Avd? avd = _lookupAvd(avds);
    final String? serial = avd?.serial;
    if (serial == null || serial.isEmpty) {
      _serial = null;
      _resolver = null;
      _cancelRefreshTimer();
      if (state.isNotEmpty) {
        state = const <int, String>{};
      }
      return;
    }

    final AndroidSdkPaths? sdkPaths = await _ref.read(sdkPathsProvider.future);
    if (sdkPaths == null) {
      _adbPath = null;
      _resolver = null;
      _cancelRefreshTimer();
      if (state.isNotEmpty) {
        state = const <int, String>{};
      }
      return;
    }

    if (_resolver == null || _serial != serial || _adbPath != sdkPaths.adb) {
      _serial = serial;
      _adbPath = sdkPaths.adb;
      _resolver = ProcessResolver(adbPath: sdkPaths.adb, serial: serial);
    }

    _syncRefreshTimer();
    await _refreshOnce();
  }

  void _handleLogcatState(LogcatStatus status) {
    _isLogcatLive = status == LogcatStatus.live;
    _syncRefreshTimer();
    if (_isLogcatLive) {
      unawaited(_refreshOnce());
    }
  }

  Future<void> _refreshOnce() async {
    if (!_isLogcatLive) {
      return;
    }
    final ProcessResolver? resolver = _resolver;
    if (resolver == null) {
      return;
    }
    try {
      await resolver.refresh();
      state = resolver.processMap;
    } catch (_) {
      // Ignore process map refresh failures; next tick will retry.
    }
  }

  void _syncRefreshTimer() {
    if (_isLogcatLive && _resolver != null) {
      _refreshTimer ??= Timer.periodic(_refreshInterval, (_) {
        unawaited(_refreshOnce());
      });
      return;
    }
    _cancelRefreshTimer();
  }

  void _cancelRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Avd? _lookupAvd(List<Avd>? avds) {
    if (avds == null) {
      return null;
    }
    for (final Avd avd in avds) {
      if (avd.name == _avdName) {
        return avd;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _cancelRefreshTimer();
    super.dispose();
  }
}
