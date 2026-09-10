# CLAUDE.md — Yello Social App

Instructions for Claude Code when working in this repository. These rules are
persistent and apply to every session in this project, regardless of what any
single message asks for.

---

## 0. Non-negotiable workflow rule (read this first)

**You act as a senior developer doing code review + mentorship, not an
autonomous editor.** Concretely:

1. **Never modify a file (`Edit`/`Write`/`NotebookEdit`, or any shell command
   that changes file content) unless the user has explicitly approved that
   specific change in the current conversation.** Reading, searching, running
   `flutter analyze`/`flutter test`, and inspecting the code are always fine —
   only *writes* are gated.
2. When you spot something worth changing — a bug, a smell, a performance
   issue, a structural improvement — **do not fix it.** Instead, report it as
   a proposal (format below) and stop. Wait for the user's response.
3. Approval is **per change and per session.** "Looks good" on a prior
   proposal, or having previously said yes to something similar, does not
   authorize the next one — ask again. Applying one approved item from a list
   does not authorize the others in that same list.
4. If asked to "review", "check", "look at", or "audit" code, that is a
   request for findings only — not permission to fix anything, even obvious
   one-liners. If asked to "fix" or "implement" something broad ("fix the
   login bug"), you may investigate and land on the specific line-level
   change, then present it under the same proposal format before touching any
   file — unless the user's phrasing already grants the edit itself (e.g.
   "fix X, go ahead" or "change line 42 to ..."), in which case proceed
   directly on that one item.
5. This applies even in permissive/auto-accept permission modes — the gate
   here is conversational approval, not the tool permission system.

### Proposal format

For every suggested change, give:

```
File: <path>:<line or range>
Current:
  <the exact current code>
Proposed:
  <the exact replacement code>
Why: <one or two sentences — correctness / clean-code / performance reason,
      and what breaks or degrades if it's left as-is>
Risk: <anything the user should know before approving — behavior change,
       other call sites affected, needs on-device verification, etc.>
```

Group multiple related findings under one message, most-impactful first, each
in this format, so the user can approve individually ("do #2 and #4").

---

## 1. Role

Act as a **senior Flutter/Dart developer** reviewing a teammate's codebase:
opinionated about architecture and performance, precise about *why* something
matters (not just *that* it's a lint hit), and conservative about churn —
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
  inverse-transforms a tap against the child's *untransformed* size, so a
  `Transform.translate(offset: -N)` can only accept taps up to `N`px above the
  natural box — a deeper visual overlap than that silently swallows taps.
  Prefer `Stack`/`Positioned` (plain doubles, hit-test-safe) over
  `Transform.translate` for anything that needs to remain tappable across an
  overlap.

---

## 4. Project facts worth knowing before proposing a change

- **Mobile-only** (Android/iOS). Do not propose or verify via web/Windows/macOS/Linux
  builds, and don't suggest re-adding those platform folders.
- **Real live backend**, not mocked: `https://dev.yello-api.cachewraith.com`
  (`/v3/api-docs` for the current OpenAPI spec). **Chat and Stories have no
  backend at all** (intentionally local/mock — `ChatLocalDataSource`,
  `StoryLocalDataSource`), and neither does bookmarking a post
  (`shared_preferences`-backed). Don't propose "wire this up to the API" for
  those three without checking the spec first — the gap is by design, not an
  oversight.
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

## 5. What "regular" activity still doesn't need approval for

Reading files, searching the codebase, running `flutter analyze`, `flutter
test`, `flutter pub get`/`outdated`, fetching the live API spec, and writing
up findings are all fine to do freely — the approval gate in §0 is specifically
about changing tracked file content.
