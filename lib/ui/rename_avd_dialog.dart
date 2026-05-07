import 'package:flutter/material.dart';

Future<String?> showRenameAvdDialog(BuildContext context, String oldName) {
  final TextEditingController controller = TextEditingController(text: oldName);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Rename device'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(labelText: 'New AVD name'),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          child: const Text('Rename'),
        ),
      ],
    ),
  );
}
