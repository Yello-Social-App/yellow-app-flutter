---
description: Load the Yello project context in the canonical read order before starting work
allowed-tools: Read, Bash(bash tool/codemap.sh --check), Bash(git log:*), Bash(git status:*)
---

Load this project's durable context. Do it by reading, in this order:

1. `AGENTS.md` — the hard rules that apply to every assistant here
2. `docs/ARCHITECTURE.md` — layers, request lifecycle, where new code goes
3. `docs/CODEMAP.md` — the generated index of files, routes, DI registrations
4. `docs/GOTCHAS.md` — what already broke on a real device
5. `docs/BACKEND.md` — endpoints, envelope, permanent gaps
6. `docs/DECISIONS.md` — why the codebase is shaped this way

Then run `bash tool/codemap.sh --check` and `git status` to see whether the
map is current and what's in flight.

Do **not** start grepping `lib/` — these six files are the index. Open source
files only once you know which ones you need.

Finish with a **five-line** orientation summary: what this app is, what state
the tree is in, whether the map is stale, anything in `[Unreleased]` in
`CHANGELOG.md`, and what looks like the natural next piece of work. Then stop
and wait — don't start changing things.
