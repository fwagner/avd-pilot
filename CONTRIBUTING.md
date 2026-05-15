# Contributing

Thanks for your interest in contributing to AVD Pilot.

## Branch model

- Feature work targets `develop`.
- Release automation promotes `develop` to `main`.
- Do not push directly to protected branches.

## Pull requests

- Open PRs against `develop` unless the change is a release promotion.
- Keep PRs focused and include a short test plan.
- CI must pass before merge.

## Commit and PR title convention

This repository uses Conventional Commits for automated release versioning.

Use one of:

- `feat: ...`
- `fix: ...`
- `perf: ...`
- `refactor: ...`
- `docs: ...`
- `test: ...`
- `build: ...`
- `ci: ...`
- `chore: ...`
- `revert: ...`

Breaking changes should include `!` in the type/scope or a `BREAKING CHANGE:` footer.

## Local checks

```bash
flutter analyze
flutter test
```

## AI agent workflow (integration-test-first)

When implementing a new user flow, agents should use this loop:

1. Add or update a test that encodes the expected behavior **before** changing app code.
   - Cross-layer flow (UI -> provider -> service): add/update a file in `integration_test/`.
   - Logic-only or single-widget behavior: add/update a file in `test/`.
2. Run only the relevant test file while iterating:
   - `flutter test integration_test/<flow>_test.dart`
   - or `flutter test test/<unit_or_widget>_test.dart`
3. Implement the feature/fix in `lib/` until the targeted test passes.
4. Run the full verification loop before opening/updating a PR:

```bash
./scripts/run_e2e.sh
```

Notes:
- Keep integration tests focused on critical user journeys and wiring.
- Prefer deterministic fakes in `integration_test/fakes/` over real SDK/emulator dependencies.
- Do not use `pumpAndSettle()` in integration tests for this project; use explicit `pump()` calls because `AvdListNotifier` uses periodic polling timers.
