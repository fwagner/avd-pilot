# Logcat Filtering — Implementation Plan

## Goal

Add real-time logcat output filtering to AVD Pilot so users can narrow visible
log lines by **log level** (minimum severity threshold), **tag**
(include/exclude via single text field), and **PID/process name** (with
automatic PID→name resolution via `adb shell ps`). Filters apply both to newly
arriving lines and retroactively to the already-buffered history. This builds
on top of PR #29 (`feat/logcat-colors`) which already provides the `LogLine`
parsed model and level-based color coding.

---

## Scope

### In scope

- A `LogcatFilter` value object describing the active filter criteria.
- A `logcatFilterProvider` (family, keyed by `avdName`) that owns filter state.
- A derived `filteredLogcatLinesProvider` that combines `LogcatState.lines`
  with the active `LogcatFilter` and emits only matching lines.
- A `ProcessResolver` service that runs `adb shell ps` to build a PID→name
  cache, refreshed periodically (every ~10s while logcat is live).
- Toolbar UI additions: a log-level dropdown, a tag-filter text field
  (comma-separated, `-prefix` means exclude), and a PID/process text field.
- Unparseable lines (control lines, adb stderr) always shown in subdued style
  regardless of filter state.
- Line count badge shows "342 of 4 801 lines" when filter is active.
- Unit tests for filtering logic and provider integration.

### Out of scope

- Full-text / message-body search (separate feature).
- Regex-based filters.
- Persisting filter presets (follow-up PR).
- Changes to `LogcatService` — the raw stream stays untouched.
- Color coding — already handled by PR #29.

---

## Architecture overview

```
LogcatService  ──stream──▶  LogcatNotifier (raw buffer, max 5 000 LogLines)
                                  │
                    ╭─────────────┤
                    ▼             ▼
          logcatFilterProvider   logcatNotifierProvider
            (LogcatFilter)         (LogcatState)
                    │             │
                    ▼             ▼
              filteredLogcatLinesProvider ◀── combines both
                    │
                    ▼               processResolverProvider
                 LogsTab (UI) ◀── (PID→name for display/matching)
```

Key design decision: **filtering is a pure, derived computation on the
existing buffered lines**. The `LogcatNotifier` keeps buffering all raw lines
regardless of filters. Changing a filter is instant (no re-fetch).

---

## Step-by-step tasks

### Step 1 — Filter model

**File:** `lib/models/logcat_filter.dart` (new)

```dart
import 'package:collection/collection.dart';
import 'package:emulator_device_manager/models/log_line.dart';

class LogcatFilter {
  const LogcatFilter({
    this.minimumLevel = LogLevel.verbose,
    this.includeTags = const <String>{},
    this.excludeTags = const <String>{},
    this.pidOrProcess = '',
  });

  final LogLevel minimumLevel;
  final Set<String> includeTags;   // empty = allow all
  final Set<String> excludeTags;
  final String pidOrProcess;       // empty = no PID filter

  bool get isActive =>
      minimumLevel != LogLevel.verbose ||
      includeTags.isNotEmpty ||
      excludeTags.isNotEmpty ||
      pidOrProcess.isNotEmpty;

  /// Returns true if the given parsed LogLine matches this filter.
  /// [processName] is the resolved name for the line's PID (may be null).
  /// Caller must ensure entry.isParsed is true before calling.
  bool matches(LogLine entry, {String? processName}) { ... }

  LogcatFilter copyWith({...}) { ... }

  // Use DeepCollectionEquality from package:collection for Set fields
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LogcatFilter &&
          minimumLevel == other.minimumLevel &&
          const SetEquality<String>().equals(includeTags, other.includeTags) &&
          const SetEquality<String>().equals(excludeTags, other.excludeTags) &&
          pidOrProcess == other.pidOrProcess;

  @override
  int get hashCode => Object.hash(
        minimumLevel,
        const SetEquality<String>().hash(includeTags),
        const SetEquality<String>().hash(excludeTags),
        pidOrProcess,
      );
}
```

`matches` logic (only called when `entry.isParsed` is true):

1. `entry.level!.index >= minimumLevel.index` — reject if below threshold.
2. If `includeTags` is non-empty, `entry.tag!.toLowerCase()` must be in the
   lowercased include set.
3. `entry.tag!.toLowerCase()` must NOT be in the lowercased exclude set.
4. If `pidOrProcess` is non-empty:
   - If it parses as an integer, match against `int.tryParse(entry.pid!)`.
   - Otherwise treat as a case-insensitive substring match against
     `processName` (from PID→name cache) OR `entry.tag` as fallback.

### Step 2 — Process resolver service

**File:** `lib/services/process_resolver.dart` (new)

A lightweight service that:
- Accepts `adbPath` and `serial` as constructor params.
- Runs `adb -s <serial> shell ps -A -o PID,NAME` (or `ps -A` with column
  parsing if `-o` is not supported on older API levels).
- Parses the output into a `Map<int, String>` (PID → process name).
- Provides a `String? resolve(int pid)` method.
- `refresh()` re-runs the command and updates the map.
- Testable via a `RunProcess` callback (same pattern as `LogcatService`).

**File:** `lib/providers/process_resolver_provider.dart` (new)

```dart
/// Exposes the current PID→process-name map for a given AVD.
/// Watches avdListProvider to obtain the emulator serial.
/// Auto-refreshes every 10s while logcat status is live.
final processMapProvider =
    StateNotifierProvider.family<ProcessMapNotifier, Map<int, String>, String>(
  (ref, avdName) => ProcessMapNotifier(ref: ref, avdName: avdName),
);
```

The notifier:
- Watches `avdListProvider` to extract `avd.serial` (same pattern used by
  `LogcatNotifier`).
- Watches `logcatNotifierProvider(avdName)` for status — starts/stops the
  refresh timer based on whether logcat is live.
- Uses `sdkPathsProvider` to get the adb path.
- On dispose, cancels the timer.

### Step 3 — Filter provider + derived provider

**File:** `lib/providers/logcat_filter_provider.dart` (new)

```dart
final logcatFilterProvider =
    StateNotifierProvider.family<LogcatFilterNotifier, LogcatFilter, String>(
  (ref, avdName) => LogcatFilterNotifier(),
);

class LogcatFilterNotifier extends StateNotifier<LogcatFilter> {
  LogcatFilterNotifier() : super(const LogcatFilter());

  void setMinimumLevel(LogLevel level) { ... }
  void setTagFilter(String rawInput) {
    // Parse comma-separated tags; -prefix → exclude, others → include
  }
  void setPidOrProcess(String value) { ... }
  void reset() => state = const LogcatFilter();
}

final filteredLogcatLinesProvider =
    Provider.family<List<LogLine>, String>((ref, avdName) {
  final LogcatState logcatState = ref.watch(logcatNotifierProvider(avdName));
  final LogcatFilter filter = ref.watch(logcatFilterProvider(avdName));
  final Map<int, String> processMap =
      ref.watch(processMapProvider(avdName));

  if (!filter.isActive) return logcatState.lines;

  return logcatState.lines.where((line) {
    if (!line.isParsed) return true; // always show unparsed lines
    final int? pid = int.tryParse(line.pid ?? '');
    final String? processName = pid != null ? processMap[pid] : null;
    return filter.matches(line, processName: processName);
  }).toList(growable: false);
});
```

### Step 4 — Update `LogsTab` to consume filtered lines

**File:** `lib/ui/detail/logs_tab.dart`

Changes:

1. Import `logcat_filter_provider.dart`.
2. In `build()`, add:
   ```dart
   final List<LogLine> filteredLines =
       ref.watch(filteredLogcatLinesProvider(widget.avdName));
   ```
3. Use `filteredLines` for the ListView itemCount and itemBuilder.
4. Keep using `logcat.lines.length` for the total count in the toolbar.
5. Pass both counts to `_LogToolbar` — when filter is active, show
   `"342 of 4 801 lines"`.
6. Update `_lastLineCount` tracking to use `filteredLines.length`.
7. When `filteredLines` is empty but `logcat.lines` is not, show
   "No lines match filter" as the empty label.

### Step 5 — Toolbar filter controls

**File:** `lib/ui/detail/logs_tab.dart` — extend `_LogToolbar`

Add a second row below the existing toolbar row (or wrap both in a Column):

1. **Level dropdown** — `PopupMenuButton<LogLevel>` showing V/D/I/W/E/F.
   Default: V (verbose = show all). Compact chip-style button.

2. **Tag filter field** — `SizedBox(width: 180)` containing a compact
   `TextField` with hint `"Tags (−exclude)"`. Debounced at 300ms, calls
   `filterNotifier.setTagFilter(value)`.

3. **PID/Process field** — `SizedBox(width: 120)` containing a compact
   `TextField` with hint `"PID / process"`. Debounced at 300ms, calls
   `filterNotifier.setPidOrProcess(value)`.

4. **Clear-filters button** — visible only when `filter.isActive`. Icon
   button (`Icons.filter_alt_off`) that calls `filterNotifier.reset()` and
   clears the text controllers.

The filter row is only visible when logcat is live or paused (not idle or
disconnected) to avoid clutter.

### Step 6 — Tests

#### 6a — `test/logcat_filter_test.dart` (new)

- `matches` respects minimum level threshold.
- Include-tags allowlist: only matching tags pass.
- Exclude-tags denylist: matching tags are rejected.
- Include + exclude combined: exclude wins.
- PID integer match.
- PID string (process name) substring match.
- Empty filter (`isActive == false`) matches everything.
- `copyWith` produces correct equality.

#### 6b — `test/logcat_filter_provider_test.dart` (new)

- `filteredLogcatLinesProvider` returns all lines when filter is default.
- Returns subset when minimum level is set.
- Returns subset when tags are set.
- Reacts to filter changes.
- Reacts to new lines arriving.
- Unparseable lines always included regardless of filter.

#### 6c — `test/process_resolver_test.dart` (new)

- Parses `adb shell ps` output into a PID→name map.
- Returns null for unknown PIDs.
- Handles malformed ps output gracefully.

#### 6d — Existing tests

Run `flutter test` to confirm no regressions.

---

## Edge cases

| Case | Handling |
|------|----------|
| **Unparseable lines** (control lines, adb stderr) | Always shown in subdued style regardless of filter. |
| **Tag field has leading/trailing spaces** | Trim each token. |
| **Tag field has both `Foo` and `-Foo`** | Exclude wins. |
| **Empty tag between commas** (`"Foo,,Bar"`) | Ignore empty tokens. |
| **PID field has non-numeric text** | Treat as process-name substring match. |
| **Process not in ps cache** | Fall back to tag-based substring match. |
| **ps command fails** | Log warning, return empty map. PID filter still works for numeric PID matching against `LogLine.pid`. |
| **5 000 lines + active filter** | O(n) filtering at most every 80ms. |
| **Clear logs while filter is active** | Derived provider re-evaluates to empty. |
| **Pause while filter is active** | Changing filter while paused re-filters the visible buffer. |
| **Filter active, 0 lines match** | Show "No lines match filter" empty state. |

---

## Testing strategy

1. **Unit tests first** (6a, 6c) — pure Dart, no Flutter dependency.
2. **Provider integration tests** (6b) — `ProviderContainer` with fakes.
3. **Existing test suite** (6d) — `flutter test` after each step.
4. **Manual smoke test** — launch emulator, exercise each filter type.

Run `flutter analyze` after each step.

---

## Rollback / risk notes

- **Zero changes to `LogcatService` or `LogcatNotifier`.** If anything goes
  wrong, the filter provider and UI additions can be reverted cleanly.
- The only change to `LogsTab` is adding a filtered-lines watch and toolbar
  controls. Reverting restores previous behavior.
- **Performance risk is low.** Filtering 5 000 `LogLine` objects through a few
  comparisons is well under 1ms. The derived provider only re-evaluates when
  raw lines or filter change.
- **Process resolver adds one external call** (`adb shell ps`) every 10s.
  Failure is non-fatal and falls back gracefully.
- **No new dependencies.** Everything uses core Dart and existing Riverpod.
