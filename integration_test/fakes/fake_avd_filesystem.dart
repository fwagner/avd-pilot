import 'dart:io';

import 'package:path/path.dart' as p;

class FakeAvdFileSystem {
  FakeAvdFileSystem._(this._root, this._avdRoot);

  final Directory _root;
  final Directory _avdRoot;

  String get avdRootPath => _avdRoot.path;

  static Future<FakeAvdFileSystem> create() async {
    final Directory root = await Directory.systemTemp.createTemp(
      'avd-pilot-integration-test-',
    );
    final Directory avdRoot = Directory(p.join(root.path, '.android', 'avd'));
    await avdRoot.create(recursive: true);
    return FakeAvdFileSystem._(root, avdRoot);
  }

  Future<void> addAvd({
    required String name,
    String deviceName = 'Pixel 8',
    String target = 'system-images/android-35/google_apis/arm64-v8a/',
    String abi = 'arm64-v8a',
    Map<String, String> extraConfig = const <String, String>{},
  }) async {
    final Directory avdDirectory = Directory(
      p.join(_avdRoot.path, '$name.avd'),
    );
    await avdDirectory.create(recursive: true);
    final File iniFile = File(p.join(_avdRoot.path, '$name.ini'));
    await iniFile.writeAsString(
      [
        'avd.ini.encoding=UTF-8',
        'path=${avdDirectory.path}',
        'path.rel=avd/$name.avd',
        'target=android-35',
      ].join('\n'),
    );
    final Map<String, String> config = <String, String>{
      'hw.device.name': deviceName,
      'image.sysdir.1': target,
      'abi.type': abi,
      'hw.ramSize': '2048',
      'vm.heapSize': '256',
      'disk.dataPartition.size': '800M',
      'sdcard.size': '512M',
      ...extraConfig,
    };
    final File configFile = File(p.join(avdDirectory.path, 'config.ini'));
    await configFile.writeAsString(
      config.entries.map((entry) => '${entry.key}=${entry.value}').join('\n'),
    );
  }

  String configPathFor(String avdName) {
    return p.join(_avdRoot.path, '$avdName.avd', 'config.ini');
  }

  Future<void> removeAvd(String name) async {
    final File iniFile = File(p.join(_avdRoot.path, '$name.ini'));
    if (await iniFile.exists()) {
      await iniFile.delete();
    }
    final Directory avdDirectory = Directory(
      p.join(_avdRoot.path, '$name.avd'),
    );
    if (await avdDirectory.exists()) {
      await avdDirectory.delete(recursive: true);
    }
  }

  Future<void> dispose() async {
    if (await _root.exists()) {
      await _root.delete(recursive: true);
    }
  }
}
