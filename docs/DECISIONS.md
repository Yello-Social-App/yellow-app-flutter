# Decision log

Why the codebase is the way it is. Each entry is short on purpose: the
decision, the reason, and what would justify revisiting it.

**Adding one:** append the next number, never renumber, never delete. If a
decision is reversed, mark it *Superseded by ADR-NNN* and leave it in place —
the record of what was tried is the valuable part.

A new non-trivial unit (a class, a module, a branch point that will grow)
deserves one or two lines here naming the shape of the problem, the candidate
patterns, the one chosen, and why. The simplest construct that works wins; a
pattern earns its place only when there are already two real variants or a
known axis of change.

---

## ADR-001 — Feature-first Clean Architecture

**Status:** Accepted

`lib/features/<feature>/{data,domain,presentation}`, cross-cutting code in
`lib/core`, shared UI in `lib/shared`.

**Why:** the app has 10 largely independent feature areas. Layer-first
(`lib/models`, `lib/screens`, …) would scatter each feature across the tree and
make ownership and deletion hard. Feature-first keeps a change to one feature
inside one directory.

**Revisit if:** the app shrinks to a handful of screens, where the ceremony
would outweigh the isolation.

---

## ADR-002 — Cubits only, no Bloc events

**Status:** Accepted

`flutter_bloc` is used exclusively through `Cubit`. One Cubit per screen-ish
concern; the Cubit and its `State` live in the same file.

**Why:** every interaction here is a direct method call from a widget. Event
classes would add a layer of indirection and a file per screen without buying
traceability we need. Keeping the State beside its Cubit means one file to read
to understand a screen's state.

**Revisit if:** a screen needs event sourcing, replay, or transformer-based
debounce/throttle that `Cubit` genuinely can't express.

---

## ADR-003 — Hand-written `get_it`, no codegen DI

**Status:** Accepted

The whole graph is wired by hand in `lib/core/di/injection.dart`. No
`injectable`, no `build_runner`.

**Why:** the wiring is readable, greppable, and diffable, and it lets each
registration carry a comment explaining its lifetime — which is where the real
knowledge lives. Codegen would hide exactly that. It also keeps the build free
of a generation step.

**Revisit if:** the registration file becomes unmaintainable (it is currently
~130 registrations in one reviewable file).

---

## ADR-004 — `registerLazySingleton` vs `registerFactory` is per-type

**Status:** Accepted

- **Singleton:** repositories, data sources, usecases, services — stateless or
  intentionally shared.
- **Singleton (deliberate, stateful):** `FeedCubit`, so Home-tab state and
  scroll position survive a tab switch under `StatefulShellRoute`.
- **Factory:** screen-scoped Cubits whose state should reset on re-entry
  (`AuthCubit`, `FriendsCubit`, `ProfileCubit`, composer Cubits, …).

**Why:** the tab shell keeps branches alive; a factory Cubit there would
discard scroll position on every switch, and a singleton composer would show
yesterday's draft.

**Cost:** a stateful singleton can serve stale data — see
[GOTCHAS.md](GOTCHAS.md#long-lived-singleton-cubits-go-stale). Whoever adds one
owns the refresh path.

**Revisit per type**, never globally. Read the comment next to a registration
before changing its lifetime.

---

## ADR-005 — `Either<Failure, T>` at the repository boundary

**Status:** Accepted

Data sources throw typed exceptions; repository implementations catch them and
return `dartz` `Either<Failure, T>`. Nothing above the repository throws.

**Why:** failure is an expected outcome of every network call, so it belongs in
the type, not in a `try`/`catch` a caller can forget. Cubits `fold` a result
into a state — the compiler enforces that the error branch exists.

**Revisit if:** Dart's own error-handling story or a sealed-class `Result` in
the SDK makes `dartz` redundant.

---

## ADR-006 — Endpoints in one catalogue, per service

**Status:** Accepted

Core API paths live in `VersionedEndpoints`; `yello-chat` and `yello-notify`
keep their own `ChatRoutes` / `NotifyRoutes` holders.

**Why:** the two satellite services don't follow the `/vN/<resource>` shape
(`/ws/...` and `/notifications/v1/...` — version *after* the resource), so
routing them through `EndpointResolver` would generate wrong paths. One
catalogue per URL convention is the honest modelling.

**Revisit if:** the services converge on one versioning scheme.

---

## ADR-007 — Stories, saved posts, and comment-reply listing stay client-side

**Status:** Accepted (forced)

Stories are an in-memory seed, saved posts live in `shared_preferences`, and
comment replies can be created but never listed back.

**Why:** the backend has no such endpoints. See
[BACKEND.md](BACKEND.md#deliberate-gaps--do-not-fix-these-client-side).

**Revisit when** the corresponding endpoints ship — and not before. Don't
propose a client-only workaround for a missing server contract.

---

## ADR-008 — Generated code map + docs as the AI/onboarding contract

**Status:** Accepted

`docs/CODEMAP.md` is generated by `tool/codemap.sh` and committed;
`ARCHITECTURE.md`, `BACKEND.md`, `GOTCHAS.md` and this log are hand-written;
`CLAUDE.md` / `AGENTS.md` point every assistant at them in a fixed read order.

**Why:** an assistant that greps 220 files each session burns context and
re-derives the same conclusions, differently each time. An index plus a small
set of durable facts makes any model — Claude, or another — start from the same
place and reach consistent answers. Generating the index means it cannot drift.

**Cost:** the map must be regenerated when the tree changes
(`bash tool/codemap.sh`, checked with `--check`).

---

## ADR-009 — The profile screen's overlap is `Stack`/`Positioned`, not `Transform`

**Status:** Accepted

The Profile tab was restructured to a cover/avatar/details layout (modelled on
a mainstream social profile). The avatar, its camera badge and the compose
bubble all overlap the cover, and all three are tappable — so the overlap is
built with `Stack` + `Positioned` and the cover block reserves
`coverHeight + avatarOverhang` of real height. Nothing is shifted with
`Transform.translate`.

**Why:** `RenderTransform.hitTest` inverse-transforms a tap against the
child's *untransformed* box, so a translated widget silently stops accepting
taps past its own edge. This screen already lost a stat tile's tap that way
(see [GOTCHAS.md](GOTCHAS.md)). `Positioned` takes plain doubles and stays
hit-test-safe. `test/features/profile/profile_header_test.dart` pins the two
overlapping tap targets so a future "tidy-up" back to `Transform` fails the
suite instead of shipping.

**Also decided here:**

- The chips filter only the post list, so they sit directly above it —
  the reference screen puts its chips above its details block, which reads as
  if they filtered that too.
- "add status…" became a composer shortcut and the personal-details rows use
  name / username / join date / email / bio / account status. There is no
  status, place, school or employer field on this backend, and inventing
  client-side ones would be fiction.
- The connections face-pile renders even at zero connections: Circle is shell
  branch 1 with no bottom-nav button, so that row (and the account menu's
  "Your circle") are the only ways into it.

**Revisit if:** the API grows real profile-detail fields, or Circle gets its
own nav button.
