import 'dart:io';

import 'package:emulator_device_manager/services/emulator_service.dart';

class ProcessStartInvocation {
  const ProcessStartInvocation({required this.executable, required this.args});

  final String executable;
  final List<String> args;
}

class FakeEmulatorService extends EmulatorService {
  FakeEmulatorService(super.shell, {this.onStart});

  final void Function(String executable, List<String> args)? onStart;
  final List<ProcessStartInvocation> startCalls = <ProcessStartInvocation>[];

  @override
  Future<Process> startProcess(String executable, List<String> args) async {
    startCalls.add(
      ProcessStartInvocation(
        executable: executable,
        args: List<String>.from(args),
      ),
    );
    onStart?.call(executable, args);
    return Process.start('/usr/bin/true', const <String>[]);
  }
}
