import 'package:emulator_device_manager/models/avd.dart';
import 'package:emulator_device_manager/models/avd_state.dart';
import 'package:flutter/material.dart';

class AvdListTile extends StatefulWidget {
  const AvdListTile({
    super.key,
    required this.avd,
    required this.selected,
    required this.onTap,
    required this.onPrimaryAction,
  });

  final Avd avd;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onPrimaryAction;

  @override
  State<AvdListTile> createState() => _AvdListTileState();
}

class _AvdListTileState extends State<AvdListTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color tileColor = widget.selected
        ? cs.secondaryContainer.withValues(alpha: 0.6)
        : _hovering
        ? cs.surfaceContainerHighest.withValues(alpha: 0.4)
        : Colors.transparent;
    final Avd avd = widget.avd;
    final String actionLabel =
        (avd.state == AvdState.running || avd.state == AvdState.booting)
        ? 'Stop'
        : avd.state == AvdState.starting
        ? 'Cancel'
        : 'Launch';
    return InkWell(
      onTap: widget.onTap,
      onHover: (value) => setState(() => _hovering = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 66,
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: <Widget>[
            _StatusDot(state: avd.state),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    avd.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    avd.deviceName ?? 'Unknown device',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (actionLabel == 'Launch')
              SizedBox(
                height: 32,
                child: FilledButton.icon(
                  onPressed: avd.state == AvdState.stopping
                      ? null
                      : widget.onPrimaryAction,
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                  label: const Text('Launch'),
                ),
              )
            else
              SizedBox(
                height: 32,
                child: FilledButton.tonalIcon(
                  onPressed: avd.state == AvdState.stopping
                      ? null
                      : widget.onPrimaryAction,
                  icon: const Icon(Icons.stop_rounded, size: 14),
                  label: Text(actionLabel),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.state});
  final AvdState state;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color color = switch (state) {
      AvdState.running => cs.primary,
      AvdState.starting || AvdState.booting || AvdState.stopping => cs.tertiary,
      AvdState.stopped => cs.outline,
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 6),
        ],
      ),
    );
  }
}
