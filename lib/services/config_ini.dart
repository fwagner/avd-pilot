import 'dart:io';

import 'package:path/path.dart' as p;

enum SizeUnit { b, k, m, g }

class SizeValue {
  const SizeValue({required this.value, required this.unit});
  final int value;
  final SizeUnit unit;

  @override
  String toString() => '$value${unit.name.toUpperCase()}';
}

class _ConfigLine {
  _ConfigLine.comment(this.raw) : key = null, value = null;
  _ConfigLine.kv(this.key, this.value) : raw = null;

  final String? raw;
  final String? key;
  String? value;
}

class ConfigIni {
  ConfigIni._(this._lines);

  final List<_ConfigLine> _lines;

  factory ConfigIni.parse(String input) {
    final List<_ConfigLine> lines = <_ConfigLine>[];
    for (final String line in input.split('\n')) {
      if (line.trim().isEmpty || line.trimLeft().startsWith('#')) {
        lines.add(_ConfigLine.comment(line));
        continue;
      }
      final int idx = line.indexOf('=');
      if (idx <= 0) {
        lines.add(_ConfigLine.comment(line));
        continue;
      }
      final String key = line.substring(0, idx).trim();
      final String value = line.substring(idx + 1).trim();
      lines.add(_ConfigLine.kv(key, value));
    }
    return ConfigIni._(lines);
  }

  static Future<ConfigIni> fromFile(String filePath) async {
    final File f = File(filePath);
    if (!await f.exists()) {
      return ConfigIni._(<_ConfigLine>[]);
    }
    return ConfigIni.parse(await f.readAsString());
  }

  Map<String, String> toMap() {
    final Map<String, String> map = <String, String>{};
    for (final _ConfigLine line in _lines) {
      if (line.key != null) {
        map[line.key!] = line.value ?? '';
      }
    }
    return map;
  }

  String? getValue(String key) {
    for (final _ConfigLine line in _lines) {
      if (line.key == key) {
        return line.value;
      }
    }
    return null;
  }

  void setValue(String key, String value) {
    for (final _ConfigLine line in _lines) {
      if (line.key == key) {
        line.value = value;
        return;
      }
    }
    _lines.add(_ConfigLine.kv(key, value));
  }

  void removeKey(String key) {
    _lines.removeWhere((line) => line.key == key);
  }

  SizeValue? getSize(String key) {
    final String? raw = getValue(key);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final RegExp exp = RegExp(r'^(\d+)([KMGkmg])?$');
    final RegExpMatch? match = exp.firstMatch(raw);
    if (match == null) {
      final int? bytes = int.tryParse(raw);
      if (bytes == null) {
        return null;
      }
      return SizeValue(value: bytes, unit: SizeUnit.b);
    }
    final int number = int.parse(match.group(1)!);
    final String? unitRaw = match.group(2)?.toUpperCase();
    final SizeUnit unit = switch (unitRaw) {
      'K' => SizeUnit.k,
      'M' => SizeUnit.m,
      'G' => SizeUnit.g,
      _ => SizeUnit.b,
    };
    return SizeValue(value: number, unit: unit);
  }

  void setSize(String key, SizeValue size) {
    final String suffix = switch (size.unit) {
      SizeUnit.b => '',
      SizeUnit.k => 'K',
      SizeUnit.m => 'M',
      SizeUnit.g => 'G',
    };
    setValue(key, '${size.value}$suffix');
  }

  Future<void> saveAtomic(String filePath) async {
    final String tmpPath = p.join(
      p.dirname(filePath),
      '${p.basename(filePath)}.tmp',
    );
    final File tmp = File(tmpPath);
    await tmp.writeAsString(serialize());
    await tmp.rename(filePath);
  }

  String serialize() {
    return _lines
        .map((line) {
          if (line.key == null) {
            return line.raw ?? '';
          }
          return '${line.key}=${line.value ?? ''}';
        })
        .join('\n');
  }
}
