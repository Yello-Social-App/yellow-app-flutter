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
- What *is* fine: a static `BoxDecoration` on a plain `Container` /
  `DecoratedBox` that only rebuilds with its parent — the feed card has
  shipped that way since 0.2.0. Use `AppShadows.card(context)`
  (`lib/core/theme/app_theme.dart`, ADR-012) rather than an inline
  `BoxShadow` list; the line not to cross is a blurred shadow whose
  decoration changes per animation frame.

### `Row`/`Column` directly in a `Scaffold` slot stretches to fill

A bare `Row`/`Column` placed straight into `bottomNavigationBar`,
`bottomSheet`, etc. inherits Scaffold's *loose* height constraint and expands
to fill it. This app shipped exactly this bug in `BottomNavBar`.

- Fix: wrap in `IntrinsicHeight`, or set `mainAxisSize: MainAxisSize.min`
  (see `tech_filter_sheet.dart:65`).

### `Transform.translate` silently swallows taps past its own box

`RenderTransform.hitTest` inverse-transforms the tap against the child's
**untransformed** size. A `Transform.translate(offset: -N)` therefore only
accepts taps up to `N` px above its natural box — a deeper visual overlap
eats taps with no error and no warning.

- Use `Stack` / `Positioned` (plain doubles, hit-test-safe) for anything that
  must stay tappable across an overlap.

### A `Container` border disappears under an edge-to-edge child

`Container` paints `decoration` *behind* its child. A border in `decoration`
is therefore only visible where nothing covers it — fine while the child sits
inside padding, invisible along any edge the child reaches. `clipBehavior`
makes it worse: the child is clipped to the rounded shape, so it looks
"right" apart from the border quietly vanishing. Bit the feed card's photo
frame (`post_card.dart`) and then the Showcase featured card, whose tinted
hero band fills the card top-to-edge (`project_card.dart`).

- Put the border in `foregroundDecoration` with the same `borderRadius`; keep
  `decoration` for the fill, shadow and the clip shape.

### Fixed-width shimmer rows overflow at 320dp

A loading skeleton is a `Row` of `ShimmerBox(width: N)` sized to what the
real card's text *usually* measures. Real text is ellipsised or sized to a
short count and fits; the fixed widths don't shrink, so a row that is fine
at 360dp throws `RenderFlex overflowed` at 320dp — which is also what a 360dp
phone becomes at Android's larger **Display size** settings. The feed's
`ShimmerPostCard` action row shipped this way.

- Give the trailing box `Flexible` (see `ShimmerPostCard`) or wrap the row in
  `FittedBox(fit: BoxFit.scaleDown)` (see `ShimmerProfileView`).
- `test/shared/widgets/shimmer_skeletons_test.dart` pumps every skeleton at
  320×640 and fails on any overflow — add a new skeleton there.

---

## Framework / package versions

### An FCM push with a `notification` block runs **no Dart** on Android

Android's FCM SDK draws a push that carries a `notification` block straight
into the system tray whenever the app is backgrounded or killed, and calls
nothing: not `onMessage`, not the `onBackgroundMessage` handler. Only a
**data-only** push wakes Dart in that state. (`CHAT_MESSAGE_DELETED` works
today precisely because it is data-only.)

- Anything that has to be *on* a backgrounded notification — an action
  button, a direct-reply field, `MessagingStyle`, a custom grouping — can
  only be attached by the code that draws it, so it needs the push to arrive
  data-only. There is no client-side workaround: you cannot intercept,
  decorate or redraw the OS's alert.
- Don't "fix" a missing reply button by cancelling id `0` and re-showing.
  The handler that would do it never runs on Android for such a push, and on
  iOS — where the handler *can* run alongside a visible alert — it doubles
  the notification. `firebaseMessagingBackgroundHandler` bails on
  `message.notification != null` for that reason.
- iOS is the mirror image: it will not show a data-only push as an alert at
  all, so there the notification block stays and `aps.category` is what adds
  the reply field. See ADR-025 and `docs/BACKEND.md`.

### A notification *action* always runs in the background isolate, even with the app open

`flutter_local_notifications`' `ActionBroadcastReceiver` routes every
`ACTION_TAPPED` to the callback dispatcher in its own `FlutterEngine` and
only ever uses the live method channel for a main-isolate *dismissal*. So on
Android:

- `onDidReceiveNotificationResponse` fires for a tap on the notification
  **body** only. An action tap — including a direct reply — goes to
  `onDidReceiveBackgroundNotificationResponse` whether or not the app is
  running, in an engine with no `sl`, no `AppConfig`, and no access to the
  service's streams.
- Anything the running app has to do in response therefore needs a process-
  wide hop. `PushNotificationService` publishes a `ReceivePort` under
  `IsolateNameServer` (`_replyPortName`) and the reply pings it; a lookup
  that returns null just means no app is running. Don't assume an `emit`,
  a `StreamController` or a `get_it` lookup in an action handler will reach
  anything.
- The action's `PendingIntent` targets that receiver by component, so the
  app's own manifest **must** declare
  `com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver`. Without
  it the button still draws and Send still dismisses the keyboard — the
  broadcast just goes nowhere, silently. Manifest changes need a full
  rebuild and reinstall, not a hot restart.

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

### A field left out of `props` makes a Cubit silently drop the emit

`Cubit.emit` skips a state that `==` the current one, and with `Equatable`
that is decided by `props` alone. `MessageEntity.props` did not include
`senderId`/`fromMe`, so replacing a message with a copy that differed only
in its sender compared equal — `ChatCubit.refreshLatest` "applied" the
server's copy and nothing changed on screen. It surfaced as a test that
could not make `deleteMessage` see its own message.

- When a widget or cubit reads a field, that field belongs in `props` —
  the `attachments`/`reactions`/`groupInvite` additions went in at the same
  time. The deliberate exceptions are presigned URLs (ADR-015), which are
  *not* state.
- In a test, the cubit's `stream` delivers asynchronously: assert on
  `state` right after an `await`ed call, or `await
  Future<void>.delayed(Duration.zero)` before reading what a listener saw.

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

### One `pump(duration)` does not run an animation — it starts it

`tester.pump(const Duration(milliseconds: 300))` advances the clock *and
then* produces the frame, so the widget's `Ticker` takes that frame as its
**start** time: the animation is still at value 0 afterwards, and a following
bare `pump()` adds no elapsed time either. A zoom/settle assertion written
that way fails while the same code works on a device.

- Pump **twice**: `await tester.pump();` to start the ticker, then
  `await tester.pump(<past the duration>)` to run it out — see
  `test/shared/widgets/photo_viewer_test.dart`.
- `pumpAndSettle()` does the same thing implicitly, but is not usable on a
  screen with a `CachedNetworkImage`, whose retry timers never settle.

### `cached_network_image` needs a path_provider stub in widget tests

Any screen that builds a `CachedNetworkImage` reaches for the temp directory
through path_provider on first build, which has no implementation under
`flutter_test` and logs a `MissingPluginException` per frame.

- Stub the channel in `setUp` (see `photo_viewer_test.dart`); the photos
  never load in a test either way, so a fake path is enough.

### `flutter analyze` is a floor, not a ceiling

A clean analyzer run says nothing about rebuild scope, list virtualization,
image decode cost, or any of the above. It is the minimum bar before a change
is considered done, not evidence that it's good.

### No emulator in the dev sandbox

There is no device here. A change touching layout, animation, gestures, or the
renderer is **unverified** until someone runs it. Say so plainly rather than
implying it works.
