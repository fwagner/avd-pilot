import 'package:emulator_device_manager/models/avd_state.dart';

class Avd {
  const Avd({
    required this.name,
    required this.iniPath,
    required this.avdPath,
    required this.state,
    this.deviceName,
    this.target,
    this.abi,
    this.serial,
    this.error,
    this.config = const {},
  });

  final String name;
  final String iniPath;
  final String avdPath;
  final AvdState state;
  final String? deviceName;
  final String? target;
  final String? abi;
  final String? serial;
  final String? error;
  final Map<String, String> config;

  bool get isUnknownEmulator => iniPath.isEmpty && avdPath.isEmpty;

  Avd copyWith({
    String? name,
    String? iniPath,
    String? avdPath,
    AvdState? state,
    String? deviceName,
    String? target,
    String? abi,
    String? serial,
    String? error,
    Map<String, String>? config,
  }) {
    return Avd(
      name: name ?? this.name,
      iniPath: iniPath ?? this.iniPath,
      avdPath: avdPath ?? this.avdPath,
      state: state ?? this.state,
      deviceName: deviceName ?? this.deviceName,
      target: target ?? this.target,
      abi: abi ?? this.abi,
      serial: serial ?? this.serial,
      error: error ?? this.error,
      config: config ?? this.config,
    );
  }
}
