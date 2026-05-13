import 'package:emulator_device_manager/models/log_line.dart';
import 'package:emulator_device_manager/models/logcat_filter.dart';
import 'package:flutter_test/flutter_test.dart';

LogLine _parsedLine({
  required String level,
  required String pid,
  required String tag,
  String message = 'message',
}) {
  return LogLine.parse('05-13 12:00:00.000 $pid 456 $level $tag: $message');
}

void main() {
  test('matches respects minimum level', () {
    const LogcatFilter filter = LogcatFilter(minimumLevel: LogLevel.warning);
    final LogLine debugLine = _parsedLine(level: 'D', pid: '100', tag: 'TagA');
    final LogLine errorLine = _parsedLine(level: 'E', pid: '101', tag: 'TagA');

    expect(filter.matches(debugLine), isFalse);
    expect(filter.matches(errorLine), isTrue);
  });

  test('include-tags allowlist', () {
    const LogcatFilter filter = LogcatFilter(includeTags: <String>{'UiTag'});
    final LogLine matching = _parsedLine(level: 'I', pid: '100', tag: 'uitag');
    final LogLine nonMatching = _parsedLine(
      level: 'I',
      pid: '100',
      tag: 'Other',
    );

    expect(filter.matches(matching), isTrue);
    expect(filter.matches(nonMatching), isFalse);
  });

  test('exclude-tags denylist', () {
    const LogcatFilter filter = LogcatFilter(excludeTags: <String>{'NoiseTag'});
    final LogLine denied = _parsedLine(level: 'I', pid: '100', tag: 'noisetag');
    final LogLine allowed = _parsedLine(level: 'I', pid: '100', tag: 'MainTag');

    expect(filter.matches(denied), isFalse);
    expect(filter.matches(allowed), isTrue);
  });

  test('exclude wins over include', () {
    const LogcatFilter filter = LogcatFilter(
      includeTags: <String>{'Network'},
      excludeTags: <String>{'Network'},
    );
    final LogLine line = _parsedLine(level: 'I', pid: '100', tag: 'network');

    expect(filter.matches(line), isFalse);
  });

  test('PID integer match', () {
    const LogcatFilter filter = LogcatFilter(pidOrProcess: '4242');
    final LogLine samePid = _parsedLine(level: 'I', pid: '4242', tag: 'TagA');
    final LogLine otherPid = _parsedLine(level: 'I', pid: '4243', tag: 'TagA');

    expect(filter.matches(samePid), isTrue);
    expect(filter.matches(otherPid), isFalse);
  });

  test('PID process name substring match', () {
    const LogcatFilter filter = LogcatFilter(pidOrProcess: 'flutter');
    final LogLine line = _parsedLine(level: 'I', pid: '500', tag: 'TagA');

    expect(
      filter.matches(line, processName: 'com.example.flutter.app'),
      isTrue,
    );
    expect(filter.matches(line, processName: 'com.example.other'), isFalse);
  });

  test('Empty filter matches everything', () {
    const LogcatFilter filter = LogcatFilter();
    final LogLine line = _parsedLine(level: 'V', pid: '10', tag: 'TagA');

    expect(filter.matches(line), isTrue);
  });

  test('copyWith and equality', () {
    const LogcatFilter filter = LogcatFilter(
      minimumLevel: LogLevel.info,
      includeTags: <String>{'TagA'},
      excludeTags: <String>{'TagB'},
      pidOrProcess: '100',
    );

    final LogcatFilter copy = filter.copyWith();
    final LogcatFilter updated = filter.copyWith(pidOrProcess: '200');

    expect(copy, equals(filter));
    expect(updated, isNot(equals(filter)));
    expect(updated.pidOrProcess, '200');
  });
}
