# AGENTS.md

Instructions for **any** AI coding assistant working in this repository —
Claude Code, Codex, Cursor, Gemini, Copilot, or whatever comes next. The point
is that all of them reach the same answers, so the repo doesn't drift by which
tool happened to be open.

Claude Code additionally reads `CLAUDE.md`, which defers to this file for the
shared parts. If the two ever disagree, this file is the one to fix.

---

## 1. Read order — do this before touching code

Read these in order, once per session. Don't skip ahead to grepping the
source: the answer is usually already written down, and searching 220 Dart
files to re-derive it wastes the context you'll need for the actual work.

| # | File | What it gives you |
|---|---|---|
| 1 | `docs/ARCHITECTURE.md` | Layers, the request lifecycle, where new code goes |
| 2 | `docs/CODEMAP.md` | Generated index of every file, route, and DI registration |
| 3 | `docs/GOTCHAS.md` | What already broke on-device. Read before any UI work |
| 4 | `docs/BACKEND.md` | Endpoints, the response envelope, gaps that are permanent |
| 5 | `docs/DECISIONS.md` | Why things are this way, so you don't "fix" a decision |

Then open only the files `CODEMAP.md` points you at.

**Don't re-read what you've already read.** Within a session, trust your
earlier reads; don't re-open a file to confirm something you already
established. Between sessions, that continuity lives in these docs — which is
why keeping them true (rule 5) is part of the job, not overhead.

---

## 2. What this project is

Yello — a Flutter social app, **Android and iOS only**. No web, no desktop;
those platform folders are absent on purpose. Live backend at
`https://api.yello.cachewraith.com` (plus `yello-chat` and `yello-notify` on
the same host).

Stack: `flutter_bloc` (Cubits only) · `get_it` (hand-written) · `go_router` ·
`dio` · `dartz` `Either<Failure, T>` · `cached_network_image`.

---

## 3. Hard rules

These are not style preferences. Breaking one produces a real defect.

1. **Cubits only.** No Bloc, no events. Cubit and its `State` class live in the
   same file.
2. **A Cubit calls a usecase** — never a repository, never a data source. If
   the usecase doesn't exist, write it.
3. **DI stays hand-written** in `lib/core/di/injection.dart`. No `injectable`,
   no `build_runner`. Read the comment beside a registration before changing
   its lifetime.
4. **Never parse `response.data['data']` by hand.** Use `ApiEnvelope`
   (`core/network/api_envelope.dart`) and `ErrorHandler`.
5. **Never hardcode a `/v1/...` path.** Use `VersionedEndpoints`, or the
   service's own `ChatRoutes` / `NotifyRoutes`.
6. **`go_router` ^17.5.0:** `GoRouterState.name` reads `null` inside a
   top-level `redirect`. Use `state.matchedLocation`.
7. **Formatting is 120 columns, by hand.** Plain `dart format` defaults to 80
   and will blow up the diff. If you must:
   `dart format --line-length=120 <touched files>` — never repo-wide.
8. **Never put a blurred `BoxShadow` in an animated or rebuilding widget.** It
   crashed the app on this project's renderer. See `docs/GOTCHAS.md`.
9. **Every mutating, tappable action needs an in-flight guard.** Copy
   `FeedCubit._pendingReactions`. Double-tap double-firing an endpoint is a bug
   this codebase has already shipped once.
10. **Don't propose wiring Stories or Saved Posts to the API.** Those endpoints
    do not exist. See `docs/BACKEND.md`. If a change needs a backend contract
    that isn't there, say so plainly instead of writing a client-side
    workaround that can't work.

---

## 4. Security — OWASP Top 10:2025

Before calling any work done that touches authentication, authorization,
sessions, input handling, data access, secrets, crypto, file uploads, outbound
requests, dependencies, or error/log output, check it against the list.

Pick the design that avoids the category up front (server-side authorization,
allowlisted outbound URLs, no secrets in logs) rather than bolting on a
mitigation. When reviewing, cite the ID with a `file:line` — "A01: this handler
trusts a client-supplied `userId` at `foo.dart:42`", never a vague "looks
insecure". Don't pad a review with categories that don't apply.

A01 Broken Access Control (incl. SSRF) · A02 Security Misconfiguration ·
A03 Software Supply Chain Failures · A04 Cryptographic Failures ·
A05 Injection · A06 Insecure Design · A07 Authentication Failures ·
A08 Software or Data Integrity Failures · A09 Security Logging & Alerting
Failures · A10 Mishandling of Exceptional Conditions

This app's live surface: JWT handling and refresh (`core/security/`,
`core/network/interceptors/auth_interceptor.dart`), secure storage,
certificate pinning, root/jailbreak detection, and the logging interceptor —
which is off in release precisely because bodies carry tokens and PII. Keep it
that way.

---

## 5. Keep the docs true — this is part of the change, not extra

The docs above are only worth reading if they're accurate. So:

| When you… | Also do this |
|---|---|
| Add/move/delete a file, route, or DI registration | `bash tool/codemap.sh` |
| Make any user-visible change | Add a `CHANGELOG.md` entry under `[Unreleased]` |
| Make a non-trivial design choice | Append an ADR to `docs/DECISIONS.md` |
| Lose time to a non-obvious trap | Add it to `docs/GOTCHAS.md` |
| Find the backend's shape differs from the docs | Correct `docs/BACKEND.md` |

`bash tool/codemap.sh --check` exits non-zero when the committed map is stale.

---

## 6. Before you call it done

- [ ] `flutter analyze` is clean — **a floor, not a ceiling.** It says nothing
      about rebuild scope, list virtualization, or image decode cost.
- [ ] `flutter test` passes.
- [ ] `bash tool/codemap.sh --check` passes.
- [ ] `CHANGELOG.md` updated if the change is user-visible.
- [ ] Performance pass: `const` constructors where the subtree is static;
      `BlocSelector`/`buildWhen` instead of a page-wide `BlocBuilder`;
      `ListView.builder` for anything variable-length; `cached_network_image`
      with `memCacheWidth/Height` for thumbnails.
- [ ] Say plainly what is **unverified**. There's no emulator in the dev
      sandbox — anything touching layout, animation, gestures, or the renderer
      needs a human on a real device. Don't imply otherwise.

---

## 7. Working style

- Scope changes to what was asked. Spotted something else worth fixing? Report
  it as a finding; don't bundle an unrelated refactor into the diff.
- "Review", "check", "audit" means *report findings*, not apply fixes. "Fix"
  or "implement" means make the change.
- Match the vocabulary already in the codebase over introducing a new one.
  Consistency beats a marginally better fit.
- The simplest construct that works wins. A function or a plain class beats a
  pattern; a pattern earns its place when there are already two real variants
  or a known axis of change — not one hypothetical future one.
- Don't retrofit patterns into working code nobody asked you to change.
- Git commit messages describe the change and nothing else — no AI/model
  attribution anywhere in subject, body, or trailers.
