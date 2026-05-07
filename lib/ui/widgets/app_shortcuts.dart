import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RefreshIntent extends Intent {
  const RefreshIntent();
}

class NewIntent extends Intent {
  const NewIntent();
}

class DeleteIntent extends Intent {
  const DeleteIntent();
}

class PrimaryActionIntent extends Intent {
  const PrimaryActionIntent();
}

class AppShortcuts extends StatelessWidget {
  const AppShortcuts({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true):
            const RefreshIntent(),
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
            const NewIntent(),
        const SingleActivator(LogicalKeyboardKey.comma, meta: true):
            const VoidCallbackIntent(_goToSettings),
        const SingleActivator(LogicalKeyboardKey.enter):
            const PrimaryActionIntent(),
        const SingleActivator(LogicalKeyboardKey.delete): const DeleteIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          RefreshIntent: CallbackAction<RefreshIntent>(
            onInvoke: (_) => RefreshRequestedNotification().dispatch(context),
          ),
          NewIntent: CallbackAction<NewIntent>(
            onInvoke: (_) => CreateRequestedNotification().dispatch(context),
          ),
          DeleteIntent: CallbackAction<DeleteIntent>(
            onInvoke: (_) {
              if (_isTextInputFocused()) {
                return;
              }
              return DeleteRequestedNotification().dispatch(context);
            },
          ),
          PrimaryActionIntent: CallbackAction<PrimaryActionIntent>(
            onInvoke: (_) {
              if (_isTextInputFocused()) {
                return;
              }
              return PrimaryActionRequestedNotification().dispatch(context);
            },
          ),
          VoidCallbackIntent: CallbackAction<VoidCallbackIntent>(
            onInvoke: (intent) => intent.callback(context),
          ),
        },
        child: child,
      ),
    );
  }

  static void _goToSettings(BuildContext context) {
    Navigator.of(context).pushNamed('/settings');
  }

  static bool _isTextInputFocused() {
    final BuildContext? focusedContext =
        FocusManager.instance.primaryFocus?.context;
    if (focusedContext == null) {
      return false;
    }
    if (focusedContext.widget is EditableText) {
      return true;
    }
    return focusedContext.findAncestorWidgetOfExactType<EditableText>() != null;
  }
}

class VoidCallbackIntent extends Intent {
  const VoidCallbackIntent(this.callback);
  final void Function(BuildContext context) callback;
}

class RefreshRequestedNotification extends Notification {}

class CreateRequestedNotification extends Notification {}

class DeleteRequestedNotification extends Notification {}

class PrimaryActionRequestedNotification extends Notification {}
