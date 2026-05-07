import 'package:emulator_device_manager/models/avd_state.dart';
import 'package:flutter/material.dart';

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.state});
  final AvdState state;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final (Color bg, Color fg, Widget icon) = switch (state) {
      AvdState.running => (
        cs.primaryContainer,
        cs.onPrimaryContainer,
        Icon(Icons.check_circle, color: cs.onPrimaryContainer, size: 14),
      ),
      AvdState.starting || AvdState.booting || AvdState.stopping => (
        cs.tertiaryContainer,
        cs.onTertiaryContainer,
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: cs.onTertiaryContainer,
          ),
        ),
      ),
      AvdState.stopped => (
        cs.surfaceContainerHighest,
        cs.onSurfaceVariant,
        Icon(Icons.power_settings_new, color: cs.onSurfaceVariant, size: 14),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          icon,
          const SizedBox(width: 6),
          Text(
            state.label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: 12,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
