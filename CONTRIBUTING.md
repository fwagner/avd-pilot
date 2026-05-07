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
