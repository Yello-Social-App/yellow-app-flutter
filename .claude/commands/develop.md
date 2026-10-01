---
description: Implement the next unchecked item in docs/current-task.md's plan
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(rg:*), Bash(grep:*), Bash(flutter analyze), Bash(flutter analyze:*), Bash(flutter test:*), Bash(bash tool/codemap.sh), Bash(dart format --line-length=120:*), Bash(git status:*), Bash(git diff:*)
---

Read `## Plan` in `docs/current-task.md`. If it's missing or empty, say so
and point at `/plan`.

Implement **the next unchecked item only**:

1. Read the files that step names. Trust what `docs/CODEMAP.md` and the scope
   already told you; don't re-derive it.
2. Make the change, following `AGENTS.md` §3 (the hard rules),
   `docs/ARCHITECTURE.md` for where code goes, and `docs/GOTCHAS.md` for
   anything on screen. For a new slice of a feature, copy the shape `/feature`
   describes. 120 columns, by hand.
3. Check the step the way the plan said it could be checked.
4. Tick its box in `docs/current-task.md`.

Then take the next unchecked item, and repeat until none are left.

**If reality diverges from the plan, stop.** A file isn't shaped the way the
plan assumed, an endpoint isn't in `docs/BACKEND.md`, a step turns out to
need a change outside `## Scope` — update `## Plan` (and say what changed and
why) before writing more code. Don't improvise quietly, and don't widen the
scope on your own; a scope change is the user's call.

Stay inside `## Scope`. Something else worth fixing gets reported, not fixed.

When every box is ticked, say so and point at `/verify`.
