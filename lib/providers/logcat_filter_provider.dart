import 'package:emulator_device_manager/models/log_line.dart';
import 'package:emulator_device_manager/models/logcat_filter.dart';
import 'package:emulator_device_manager/providers/logcat_provider.dart';
import 'package:emulator_device_manager/providers/process_resolver_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final logcatFilterProvider =
    StateNotifierProvider.family<LogcatFilterNotifier, LogcatFilter, String>(
      (ref, avdName) => LogcatFilterNotifier(),
    );

class LogcatFilterNotifier extends StateNotifier<LogcatFilter> {
  LogcatFilterNotifier() : super(const LogcatFilter());

  void setMinimumLevel(LogLevel level) {
    state = state.copyWith(minimumLevel: level);
  }

  void setTagFilter(String rawInput) {
    final Iterable<String> tokens = rawInput
        .split(',')
        .map((String t) => t.trim())
        .where((String t) => t.isNotEmpty);
    final Set<String> include = <String>{};
    final Set<String> exclude = <String>{};
    for (final String token in tokens) {
      if (token.startsWith('-')) {
        exclude.add(token.substring(1));
      } else {
        include.add(token);
      }
    }
    state = state.copyWith(includeTags: include, excludeTags: exclude);
  }

  void setPidOrProcess(String value) {
    state = state.copyWith(pidOrProcess: value.trim());
  }

  void reset() {
    state = const LogcatFilter();
  }
}

final filteredLogcatLinesProvider = Provider.family<List<LogLine>, String>((
  ref,
  avdName,
) {
  final LogcatState logcatState = ref.watch(logcatNotifierProvider(avdName));
  final LogcatFilter filter = ref.watch(logcatFilterProvider(avdName));
  final Map<int, String> processMap = ref.watch(processMapProvider(avdName));

  if (!filter.isActive) {
    return logcatState.lines;
  }

  return logcatState.lines
      .where((LogLine line) {
        if (!line.isParsed) {
          return true;
        }
        final int? pid = int.tryParse(line.pid ?? '');
        final String? processName = pid != null ? processMap[pid] : null;
        return filter.matches(line, processName: processName);
      })
      .toList(growable: false);
});
