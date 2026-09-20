---
description: Add a CHANGELOG entry under [Unreleased] for the current work
argument-hint: [optional summary of the change]
allowed-tools: Bash(git diff:*), Bash(git status:*), Bash(git log:*), Read, Edit
---

Add an entry to `CHANGELOG.md` under `[Unreleased]` describing: $ARGUMENTS

If no summary was given, work it out from `git diff` and `git diff --cached`.

Rules:

- Pick the right category — `Added`, `Changed`, `Deprecated`, `Removed`,
  `Fixed`, `Security` — and create it under `[Unreleased]` only if absent.
  Keep that category order.
- Write for someone **using the app**, not someone reading the diff. "Stories
  no longer reset when switching tabs" beats "refactor StoryCubit state
  handling".
- One entry per user-visible change. A pure refactor with no user-visible
  effect usually doesn't belong here — say so rather than padding the file.
- Reference a file only when it genuinely helps a reader.

Show the added lines when you're done. Don't touch released sections.
