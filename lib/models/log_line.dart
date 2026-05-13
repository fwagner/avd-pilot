enum LogLevel { verbose, debug, info, warning, error, fatal }

class LogLine {
  const LogLine._({
    required this.raw,
    this.timestamp,
    this.pid,
    this.tid,
    this.level,
    this.tag,
    this.message,
  });

  final String raw;
  final String? timestamp;
  final String? pid;
  final String? tid;
  final LogLevel? level;
  final String? tag;
  final String? message;

  bool get isParsed => level != null;

  static final RegExp _pattern = RegExp(
    r'^(\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\.\d{3})\s+(\d+)\s+(\d+)\s+([VDIWEF])\s+(.+?)\s*:\s(.*)$',
  );

  static const Map<String, LogLevel> _levelMap = {
    'V': LogLevel.verbose,
    'D': LogLevel.debug,
    'I': LogLevel.info,
    'W': LogLevel.warning,
    'E': LogLevel.error,
    'F': LogLevel.fatal,
  };

  factory LogLine.parse(String raw) {
    final RegExpMatch? match = _pattern.firstMatch(raw);
    if (match == null) {
      return LogLine._(raw: raw);
    }
    return LogLine._(
      raw: raw,
      timestamp: match.group(1),
      pid: match.group(2),
      tid: match.group(3),
      level: _levelMap[match.group(4)],
      tag: match.group(5),
      message: match.group(6),
    );
  }
}
