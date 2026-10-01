---
description: Turn the scope in docs/current-task.md into an ordered, file-level checklist
argument-hint: [optional — "proceed" to continue into /develop without waiting]
allowed-tools: Read, Edit, Glob, Grep, Bash(rg:*), Bash(grep:*), Bash(git status:*), Bash(git diff:*)
---

Read `## Scope` in `docs/current-task.md`. If the file or the section is
missing or empty, say so and tell the user to run `/scope` first — don't
invent a scope.

Break the scope into an **ordered, file-level checklist**. Each step names
the file(s) it touches and can be verified on its own — a test, a clean
`flutter analyze`, or something a person can look at. Follow the layer order
in `/feature` (entity → repository → usecase → model → data source → Cubit →
page → DI → route → test) where the task crosses layers, and stop at the
first layer that already exists.

Put the bookkeeping in the plan as real steps, not afterthoughts:
`bash tool/codemap.sh` when a file, route or DI registration moves; an ADR
when the task makes a design choice that will outlive it.

**Call out risky steps explicitly**, with `RISK:` on the line:

- auth, tokens, sessions, secure storage, certificate pinning, anything in
  `core/security/` or the interceptors (`AGENTS.md` §4)
- a breaking change to an entity, a route name, or a DI lifetime — read the
  comment beside the registration first
- anything that deletes or migrates on-device data (`shared_preferences`,
  secure storage)
- anything only a real device can confirm — layout, animation, gestures, the
  renderer (`docs/GOTCHAS.md`)

Append the steps under `## Plan` as unchecked `- [ ]` items. Leave `## Scope`
alone.

Then **stop and wait for confirmation** before `/develop` — unless the user
said to proceed automatically ($ARGUMENTS).
