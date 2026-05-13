import 'dart:io';

import 'package:collection/collection.dart';
import 'package:emulator_device_manager/models/avd.dart';
import 'package:emulator_device_manager/models/avd_state.dart';
import 'package:emulator_device_manager/providers/avd_providers.dart';
import 'package:emulator_device_manager/providers/sdk_providers.dart';
import 'package:emulator_device_manager/providers/selection_provider.dart';
import 'package:emulator_device_manager/services/config_ini.dart';
import 'package:emulator_device_manager/ui/create_avd_dialog.dart';
import 'package:emulator_device_manager/ui/detail/avd_detail_pane.dart';
import 'package:emulator_device_manager/ui/master/avd_list_pane.dart';
import 'package:emulator_device_manager/ui/rename_avd_dialog.dart';
import 'package:emulator_device_manager/ui/widgets/app_shortcuts.dart';
import 'package:emulator_device_manager/ui/widgets/confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final sdkAsync = ref.watch(sdkPathsProvider);
    final avdAsync = ref.watch(avdListProvider);
    final selectedName = ref.watch(selectedAvdNameProvider);

    final Avd? selected = avdAsync.valueOrNull
        ?.where((a) => a.name == selectedName)
        .firstOrNull;
    final running =
        avdAsync.valueOrNull
            ?.where((a) => a.state == AvdState.running)
            .length ??
        0;
    final total = avdAsync.valueOrNull?.length ?? 0;

    return NotificationListener<Notification>(
      onNotification: (notification) {
        if (notification is RefreshRequestedNotification) {
          ref.read(avdListProvider.notifier).refresh();
          return true;
        }
        if (notification is CreateRequestedNotification) {
          _create();
          return true;
        }
        if (notification is DeleteRequestedNotification && selected != null) {
          _onMore(selected, AvdMoreAction.delete);
          return true;
        }
        if (notification is PrimaryActionRequestedNotification &&
            selected != null) {
          _onPrimaryAction(selected);
          return true;
        }
        return false;
      },
      child: Scaffold(
        body: Column(
          children: <Widget>[
            _TopToolbar(
              running: running,
              total: total,
              onRefresh: () => ref.read(avdListProvider.notifier).refresh(),
              onOpenSettings: () =>
                  Navigator.of(context).pushNamed('/settings'),
            ),
            Expanded(
              child: sdkAsync.when(
                data: (sdk) {
                  if (sdk == null) {
                    return Center(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 40,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Android SDK not found. Configure SDK path in Settings.',
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: () => Navigator.of(
                                  context,
                                ).pushNamed('/settings'),
                                child: const Text('Set SDK path'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  return Row(
                    children: <Widget>[
                      SizedBox(
                        width: 380,
                        child: ColoredBox(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          child: AvdListPane(
                            query: _query,
                            onQueryChanged: (v) => setState(() => _query = v),
                            onCreate: _create,
                            onStopAll: _stopAll,
                            onPrimaryAction: _onPrimaryAction,
                          ),
                        ),
                      ),
                      const VerticalDivider(width: 1, thickness: 0.6),
                      Expanded(
                        child: ColoredBox(
                          color: Theme.of(context).colorScheme.surface,
                          child: AvdDetailPane(
                            avd: selected,
                            onPrimaryAction: _onPrimaryAction,
                            onMoreAction: _onMore,
                            onSaveConfig: _saveConfig,
                            onStopAndSaveConfig: _stopAndSaveConfig,
                          ),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('SDK error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onPrimaryAction(Avd avd) async {
    final sdk = await ref.read(sdkPathsProvider.future);
    if (sdk == null) {
      return;
    }
    final emulator = ref.read(emulatorServiceProvider);
    try {
      if (avd.state == AvdState.running ||
          avd.state == AvdState.booting ||
          avd.state == AvdState.starting) {
        await emulator.stop(adbPath: sdk.adb, avd: avd);
      } else {
        await emulator.launch(
          emulatorPath: sdk.emulator,
          adbPath: sdk.adb,
          avdName: avd.name,
        );
      }
      await ref.read(avdListProvider.notifier).refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _onMore(Avd avd, AvdMoreAction action) async {
    final sdk = await ref.read(sdkPathsProvider.future);
    if (sdk == null) {
      return;
    }
    if (!mounted) return;
    final avdService = ref.read(avdServiceProvider);
    switch (action) {
      case AvdMoreAction.coldBoot:
        await ref
            .read(emulatorServiceProvider)
            .launch(
              emulatorPath: sdk.emulator,
              adbPath: sdk.adb,
              avdName: avd.name,
              coldBoot: true,
            );
      case AvdMoreAction.wipeData:
        if (!context.mounted) return;
        final ok = await showConfirmDialog(
          context: context,
          title: 'Wipe data',
          message: 'Delete userdata and cache files for ${avd.name}?',
          confirmLabel: 'Wipe',
        );
        if (!mounted) return;
        if (ok) {
          await avdService.wipeData(avd.avdPath);
        }
      case AvdMoreAction.rename:
        if (!context.mounted) return;
        final next = await showRenameAvdDialog(context, avd.name);
        if (!mounted) return;
        if (next != null && next.isNotEmpty && next != avd.name) {
          await avdService.renameAvd(
            avdManagerPath: sdk.avdmanager,
            oldName: avd.name,
            newName: next,
          );
          ref.read(selectedAvdNameProvider.notifier).state = next;
        }
      case AvdMoreAction.showInFinder:
        await Process.run('open', <String>['-R', avd.avdPath]);
      case AvdMoreAction.delete:
        if (!context.mounted) return;
        final ok = await showConfirmDialog(
          context: context,
          title: 'Delete ${avd.name}',
          message: 'This action is irreversible.',
          confirmLabel: 'Delete',
        );
        if (!mounted) return;
        if (ok) {
          await avdService.deleteAvd(
            avdManagerPath: sdk.avdmanager,
            name: avd.name,
          );
          ref.read(selectedAvdNameProvider.notifier).state = null;
        }
      case AvdMoreAction.showLogs:
        return;
      case AvdMoreAction.coldRestart:
        await ref
            .read(emulatorServiceProvider)
            .stop(adbPath: sdk.adb, avd: avd);
        await ref
            .read(emulatorServiceProvider)
            .launch(
              emulatorPath: sdk.emulator,
              adbPath: sdk.adb,
              avdName: avd.name,
              coldBoot: true,
            );
    }
    await ref.read(avdListProvider.notifier).refresh();
  }

  Future<void> _saveConfig(Avd avd, Map<String, String> updates) async {
    final ConfigIni ini = await ConfigIni.fromFile('${avd.avdPath}/config.ini');
    for (final entry in updates.entries) {
      ini.setValue(entry.key, entry.value);
    }
    await ini.saveAtomic('${avd.avdPath}/config.ini');
    await ref.read(avdListProvider.notifier).refresh();
  }

  Future<void> _stopAndSaveConfig(Avd avd, Map<String, String> updates) async {
    final sdk = await ref.read(sdkPathsProvider.future);
    if (sdk == null) {
      return;
    }
    await ref.read(emulatorServiceProvider).stop(adbPath: sdk.adb, avd: avd);
    await Future<void>.delayed(const Duration(seconds: 2));
    await _saveConfig(avd, updates);
  }

  Future<void> _create() async {
    if (!mounted) return;
    final sdk = await ref.read(sdkPathsProvider.future);
    if (sdk == null) {
      return;
    }
    if (!context.mounted) return;
    // ignore: use_build_context_synchronously
    final request = await showCreateAvdDialog(context, ref);
    if (request == null) {
      return;
    }
    await ref
        .read(avdServiceProvider)
        .createAvd(
          avdManagerPath: sdk.avdmanager,
          name: request.name,
          packageId: request.image.packageId,
          deviceId: request.device.id,
        );
    ref.read(selectedAvdNameProvider.notifier).state = request.name;
    await ref.read(avdListProvider.notifier).refresh();
  }

  Future<void> _stopAll() async {
    final sdk = await ref.read(sdkPathsProvider.future);
    if (sdk == null) {
      return;
    }
    final avds = ref.read(avdListProvider).valueOrNull ?? const <Avd>[];
    await ref.read(emulatorServiceProvider).stopAll(sdk.adb, avds);
    await ref.read(avdListProvider.notifier).refresh();
  }
}

class _TopToolbar extends StatelessWidget {
  const _TopToolbar({
    required this.running,
    required this.total,
    required this.onRefresh,
    required this.onOpenSettings,
  });

  final int running;
  final int total;
  final VoidCallback onRefresh;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return DragToMoveArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool compact = constraints.maxWidth < 820;
          final double leadingInset = Platform.isMacOS ? 92 : 14;
          final double verticalNudge = Platform.isMacOS ? 0 : 0;
          return Container(
            height: 34,
            padding: EdgeInsets.only(
              // Reserve room for macOS traffic-light controls in hidden title bar.
              left: leadingInset,
              right: 12,
            ),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              border: Border(
                bottom: BorderSide(color: cs.outlineVariant, width: 0.6),
              ),
            ),
            child: Transform.translate(
              offset: Offset(0, verticalNudge),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            'AVD Pilot',
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                        if (!compact) ...[
                          const SizedBox(width: 8),
                          Row(
                            children: <Widget>[
                              if (running > 0)
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: cs.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              if (running > 0) const SizedBox(width: 6),
                              Text(
                                '$running running / $total total',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontFeatures: const <FontFeature>[
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    style: IconButton.styleFrom(
                      minimumSize: const Size(26, 26),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh, size: 18),
                    tooltip: 'Refresh',
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    style: IconButton.styleFrom(
                      minimumSize: const Size(26, 26),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: onOpenSettings,
                    icon: const Icon(Icons.settings, size: 18),
                    tooltip: 'Settings',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
