---
description: Regenerate docs/CODEMAP.md from the source tree and report what moved
allowed-tools: Bash(bash tool/codemap.sh), Bash(bash tool/codemap.sh --check), Bash(git diff:*), Read
---

Run `bash tool/codemap.sh` to regenerate `docs/CODEMAP.md`, then
`git diff --stat docs/CODEMAP.md` followed by `git diff docs/CODEMAP.md` to
see what actually changed.

Report in a few lines: which routes, DI registrations, or files appeared or
disappeared. If nothing changed, say "map was already current" and stop.

If a new file showed up that doesn't fit the layer layout in
`docs/ARCHITECTURE.md` — a Cubit under `data/`, a model under `domain/`, a
`*_1.dart` duplicate — flag it. Don't move it; report it as a finding.

`docs/CODEMAP.md` is generated. Never hand-edit it; fix `tool/codemap.sh`
instead.
