import 'package:emulator_device_manager/models/log_line.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses each log level from threadtime lines', () {
    final Map<String, LogLevel> levelByLetter = <String, LogLevel>{
      'V': LogLevel.verbose,
      'D': LogLevel.debug,
      'I': LogLevel.info,
      'W': LogLevel.warning,
      'E': LogLevel.error,
      'F': LogLevel.fatal,
    };

    for (final MapEntry<String, LogLevel> entry in levelByLetter.entries) {
      final String raw =
          '05-13 12:34:56.789  1234  5678 ${entry.key} MyTag: sample ${entry.key} message';
      final LogLine line = LogLine.parse(raw);

      expect(line.raw, raw);
      expect(line.isParsed, isTrue);
      expect(line.timestamp, '05-13 12:34:56.789');
      expect(line.pid, '1234');
      expect(line.tid, '5678');
      expect(line.level, entry.value);
      expect(line.tag, 'MyTag');
      expect(line.message, 'sample ${entry.key} message');
    }
  });

  test('parses tag containing dots', () {
    const String raw =
        '05-13 12:34:56.789  1024  1024 E System.err: java.lang.IllegalStateException';
    final LogLine line = LogLine.parse(raw);

    expect(line.raw, raw);
    expect(line.isParsed, isTrue);
    expect(line.tag, 'System.err');
    expect(line.level, LogLevel.error);
    expect(line.message, 'java.lang.IllegalStateException');
  });

  test('parses message containing colons', () {
    const String raw =
        '05-13 12:34:56.789  2222  3333 I Network: URL: http://example.com:8080';
    final LogLine line = LogLine.parse(raw);

    expect(line.raw, raw);
    expect(line.isParsed, isTrue);
    expect(line.tag, 'Network');
    expect(line.message, 'URL: http://example.com:8080');
  });

  test('parses wide five digit pid values', () {
    const String raw =
        '05-13 12:34:56.789 12345  6789 D Worker: five digit pid works';
    final LogLine line = LogLine.parse(raw);

    expect(line.raw, raw);
    expect(line.isParsed, isTrue);
    expect(line.pid, '12345');
    expect(line.tid, '6789');
    expect(line.level, LogLevel.debug);
    expect(line.tag, 'Worker');
    expect(line.message, 'five digit pid works');
  });

  test('returns raw-only object for unparseable lines', () {
    const List<String> rawLines = <String>[
      '--------- beginning of main',
      '',
      '[adb] error',
    ];

    for (final String raw in rawLines) {
      final LogLine line = LogLine.parse(raw);
      expect(line.raw, raw);
      expect(line.isParsed, isFalse);
      expect(line.timestamp, isNull);
      expect(line.pid, isNull);
      expect(line.tid, isNull);
      expect(line.level, isNull);
      expect(line.tag, isNull);
      expect(line.message, isNull);
    }
  });
}
