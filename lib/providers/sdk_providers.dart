import 'package:emulator_device_manager/models/device_profile.dart';
import 'package:emulator_device_manager/models/system_image.dart';
import 'package:emulator_device_manager/services/android_sdk.dart';
import 'package:emulator_device_manager/services/avd_service.dart';
import 'package:emulator_device_manager/services/sdkmanager_service.dart';
import 'package:emulator_device_manager/services/shell.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final shellServiceProvider = Provider<ShellService>((ref) => ShellService());
final sdkServiceProvider = Provider<AndroidSdkService>(
  (ref) => AndroidSdkService(),
);
final avdServiceProvider = Provider<AvdService>(
  (ref) => AvdService(ref.read(shellServiceProvider)),
);
final sdkManagerServiceProvider = Provider<SdkManagerService>(
  (ref) => SdkManagerService(ref.read(shellServiceProvider)),
);

final sdkPathsProvider = FutureProvider<AndroidSdkPaths?>((ref) {
  return ref.read(sdkServiceProvider).resolvePaths();
});

final systemImagesProvider = FutureProvider<List<SystemImage>>((ref) async {
  final AndroidSdkPaths? paths = await ref.watch(sdkPathsProvider.future);
  if (paths == null) {
    return <SystemImage>[];
  }
  return ref.read(sdkManagerServiceProvider).listSystemImages(paths.sdkmanager);
});

final deviceProfilesProvider = FutureProvider<List<DeviceProfile>>((ref) async {
  final AndroidSdkPaths? paths = await ref.watch(sdkPathsProvider.future);
  if (paths == null) {
    return <DeviceProfile>[];
  }
  return ref.read(avdServiceProvider).listDeviceProfiles(paths.avdmanager);
});
