---
description: Run the full "is this done" checklist before committing
allowed-tools: Bash(flutter analyze), Bash(flutter test), Bash(bash tool/codemap.sh --check), Bash(git diff:*), Bash(git status:*), Read
---

Run the done-checklist for the current working tree and report each item as
**pass / fail / not applicable**, with the actual output for anything failing.

1. `flutter analyze` — clean? (A floor, not a ceiling. A clean run says nothing
   about rebuild scope, list virtualization, or image decode cost.)
2. `flutter test` — passing?
3. `bash tool/codemap.sh --check` — map current?
4. `CHANGELOG.md` — does `[Unreleased]` cover the user-visible part of
   `git diff`? If the diff is purely internal, say so.
5. Read the diff yourself and check it against:
   - `docs/GOTCHAS.md` — any blurred `BoxShadow` in a rebuilding widget? a
     bare `Row`/`Column` in a Scaffold slot? a `Transform.translate` that must
     stay tappable? a mutating action with no in-flight guard?
   - `AGENTS.md` §3 — Cubit calling a repository directly? a hand-built
     `/v1/...` path? raw `response.data['data']` parsing? lines past 120 cols?
   - `AGENTS.md` §4 — does the change touch auth, sessions, input, storage,
     secrets, or logging? If so, name the OWASP category at risk with a
     `file:line`, or state that none applies.

End with a plain verdict, and **name explicitly what is unverified** — there
is no emulator here, so anything touching layout, animation, gestures, or the
renderer needs a human on a real device. Don't imply otherwise.

Fix nothing. This command reports.
