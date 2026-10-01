---
description: Check the finished task against its scope and record pass/fail in docs/current-task.md
allowed-tools: Read, Edit, Agent, Bash(flutter analyze), Bash(flutter analyze:*), Bash(flutter test:*), Bash(bash tool/codemap.sh --check), Bash(git diff:*), Bash(git status:*)
---

Verify the task in `docs/current-task.md`. If `## Plan` still has unchecked
items, say so and stop — that's `/develop`'s job, not a fail to record.

This is `/preflight` narrowed to the task, plus a review against its scope:

1. `flutter analyze` — clean?
2. **Affected tests only**: `flutter test <paths>` for the test files that
   cover what `git diff` touched (`test/` mirrors `lib/`). Name the paths you
   ran. If the change has no test covering it, say that — it isn't a pass.
3. `bash tool/codemap.sh --check` — map current?
4. Hand the diff to the `flutter-reviewer` subagent. Give it `## Scope` and
   ask it to check the working-tree diff against that scope (every acceptance
   criterion met? anything changed that the scope put out of bounds?) and
   against `AGENTS.md` §3–4 and `docs/GOTCHAS.md`.
5. Go down the acceptance criteria yourself and mark each met / not met /
   **needs a device**.

Record the result under `## Verify`, replacing any earlier run:

```
Result: pass | fail
- analyze: …
- tests: … (paths run)
- codemap: …
- review: … (findings, or "none")
- unverified on-device: … (or "nothing")
```

`Result: fail` on any failing check, any reviewer finding that is a
correctness bug, a hard-rule break or a scope violation, or any acceptance
criterion not met. A fail **blocks `/ship`** — report it with the actual
output and stop.

Criteria that only a real device can confirm don't fail the run, but list
them under `unverified on-device` so `/ship` carries them forward. Don't
imply they were checked.

Fix nothing. This command reports.
