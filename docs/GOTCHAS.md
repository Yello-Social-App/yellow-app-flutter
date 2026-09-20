# Gotchas

Things that already broke this app — on a real device, not in the analyzer.
Every entry cost someone a debugging session. `flutter analyze` catches none
of them.

**If you burn time rediscovering something that isn't here, add it here.**
That is the whole point of this file: the next session (or the next AI) should
not pay for the same lesson twice.

---

## Rendering / device

### Blurred `BoxShadow` inside an animated or rebuilding widget → crash

Putting `BoxDecoration(boxShadow: [BoxShadow(blurRadius: > 0)])` inside an
`AnimatedContainer`, or anything that rebuilds on Cubit state, **crashed on
this project's Impeller/Android renderer.**

- Safe alternative already used here: a `CustomPainter` with its own blurred
  `Paint` on a *static* element — see `_ActiveTabIndicatorPainter` in
  `lib/features/shell/presentation/widgets/bottom_nav_bar.dart:422`.
- For a simple "active" glow, a plain colour change is safest and is this
  app's existing convention.

### `Row`/`Column` directly in a `Scaffold` slot stretches to fill

A bare `Row`/`Column` placed straight into `bottomNavigationBar`,
`bottomSheet`, etc. inherits Scaffold's *loose* height constraint and expands
to fill it. This app shipped exactly this bug in `BottomNavBar`.

- Fix: wrap in `IntrinsicHeight`, or set `mainAxisSize: MainAxisSize.min`
  (see `explore_sheet.dart:31`).

### `Transform.translate` silently swallows taps past its own box

`RenderTransform.hitTest` inverse-transforms the tap against the child's
**untransformed** size. A `Transform.translate(offset: -N)` therefore only
accepts taps up to `N` px above its natural box — a deeper visual overlap
eats taps with no error and no warning.

- Use `Stack` / `Positioned` (plain doubles, hit-test-safe) for anything that
  must stay tappable across an overlap.

---

## Framework / package versions

### `go_router` ^17.5.0: `GoRouterState.name` is `null` in a top-level `redirect`

Reading `state.name` inside `AppRouter`'s redirect returns `null` regardless of
the matched route.

- Use `state.matchedLocation`. Don't reintroduce `state.name` in redirect
  logic — see `lib/core/router/route_guards.dart`.

---

## Async & state

### Double-tap double-fires a mutating endpoint

A real bug in this codebase: fast double-taps fired the reaction endpoint
twice. Fixed with a Cubit-private in-flight set.

- Pattern to copy: `FeedCubit._pendingReactions`
  (`lib/features/feed/presentation/bloc/feed_cubit.dart:242`) and
  `PostDetailCubit._pendingCommentReactions`
  (`post_detail_cubit.dart:453`) — `if (!_pending.add(id)) return;` at entry,
  `remove` in `finally`.
- **Check every new mutating button for this shape.** Any tappable action that
  hits the network and isn't disabled during flight needs a guard.

### Long-lived singleton Cubits go stale

A `registerLazySingleton` Cubit that short-circuits (`if (status == loaded)
return;`), combined with `StatefulShellRoute` keeping every branch alive, means
its data can stay stale for the rest of the process lifetime unless something
explicitly calls `refresh()` on re-entry.

- `FeedCubit` is a singleton **on purpose** — Home-tab scroll/state must
  survive tab switches. That's a trade, not an accident. Check
  `injection.dart`'s comments before "fixing" a lifetime.
- Any new long-lived Cubit: decide who re-triggers the load, and write it down.

---

## Tooling

### `dart format` will explode the diff

`analysis_options.yaml` has no `formatter:` key, so plain `dart format`
defaults to **80** columns while this repo is hand-written at **120**.

- Only ever: `dart format --line-length=120 <touched files>`.
- Never repo-wide.

### `flutter analyze` is a floor, not a ceiling

A clean analyzer run says nothing about rebuild scope, list virtualization,
image decode cost, or any of the above. It is the minimum bar before a change
is considered done, not evidence that it's good.

### No emulator in the dev sandbox

There is no device here. A change touching layout, animation, gestures, or the
renderer is **unverified** until someone runs it. Say so plainly rather than
implying it works.
