import 'package:emulator_device_manager/models/avd.dart';
import 'package:emulator_device_manager/providers/avd_providers.dart';
import 'package:emulator_device_manager/providers/selection_provider.dart';
import 'package:emulator_device_manager/ui/master/avd_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AvdListPane extends ConsumerWidget {
  const AvdListPane({
    super.key,
    required this.query,
    required this.onQueryChanged,
    required this.onCreate,
    required this.onStopAll,
    required this.onPrimaryAction,
  });

  final String query;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onCreate;
  final VoidCallback onStopAll;
  final Future<void> Function(Avd avd) onPrimaryAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avdsAsync = ref.watch(avdListProvider);
    final selected = ref.watch(selectedAvdNameProvider);
    final int totalDevices = avdsAsync.valueOrNull?.length ?? 0;
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            children: <Widget>[
              Text(
                'Devices',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '$totalDevices',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, size: 18),
                      hintText: 'Search AVDs',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide(
                          color: cs.outlineVariant.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide(
                          color: cs.outlineVariant.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide(color: cs.primary, width: 1),
                      ),
                    ),
                    onChanged: onQueryChanged,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                tooltip: 'Create',
              ),
              const SizedBox(width: 4),
              IconButton.filledTonal(
                onPressed: onStopAll,
                icon: const Icon(Icons.stop_circle_outlined),
                tooltip: 'Stop all',
              ),
            ],
          ),
        ),
        Expanded(
          child: avdsAsync.when(
            data: (items) {
              final List<Avd> filtered = items
                  .where(
                    (a) =>
                        a.name.toLowerCase().contains(query.toLowerCase()) ||
                        (a.deviceName ?? '').toLowerCase().contains(
                          query.toLowerCase(),
                        ),
                  )
                  .toList();
              if (filtered.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(Icons.devices_outlined, size: 36),
                            const SizedBox(height: 10),
                            Text(
                              'No AVDs yet',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            const Text('Create your first AVD to get started.'),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: onCreate,
                              icon: const Icon(Icons.add),
                              label: const Text('Create'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                itemCount: filtered.length,
                itemBuilder: (_, index) {
                  final avd = filtered[index];
                  return AvdListTile(
                    avd: avd,
                    selected: selected == avd.name,
                    onTap: () =>
                        ref.read(selectedAvdNameProvider.notifier).state =
                            avd.name,
                    onPrimaryAction: () => onPrimaryAction(avd),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'Failed to load AVDs',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 6),
                        Text('$err'),
                        const SizedBox(height: 10),
                        FilledButton.tonal(
                          onPressed: () =>
                              ref.read(avdListProvider.notifier).refresh(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
