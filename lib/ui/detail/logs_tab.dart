import 'dart:async';

import 'package:emulator_device_manager/models/log_line.dart';
import 'package:emulator_device_manager/models/logcat_filter.dart';
import 'package:emulator_device_manager/providers/logcat_filter_provider.dart';
import 'package:emulator_device_manager/providers/logcat_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LogsTab extends ConsumerStatefulWidget {
  const LogsTab({super.key, required this.avdName});
  final String avdName;

  @override
  ConsumerState<LogsTab> createState() => _LogsTabState();
}

class _LogsTabState extends ConsumerState<LogsTab> {
  static const Duration _filterDebounce = Duration(milliseconds: 300);

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _tagFilterController = TextEditingController();
  final TextEditingController _pidFilterController = TextEditingController();
  bool _isAtBottom = true;
  int _lastLineCount = 0;
  Timer? _tagDebounce;
  Timer? _pidDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tagDebounce?.cancel();
    _pidDebounce?.cancel();
    _tagFilterController.dispose();
    _pidFilterController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final double delta =
        _scrollController.position.maxScrollExtent - _scrollController.offset;
    final bool atBottom = delta < 24;
    if (atBottom != _isAtBottom) {
      setState(() => _isAtBottom = atBottom);
    }
  }

  void _jumpToLatest() {
    if (!_scrollController.hasClients) {
      return;
    }
    final double target = _scrollController.position.maxScrollExtent;
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  void _snapToLatest() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  void _onTagFilterChanged(String value) {
    _tagDebounce?.cancel();
    _tagDebounce = Timer(_filterDebounce, () {
      if (!mounted) {
        return;
      }
      ref
          .read(logcatFilterProvider(widget.avdName).notifier)
          .setTagFilter(value);
    });
  }

  void _onPidFilterChanged(String value) {
    _pidDebounce?.cancel();
    _pidDebounce = Timer(_filterDebounce, () {
      if (!mounted) {
        return;
      }
      ref
          .read(logcatFilterProvider(widget.avdName).notifier)
          .setPidOrProcess(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final LogcatState logcat = ref.watch(
      logcatNotifierProvider(widget.avdName),
    );
    final List<LogLine> filteredLines = ref.watch(
      filteredLogcatLinesProvider(widget.avdName),
    );
    final LogcatFilter filter = ref.watch(logcatFilterProvider(widget.avdName));
    final LogcatFilterNotifier filterNotifier = ref.read(
      logcatFilterProvider(widget.avdName).notifier,
    );
    final LogcatNotifier notifier = ref.read(
      logcatNotifierProvider(widget.avdName).notifier,
    );
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool darkMode = Theme.of(context).brightness == Brightness.dark;
    final Color consoleBackground = darkMode
        ? const Color(0xFF111111)
        : const Color(0xFF1E1E1E);
    final Color consoleText = darkMode
        ? const Color(0xFFD4D4D4)
        : const Color(0xFFE6E6E6);

    if (filteredLines.length != _lastLineCount) {
      _lastLineCount = filteredLines.length;
      if (_isAtBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _snapToLatest());
      }
    }

    return Column(
      children: <Widget>[
        _LogToolbar(
          state: logcat,
          totalLineCount: logcat.lines.length,
          filteredLineCount: filteredLines.length,
          filterActive: filter.isActive,
          onPauseResume: () =>
              logcat.paused ? notifier.resume() : notifier.pause(),
          onReconnect: notifier.reconnect,
          onClear: notifier.clear,
          onClearFilters: filter.isActive
              ? () {
                  _tagDebounce?.cancel();
                  _pidDebounce?.cancel();
                  _tagFilterController.clear();
                  _pidFilterController.clear();
                  filterNotifier.reset();
                }
              : null,
        ),
        if (logcat.status == LogcatStatus.live ||
            logcat.status == LogcatStatus.paused) ...<Widget>[
          const SizedBox(height: 8),
          _LogFilterToolbar(
            filter: filter,
            tagController: _tagFilterController,
            pidController: _pidFilterController,
            onLevelSelected: filterNotifier.setMinimumLevel,
            onTagChanged: _onTagFilterChanged,
            onPidChanged: _onPidFilterChanged,
            onClearFilters: () {
              _tagDebounce?.cancel();
              _pidDebounce?.cancel();
              _tagFilterController.clear();
              _pidFilterController.clear();
              filterNotifier.reset();
            },
          ),
        ],
        const SizedBox(height: 8),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: consoleBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.45),
                width: 0.6,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: <Widget>[
                  if (filteredLines.isEmpty)
                    Center(
                      child: Text(
                        logcat.lines.isNotEmpty
                            ? 'No lines match filter'
                            : _emptyLabel(logcat.status),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: consoleText.withValues(alpha: 0.7),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(0, 6, 0, 10),
                      itemCount: filteredLines.length,
                      itemBuilder: (_, index) =>
                          _buildLogLine(filteredLines[index], consoleText),
                    ),
                  if (!_isAtBottom && filteredLines.isNotEmpty)
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: FilledButton.tonalIcon(
                        onPressed: _jumpToLatest,
                        icon: const Icon(
                          Icons.arrow_downward_rounded,
                          size: 14,
                        ),
                        label: const Text('Jump to latest'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogLine(LogLine line, Color consoleText) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: line.isParsed
          ? Text.rich(
              TextSpan(
                style: _baseStyle(consoleText),
                children: <TextSpan>[
                  TextSpan(
                    text: '${line.timestamp} ',
                    style: TextStyle(color: consoleText.withValues(alpha: 0.5)),
                  ),
                  TextSpan(
                    text: '${line.pid!.padLeft(5)} ${line.tid!.padLeft(5)} ',
                    style: TextStyle(color: consoleText.withValues(alpha: 0.4)),
                  ),
                  TextSpan(
                    text: '${_levelLetter(line.level!)} ',
                    style: TextStyle(
                      color: _colorForLevel(line.level),
                      fontWeight:
                          line.level == LogLevel.error ||
                              line.level == LogLevel.fatal
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  TextSpan(
                    text: '${line.tag}: ',
                    style: TextStyle(
                      color: _colorForLevel(line.level).withValues(alpha: 0.7),
                    ),
                  ),
                  TextSpan(
                    text: line.message,
                    style: TextStyle(color: _colorForLevel(line.level)),
                  ),
                ],
              ),
            )
          : Text(line.raw, style: _baseStyle(consoleText)),
    );
  }

  String _emptyLabel(LogcatStatus status) {
    switch (status) {
      case LogcatStatus.idle:
        return 'Waiting for emulator...';
      case LogcatStatus.live:
      case LogcatStatus.paused:
        return 'Waiting for logcat...';
      case LogcatStatus.disconnected:
        return 'Start the emulator to capture logs.';
      case LogcatStatus.error:
        return 'Unable to read logs.';
    }
  }
}

class _LogToolbar extends StatelessWidget {
  const _LogToolbar({
    required this.state,
    required this.totalLineCount,
    required this.filteredLineCount,
    required this.filterActive,
    required this.onPauseResume,
    required this.onReconnect,
    required this.onClear,
    this.onClearFilters,
  });

  final LogcatState state;
  final int totalLineCount;
  final int filteredLineCount;
  final bool filterActive;
  final VoidCallback onPauseResume;
  final VoidCallback onReconnect;
  final VoidCallback onClear;
  final VoidCallback? onClearFilters;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final bool disconnected = state.status == LogcatStatus.disconnected;
    final bool canPause = state.status == LogcatStatus.live || state.paused;

    return Row(
      children: <Widget>[
        _StatusChip(status: state.status),
        const SizedBox(width: 8),
        Text(
          filterActive
              ? '${_formatLineCount(filteredLineCount)} of ${_formatLineCount(totalLineCount)} lines'
              : '${_formatLineCount(totalLineCount)} lines',
          style: theme.textTheme.bodySmall?.copyWith(
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
        if (state.error != null) ...<Widget>[
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              state.error!,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
            ),
          ),
        ] else
          const Spacer(),
        const SizedBox(width: 8),
        IconButton(
          onPressed: disconnected
              ? onReconnect
              : (canPause ? onPauseResume : null),
          tooltip: disconnected
              ? 'Reconnect logcat'
              : (state.paused ? 'Resume' : 'Pause'),
          icon: Icon(
            disconnected
                ? Icons.play_arrow_rounded
                : (state.paused
                      ? Icons.play_arrow_rounded
                      : Icons.pause_rounded),
          ),
        ),
        if (filterActive && onClearFilters != null)
          IconButton(
            onPressed: onClearFilters,
            tooltip: 'Clear filters',
            icon: const Icon(Icons.filter_alt_off, size: 20),
          ),
        IconButton(
          onPressed: state.lines.isEmpty ? null : onClear,
          tooltip: 'Clear logs',
          icon: const Icon(Icons.delete_sweep_outlined),
        ),
      ],
    );
  }
}

class _LogFilterToolbar extends StatelessWidget {
  const _LogFilterToolbar({
    required this.filter,
    required this.tagController,
    required this.pidController,
    required this.onLevelSelected,
    required this.onTagChanged,
    required this.onPidChanged,
    required this.onClearFilters,
  });

  final LogcatFilter filter;
  final TextEditingController tagController;
  final TextEditingController pidController;
  final ValueChanged<LogLevel> onLevelSelected;
  final ValueChanged<String> onTagChanged;
  final ValueChanged<String> onPidChanged;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Row(
      children: <Widget>[
        PopupMenuButton<LogLevel>(
          tooltip: 'Minimum level',
          onSelected: onLevelSelected,
          itemBuilder: (BuildContext context) {
            return LogLevel.values
                .map((LogLevel level) {
                  return PopupMenuItem<LogLevel>(
                    value: level,
                    child: Text(_levelLetter(level)),
                  );
                })
                .toList(growable: false);
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: cs.outlineVariant),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.filter_alt_outlined, size: 16),
                  const SizedBox(width: 8),
                  Text('Level: ${_levelLetter(filter.minimumLevel)}'),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 180,
          child: TextField(
            controller: tagController,
            onChanged: onTagChanged,
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Tags (-exclude)',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 120,
          child: TextField(
            controller: pidController,
            onChanged: onPidChanged,
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'PID / process',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (filter.isActive)
          IconButton(
            onPressed: onClearFilters,
            tooltip: 'Clear filters',
            icon: const Icon(Icons.filter_alt_off),
          ),
      ],
    );
  }
}

String _formatLineCount(int value) {
  final String digits = value.toString();
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      out.write(' ');
    }
    out.write(digits[i]);
  }
  return out.toString();
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final LogcatStatus status;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final ({String label, Color fg, Color bg}) style = switch (status) {
      LogcatStatus.live => (
        label: 'Live',
        fg: cs.onPrimaryContainer,
        bg: cs.primaryContainer,
      ),
      LogcatStatus.paused => (
        label: 'Paused',
        fg: cs.onSecondaryContainer,
        bg: cs.secondaryContainer,
      ),
      LogcatStatus.disconnected => (
        label: 'Disconnected',
        fg: cs.onSurfaceVariant,
        bg: cs.surfaceContainerHighest,
      ),
      LogcatStatus.error => (
        label: 'Error',
        fg: cs.onErrorContainer,
        bg: cs.errorContainer,
      ),
      LogcatStatus.idle => (
        label: 'Idle',
        fg: cs.onSurfaceVariant,
        bg: cs.surfaceContainerHigh,
      ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          style.label,
          style: theme.textTheme.labelSmall?.copyWith(color: style.fg),
        ),
      ),
    );
  }
}

TextStyle _baseStyle(Color color) => TextStyle(
  color: color,
  fontSize: 12,
  height: 1.35,
  letterSpacing: 0,
  fontFamily: 'SF Mono',
  fontFamilyFallback: const <String>[
    'Menlo',
    'Monaco',
    'Consolas',
    'Liberation Mono',
    'Courier New',
    'monospace',
  ],
  fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
);

Color _colorForLevel(LogLevel? level) {
  return switch (level) {
    LogLevel.verbose => const Color(0xFF888888),
    LogLevel.debug => const Color(0xFF6897DC),
    LogLevel.info => const Color(0xFF48B685),
    LogLevel.warning => const Color(0xFFD4A843),
    LogLevel.error => const Color(0xFFE05252),
    LogLevel.fatal => const Color(0xFFFF5252),
    null => const Color(0xFFD4D4D4),
  };
}

String _levelLetter(LogLevel level) {
  return switch (level) {
    LogLevel.verbose => 'V',
    LogLevel.debug => 'D',
    LogLevel.info => 'I',
    LogLevel.warning => 'W',
    LogLevel.error => 'E',
    LogLevel.fatal => 'F',
  };
}
