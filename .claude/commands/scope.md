---
description: Pin down the task — goal, boundaries, acceptance criteria — into docs/current-task.md
argument-hint: <what you want done>
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(rg:*), Bash(grep:*), Bash(git status:*), Bash(git diff:*)
---

Scope this task: $ARGUMENTS

**Do not plan and do not write code in this command.** It ends with a scope
on disk and nothing else changed.

1. Restate the goal in one or two sentences — what will be true for someone
   using the app when this is done.
2. Set the boundaries explicitly: what is **in**, and what is deliberately
   **out**. Anything nearby that's worth fixing but wasn't asked for goes under
   out, as a finding (`AGENTS.md` §7).
3. Write the acceptance criteria as a markdown checklist, each one checkable —
   by a test, by `flutter analyze`, or by a named action on a real device.
4. Find the 3–6 files most likely touched. Start from `docs/CODEMAP.md`, not a
   sweep of `lib/`; grep only to confirm. One line of reason per file.
5. Check the request against `docs/BACKEND.md`, `docs/GOTCHAS.md` and
   `docs/DECISIONS.md`. If it needs an endpoint that doesn't exist, or would
   undo a recorded decision, say so here rather than discovering it mid-build.

If anything is ambiguous — two readings that lead to different code — **stop
and ask**. Don't pick one and carry on.

Write the result to `docs/current-task.md` under `## Scope`, replacing
whatever an earlier task left in the file (all three sections, not just
Scope). If the old file has unchecked `## Plan` items, say that you're
discarding an unfinished task before you overwrite it. The file's shape:

```
# Current task

Scratchpad for the task in flight. Gitignored; written by /scope, /plan,
/develop and /verify, reset by /ship.

## Scope

## Plan

## Verify
```

Finish by showing the scope and pointing at `/plan`.
