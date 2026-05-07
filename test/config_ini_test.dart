import 'package:emulator_device_manager/services/config_ini.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('config parser preserves comments and order', () {
    const input = '''
# comment
hw.ramSize=4096
disk.dataPartition.size=6G
sdcard.size=8000M
''';
    final cfg = ConfigIni.parse(input);
    expect(cfg.getValue('hw.ramSize'), '4096');
    cfg.setValue('hw.gpu.mode', 'auto');
    final output = cfg.serialize();
    expect(output.contains('# comment'), true);
    expect(
      output.indexOf('hw.ramSize'),
      lessThan(output.indexOf('disk.dataPartition.size')),
    );
  });

  test('size helpers parse and write units', () {
    final cfg = ConfigIni.parse(
      'disk.dataPartition.size=6442450944\nsdcard.size=8000M',
    );
    final disk = cfg.getSize('disk.dataPartition.size');
    final sd = cfg.getSize('sdcard.size');
    expect(disk?.unit, SizeUnit.b);
    expect(sd?.unit, SizeUnit.m);
    cfg.setSize('sdcard.size', const SizeValue(value: 6, unit: SizeUnit.g));
    expect(cfg.getValue('sdcard.size'), '6G');
  });
}
