import 'package:emulator_device_manager/models/log_line.dart';
import 'package:emulator_device_manager/providers/logcat_filter_provider.dart';
import 'package:emulator_device_manager/providers/logcat_provider.dart';
import 'package:emulator_device_manager/providers/process_resolver_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLogcatNotifier extends StateNotifier<LogcatState>
    implements LogcatNotifier {
  _FakeLogcatNotifier(super.initialState);

  void setLines(List<LogLine> lines) {
    state = state.copyWith(lines: lines);
  }

  @override
  void clear() {}

  @override
  void pause() {}

  @override
  Future<void> reconnect() async {}

  @override
  void resume() {}
}

class _FakeProcessMapNotifier extends StateNotifier<Map<int, String>>
    implements ProcessMapNotifier {
  _FakeProcessMapNotifier(super.initialState);

  void setProcessMap(Map<int, String> map) {
    state = map;
  }
}

LogLine _parsedLine({
  required String level,
  required String pid,
  required String tag,
  String message = 'message',
}) {
  return LogLine.parse('05-13 12:00:00.000 $pid 456 $level $tag: $message');
}

void main() {
  const String avdName = 'Pixel_API_35';

  ProviderContainer containerWithOverrides({
    required _FakeLogcatNotifier logcatNotifier,
    required _FakeProcessMapNotifier processMapNotifier,
  }) {
    return ProviderContainer(
      overrides: <Override>[
        logcatNotifierProvider(avdName).overrideWith((ref) => logcatNotifier),
        processMapProvider(avdName).overrideWith((ref) => processMapNotifier),
      ],
    );
  }

  test('Returns all lines when no filter', () {
    final _FakeLogcatNotifier logcatNotifier = _FakeLogcatNotifier(
      LogcatState(
        lines: <LogLine>[
          _parsedLine(level: 'D', pid: '100', tag: 'TagA'),
          _parsedLine(level: 'E', pid: '101', tag: 'TagB'),
        ],
      ),
    );
    final _FakeProcessMapNotifier processMapNotifier = _FakeProcessMapNotifier(
      <int, String>{},
    );
    final ProviderContainer container = containerWithOverrides(
      logcatNotifier: logcatNotifier,
      processMapNotifier: processMapNotifier,
    );
    addTearDown(container.dispose);

    final List<LogLine> filtered = container.read(
      filteredLogcatLinesProvider(avdName),
    );

    expect(filtered.length, 2);
  });

  test('Returns subset with level filter', () {
    final _FakeLogcatNotifier logcatNotifier = _FakeLogcatNotifier(
      LogcatState(
        lines: <LogLine>[
          _parsedLine(level: 'D', pid: '100', tag: 'TagA'),
          _parsedLine(level: 'W', pid: '101', tag: 'TagA'),
        ],
      ),
    );
    final _FakeProcessMapNotifier processMapNotifier = _FakeProcessMapNotifier(
      <int, String>{},
    );
    final ProviderContainer container = containerWithOverrides(
      logcatNotifier: logcatNotifier,
      processMapNotifier: processMapNotifier,
    );
    addTearDown(container.dispose);

    container
        .read(logcatFilterProvider(avdName).notifier)
        .setMinimumLevel(LogLevel.warning);
    final List<LogLine> filtered = container.read(
      filteredLogcatLinesProvider(avdName),
    );

    expect(filtered.length, 1);
    expect(filtered.first.level, LogLevel.warning);
  });

  test('Returns subset with tag filter', () {
    final _FakeLogcatNotifier logcatNotifier = _FakeLogcatNotifier(
      LogcatState(
        lines: <LogLine>[
          _parsedLine(level: 'I', pid: '100', tag: 'UiTag'),
          _parsedLine(level: 'I', pid: '101', tag: 'NetTag'),
        ],
      ),
    );
    final _FakeProcessMapNotifier processMapNotifier = _FakeProcessMapNotifier(
      <int, String>{},
    );
    final ProviderContainer container = containerWithOverrides(
      logcatNotifier: logcatNotifier,
      processMapNotifier: processMapNotifier,
    );
    addTearDown(container.dispose);

    container
        .read(logcatFilterProvider(avdName).notifier)
        .setTagFilter('UiTag');
    final List<LogLine> filtered = container.read(
      filteredLogcatLinesProvider(avdName),
    );

    expect(filtered.length, 1);
    expect(filtered.first.tag, 'UiTag');
  });

  test('Unparseable lines always included', () {
    final _FakeLogcatNotifier logcatNotifier = _FakeLogcatNotifier(
      LogcatState(
        lines: <LogLine>[
          LogLine.parse('plain-text-line'),
          _parsedLine(level: 'D', pid: '100', tag: 'UiTag'),
        ],
      ),
    );
    final _FakeProcessMapNotifier processMapNotifier = _FakeProcessMapNotifier(
      <int, String>{},
    );
    final ProviderContainer container = containerWithOverrides(
      logcatNotifier: logcatNotifier,
      processMapNotifier: processMapNotifier,
    );
    addTearDown(container.dispose);

    container
        .read(logcatFilterProvider(avdName).notifier)
        .setMinimumLevel(LogLevel.error);
    final List<LogLine> filtered = container.read(
      filteredLogcatLinesProvider(avdName),
    );

    expect(filtered.length, 1);
    expect(filtered.first.isParsed, isFalse);
  });

  test('Reacts to filter changes', () {
    final _FakeLogcatNotifier logcatNotifier = _FakeLogcatNotifier(
      LogcatState(
        lines: <LogLine>[
          _parsedLine(level: 'I', pid: '100', tag: 'UiTag'),
          _parsedLine(level: 'I', pid: '200', tag: 'OtherTag'),
        ],
      ),
    );
    final _FakeProcessMapNotifier processMapNotifier = _FakeProcessMapNotifier(
      <int, String>{100: 'com.example.app'},
    );
    final ProviderContainer container = containerWithOverrides(
      logcatNotifier: logcatNotifier,
      processMapNotifier: processMapNotifier,
    );
    addTearDown(container.dispose);

    container
        .read(logcatFilterProvider(avdName).notifier)
        .setPidOrProcess('example');
    List<LogLine> filtered = container.read(
      filteredLogcatLinesProvider(avdName),
    );
    expect(filtered.length, 1);
    expect(filtered.first.pid, '100');

    container
        .read(logcatFilterProvider(avdName).notifier)
        .setTagFilter('OtherTag');
    filtered = container.read(filteredLogcatLinesProvider(avdName));
    expect(filtered.length, 0);
  });

  test('Reacts to new lines', () {
    final _FakeLogcatNotifier logcatNotifier = _FakeLogcatNotifier(
      LogcatState(lines: <LogLine>[]),
    );
    final _FakeProcessMapNotifier processMapNotifier = _FakeProcessMapNotifier(
      <int, String>{},
    );
    final ProviderContainer container = containerWithOverrides(
      logcatNotifier: logcatNotifier,
      processMapNotifier: processMapNotifier,
    );
    addTearDown(container.dispose);

    container
        .read(logcatFilterProvider(avdName).notifier)
        .setMinimumLevel(LogLevel.error);
    expect(container.read(filteredLogcatLinesProvider(avdName)), isEmpty);

    logcatNotifier.setLines(<LogLine>[
      _parsedLine(level: 'D', pid: '100', tag: 'TagA'),
      _parsedLine(level: 'E', pid: '100', tag: 'TagA'),
    ]);
    final List<LogLine> filtered = container.read(
      filteredLogcatLinesProvider(avdName),
    );

    expect(filtered.length, 1);
    expect(filtered.first.level, LogLevel.error);
  });
}
