import 'package:collection/collection.dart';
import 'package:emulator_device_manager/models/log_line.dart';

class LogcatFilter {
  const LogcatFilter({
    this.minimumLevel = LogLevel.verbose,
    this.includeTags = const <String>{},
    this.excludeTags = const <String>{},
    this.pidOrProcess = '',
  });

  final LogLevel minimumLevel;
  final Set<String> includeTags;
  final Set<String> excludeTags;
  final String pidOrProcess;

  bool get isActive =>
      minimumLevel != LogLevel.verbose ||
      includeTags.isNotEmpty ||
      excludeTags.isNotEmpty ||
      pidOrProcess.isNotEmpty;

  bool matches(LogLine entry, {String? processName}) {
    if (!entry.isParsed) {
      return true;
    }
    if (entry.level!.index < minimumLevel.index) {
      return false;
    }

    if (includeTags.isNotEmpty) {
      final String tagLower = entry.tag!.toLowerCase();
      if (!includeTags.any((String t) => t.toLowerCase() == tagLower)) {
        return false;
      }
    }

    if (excludeTags.isNotEmpty) {
      final String tagLower = entry.tag!.toLowerCase();
      if (excludeTags.any((String t) => t.toLowerCase() == tagLower)) {
        return false;
      }
    }

    if (pidOrProcess.isNotEmpty) {
      final int? pidInt = int.tryParse(pidOrProcess);
      if (pidInt != null) {
        final int? entryPid = int.tryParse(entry.pid ?? '');
        if (entryPid != pidInt) {
          return false;
        }
      } else {
        final String query = pidOrProcess.toLowerCase();
        final bool nameMatches =
            processName != null && processName.toLowerCase().contains(query);
        final bool tagMatches =
            entry.tag != null && entry.tag!.toLowerCase().contains(query);
        if (!nameMatches && !tagMatches) {
          return false;
        }
      }
    }
    return true;
  }

  LogcatFilter copyWith({
    LogLevel? minimumLevel,
    Set<String>? includeTags,
    Set<String>? excludeTags,
    String? pidOrProcess,
  }) {
    return LogcatFilter(
      minimumLevel: minimumLevel ?? this.minimumLevel,
      includeTags: includeTags ?? this.includeTags,
      excludeTags: excludeTags ?? this.excludeTags,
      pidOrProcess: pidOrProcess ?? this.pidOrProcess,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LogcatFilter &&
          minimumLevel == other.minimumLevel &&
          const SetEquality<String>().equals(includeTags, other.includeTags) &&
          const SetEquality<String>().equals(excludeTags, other.excludeTags) &&
          pidOrProcess == other.pidOrProcess;

  @override
  int get hashCode => Object.hash(
    minimumLevel,
    const SetEquality<String>().hash(includeTags),
    const SetEquality<String>().hash(excludeTags),
    pidOrProcess,
  );
}
