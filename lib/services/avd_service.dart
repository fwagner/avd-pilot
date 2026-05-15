import 'dart:io';

import 'package:emulator_device_manager/models/avd.dart';
import 'package:emulator_device_manager/models/avd_state.dart';
import 'package:emulator_device_manager/models/device_profile.dart';
import 'package:emulator_device_manager/services/config_ini.dart';
import 'package:emulator_device_manager/services/shell.dart';
import 'package:path/path.dart' as p;

class AvdService {
  AvdService(this._shell, {String? avdRootOverride})
    : _avdRootOverride = avdRootOverride;
  final ShellService _shell;
  final String? _avdRootOverride;

  String get _home => Platform.environment['HOME'] ?? '';
  String get _avdRoot => _avdRootOverride ?? p.join(_home, '.android', 'avd');

  Future<List<Avd>> listAvds() async {
    final Directory root = Directory(_avdRoot);
    if (!await root.exists()) {
      return <Avd>[];
    }
    final List<Avd> items = <Avd>[];
    await for (final FileSystemEntity entity in root.list()) {
      if (entity is! File || !entity.path.endsWith('.ini')) {
        continue;
      }
      final String iniText = await entity.readAsString();
      final String pathLine = iniText
          .split('\n')
          .firstWhere((line) => line.startsWith('path='), orElse: () => '')
          .replaceFirst('path=', '')
          .trim();
      if (pathLine.isEmpty) {
        continue;
      }
      final String avdPath = pathLine;
      final String configPath = p.join(avdPath, 'config.ini');
      final ConfigIni cfg = await ConfigIni.fromFile(configPath);
      items.add(
        Avd(
          name: p.basenameWithoutExtension(entity.path),
          iniPath: entity.path,
          avdPath: avdPath,
          state: AvdState.stopped,
          deviceName: cfg.getValue('hw.device.name'),
          target: cfg.getValue('image.sysdir.1'),
          abi: cfg.getValue('abi.type'),
          config: cfg.toMap(),
        ),
      );
    }
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }

  Future<void> createAvd({
    required String avdManagerPath,
    required String name,
    required String packageId,
    required String deviceId,
  }) async {
    await _shell.runTool(
      avdManagerPath,
      <String>[
        'create',
        'avd',
        '-n',
        name,
        '-k',
        packageId,
        '-d',
        deviceId,
        '-f',
      ],
      stdinData: 'no\n',
      timeout: const Duration(minutes: 2),
    );
  }

  Future<void> deleteAvd({
    required String avdManagerPath,
    required String name,
  }) async {
    await _shell.runTool(avdManagerPath, <String>['delete', 'avd', '-n', name]);
  }

  Future<void> renameAvd({
    required String avdManagerPath,
    required String oldName,
    required String newName,
  }) async {
    await _shell.runTool(avdManagerPath, <String>[
      'move',
      'avd',
      '-n',
      oldName,
      '-r',
      newName,
    ]);
  }

  Future<void> wipeData(String avdPath) async {
    final List<String> names = <String>[
      'userdata-qemu.img',
      'userdata-qemu.img.qcow2',
      'cache.img',
    ];
    for (final String name in names) {
      final File file = File(p.join(avdPath, name));
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<List<DeviceProfile>> listDeviceProfiles(String avdManagerPath) async {
    final ToolResult result = await _shell.runTool(avdManagerPath, <String>[
      'list',
      'device',
    ]);
    final List<DeviceProfile> profiles = <DeviceProfile>[];
    String? currentId;
    String? currentName;
    String? currentOem;

    void flushCurrent() {
      if (currentId == null || currentName == null) {
        return;
      }
      profiles.add(
        DeviceProfile(
          id: currentId!,
          name: currentName!,
          oem: currentOem ?? 'Android',
        ),
      );
      currentId = null;
      currentName = null;
      currentOem = null;
    }

    final RegExp idPattern = RegExp(r'^id:\s+\d+\s+or\s+"([^"]+)"');
    for (final String rawLine in result.stdout.split('\n')) {
      final String line = rawLine.trimRight();
      final RegExpMatch? idMatch = idPattern.firstMatch(line.trimLeft());
      if (idMatch != null) {
        flushCurrent();
        currentId = idMatch.group(1)!.trim();
        continue;
      }
      final String trimmed = line.trim();
      if (trimmed.startsWith('Name:')) {
        currentName = trimmed.replaceFirst('Name:', '').trim();
        continue;
      }
      if (trimmed.startsWith('OEM :')) {
        currentOem = trimmed.replaceFirst('OEM :', '').trim();
        continue;
      }
      if (trimmed == '---------' || trimmed.isEmpty) {
        flushCurrent();
      }
    }
    flushCurrent();
    profiles.sort((a, b) => a.displayName.compareTo(b.displayName));
    return profiles;
  }
}
