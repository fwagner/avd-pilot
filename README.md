# AVD Pilot

AVD Pilot is a Flutter macOS desktop app for managing Android Emulator AVDs.

## Features

- List AVDs with clear state indicators (running, booting, stopped)
- Launch, stop, cold boot, and cold restart emulators
- Create, rename, delete, and wipe AVDs
- Edit emulator config from a curated Overview tab or raw key/value editor
- Live logcat console with pause/resume and auto-follow
- Build and package a distributable DMG installer

## Prerequisites

- Flutter stable with macOS desktop support enabled
- Android SDK with the following tools installed:
  - `emulator`
  - `adb`
  - `avdmanager`
  - `sdkmanager`

Default macOS SDK path: `~/Library/Android/sdk`.

## Local development

```bash
flutter pub get
flutter run -d macos
```

## Quality checks

```bash
flutter analyze
flutter test
```

## Build release app

```bash
flutter build macos --release
```

## Project notes

- SDK path resolution order:
  1. User override (saved in app settings)
  2. `ANDROID_SDK_ROOT`
  3. `ANDROID_HOME`
  4. `~/Library/Android/sdk`
- Tool invocations use absolute executable paths (no `$PATH` dependency).
- macOS sandbox entitlement is disabled so the app can execute Android SDK tools outside the app bundle.

## Distribution notes

- Current release artifacts are unsigned and not notarized.
- Use the published SHA256 checksum to verify downloaded DMGs.
