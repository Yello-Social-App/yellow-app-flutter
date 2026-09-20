# Changelog

All notable changes to Yello are recorded here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning: [Semantic Versioning](https://semver.org/spec/v2.0.0.html) —
the app version lives in `pubspec.yaml` as `version: <semver>+<build>`.

**Every user-visible change gets an entry under `[Unreleased]` in the same
commit that makes the change.** Categories, in this order: `Added`, `Changed`,
`Deprecated`, `Removed`, `Fixed`, `Security`. Omit empty ones. Write for
someone using the app, not for someone reading the diff — and reference the
file only when it genuinely helps.

---

## [Unreleased]

### Added

- Project documentation set under `docs/` — `ARCHITECTURE.md`, `CODEMAP.md`,
  `BACKEND.md`, `GOTCHAS.md`, `DECISIONS.md` — plus `AGENTS.md` so every AI
  assistant starts from the same facts and the same read order.
- `tool/codemap.sh`, which regenerates `docs/CODEMAP.md` from the source tree
  (`--check` fails when the committed map is stale).

### Fixed

- `README.md` no longer contains unresolved merge-conflict markers.

---

## [0.2.0] — 2026-09-20

First tagged APK build.

### Added

- Push notifications: Firebase Core + Messaging and local notifications,
  Android/iOS manifest wiring, `core/notifications/push_notification_service.dart`.
- `lib/bootstrap.dart` as the single startup path — config, DI, session
  restore — called from `main.dart`.
- Communities: browse, join/leave, community feed, post composer with tag
  picker, threads and votes.
- Showcase: project list, detail, publishing, likes, view counts, tech filter.
- User search (`/users/search`).
- Reactor list on a post's reaction breakdown.

### Changed

- Consolidated three competing DI files (`injection1`, `injection_1`,
  `injection_2`) into a single `lib/core/di/injection.dart`.
- Expanded `VersionedEndpoints` to cover the v0.2.0 spec (40 paths /
  53 operations).

### Fixed

- Reaction and post field mapping realigned with the updated API contract.
- Error handling widened to the server's full error-code vocabulary in
  `core/error/error_handler.dart`.

---

## [0.1.1] — 2026-09-16

### Changed

- API base URL moved to the live host, passed once from `main.dart` through
  `bootstrap(baseUrl:)`.

### Fixed

- Assorted bug fixes carried by PR #2.

---

## [0.1.0] — 2026-09-10

### Added

- Initial app: auth (register, OTP verification, login, password reset),
  feed with cursor pagination, post detail and comments, reactions, stories
  rail, friends and requests, chat, notifications, profile, and the
  five-tab shell.
- Clean Architecture skeleton, `get_it` DI, `go_router` routing, `dio` client
  with auth/retry/error/logging interceptors, JWT + secure storage + biometric
  and root/jailbreak checks.

[Unreleased]: https://github.com/hushstack/yellow-app-flutter/compare/main...HEAD
