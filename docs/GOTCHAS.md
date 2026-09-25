# Gotchas

Things that already broke this app — on a real device, not in the analyzer.
Every entry cost someone a debugging session. `flutter analyze` catches none
of them.

**If you burn time rediscovering something that isn't here, add it here.**
That is the whole point of this file: the next session (or the next AI) should
not pay for the same lesson twice.

---

## Rendering / device

### A half-pinned `Positioned` gives its child **unbounded** height

A `Positioned` inside a `Stack` only gets a tight height when *both* `top`
and `bottom` (or one of them plus `height`) are set. Pin only `bottom` — the
natural way to float a caption above the footer — and the child is laid out
with `maxHeight: infinity`.

- Anything that tries to fill that space throws: `Align`/`Center` without a
  `heightFactor`, `Expanded`, a `Column` with `MainAxisSize.max`. The error
  is a `RenderBox was not laid out` / infinite-size assertion, usually
  pointing at a widget several levels below the `Positioned` that caused it.
- Widgets that size to their content — `Text`, a `Column` with
  `mainAxisSize: MainAxisSize.min`, a `Row` — are fine there.
- Hit while building the story viewer: the full-frame text story pins top
  *and* bottom, so it can centre its text in a real box, while an image
  story's caption pins only its bottom and hands back the bare `Text`. See
  `_StoryText` in
  `lib/features/feed/presentation/pages/story_viewer_page.dart`.

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

### `resizeToAvoidBottomInset: false` makes the keyboard *your* problem

The full-bleed story screens turn the Scaffold's resize off on purpose —
letting it resize reframes the photo, so the composer would no longer preview
the story the way the viewer plays it back. The cost is that **nothing** moves
when the IME opens: every bottom-anchored `Positioned` stays exactly where it
was, behind the keyboard. The composer shipped with the caption field pinned
at `bottom: 96`, so typing a caption was typing blind.

- Fix: each piece of bottom chrome adds the keyboard inset to its own offset
  the same way it already adds the safe-area inset —
  `bottom: 96 + bottomInset + keyboardInset`, with
  `keyboardInset = MediaQuery.viewInsetsOf(context).bottom`. `paddingOf`'s
  bottom already drops to 0 while the IME is up, so the two never double up.
  See `story_compose_page.dart` and `story_viewer_page.dart`.
- Don't reach for `AnimatedPositioned` here — `viewInsets` is already animated
  frame by frame by the platform, and a second curve on top of it lags.
- In a widget test, `tester.view.viewInsets` is in **physical** pixels, so a
  300dp keyboard is `FakeViewPadding(bottom: 300 * devicePixelRatio)`.

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

### An emoji `Text` is not the same size as an `Icon`, or as another emoji

A control that swaps its glyph between `Icon(size: N)` and
`Text(emoji, fontSize: N)` resizes whenever the glyph changes, and the emoji
are not even consistent with each other: `❤️` is U+2764 + a variation
selector, a **text**-presentation glyph with a narrow advance, while `😆`
and `😮` are wide pictographic ones. The like pill shipped this way and
visibly grew and shrank depending on which reaction was active — and because
the swap sat inside an `AnimatedSwitcher`, whose default layout is a `Stack`
sized to the largest child, it also jumped mid-transition.

- Put the glyph in a fixed square: `ReactionGlyphSlot`
  (`features/feed/presentation/widgets/reaction_glyph.dart`) is
  `SizedBox.square` + `FittedBox(fit: BoxFit.scaleDown)`. `scaleDown`, not
  `contain` — it pulls an oversized glyph back in without blowing the small
  ones up to fill the box.
- Give the emoji `height: 1`, or the font's own line spacing pads the slot.
- A bare `SizedBox` is not enough on its own: the child gets loose
  constraints and a too-wide emoji is clipped rather than fitted.
- The same applies to a row of emoji tiles (the reaction picker) — without a
  slot the tiles come out different widths.
- `test/features/feed/reaction_glyph_test.dart` measures every reaction and
  fails if any renders at a different size.

### A fixed-width `CustomPaint` in a chat bubble overflows at 320pt

An incoming bubble is given `MediaQuery.width * 0.78 - 36` (the avatar
column), then spends 30 of that on its own padding — **183pt of content on a
320pt phone**. The voice note's 110pt waveform plus its button, gaps and
length label came to 189pt, so the row was overflowing there *before*
anything was added to it; adding the unheard dot (ADR-037) made it 19pt
worse and loud enough to notice.

- The waveform is the one thing in that row that can give ground, so it is
  the one `Flexible`. Loose fit means `CustomPaint(size: Size(110, 26))`
  still draws at 110 wherever there is room — `constraints.constrain` only
  bites when the free space is smaller — and `_WaveformPainter` already
  resamples the server's values to however many bars fit, so a narrower bar
  is fewer bars rather than a clipped one.
- Once the width is no longer the constant, **the scrub fraction cannot use
  the constant either**: `onTapDown` reads the painted width off the render
  box (via a `Builder`'s context) instead of `_waveWidth`, or a tap on a
  narrow bubble seeks short.
- Do not reach for `LayoutBuilder` here. A voice note sent as a reply is
  wrapped in `IntrinsicWidth` by `_MessageRow`, and `LayoutBuilder` throws
  when a parent asks it for an intrinsic dimension. `Flexible` answers that
  question fine.
- `test/features/chat/voice_note_bubble_test.dart` pumps the bubble at 320pt
  and inside an `IntrinsicWidth` for exactly these two.

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

### `maxScrollExtent` on a `ListView.builder` is an estimate, so one `animateTo` lands mid-list

A builder-backed list only lays out what fits, and extrapolates the rest.
`position.maxScrollExtent` is therefore a guess drawn from the rows built so
far — and it **grows as the scroll itself builds more of them**. A single
`animateTo(maxScrollExtent)` runs at a target that is still moving and stops
partway. With rows as uneven as a chat transcript (a one-word reply, a photo,
an invite card) "partway" is the middle of the history.

- This is what opening a conversation did: it landed mid-transcript instead
  of on the last message.
- Fix: `jumpTo(extent)`, `await WidgetsBinding.instance.endOfFrame`, re-read
  the extent, and jump again until it stops growing — bounded, and it settles
  in two or three frames. See `_pinToBottom` in `chat_page.dart`.
- An `animateTo` is still right for a *new* message arriving at a list that
  is already at the bottom: one more row does not move the estimate.
- `reverse: true` avoids the whole problem and is what a chat list built from
  scratch should do — it was not worth re-deriving run grouping, pagination
  and the quote-jump walk for.

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

### A pushed detail screen leaves the row behind it showing stale counts

Nothing re-fetches a list when a route pushed over it pops. React or comment
on a post's own screen and the card you tapped keeps the counts it had at tap
time — for as long as that screen stays alive, which with a singleton
`FeedCubit` and a `StatefulShellRoute` is the rest of the process.

- The fix in place is ADR-032: the detail screen pops with the entity it
  holds (`PopScope<T>` + `canPop: false`, so the back *gesture* carries it
  too), and the caller applies it — `FeedCubit.replacePost`,
  `<X>Cubit.applyUpdated`. **Any new list → detail → back path needs both
  halves**; each one on its own is silent.
- An applier must swap in place and no-op on an id it doesn't hold, or it
  will resurrect a row that a delete/hide/mute just removed.
- `PostEntity.repostedByMe` never travels between screens — re-derive it from
  the receiving cubit's own `_myRepostIds`. It exists on no wire response, so
  the incoming copy's value is only as good as whatever that screen happened
  to recover.
- Known gap: opening the embedded original inside a repost
  (`RepostedPostPreview`) still leaves that embed stale — the list's row is
  the repost, and what changed is the `originalPost` nested in it.

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

### A re-signed attachment link reaches nothing on its own

`yello-chat` presigns every attachment URL for an hour and re-signs it on
every read, so a stale link 403s and has to be swapped for a fresh one
(`GET /ws/attachments/{id}`, `ChatCubit.refreshAttachment`). Two separate
equality traps sit between that call and a picture on the screen, and both
have to be cleared or the refresh is a no-op:

1. `AttachmentEntity.props` leave `url` out on purpose — the history poll
   re-signs every link, and counting that as a change would make the whole
   transcript look new every few seconds. The cost is that a message holding
   the re-signed attachment is `==` the old one, so the `ChatState` is too,
   and **`emit` drops equal states**. `ChatState.attachmentRevision` is
   bumped alongside `messages` so that one emit lands.
2. `CachedNetworkImageProvider` compares equal on `cacheKey ?? url`, so once
   a `cacheKey` is set the URL is not part of its identity at all. `Image`
   sees the same provider, never re-resolves, and a thumbnail that 403'd sits
   in its error state forever. The widget needs a `key: ValueKey(url)` to be
   rebuilt from scratch — the `cacheKey` still keeps the file cached by
   attachment id, which is the point of having it.

### `flutter analyze` is a floor, not a ceiling

A clean analyzer run says nothing about rebuild scope, list virtualization,
image decode cost, or any of the above. It is the minimum bar before a change
is considered done, not evidence that it's good.

### No emulator in the dev sandbox

There is no device here. A change touching layout, animation, gestures, or the
renderer is **unverified** until someone runs it. Say so plainly rather than
implying it works.
