import 'dart:io';

import 'package:collection/collection.dart';
import 'package:emulator_device_manager/models/device_profile.dart';
import 'package:emulator_device_manager/models/system_image.dart';
import 'package:emulator_device_manager/providers/sdk_providers.dart';
import 'package:emulator_device_manager/ui/install_image_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CreateAvdRequest {
  const CreateAvdRequest({
    required this.name,
    required this.device,
    required this.image,
  });
  final String name;
  final DeviceProfile device;
  final SystemImage image;
}

Future<CreateAvdRequest?> showCreateAvdDialog(
  BuildContext context,
  WidgetRef ref,
) {
  return showDialog<CreateAvdRequest>(
    context: context,
    builder: (_) => const _CreateAvdDialog(),
  );
}

class _CreateAvdDialog extends ConsumerStatefulWidget {
  const _CreateAvdDialog();

  @override
  ConsumerState<_CreateAvdDialog> createState() => _CreateAvdDialogState();
}

class _CreateAvdDialogState extends ConsumerState<_CreateAvdDialog> {
  final TextEditingController _nameController = TextEditingController();
  bool _nameManuallyEdited = false;
  bool _updatingNameProgrammatically = false;
  DeviceProfile? _device;
  SystemImage? _image;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _updateAutoNameIfNeeded() {
    final String suggested = _buildSuggestedName();
    if (suggested.isEmpty) {
      return;
    }
    if (_nameController.text.trim().isEmpty || !_nameManuallyEdited) {
      _updatingNameProgrammatically = true;
      _nameController.text = suggested;
      _nameController.selection = TextSelection.collapsed(
        offset: _nameController.text.length,
      );
      _updatingNameProgrammatically = false;
    }
  }

  String _buildSuggestedName() {
    if (_device == null || _image == null) {
      return '';
    }
    final String deviceToken = _sanitizeToken(_device!.name);
    final String raw = '${deviceToken}_API_${_image!.apiLevel}';
    return raw.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
  }

  String _sanitizeToken(String input) {
    return input
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '')
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(deviceProfilesProvider);
    final images = ref.watch(systemImagesProvider);
    final String preferredAbi = Platform.isMacOS ? 'arm64-v8a' : 'x86_64';
    return AlertDialog(
      title: const Text('Create new AVD'),
      content: SizedBox(
        width: 680,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Auto-generated from device and image',
              ),
              onChanged: (_) {
                if (_updatingNameProgrammatically) {
                  return;
                }
                _nameManuallyEdited = _nameController.text.trim().isNotEmpty;
              },
            ),
            const SizedBox(height: 8),
            devices.when(
              data: (items) {
                final DeviceProfile? selectedDeviceValue = _device == null
                    ? null
                    : items.where((d) => d.id == _device!.id).firstOrNull;
                if (_device == null && items.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) {
                      return;
                    }
                    setState(() {
                      _device = items.first;
                      _updateAutoNameIfNeeded();
                    });
                  });
                }
                return DropdownButtonFormField<DeviceProfile>(
                  initialValue: selectedDeviceValue,
                  items: items
                      .map(
                        (d) => DropdownMenuItem<DeviceProfile>(
                          value: d,
                          child: Text(d.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() {
                    _device = v;
                    _updateAutoNameIfNeeded();
                  }),
                  decoration: const InputDecoration(
                    labelText: 'Device profile',
                  ),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Device profiles failed: $e'),
            ),
            const SizedBox(height: 8),
            images.when(
              data: (items) {
                final List<SystemImage> installed = items
                    .where((img) => img.installed)
                    .toList();
                final List<SystemImage> candidates = installed.isNotEmpty
                    ? installed
                    : items;
                candidates.sort((a, b) {
                  final int apiCmp = b.apiLevel.compareTo(a.apiLevel);
                  if (apiCmp != 0) {
                    return apiCmp;
                  }
                  final int abiRankA = a.abi == preferredAbi ? 0 : 1;
                  final int abiRankB = b.abi == preferredAbi ? 0 : 1;
                  final int abiCmp = abiRankA.compareTo(abiRankB);
                  if (abiCmp != 0) {
                    return abiCmp;
                  }
                  return a.displayName.compareTo(b.displayName);
                });
                final bool selectedStillExists = _image == null
                    ? false
                    : candidates.any(
                        (img) => img.packageId == _image!.packageId,
                      );
                final SystemImage? selectedImageValue = !selectedStillExists
                    ? null
                    : candidates
                          .where((img) => img.packageId == _image!.packageId)
                          .firstOrNull;
                if (!selectedStillExists && candidates.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) {
                      return;
                    }
                    setState(() {
                      _image = candidates.first;
                      _updateAutoNameIfNeeded();
                    });
                  });
                }
                return DropdownButtonFormField<SystemImage>(
                  initialValue: selectedImageValue,
                  items: candidates
                      .map(
                        (img) => DropdownMenuItem<SystemImage>(
                          value: img,
                          child: Text(
                            img.installed
                                ? img.displayName
                                : '${img.displayName} (not installed)',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() {
                    _image = v;
                    _updateAutoNameIfNeeded();
                  }),
                  decoration: const InputDecoration(labelText: 'System image'),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('System images failed: $e'),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => showInstallImageDialog(context, ref),
                icon: const Icon(Icons.download),
                label: const Text('Install new image...'),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_nameController.text.trim().isEmpty ||
                _device == null ||
                _image == null) {
              return;
            }
            Navigator.of(context).pop(
              CreateAvdRequest(
                name: _nameController.text.trim(),
                device: _device!,
                image: _image!,
              ),
            );
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
