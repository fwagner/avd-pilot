import 'package:emulator_device_manager/models/system_image.dart';
import 'package:emulator_device_manager/providers/sdk_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> showInstallImageDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => const _InstallImageDialog(),
  );
}

class _InstallImageDialog extends ConsumerStatefulWidget {
  const _InstallImageDialog();

  @override
  ConsumerState<_InstallImageDialog> createState() =>
      _InstallImageDialogState();
}

class _InstallImageDialogState extends ConsumerState<_InstallImageDialog> {
  bool _busy = false;
  String _search = '';
  String? _installingPackageId;
  double? _progress;
  String _progressMessage = '';

  @override
  Widget build(BuildContext context) {
    final imagesAsync = ref.watch(systemImagesProvider);
    final pathsAsync = ref.watch(sdkPathsProvider);
    return AlertDialog(
      title: const Text('Install system image'),
      content: SizedBox(
        width: 700,
        height: 540,
        child: Column(
          children: <Widget>[
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Filter',
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: 8),
            if (_busy) ...[
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _progress == null
                      ? _progressMessage
                      : '${(_progress! * 100).round()}% ${_progressMessage.isEmpty ? 'Installing...' : _progressMessage}',
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: imagesAsync.when(
                data: (images) {
                  final filtered = images
                      .where(
                        (img) => img.displayName.toLowerCase().contains(
                          _search.toLowerCase(),
                        ),
                      )
                      .toList();
                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final SystemImage img = filtered[i];
                      final bool thisInstalling =
                          _installingPackageId == img.packageId;
                      return ListTile(
                        title: Text(img.displayName),
                        subtitle: Text(img.packageId),
                        trailing: img.installed
                            ? const Text('Installed')
                            : FilledButton(
                                onPressed: _busy
                                    ? null
                                    : () async {
                                        final paths = pathsAsync.value;
                                        if (paths == null) {
                                          return;
                                        }
                                        setState(() {
                                          _busy = true;
                                          _installingPackageId = img.packageId;
                                          _progress = null;
                                          _progressMessage =
                                              'Preparing install…';
                                        });
                                        final sdk = ref.read(
                                          sdkManagerServiceProvider,
                                        );
                                        final licenses = await sdk
                                            .checkLicenses(paths.sdkmanager);
                                        if (!context.mounted) {
                                          return;
                                        }
                                        if (licenses.pendingCount > 0 &&
                                            mounted) {
                                          final accepted = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text(
                                                'Accept Android SDK licenses',
                                              ),
                                              content: SizedBox(
                                                width: 520,
                                                child: SelectableText(
                                                  licenses.details,
                                                ),
                                              ),
                                              actions: <Widget>[
                                                TextButton(
                                                  onPressed: () => Navigator.of(
                                                    ctx,
                                                  ).pop(false),
                                                  child: const Text('Cancel'),
                                                ),
                                                FilledButton(
                                                  onPressed: () => Navigator.of(
                                                    ctx,
                                                  ).pop(true),
                                                  child: const Text(
                                                    'Accept all',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (accepted != true) {
                                            setState(() {
                                              _busy = false;
                                              _installingPackageId = null;
                                              _progress = null;
                                              _progressMessage = '';
                                            });
                                            return;
                                          }
                                          await sdk.acceptLicenses(
                                            paths.sdkmanager,
                                          );
                                        }
                                        await sdk.installImage(
                                          sdkManagerPath: paths.sdkmanager,
                                          packageId: img.packageId,
                                          onProgress: (progress, message) {
                                            if (!mounted) {
                                              return;
                                            }
                                            setState(() {
                                              _progress = progress;
                                              _progressMessage = message;
                                            });
                                          },
                                        );
                                        if (!mounted) {
                                          return;
                                        }
                                        ref.invalidate(systemImagesProvider);
                                        setState(() {
                                          _busy = false;
                                          _installingPackageId = null;
                                          _progress = null;
                                          _progressMessage = '';
                                        });
                                      },
                                child: Text(
                                  thisInstalling ? 'Installing…' : 'Install',
                                ),
                              ),
                      );
                    },
                  );
                },
                error: (err, _) => Text('Failed: $err'),
                loading: () => const Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
