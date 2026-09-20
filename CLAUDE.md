# CLAUDE.md — Yello Social App

Instructions for Claude Code when working in this repository. These rules are
persistent and apply to every session in this project, regardless of what any
single message asks for.

---

## Start here — the read order

This repo carries its own durable context. Read it before searching `lib/`;
re-deriving it by grepping 220 Dart files burns the context you'll need for
the actual work, and lands on a slightly different answer every time.

| # | File | What it gives you |
|---|---|---|
| 1 | `AGENTS.md` | The hard rules, shared with every other AI tool |
| 2 | `docs/ARCHITECTURE.md` | Layers, request lifecycle, where new code goes |
| 3 | `docs/CODEMAP.md` | Generated index: every file, route, DI registration |
| 4 | `docs/GOTCHAS.md` | What already broke on-device — read before any UI work |
| 5 | `docs/BACKEND.md` | Endpoints, envelope, gaps that are permanent |
| 6 | `docs/DECISIONS.md` | Why it is this way, so you don't "fix" a decision |

Then open only the files `CODEMAP.md` points you at. Within a session, trust
what you've already read — don't reopen a file to re-confirm something you
established earlier.

`AGENTS.md` holds everything that isn't Claude-specific, so the rules stay the
same whichever assistant is driving. Where the two files overlap, fix
`AGENTS.md` and let this one defer to it.

**Keeping them true is part of the change, not overhead:**

| When you… | Also do this |
|---|---|
| Add/move/delete a file, route, or DI registration | `bash tool/codemap.sh` |
| Make a user-visible change | `CHANGELOG.md` entry under `[Unreleased]` |
| Make a non-trivial design choice | Append an ADR to `docs/DECISIONS.md` |
| Lose time to a non-obvious trap | Add it to `docs/GOTCHAS.md` |
| Find the backend differs from the docs | Correct `docs/BACKEND.md` |

`bash tool/codemap.sh --check` exits non-zero when the committed map is stale.

Slash commands wired up for this project: `/prime` (load context), `/codemap`,
`/changelog`, `/adr`, `/feature`, `/review`, `/preflight`.

---

## 0. Workflow

**You act as a senior developer with write access, not just a reviewer.**
Concretely:

1. You may modify files (`Edit`/`Write`/`NotebookEdit`, or shell commands that
   change file content) directly — no need to wait for step-by-step approval
   once you've landed on the right change. Reading, searching, running
   `flutter analyze`/`flutter test`, and inspecting the code remain fine to do
   freely, as always.
2. When you spot something worth changing — a bug, a smell, a performance
   issue, a structural improvement — fix it (scoped to what's actually being
   asked; see #4), and say what you changed and why in the response so it's
   easy to review in the diff. For anything non-trivial or risky (a behavior
   change, other call sites affected, something that needs on-device
   verification), call that out explicitly rather than implying it's fully
   confirmed working.
3. If asked to "review", "check", "look at", or "audit" code, that's still a
   request for findings/a report, not an invitation to also apply fixes in the
   same pass — use the reporting format below and let the user decide what to
   do with it. If asked to "fix" or "implement" something, go ahead and make
   the change directly.
4. Keep changes scoped to the request — don't turn a request for one fix into
   an unrelated refactor or cleanup pass nearby; report those as findings
   instead of bundling them into the diff.

### Reporting format (for review/audit findings)

For every finding, give:

```
File: <path>:<line or range>
Current:
  <the exact current code>
Proposed:
  <the exact replacement code>
Why: <one or two sentences — correctness / clean-code / performance reason,
      and what breaks or degrades if it's left as-is>
Risk: <anything the user should know — behavior change, other call sites
       affected, needs on-device verification, etc.>
```

Group multiple related findings under one message, most-impactful first.

---

## 1. Role

Act as a **senior Flutter/Dart developer** reviewing a teammate's codebase:
opinionated about architecture and performance, precise about _why_ something
matters (not just _that_ it's a lint hit), and conservative about churn —
don't propose a rewrite where a two-line fix does the job.

---

## 2. Architecture & clean-code conventions already in place

Follow the existing conventions; flag deviations from them as findings rather
than introducing new patterns of your own.

- **Clean Architecture, feature-first**: `lib/features/<feature>/{data,domain,presentation}`,
  cross-cutting code in `lib/core/{config,constants,network,security,error,usecase,utils,router,theme,di}`,
  shared UI in `lib/shared/{widgets,models,extensions}`.
- **State management**: `flutter_bloc` **Cubits only** (no Bloc/events). One
  Cubit per screen-ish concern; the Cubit and its `State` class live together
  in one file (e.g. `feed_cubit.dart` has both `FeedCubit` and `FeedState`).
- **DI**: hand-written `get_it` (`lib/core/di/injection.dart`) — no
  `injectable`/build_runner. Keep it that way; don't introduce codegen DI.
  Note the existing `registerLazySingleton` vs `registerFactory` choices are
  deliberate (e.g. `FeedCubit` is a singleton so Home-tab state/scroll survive
  tab switches) — check `injection.dart`'s comments before flagging a
  singleton/factory choice as wrong.
- **Networking**: `dio` behind `core/network/api_client.dart` +
  interceptors (`core/network/interceptors/`). Responses are enveloped
  (`{success, data, timestamp}` / error shape) — handle via
  `core/network/api_envelope.dart` / `core/error/error_handler.dart`, don't
  parse raw response bodies ad hoc in a data source.
- **Routing**: `go_router`, guards in `core/router/route_guards.dart`. This
  project's `go_router: ^17.5.0` has `GoRouterState.name` reading `null`
  inside a top-level `redirect` — use `state.matchedLocation` instead; don't
  reintroduce `state.name` in redirect logic.
- **Usecases**: one class per action (`core/usecase/usecase.dart` base type),
  called from Cubits — don't call repositories directly from a Cubit.
- **Formatting**: this repo is hand-written at a consistent **120-column**
  style (no `formatter:` key in `analysis_options.yaml`, so plain
  `dart format` defaults to 80 and will blow up the diff). If a proposed
  change needs formatting, specify `dart format --line-length=120 <file>` on
  just the touched file(s) — never a blanket repo-wide format.
- **Lints**: `package:flutter_lints/flutter.yaml` via `analysis_options.yaml`.
  Treat `flutter analyze` output as a floor, not a ceiling — a clean analyzer
  run doesn't mean the code is idiomatic or performant.

---

## 3. Performance best practices to check for (Flutter/Dart specific)

When reviewing, actively look for these — they're the highest-value class of
finding in a Flutter codebase:

- **Widget rebuild scope**: `const` constructors wherever the widget subtree
  is static; `BlocBuilder`/`BlocSelector` scoped as tightly as possible
  (prefer `BlocSelector` or a `buildWhen` over rebuilding a whole page for one
  field's change); no `BlocBuilder` wrapping more of the tree than the part
  that actually reads state.
- **Lists**: `ListView.builder`/`SliverList.builder` for anything
  variable-length or long — never a `Column`/`ListView` with a fully
  materialized `.map().toList()` of unbounded data.
- **Images**: `cached_network_image` (already a dependency) for any remote
  image instead of a bare `Image.network`; specify `cacheWidth`/`cacheHeight`
  or `memCacheWidth/Height` when displaying a thumbnail-sized rendering of a
  full-resolution source, so decode cost matches display size.
- **Async/rebuild loops**: check for missing in-flight guards on
  double-tappable mutating actions (this codebase already had a real bug here
  — fast double-taps double-firing a reaction endpoint — fixed via a
  Cubit-private `Set`/`bool` pending-flag; look for the same missing-guard
  shape on any new mutating button).
- **Animation-driven widgets**: don't add a blurred `BoxShadow`
  (`BoxDecoration(boxShadow: [BoxShadow(blurRadius: >0)])`) inside an
  `AnimatedContainer` or anything that rebuilds on Cubit state — this crashed
  on-device on this project's Impeller/Android renderer. A `CustomPainter`
  with its own blurred `Paint` on a static element is the safe alternative
  already used elsewhere (`_ActiveTabIndicatorPainter`); for a simple
  "active" glow, a plain color change is safest and is this app's existing
  convention.
- **Layout under `Scaffold` slots**: a bare `Row`/`Column` placed directly in
  `bottomNavigationBar`/`bottomSheet` etc. will stretch to fill the loose
  height constraint Scaffold gives it — wrap in `IntrinsicHeight` or set
  `mainAxisSize: MainAxisSize.min` (this app had exactly this bug in
  `BottomNavBar`).
- **DI lifetime vs. staleness**: a `registerLazySingleton` Cubit that only
  loads once (`if (status == loaded) return;` short-circuit) combined with
  `StatefulShellRoute` keeping branches alive means the data can go stale for
  the rest of the app's life unless something explicitly calls `refresh()` on
  re-entry. Check any new long-lived Cubit for this pattern.
- **`Transform` for overlapping layouts**: `RenderTransform.hitTest`
  inverse-transforms a tap against the child's _untransformed_ size, so a
  `Transform.translate(offset: -N)` can only accept taps up to `N`px above the
  natural box — a deeper visual overlap than that silently swallows taps.
  Prefer `Stack`/`Positioned` (plain doubles, hit-test-safe) over
  `Transform.translate` for anything that needs to remain tappable across an
  overlap.

---

## 4. Project facts worth knowing before proposing a change

- **Mobile-only** (Android/iOS). Do not propose or verify via web/Windows/macOS/Linux
  builds, and don't suggest re-adding those platform folders.
- **Real live backend**, not mocked: `https://api.yello.cachewraith.com`
  (Swagger UI at `/docs`, raw OpenAPI at `/docs/json?api-docs.json`). Two
  satellite services share the host: `yello-chat` (`/ws/...`) and
  `yello-notify` (`/notifications/v1/...` — version *after* the resource,
  which is why both keep their own route holders instead of going through
  `VersionedEndpoints`).
- **Stories and saved posts have no backend at all** — no `/stories` resource
  exists, and bookmarking is `shared_preferences`-backed on-device. Both are
  permanent client-side stand-ins, not placeholders waiting to be wired up.
  **Chat does have a backend** (`yello-chat`), despite what older notes said.
  Full contract and the gap list: `docs/BACKEND.md`.
- Some backend limitations aren't fixable client-side (e.g. comment replies
  can be created but never listed back by any endpoint; no per-notification
  "already responded" field; feed-list vs. single-post endpoints can briefly
  disagree on reaction counts before self-correcting). If a proposed fix
  would require a backend contract that doesn't exist, say so explicitly
  instead of proposing a client-only workaround that can't actually solve it.
- No verification tooling beyond `flutter analyze` / `flutter test` exists in
  this sandbox — there is no emulator here. Say plainly when a proposed
  change is unverified on-device rather than implying it's confirmed working.

---

## 5. Always fine to do freely

Reading files, searching the codebase, running `flutter analyze`, `flutter
test`, `flutter pub get`/`outdated`, `bash tool/codemap.sh` and
`tool/codemap.sh --check`, fetching the live API spec, writing up findings,
and — per §0 — making the actual code changes once you know what they should
be.
