---
description: Close out a verified task — changelog, docs, commit message, reset docs/current-task.md
allowed-tools: Read, Write, Edit, Bash(git diff:*), Bash(git status:*), Bash(git log:*), Bash(bash tool/codemap.sh), Bash(bash tool/codemap.sh --check)
---

Read `## Verify` in `docs/current-task.md`. **Refuse unless it says
`Result: pass`** — on a fail, a missing section, or a diff that has changed
since the verify ran, say which and point at `/verify`. Don't re-run the
checks here and don't talk yourself past a fail.

Then, in order:

1. **Changelog.** Add one entry under `[Unreleased]` in `CHANGELOG.md`,
   following `/changelog`'s rules — written for someone using the app, in the
   right category. A purely internal change gets no entry; say so instead of
   padding the file.
2. **Docs, now, while the reason is still in context:**
   - architecture or where-code-goes changed → `docs/ARCHITECTURE.md`
   - a design choice that outlives this task → an ADR in `docs/DECISIONS.md`
     (`/adr`'s shape, next number)
   - a trap that cost time → `docs/GOTCHAS.md`
   - the backend differed from the docs → `docs/BACKEND.md`
   - a rule every assistant must follow changed → `AGENTS.md`
   - a file, route or DI registration moved → `bash tool/codemap.sh`

   Most tasks touch none of these. Don't write an ADR to have written one.
3. **Suggest a conventional commit message** (`feat:` / `fix:` / `refactor:` /
   `docs:` / `chore:` …) describing the change and nothing else — no AI or
   model attribution anywhere (`AGENTS.md` §7). Suggest it; don't commit
   unless asked.
4. **Carry forward what's unverified.** Repeat the `unverified on-device`
   lines from `## Verify` in your summary, so they don't vanish with the
   scratchpad.
5. **Reset `docs/current-task.md`** to its empty template:

```
# Current task

Scratchpad for the task in flight. Gitignored; written by /scope, /plan,
/develop and /verify, reset by /ship.

## Scope

## Plan

## Verify
```
