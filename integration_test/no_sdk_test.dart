import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_emulator_service.dart';
import 'fakes/fake_shell_service.dart';
import 'fakes/test_app.dart';

void main() {
  testWidgets('missing SDK shows error state and navigates to settings', (
    tester,
  ) async {
    final FakeShellService shell = FakeShellService(
      handler: (_, __) => throw UnimplementedError('No shell calls expected'),
    );
    final FakeEmulatorService emulator = FakeEmulatorService(shell);

    await pumpTestApp(
      tester,
      shellService: shell,
      emulatorService: emulator,
      sdkPaths: null,
    );

    expect(
      find.text('Android SDK not found. Configure SDK path in Settings.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Set SDK path'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Settings'), findsOneWidget);
  });
}
