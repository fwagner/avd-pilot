import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:emulator_device_manager/models/system_image.dart';
import 'package:emulator_device_manager/services/shell.dart';

class LicenseStatus {
  const LicenseStatus({required this.pendingCount, required this.details});
  final int pendingCount;
  final String details;
}

class SdkManagerService {
  SdkManagerService(this._shell);
  final ShellService _shell;

  Future<List<SystemImage>> listSystemImages(String sdkManagerPath) async {
    final ToolResult installed = await _shell.runTool(sdkManagerPath, <String>[
      '--list_installed',
    ]);
    final ToolResult all = await _shell.runTool(sdkManagerPath, <String>[
      '--list',
    ]);

    final Set<String> installedPkgs = _extractSystemImagePackages(
      installed.stdout,
    ).toSet();

    final Set<String> allPackages = _extractSystemImagePackages(
      all.stdout,
    ).toSet();
    final List<SystemImage> images = <SystemImage>[];
    for (final String packageId in allPackages) {
      final List<String> chunks = packageId.split(';');
      if (chunks.length < 4) {
        continue;
      }
      final int api = int.tryParse(chunks[1].replaceAll('android-', '')) ?? 0;
      final String variant = chunks[2];
      final String abi = chunks[3];
      images.add(
        SystemImage(
          packageId: packageId,
          apiLevel: api,
          variant: variant,
          abi: abi,
          installed: installedPkgs.contains(packageId),
        ),
      );
    }
    images.sort((a, b) => b.apiLevel.compareTo(a.apiLevel));
    return images;
  }

  List<String> _extractSystemImagePackages(String output) {
    final RegExp packagePattern = RegExp(
      r'(system-images;android-\d+;[^;\s|]+;[^;\s|]+)',
    );
    return packagePattern
        .allMatches(output)
        .map((match) => match.group(1)!.trim())
        .toList();
  }

  Future<LicenseStatus> checkLicenses(String sdkManagerPath) async {
    final ToolResult result = await _shell.runTool(
      sdkManagerPath,
      <String>['--licenses'],
      stdinData: '\n',
      timeout: const Duration(minutes: 2),
    );
    final RegExp exp = RegExp(
      r'(\d+)\s+of\s+\d+\s+SDK package licenses? not accepted',
    );
    final RegExpMatch? match = exp.firstMatch(result.stdout);
    final int count = int.tryParse(match?.group(1) ?? '0') ?? 0;
    return LicenseStatus(pendingCount: count, details: result.stdout);
  }

  Future<void> acceptLicenses(String sdkManagerPath) async {
    await _shell.runTool(
      sdkManagerPath,
      <String>['--licenses'],
      stdinData: List<String>.filled(100, 'y').join('\n'),
      timeout: const Duration(minutes: 3),
    );
  }

  Future<void> installImage({
    required String sdkManagerPath,
    required String packageId,
    void Function(double? progress, String message)? onProgress,
  }) async {
    final Process process = await Process.start(sdkManagerPath, <String>[
      '--install',
      packageId,
    ]);
    final RegExp percentPattern = RegExp(r'(\d{1,3})%');

    void handleOutputChunk(String chunk) {
      for (final String line in chunk.split('\n')) {
        final String trimmed = line.trim();
        if (trimmed.isEmpty) {
          continue;
        }
        final RegExpMatch? match = percentPattern.firstMatch(trimmed);
        if (match != null) {
          final int percent = int.tryParse(match.group(1) ?? '') ?? 0;
          final double normalized = (percent.clamp(0, 100)) / 100.0;
          final String cleaned = _cleanProgressMessage(
            trimmed,
            match.group(0)!,
          );
          onProgress?.call(
            normalized,
            cleaned.isEmpty ? 'Installing...' : cleaned,
          );
        } else {
          onProgress?.call(null, _cleanProgressMessage(trimmed, null));
        }
      }
    }

    final StreamSubscription<String> outSub = process.stdout
        .transform(utf8.decoder)
        .listen(handleOutputChunk);
    final StreamSubscription<String> errSub = process.stderr
        .transform(utf8.decoder)
        .listen(handleOutputChunk);

    final int exitCode = await process.exitCode.timeout(
      const Duration(minutes: 30),
    );
    await outSub.cancel();
    await errSub.cancel();
    if (exitCode != 0) {
      throw ToolFailed(
        command: '$sdkManagerPath --install $packageId',
        exitCode: exitCode,
        stdout: '',
        stderr: 'sdkmanager install failed',
      );
    }
    onProgress?.call(1.0, 'Done');
  }

  String _cleanProgressMessage(String line, String? percentToken) {
    String message = line;
    // Remove leading ascii progress bars like "[====      ]".
    message = message.replaceFirst(RegExp(r'^\[[^\]]*\]\s*'), '');
    // Remove redundant percentage token from the remainder.
    if (percentToken != null) {
      message = message.replaceFirst(percentToken, '').trimLeft();
    }
    // Remove common leading separators after stripping.
    message = message.replaceFirst(RegExp(r'^[\-\:\|]+\s*'), '');
    return message.trim();
  }
}
