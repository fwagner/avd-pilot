import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class AndroidSdkPaths {
  const AndroidSdkPaths({
    required this.root,
    required this.emulator,
    required this.adb,
    required this.avdmanager,
    required this.sdkmanager,
  });
  final String root;
  final String emulator;
  final String adb;
  final String avdmanager;
  final String sdkmanager;
}

class AndroidSdkService {
  static const String _prefKey = 'android_sdk_override';

  Future<String?> getOverridePath() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKey);
  }

  Future<void> setOverridePath(String? value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (value == null || value.trim().isEmpty) {
      await prefs.remove(_prefKey);
      return;
    }
    await prefs.setString(_prefKey, value.trim());
  }

  Future<AndroidSdkPaths?> resolvePaths() async {
    final String? override = await getOverridePath();
    final String home = Platform.environment['HOME'] ?? '';
    final List<String?> candidates = <String?>[
      override,
      Platform.environment['ANDROID_SDK_ROOT'],
      Platform.environment['ANDROID_HOME'],
      home.isEmpty ? null : p.join(home, 'Library', 'Android', 'sdk'),
    ];
    for (final String? candidate in candidates) {
      if (candidate == null || candidate.isEmpty) {
        continue;
      }
      final Directory root = Directory(candidate);
      if (!root.existsSync()) {
        continue;
      }
      final String emulator = p.join(candidate, 'emulator', 'emulator');
      final String adb = p.join(candidate, 'platform-tools', 'adb');
      final String? cmdlineToolsBin = _findCmdlineToolsBin(candidate);
      if (File(emulator).existsSync() &&
          File(adb).existsSync() &&
          cmdlineToolsBin != null) {
        final String avdmanager = p.join(cmdlineToolsBin, 'avdmanager');
        final String sdkmanager = p.join(cmdlineToolsBin, 'sdkmanager');
        if (!File(avdmanager).existsSync() || !File(sdkmanager).existsSync()) {
          continue;
        }
        return AndroidSdkPaths(
          root: candidate,
          emulator: emulator,
          adb: adb,
          avdmanager: avdmanager,
          sdkmanager: sdkmanager,
        );
      }
    }
    return null;
  }

  String? _findCmdlineToolsBin(String sdkRoot) {
    final String latest = p.join(sdkRoot, 'cmdline-tools', 'latest', 'bin');
    if (Directory(latest).existsSync()) {
      return latest;
    }
    final Directory cmdlineRoot = Directory(p.join(sdkRoot, 'cmdline-tools'));
    if (!cmdlineRoot.existsSync()) {
      return null;
    }
    final List<Directory> bins =
        cmdlineRoot
            .listSync()
            .whereType<Directory>()
            .map((d) => Directory(p.join(d.path, 'bin')))
            .where((d) => d.existsSync())
            .toList()
          ..sort((a, b) => b.path.compareTo(a.path));
    if (bins.isEmpty) {
      return null;
    }
    return bins.first.path;
  }
}
