# Emulator Device Manager

Flutter macOS desktop app to manage Android emulator AVDs:

- List AVDs and clearly separate running/stopped/transitioning devices
- Launch/stop/cold-boot emulators
- Create, rename, delete, and wipe AVDs
- Edit config via curated controls and raw key/value config editor
- Install system images with a license acceptance flow

## Prerequisites

- Flutter stable with macOS desktop support enabled
- Android SDK with tools:
  - `emulator`
  - `adb`
  - `avdmanager`
  - `sdkmanager`

On macOS the default SDK path is `~/Library/Android/sdk`.

## Run

```bash
flutter pub get
flutter run -d macos
```

## Tests

```bash
flutter test
```

## Implementation notes

- SDK path resolution order:
  1. User override (saved in app settings)
  2. `ANDROID_SDK_ROOT`
  3. `ANDROID_HOME`
  4. `~/Library/Android/sdk`
- All tool invocations use absolute executable paths (no `$PATH` dependency).
- macOS sandbox entitlement is disabled so the app can execute Android SDK tools located outside the app bundle.

## Known limitations

- macOS desktop target only (Windows/Linux not implemented)
- Duplicate AVD is intentionally out of scope for this MVP
- No packaging/codesigning/notarization flow yet
