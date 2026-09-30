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
  `Paint` on a *static* element — see `ActiveTabIndicatorPainter` in
  `lib/shared/widgets/active_tab_indicator_painter.dart`.
- For a simple "active" glow, a plain colour change is safest and is this
  app's existing convention.
- What *is* fine: a static `BoxDecoration` on a plain `Container` /
  `DecoratedBox` that only rebuilds with its parent — the feed card has
  shipped that way since 0.2.0. Use `AppShadows.card(context)`
  (`lib/core/theme/app_theme.dart`, ADR-012) rather than an inline
  `BoxShadow` list; the line not to cross is a blurred shadow whose
  decoration changes per animation frame.

### A hard shadow shows through a transparent button

Under the Ink outline theme (ADR-050), `AppStyle.hardShadow` is a *solid*
copy of the shape, offset a few pixels. Put it under anything whose face is
transparent and the whole shadow shows through the face. When the shadow was
still cream in dark mode, the same colour as the label, "Edit profile" (a
secondary `AppButton`) shipped as a blank cream pill. A black shadow would
blank a dark label the same way.

- Give an outlined element an opaque fill: `AppButton` secondary uses `surf`
  under ink outline, and `InkOutline` fills with `surf` by default.
- A chip that stays transparent when idle gets no shadow (see post card
  `_Pill`: only filled chips lift). `InputGlow` skips the shadow when it has no
  `fillColor`.

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
  `FittedBox(fit: BoxFit.scaleDown)` (see `AppButton`'s full-width label).
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

### A tapped link does nothing on API 30+ without a `<queries>` entry

`url_launcher` asks the OS which app handles a URL, and on Android 11 (API 30)
and up an app can only see packages it declares an interest in. With no
declaration, `canLaunchUrl` answers **false** on a phone that plainly has
Chrome installed, and `launchUrl` throws — so a tap on a link in a post is
silently dead, on a device, with nothing in the analyzer and nothing in the
log that names the cause.

- `android/app/src/main/AndroidManifest.xml` carries `<intent>` entries for
  `ACTION_VIEW` on `https` and on `http`, scheme-only so every web link is
  covered. Don't remove them when tidying the manifest.
- iOS needs no counterpart for `http(s)`. A *custom* scheme would need
  `LSApplicationQueriesSchemes` in `Info.plist` — but `ExternalLink` refuses
  every scheme but `http`/`https`, so that case cannot arise here.
- `ExternalLink.open` returns `false` rather than throwing, and each caller
  decides what to do with that (the showcase and chat link rows fall back to
  copying). A link that does nothing *and* says nothing is the bug this
  replaces.

### Android silences the microphone once the app leaves the screen

A call's audio does not stop when Yello is backgrounded — WebRTC keeps
capturing — but shortly after the app stops being visible Android starts
handing it **silence**, and the screen timing out mid-call counts. Nothing
errors; the other person just stops hearing you about a minute in.
(Documented platform behaviour, designed around before the first call ran —
not yet reproduced on this project's phones.)

- The fix is a foreground service of type `microphone` for the length of the
  call: `CallService.kt`, started by `CallKeepAlive.hold`.
- Start it with `startService` and promote *inside* the service. With
  `startForegroundService` the app is killed if the promotion does not happen
  within seconds — and on Android 14 it cannot happen until RECORD_AUDIO is
  granted, which on a first call is only asked for when WebRTC publishes.
- A foreground service can only be *started* while the app is on screen,
  which is why `hold` runs at dial and answer time, and again once the
  microphone is live, rather than when the app goes to the background.

### Screen capture needs consent, *then* a `mediaProjection` service, *then* capture

Android hands WebRTC a screen capture only while the app runs a foreground
service of type `mediaProjection`, and Android 14 refuses to give a service
that type until the user has accepted the "start recording or casting?"
dialog. The order is fixed: consent (`CallRoom.requestScreenCapture`) →
re-promote `CallService` with the type (`CallKeepAlive.setScreenCapture`) →
create and publish the track. (From the platform docs and flutter_webrtc's
source; not yet reproduced on this project's phones.)

- `startService` returns before the service's `onStartCommand` runs, so
  "started" is not "promoted". `MainActivity.startForScreenCapture` answers
  the channel only once `CallService.onPromoted` reports back (3 s cap) —
  otherwise the capture can race ahead of the type and be refused.
- A consent token captures once on Android 14. flutter_webrtc keeps the last
  one and would reuse it, so ask again before every share
  (`requestCapturePermission` clears it first).
- Ask for `microphone` only when RECORD_AUDIO is granted: on Android 14 a
  refused type fails the whole promotion, screen share included.

## Framework / package versions

### A widget above the router gets neither Back nor predictive back

The call UI sits in `MaterialApp.router`'s `builder`, beside the router's
output rather than on a route (ADR-042). No `PopScope` reaches it there, so
Back pops — or on the Feed tab, *closes* — the app hidden underneath a
full-screen call. (Found by reading the framework's back handling while
building the call UI; confirm on a device before trusting the details.)

- Back: a `ChildBackButtonDispatcher` off the router's own dispatcher, with
  `takePriority()`, is asked first; return `true` to consume. A
  `WidgetsBindingObserver.didPopRoute` does not work — observers are asked in
  registration order and the router's dispatcher registered first.
- Predictive back (Android 14+/16 targets): the OS asks *up front* whether
  the framework handles Back, and the answer comes from the router's
  `NavigationNotification(canHandlePop:)`. On Feed that is `false`, so the
  gesture goes straight to the OS and the dispatcher is never called. Catch
  the router's notifications on their way up and re-dispatch with the
  overlay's own answer OR-ed in — `CallHost._onNavigation`.
- **No `Overlay` either.** The router's `Navigator` owns the app's only
  `Overlay`, and the call UI is its sibling, not its child. Anything that
  floats in one throws "No Overlay widget found" the moment it builds:
  `Tooltip` (including `IconButton(tooltip:)`), menus, dropdowns, text
  selection handles. The group call screen crashed on its first open this
  way (2026-09-30). Name call buttons with `Semantics(label:)` instead
  (`CallRoundAction.semanticLabel`).


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

### A notification channel keeps its first definition — and ids are shared with Kotlin

Android fixes a channel's importance, sound and audio usage when it is first
created; `createNotificationChannel` with the same id later only renames it.
The call ring was first given `yello_calls` — already `CallService.kt`'s
quiet ongoing-call channel — and on the phone it came out LOW importance,
no ringtone, no vibration, with the Kotlin channel now *named* "Incoming
calls". Nothing errors. (Found on the SM-S928B via `dumpsys notification`,
2026-09-30.)

- Grep `android/` for a channel id before taking one: `yello_default`
  (pushes), `yello_calls` (CallService), `yello_incoming_calls` (the ring).
- To check what a phone actually has:
  `adb shell dumpsys notification | grep "mId='<id>'"`.
- A channel already on a device cannot be changed by the app — only a new id,
  or the user in system settings, or an uninstall.

### An action that opens the app cancels its notification by **id only**

`flutter_local_notifications` cancels a notification when one of its actions
is tapped (`cancelNotification: true`), but not the same way for both kinds:
the background receiver (`showsUserInterface: false` — Reply, Decline)
cancels by `(tag, id)`, while an action that opens the activity
(`showsUserInterface: true` — Accept) cancels by **id alone**. A tagged
notification survives that second cancel. (Read in the plugin's
`ActionBroadcastReceiver` / `processForegroundNotificationAction`, v22.3.1.)

- The call ring is therefore drawn **untagged** (`callAlertId`), and an
  insistent ringtone left sounding after Accept is what the tag would cost.
- The Accept handler cancels explicitly as well: the plugin only does it
  when the tap started the activity with that intent.

### iOS: button taps on an alert iOS drew never reach Dart as buttons

`flutter_local_notifications` returns early from `didReceive response` for
any notification it did not schedule itself, and `firebase_messaging` turns
every response to an FCM alert — whichever button — into a plain
`onMessageOpenedApp`. So an APNs alert's action buttons (the `YELLO_CALL`
category's Accept / Decline) cannot be told apart in Dart. Registering the
category anyway would draw a Decline that declines nothing; it is left
unregistered until native `AppDelegate` handling exists (ADR-051).

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

### Keep PNG conversion separate from a GIF's palette source

When generating the notification bells with Pillow, converting and saving the
resting palette image as RGBA before using that same image for the GIF header
corrupted the exported GIF palette (white became cyan). Generate the PNG from
a separate image, as `tool/generate_notification_bells.py` does. Decode every
GIF frame to verify its opaque pixels are exactly the intended black or white;
checking just the source palette misses the export failure.

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

### A presigned sticker link cannot be re-signed on its own

`GET /ws/attachments/{id}` hands back a fresh link for one attachment. There
is **no `GET /ws/stickers/{id}`** — the sticker API's answer for an expired
URL on a message is "load the page again". So the same two equality traps as
a re-signed attachment apply, plus a third:

1. `StickerImage.props` leave `url` out, for the reason ADR-015 gives, so a
   message holding a re-signed sticker is `==` the old one and `emit` drops
   the state. `ChatState.attachmentRevision` is what makes that emit land —
   it counts *both* kinds of link now, not just attachments.
2. `CachedNetworkImageProvider` compares equal on `cacheKey ?? url`, so
   `StickerImageView` needs its `key: ValueKey(url)` to be rebuilt from
   scratch once a link has 403'd. The `cacheKey` still keeps the file cached
   by sticker id, which is the point of having it.
3. Because there is no single-sticker route, `ChatCubit.refreshSticker` has
   to re-read the whole newest history page and pick the one sticker out of
   it. Guarded per sticker id like `refreshAttachment` — without that, an
   image erroring on every frame would hammer the messages endpoint rather
   than a cheap per-id one.

### Clearing the busy set drops `actionError` with it

`ChatState.copyWith` deliberately does not carry `actionError` forward, so
any emit that does not set it clears it. A `finally` that removes the id from
`busyMessageIds` therefore lands *after* the failure emit and wipes the
message — which is fine on screen, because `BlocListener` sees the
intermediate state and shows the snackbar, but means a test asserting on the
final `state.actionError` reads `null`.

- Assert on the stream, the way
  `test/features/chat/chat_cubit_actions_test.dart` does ("a failed action
  surfaces once as actionError, then clears").
- `StickersCubit` clears its busy set *before* folding the result, so there
  the failure is what the last emit carries. Both shapes behave the same for
  a user; only the test differs.

### A non-raw Dart string silently eats a regex's backslashes

`RegExp('''([a-zA-Z][\w:.-]*)\s*=...''')` — triple-quoted, because the
pattern needs both quote characters in it — compiles, runs, and matches the
wrong thing: in a non-raw string `\w` is just `w` and `\s` is `s`, so the
character class became `[w:.-]` and `\s*` became `s*`.

- `flutter analyze` does flag it, as **`unnecessary_string_escapes`, an
  `info`** — which reads like a cosmetic nit and is exactly the kind of line
  that gets skimmed past on a clean-ish run. It is not cosmetic; it means the
  pattern is not the pattern you wrote.
- Every `RegExp` literal in this repo is `r'…'` or `r'''…'''`. Keep it that
  way, and treat that particular `info` as an error.
- Hit writing `LinkPreviewModel._attribute` (ADR-039).

### `flutter analyze` is a floor, not a ceiling

A clean analyzer run says nothing about rebuild scope, list virtualization,
image decode cost, or any of the above. It is the minimum bar before a change
is considered done, not evidence that it's good.

### Scroll jank in a debug build is not a bug report

A debug APK runs JIT-compiled Dart with asserts on, so it stutters whatever
the widget tree looks like. Judge smoothness only on
`flutter build apk --profile` (or `flutter run --profile`). On the Galaxy S24
Ultra (120 Hz), the same 12-swipe run over the home feed (2026-09-30) gave:

| Build   | 8 ms frames | 16 ms | 24 ms | ≥ 33 ms hitches |
|---------|-------------|-------|-------|-----------------|
| debug   | 1410        | 56    | 12    | 12              |
| profile | 1219        | 43    | 4     | 1               |

- Flutter draws into a `SurfaceView`, so `dumpsys gfxinfo` sees nothing.
  Measure with SurfaceFlinger instead: `dumpsys SurfaceFlinger --timestats
  -enable -clear`, scroll with `input swipe`, then `--timestats -dump` and
  read the app layer's `present2present` histogram.
- From Git Bash, set `MSYS_NO_PATHCONV=1` first, or it rewrites
  `/data/local/tmp/...` into a Windows path.

### No emulator in the dev sandbox

There is no device here. A change touching layout, animation, gestures, or the
renderer is **unverified** until someone runs it. Say so plainly rather than
implying it works.
