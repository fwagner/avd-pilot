import 'dart:async';
import 'dart:io';

import 'package:emulator_device_manager/models/avd.dart';
import 'package:emulator_device_manager/models/avd_state.dart';
import 'package:emulator_device_manager/services/shell.dart';

class AlreadyRunningException implements Exception {}

class EmulatorService {
  EmulatorService(this._shell);
  final ShellService _shell;

  final Map<String, Process> _launches = <String, Process>{};
  final Map<String, int> _ports = <String, int>{};
  final Map<String, DateTime> _launchStartedAt = <String, DateTime>{};
  final Map<String, DateTime> _stopRequests = <String, DateTime>{};

  int _nextPort = 5554;

  // Exposed for tests.
  void seedLaunchPortForTesting(String avdName, int port) {
    _ports[avdName] = port;
  }

  Future<int> _reservePort(String adbPath) async {
    final Set<int> occupied = <int>{..._ports.values};
    try {
      final ToolResult devices = await _shell.runTool(adbPath, <String>[
        'devices',
      ]);
      final RegExp serialPattern = RegExp(r'^emulator-(\d+)\s+');
      for (final String line in devices.stdout.split('\n')) {
        final RegExpMatch? match = serialPattern.firstMatch(line.trim());
        if (match == null) {
          continue;
        }
        final int? port = int.tryParse(match.group(1)!);
        if (port != null) {
          occupied.add(port);
        }
      }
    } catch (_) {
      // Best-effort detection; if adb lookup fails, fallback to local tracking.
    }

    int candidate = _nextPort;
    while (occupied.contains(candidate)) {
      candidate += 2;
    }
    _nextPort = candidate + 2;
    return candidate;
  }

  Future<void> launch({
    required String emulatorPath,
    required String adbPath,
    required String avdName,
    bool coldBoot = false,
  }) async {
    if (_launches.containsKey(avdName)) {
      throw AlreadyRunningException();
    }
    final int port = await _reservePort(adbPath);
    final List<String> args = <String>['-avd', avdName, '-port', '$port'];
    if (coldBoot) {
      args.add('-no-snapshot-load');
    }
    final Process process = await Process.start(
      emulatorPath,
      args,
      mode: ProcessStartMode.detached,
    );
    _launches[avdName] = process;
    _ports[avdName] = port;
    _launchStartedAt[avdName] = DateTime.now();
  }

  Future<void> stop({required String adbPath, required Avd avd}) async {
    _stopRequests[avd.name] = DateTime.now();
    if (avd.state == AvdState.starting && _launches.containsKey(avd.name)) {
      final Process process = _launches[avd.name]!;
      Process.killPid(process.pid, ProcessSignal.sigterm);
      await Future<void>.delayed(const Duration(seconds: 5));
      if (_launches.containsKey(avd.name)) {
        Process.killPid(process.pid, ProcessSignal.sigkill);
      }
      _launches.remove(avd.name);
      _ports.remove(avd.name);
      _launchStartedAt.remove(avd.name);
      return;
    }
    if (avd.serial != null) {
      await _shell.runTool(adbPath, <String>['-s', avd.serial!, 'emu', 'kill']);
    }
  }

  Future<void> stopAll(String adbPath, List<Avd> avds) async {
    for (final Avd avd in avds.where(
      (a) => a.state == AvdState.running || a.state == AvdState.booting,
    )) {
      if (avd.serial != null) {
        await _shell.runTool(adbPath, <String>[
          '-s',
          avd.serial!,
          'emu',
          'kill',
        ]);
      }
    }
  }

  Future<Map<String, String>> _serialToAvdMap(String adbPath) async {
    final ToolResult devices = await _shell.runTool(adbPath, <String>[
      'devices',
    ]);
    final Map<String, String> map = <String, String>{};
    final RegExp serialPattern = RegExp(r'^(emulator-(\d+))\s+(\S+)');
    for (final String line in devices.stdout.split('\n')) {
      final RegExpMatch? serialMatch = serialPattern.firstMatch(line.trim());
      if (serialMatch == null) {
        continue;
      }
      final String serial = serialMatch.group(1)!;
      final int serialPort = int.tryParse(serialMatch.group(2) ?? '') ?? -1;
      String? name;

      // Most reliable mapping for emulators launched by this app.
      if (serialPort > 0) {
        for (final MapEntry<String, int> entry in _ports.entries) {
          if (entry.value == serialPort) {
            name = entry.key;
            break;
          }
        }
      }

      try {
        if (name == null || name.isEmpty) {
          final ToolResult prop = await _shell.runTool(adbPath, <String>[
            '-s',
            serial,
            'shell',
            'getprop',
            'ro.kernel.qemu.avd_name',
          ]);
          name = prop.stdout.trim();
        }
      } catch (_) {}
      try {
        if (name == null || name.isEmpty) {
          final ToolResult prop = await _shell.runTool(adbPath, <String>[
            '-s',
            serial,
            'shell',
            'getprop',
            'ro.boot.qemu.avd_name',
          ]);
          name = prop.stdout.trim();
        }
      } catch (_) {}
      if (name == null || name.isEmpty) {
        try {
          final ToolResult legacy = await _shell.runTool(adbPath, <String>[
            '-s',
            serial,
            'emu',
            'avd',
            'name',
          ]);
          name = _extractNameFromLegacyOutput(legacy.stdout);
        } catch (_) {}
      }
      name = _normalizeName(name);
      if (name == null || name.isEmpty) {
        name = 'Unknown emulator ($serial)';
      }
      map[serial] = name;
    }
    return map;
  }

  Future<List<Avd>> deriveStates({
    required String adbPath,
    required List<Avd> avds,
  }) async {
    final Map<String, String> serialToName = await _serialToAvdMap(adbPath);
    final Set<String> runningNamesLower = serialToName.values
        .map((name) => name.toLowerCase())
        .toSet();
    final Map<String, Avd> byName = <String, Avd>{};
    final Map<String, String> lowerToOriginalName = <String, String>{};
    for (final Avd avd in avds) {
      byName[avd.name] = avd.copyWith(state: AvdState.stopped);
      lowerToOriginalName[avd.name.toLowerCase()] = avd.name;
    }

    for (final MapEntry<String, Process> entry in _launches.entries) {
      if (byName.containsKey(entry.key)) {
        byName[entry.key] = byName[entry.key]!.copyWith(
          state: AvdState.starting,
        );
      }
    }

    for (final MapEntry<String, String> entry in serialToName.entries) {
      final String serial = entry.key;
      final String rawName = entry.value;
      final String name = lowerToOriginalName[rawName.toLowerCase()] ?? rawName;
      if (!byName.containsKey(name)) {
        byName[name] = Avd(
          name: name,
          iniPath: '',
          avdPath: '',
          state: AvdState.running,
          serial: serial,
        );
        continue;
      }
      bool complete = false;
      try {
        final ToolResult boot = await _shell.runTool(adbPath, <String>[
          '-s',
          serial,
          'shell',
          'getprop',
          'sys.boot_completed',
        ]);
        complete = boot.stdout.trim() == '1';
      } catch (_) {
        complete = false;
      }
      final AvdState next = complete ? AvdState.running : AvdState.booting;
      byName[name] = byName[name]!.copyWith(state: next, serial: serial);
    }

    final DateTime now = DateTime.now();
    final List<String> launchKeys = _launches.keys.toList();
    for (final String name in launchKeys) {
      final DateTime? startedAt = _launchStartedAt[name];
      final bool mappedRunning = runningNamesLower.contains(name.toLowerCase());
      final bool stale =
          startedAt != null &&
          now.difference(startedAt) > const Duration(seconds: 90);
      if (mappedRunning || stale) {
        _launches.remove(name);
        _ports.remove(name);
        _launchStartedAt.remove(name);
      }
    }

    for (final MapEntry<String, DateTime> entry in _stopRequests.entries) {
      if (now.difference(entry.value) < const Duration(seconds: 10) &&
          byName.containsKey(entry.key)) {
        byName[entry.key] = byName[entry.key]!.copyWith(
          state: AvdState.stopping,
        );
      }
    }

    return byName.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  String? _extractNameFromLegacyOutput(String output) {
    final List<String> lines = output
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return null;
    }
    for (final String line in lines.reversed) {
      final String? normalized = _normalizeName(line);
      if (normalized != null) {
        return normalized;
      }
    }
    return null;
  }

  String? _normalizeName(String? input) {
    if (input == null) {
      return null;
    }
    final String candidate = input.trim().replaceAll('"', '');
    if (candidate.isEmpty) {
      return null;
    }
    final Set<String> invalid = <String>{'ok', 'ko', 'error', 'null', 'none'};
    if (invalid.contains(candidate.toLowerCase())) {
      return null;
    }
    return candidate;
  }
}
