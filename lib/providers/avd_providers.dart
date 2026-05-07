import 'dart:async';

import 'package:emulator_device_manager/models/avd.dart';
import 'package:emulator_device_manager/models/avd_state.dart';
import 'package:emulator_device_manager/providers/sdk_providers.dart';
import 'package:emulator_device_manager/services/emulator_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final emulatorServiceProvider = Provider<EmulatorService>((ref) {
  return EmulatorService(ref.read(shellServiceProvider));
});

class AvdListNotifier extends AsyncNotifier<List<Avd>> {
  Timer? _poll;

  @override
  Future<List<Avd>> build() async {
    ref.onDispose(() => _poll?.cancel());
    _startPolling();
    return _load();
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => refresh());
  }

  Future<List<Avd>> _load() async {
    final sdk = await ref.read(sdkPathsProvider.future);
    if (sdk == null) {
      return <Avd>[];
    }
    final avdService = ref.read(avdServiceProvider);
    final emulatorService = ref.read(emulatorServiceProvider);
    final avds = await avdService.listAvds();
    final withStates = await emulatorService.deriveStates(
      adbPath: sdk.adb,
      avds: avds,
    );
    final hasTransitions = withStates.any((a) => a.state.isTransitioning);
    if (hasTransitions) {
      _poll?.cancel();
      _poll = Timer.periodic(const Duration(seconds: 1), (_) => refresh());
    } else {
      _startPolling();
    }
    return withStates;
  }

  Future<void> refresh() async {
    try {
      final next = await _load();
      state = AsyncValue.data(next);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

final avdListProvider = AsyncNotifierProvider<AvdListNotifier, List<Avd>>(
  AvdListNotifier.new,
);
