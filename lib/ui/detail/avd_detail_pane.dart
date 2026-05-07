import 'package:emulator_device_manager/models/avd.dart';
import 'package:emulator_device_manager/models/avd_state.dart';
import 'package:emulator_device_manager/ui/detail/logs_tab.dart';
import 'package:emulator_device_manager/ui/detail/overview_tab.dart';
import 'package:emulator_device_manager/ui/detail/raw_config_tab.dart';
import 'package:emulator_device_manager/ui/widgets/status_pill.dart';
import 'package:flutter/material.dart';

enum AvdMoreAction {
  coldBoot,
  wipeData,
  rename,
  showInFinder,
  delete,
  showLogs,
  coldRestart,
}

class AvdDetailPane extends StatefulWidget {
  const AvdDetailPane({
    super.key,
    required this.avd,
    required this.onPrimaryAction,
    required this.onMoreAction,
    required this.onSaveConfig,
    required this.onStopAndSaveConfig,
  });

  final Avd? avd;
  final Future<void> Function(Avd avd) onPrimaryAction;
  final Future<void> Function(Avd avd, AvdMoreAction action) onMoreAction;
  final Future<void> Function(Avd avd, Map<String, String> updates)
  onSaveConfig;
  final Future<void> Function(Avd avd, Map<String, String> updates)
  onStopAndSaveConfig;

  @override
  State<AvdDetailPane> createState() => _AvdDetailPaneState();
}

class _AvdDetailPaneState extends State<AvdDetailPane> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final Avd? avd = widget.avd;
    final ColorScheme cs = Theme.of(context).colorScheme;
    if (avd == null) {
      return Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.smartphone_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Select a device',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                const Text('Select an AVD on the left, or create a new one.'),
              ],
            ),
          ),
        ),
      );
    }

    final String primaryLabel = switch (avd.state) {
      AvdState.starting => 'Cancel',
      AvdState.booting || AvdState.running => 'Stop',
      _ => 'Launch',
    };
    final IconData primaryIcon = switch (avd.state) {
      AvdState.starting => Icons.close_rounded,
      AvdState.booting || AvdState.running => Icons.stop_rounded,
      _ => Icons.play_arrow_rounded,
    };
    final bool disableAll = avd.state == AvdState.stopping;
    final String summaryLine = _buildSummaryLine(avd);
    final String summaryTooltip = _buildSummaryTooltip(avd);

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: <Widget>[
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.smartphone_rounded,
                      size: 22,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          avd.name,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Tooltip(
                          message: summaryTooltip,
                          waitDuration: const Duration(milliseconds: 250),
                          child: Text(
                            summaryLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ),
                        const SizedBox(height: 8),
                        StatusPill(state: avd.state),
                      ],
                    ),
                  ),
                  if (primaryLabel == 'Stop')
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        foregroundColor: cs.onErrorContainer,
                        backgroundColor: cs.errorContainer,
                      ),
                      onPressed: disableAll
                          ? null
                          : () => widget.onPrimaryAction(avd),
                      icon: Icon(primaryIcon, size: 16),
                      label: Text(primaryLabel),
                    )
                  else
                    FilledButton.icon(
                      onPressed: disableAll
                          ? null
                          : () => widget.onPrimaryAction(avd),
                      icon: Icon(primaryIcon, size: 16),
                      label: Text(primaryLabel),
                    ),
                  const SizedBox(width: 8),
                  PopupMenuButton<AvdMoreAction>(
                    enabled: !disableAll,
                    onSelected: (action) {
                      if (action == AvdMoreAction.showLogs) {
                        setState(() => _tabIndex = 1);
                        return;
                      }
                      widget.onMoreAction(avd, action);
                    },
                    itemBuilder: (_) => <PopupMenuEntry<AvdMoreAction>>[
                      if (avd.state == AvdState.stopped)
                        const PopupMenuItem(
                          value: AvdMoreAction.coldBoot,
                          child: Text('Cold boot'),
                        ),
                      if (avd.state == AvdState.stopped)
                        const PopupMenuItem(
                          value: AvdMoreAction.wipeData,
                          child: Text('Wipe data'),
                        ),
                      if (avd.state == AvdState.stopped)
                        const PopupMenuItem(
                          value: AvdMoreAction.rename,
                          child: Text('Rename'),
                        ),
                      if (avd.state == AvdState.running)
                        const PopupMenuItem(
                          value: AvdMoreAction.coldRestart,
                          child: Text('Cold restart'),
                        ),
                      const PopupMenuItem(
                        value: AvdMoreAction.showInFinder,
                        child: Text('Show in Finder'),
                      ),
                      if (avd.state == AvdState.stopped)
                        const PopupMenuItem(
                          value: AvdMoreAction.delete,
                          child: Text('Delete'),
                        ),
                      const PopupMenuItem(
                        value: AvdMoreAction.showLogs,
                        child: Text('Show logs'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: const <ButtonSegment<int>>[
                    ButtonSegment<int>(value: 0, label: Text('Overview')),
                    ButtonSegment<int>(value: 1, label: Text('Logs')),
                    ButtonSegment<int>(value: 2, label: Text('Raw config')),
                  ],
                  selected: <int>{_tabIndex},
                  onSelectionChanged: (selection) {
                    setState(() => _tabIndex = selection.first);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: switch (_tabIndex) {
              0 => Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: OverviewTab(
                    avd: avd,
                    onSave: (updates) => widget.onSaveConfig(avd, updates),
                    onStopAndSave: (updates) =>
                        widget.onStopAndSaveConfig(avd, updates),
                  ),
                ),
              ),
              1 => LogsTab(avdName: avd.name),
              _ => Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: RawConfigTab(
                    config: avd.config,
                    editable: avd.state == AvdState.stopped,
                    onSave: (updates) => widget.onSaveConfig(avd, updates),
                  ),
                ),
              ),
            },
          ),
        ],
      ),
    );
  }

  String _buildSummaryLine(Avd avd) {
    final List<String> parts = <String>[
      if (avd.deviceName != null && avd.deviceName!.trim().isNotEmpty)
        avd.deviceName!.trim(),
      ..._targetSummaryParts(avd.target),
      if (avd.abi != null && avd.abi!.trim().isNotEmpty) avd.abi!.trim(),
    ];
    if (parts.isEmpty) {
      return 'Device details unavailable';
    }
    return parts.join(' \u00b7 ');
  }

  String _buildSummaryTooltip(Avd avd) {
    final String summary = _buildSummaryLine(avd);
    if (avd.target == null || avd.target!.trim().isEmpty) {
      return summary;
    }
    return '$summary\n${avd.target!.trim()}';
  }

  List<String> _targetSummaryParts(String? target) {
    if (target == null || target.trim().isEmpty) {
      return <String>[];
    }
    final String normalized = target.trim();
    final RegExpMatch? apiMatch = RegExp(
      r'android-(\d+)',
    ).firstMatch(normalized);
    final String? apiLevel = apiMatch?.group(1);
    final List<String> segments = normalized.split('/');
    final String? variant = segments.length >= 3 ? segments[2] : null;
    final List<String> parts = <String>[
      if (apiLevel != null) 'API $apiLevel',
      if (variant != null && variant.isNotEmpty)
        _humanizeSegment(variant, capitalizeWords: true),
    ];
    return parts;
  }

  String _humanizeSegment(String input, {bool capitalizeWords = false}) {
    final String spaced = input.replaceAll('_', ' ');
    if (!capitalizeWords) {
      return spaced;
    }
    return spaced
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}
