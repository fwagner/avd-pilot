import 'package:emulator_device_manager/providers/sdk_providers.dart';
import 'package:emulator_device_manager/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final TextEditingController _sdkOverrideController = TextEditingController();

  @override
  void initState() {
    super.initState();
    ref.read(sdkServiceProvider).getOverridePath().then((value) {
      if (!mounted) return;
      _sdkOverrideController.text = value ?? '';
    });
  }

  @override
  void dispose() {
    _sdkOverrideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sdkAsync = ref.watch(sdkPathsProvider);
    final ThemeMode selectedThemeMode = ref.watch(themeModeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Appearance',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      SegmentedButton<ThemeMode>(
                        showSelectedIcon: false,
                        segments: const <ButtonSegment<ThemeMode>>[
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.system,
                            label: Text('System'),
                            icon: Icon(Icons.settings_suggest_rounded),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.light,
                            label: Text('Light'),
                            icon: Icon(Icons.light_mode_outlined),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.dark,
                            label: Text('Dark'),
                            icon: Icon(Icons.dark_mode_outlined),
                          ),
                        ],
                        selected: <ThemeMode>{selectedThemeMode},
                        onSelectionChanged: (selection) {
                          ref
                              .read(themeModeProvider.notifier)
                              .setThemeMode(selection.first);
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'System follows your macOS appearance automatically.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Android SDK',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _sdkOverrideController,
                        decoration: const InputDecoration(
                          labelText: 'SDK override path',
                          hintText: '/Users/<you>/Library/Android/sdk',
                        ),
                      ),
                      const SizedBox(height: 10),
                      sdkAsync.when(
                        data: (sdk) => Row(
                          children: <Widget>[
                            Icon(
                              sdk == null
                                  ? Icons.error_outline
                                  : Icons.check_circle_outline,
                              size: 16,
                              color: sdk == null
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                sdk == null
                                    ? 'SDK not found'
                                    : 'Valid SDK detected at ${sdk.root}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (err, _) => Text('Error: $err'),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          FilledButton(
                            onPressed: () async {
                              await ref
                                  .read(sdkServiceProvider)
                                  .setOverridePath(_sdkOverrideController.text);
                              ref.invalidate(sdkPathsProvider);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Saved SDK override path'),
                                ),
                              );
                            },
                            child: const Text('Save'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () async {
                              await ref
                                  .read(sdkServiceProvider)
                                  .setOverridePath(null);
                              if (!context.mounted) return;
                              _sdkOverrideController.clear();
                              ref.invalidate(sdkPathsProvider);
                            },
                            child: const Text('Clear override'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
