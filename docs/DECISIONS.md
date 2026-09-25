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

## ADR-009 — On-dark surfaces read the dark token set, not the active theme

**Status:** Accepted

The Inbox header is a slab that stays dark in **both** themes (like the
bottom nav, which already uses `AppColors.shell`). Everything drawn on it —
ink, secondary ink, hairlines, the compose button's fill — is read from the
const `AppColors.dark` set through a file-local `_onSlab` alias, not from
`AppColors.of(context)`.

**Why:** `AppColors.of(context).ink` is near-white in dark mode. A
permanently dark surface that colors its contents from the active theme
therefore inverts itself — white text on a white slab — the moment the user
switches themes. Pinning the on-dark contents to the dark token set is what
"on a dark surface" means in this palette, and it keeps the values as design
tokens rather than hex literals sprinkled through the widget.

**Cost:** two token sets are in play in one file, so a reviewer has to notice
which is which. The `_onSlab` name and its doc comment exist to make that
obvious at every use site.

**The one exception in that file** is the search field, which is bright in
light mode (the design's white pill on the dark slab) and inset-dark in dark
mode, so it branches on `Theme.of(context).brightness`. A pinned-bright pill
would be the loudest thing on a dark screen.

**Revisit if:** a third surface needs the same treatment — at that point the
alias belongs in `app_colors.dart` as a named `AppColors.onShell` rather than
being redeclared per file.

---

## ADR-010 — Badge polling is two-tier and branch-gated, not a flat 5s

**Status:** Accepted

`MainShellPage`'s inbox timer was `Timer.periodic(5s)` firing both
`MessagesCubit.refresh()` (`GET /ws/conversations`) and
`NotificationsCubit.refreshUnreadCount()` (`GET /notifications/v1?unread=true`)
from every tab. It now runs at 10s while the Inbox branch is on screen and 30s
everywhere else, and the Signals count is fetched only on the branches that can
display it — Feed (whose app bar carries the dot) and Signals itself, plus
once on re-entering Feed.

**Why:** the old shape cost ~24 requests/minute sitting idle on the feed, and
the notifications half is not a single cheap call.
`NotificationRepositoryImpl.getUnreadCount` deliberately ignores
`NotifyRoutes.unreadCount` and walks *every* unread page instead, so the badge
applies the same `isSignal` filter as the rows — meaning one tick is one
request per 20 unread notifications. Paying
that from Circle or Profile, where nothing renders the count, bought nothing.
Splitting the cadence keeps the Inbox list feeling live where its staleness is
actually visible.

**Cost:** the Inbox dot can now lag up to 30s behind on a non-Inbox tab, and
the Signals dot up to 30s on Feed. Push updates and app resume still call
`_refreshActivity()` immediately, so a real event does not wait for a tick.
The cadence is branch-dependent, which means `didUpdateWidget` has to re-arm
the timer when crossing into or out of the Inbox branch — one more thing to
keep right if the branch indexes change.

**Do not** "simplify" `getUnreadCount` back onto
`/notifications/v1/unread-count` to make the tick cheap. That endpoint counts
notification types Signals hides, so the dot would light up for rows the list
never shows. Closing this properly needs a server-side count that accepts a
type filter — a backend change, noted in
[BACKEND.md](BACKEND.md#known-backend-limitations-not-solvable-in-this-repo).

**Revisit when** `yello-chat`'s socket delivers conversation-level updates (it
already carries per-message delivery). At that point the `MessagesCubit` half
of the tick is redundant and the timer can drop to a Signals-only safety net.

**Addendum (2026-09-22):** the tick now also stands down while a full-screen
overlay covers the shell (`ModalRoute.isCurrent` is false — a chat, a post, a
profile, a composer). By this ADR's own rule nothing on screen can show
either count then. The one thing the 10-second list fetch *was* feeding
inside a chat — the "Read" ticks, computed from participants'
`lastReadMessageId` on the inbox row — now comes from
`GET /ws/conversations/{id}` at the same cadence, folded into
`ChatCubit.refreshLatest` (`detailRefreshInterval`), which is lighter than
the whole list and also picks up group renames, photos and member changes
made by others. The chat screen refreshes the list once as it closes.

---

## ADR-011 — Explore is a shell branch holding Communities and Showcase

**Status:** Accepted

The bottom nav's Explore slot is now a real tab: branch 5 of the
`StatefulShellRoute`, holding `/communities` (its initial location) and
`/showcase`. Tapping Explore lights the slot, moves the indicator, and shows
Communities with the bar still on screen — the same behaviour as Feed, Inbox
and Profile. The page title on both screens is `ExploreTitleMenu`
(`lib/shared/widgets/`): the usual `YelloWordmark` with a chevron, opening a
`MenuAnchor` listing the two screens with the current one ticked. Picking the
other one is a `goNamed` into the same branch, so the page swaps in place
(`NoTransitionPage`, so it reads as a tab change) and Explore stays lit.

**Why:** the slot went through two shapes that were both wrong on-device.
First a two-row sheet (`explore_sheet.dart`, deleted) asking Communities or
Showcase before showing anything — a modal question in front of every visit.
Then a bare `pushNamed` of Communities over the shell — which hid the bottom
nav and never lit the slot, so Explore did not feel like a tab at all. Both
screens sharing one branch is what lets a single slot stay active for either
view: the alternative — two branches — would need two slots, and the bar has
none to spare.

**What it changes elsewhere:**

- Communities and Showcase lost their back arrows. They are tab screens now;
  Back on them means "hop to Feed", handled by `MainShellPage`'s `PopScope`
  exactly as on every other tab. `Navigator.maybePop` on a one-route branch
  navigator is a no-op anyway, so the arrow would have done nothing.
- Anything that used to `pushNamed`/`pushReplacementNamed` the hubs must `go`
  instead — a branch route cannot be pushed over the shell.
  `CommunityPostRouteFallback`'s "Browse communities" is the one such site.
- The sub-screens — community detail, thread, composer, project detail,
  publish — stay root-level `_overlayRoute`s pushed over the shell, like a
  post detail is for the feed. `/communities` in the branch has no children,
  so go_router treats it as an exact match and `/communities/:slug` still
  resolves to the overlay.
- Reselecting Explore resets to Communities (`goBranch(initialLocation:
  true)` on a reselect, in `_selectBranch`); switching away and back keeps
  whichever of the two was showing.

**Cost:** Showcase is three taps from the nav (Explore, title, Showcase)
instead of the sheet's two, and its entry point is a title with a chevron
rather than a labelled row — less discoverable. The branch order in
`AppRouter` is now load-bearing in one more place (`_slotForBranch`'s `5: 1`),
pinned by a test in `bottom_nav_bar_test.dart`.

**Do not** put a third Explore screen in its own branch or revive the sheet.
Add it to `ExploreDestination` and to the same branch; the title menu lists
the enum.

---

## ADR-012 — Card depth is one shared two-layer shadow token, black-based

**Status:** Accepted

Every content card on a page — feed post, Stories rail, create-post prompt,
community row/post, project card, profile header and stat tiles, connection
groups, search rows, settings groups, the post-detail header — takes its
`boxShadow` from `AppShadows.card(context)` in `lib/core/theme/app_theme.dart`,
next to `AppRadii` and `AppSpacing`. Nothing declares its own `BoxShadow`
list for card chrome any more.

The token is two layers: a wide, soft *key* shadow (blur 24, offset `(0,
10)`, spread `-4`) that sells the lift, plus a tight *contact* shadow (blur
6, offset `(0, 2)`) that anchors the bottom edge. Both are
`Colors.black` at a per-brightness alpha (10% / 5% light, 50% / 30% dark).

**Why:**

- The page background and the card fill are both pure white in light mode
  (`AppColors.light.bg == surf`), so a card's depth has to come from its
  shadow — the 1.5px hairline border only outlines it. The single 6%
  `ink` shadow the feed card had was invisible enough that the cards read as
  drawn-on, which is the complaint that prompted this.
- Two layers instead of a stronger single blur: one wide blur turned up
  reads as a grey smudge under the card; the pair reads as a real object
  above a surface. The negative spread on the key layer keeps the sides
  from growing a halo.
- Black, not the `ink` token: `ink` is near-white in dark mode, so an
  `ink`-based shadow becomes a glow there. `BottomNavBar` already made this
  call; the token makes it the rule rather than something each site has to
  remember.
- One token, not three copies: the feed card, Stories rail and the shimmer
  skeleton each carried the same literal shadow. The skeleton in particular
  must match the real card exactly so posts don't "pop" when they swap in —
  a shared token is the only way that stays true.

**Renderer note:** this is a static `BoxDecoration` on a plain `Container` /
`DecoratedBox` — the same shape the feed card has shipped with since 0.2.0.
The Impeller crash in `docs/GOTCHAS.md` was a blurred shadow inside an
`AnimatedContainer` re-decorated per frame. Do not move `AppShadows.card`
into anything animated; for an animated "active" cue keep using a colour
change.

**Do not** hand-tune a card's shadow inline. If a surface genuinely needs a
different depth (a sheet, a floating button), add a second named token to
`AppShadows` and say what it's for.


---

## ADR-013 — Loading skeletons mirror the card they stand in for, and live beside it

**Status:** Accepted

Every list or page with a distinctive row shape gets its own shimmer
skeleton, built to that row's exact geometry and kept next to the row it
mirrors in the feature's `presentation/widgets/`:

| Real widget | Skeleton |
|---|---|
| `PostCard` (feed, profile tabs) | `ShimmerPostCard` (`shared/widgets/shimmer_loading.dart`) |
| `CommunityPostCard` | `ShimmerCommunityPostCard` |
| `_CommunityCard` (directory) | `ShimmerCommunityCard` |
| `ProjectCard` | `ShimmerProjectCard` |
| `_ResultRow` (people search) | `ShimmerSearchResultRow` |
| Profile / public-profile page | `ShimmerProfileView` |

`PagedListView` takes the skeleton as a `skeleton:` list and lays it out with
the same `separatorHeight` as the rows. `ShimmerListCard` stays as the
default for screens whose rows really are "avatar, two lines, a block"
(Inbox, Circle, Signals) and for the project detail body. A community's own
screen shares `ShimmerCommunityPostCard` with the timeline, chip hidden, the
way it shares the card. `ShimmerBox` is the one shared primitive.

**Why:**

- One generic card under every list meant the placeholder never occupied the
  space the real rows would: a directory card is 68px of cover plus an
  avatar breaking out of it, a search row is 70px tall with no block at all,
  and the profile is a cover, a header card, three stat tiles and a tab bar
  before the first post. Each of those visibly re-flowed the moment real
  data landed. `ShimmerPostCard` had already solved this for the feed; this
  extends the same rule to the other screens rather than leaving it a
  feed-only nicety.
- Profile showed a lone `CircularProgressIndicator` on an empty background
  and then cut to a full page. A page-shaped skeleton reads as "your profile
  is coming" instead of "something is spinning".
- Beside the real widget, not in `shared/`: a skeleton is a copy of one
  card's measurements, so whoever changes the card is looking at the file
  next to it. `ShimmerPostCard` predates this rule and stays in `shared/`
  because two features (feed, profile) render `PostCard`.

**Cost:** each skeleton is a second copy of its card's spacing that has to
be updated by hand when the card changes — there is no shared source of
truth for the numbers. The doc comment on each skeleton lists exactly which
measurements it copies, so a card change has a checklist.

**Do not** reach for `ShimmerListCard` when adding a screen whose rows
aren't that shape; build the matching skeleton, pass it to `PagedListView`'s
`skeleton:`, and add it to `test/shared/widgets/shimmer_skeletons_test.dart`
(see the 320dp gotcha in `docs/GOTCHAS.md`).

---

## ADR-014 — Showcase tech filter is a chip row *and* a sheet; featured projects get a hero card

**Status:** Accepted

The Showcase's tech facet (`GET /projects/tech`) is presented twice:
`TechChipRow` under the sort control shows "All" plus the
`kTechChipRowMax` (8) busiest tags, sorted by project count, and a trailing
button opens `showTechFilterSheet` — the complete list with counts, plus the
Featured-only toggle. A tag chosen from the sheet that is not among the
busiest is inserted at the front of the row, so the active filter is always
on screen and clearable in place. The facet is labelled **Tech** everywhere
(it was "Language").

A project with `isFeatured` renders as a hero inside the same `ProjectCard`:
a `yelb` band holding a FEATURED pill, the name on its own line at
`titleLg`, and a 56px emoji tile; tagline, tech and footer below. Every
card caps visible tech at `kProjectCardTechVisible` (3) plus a "+N" pill,
and the footer carries author, the like pill, views and — when the backend
resolved one — the upstream star count. A short, unfiltered list (≤ 2
projects, nothing more to page in) ends with `PublishNudgeCard`.

**Why:**

- The row-only shape was dropped earlier because anything past the third
  chip scrolled off-screen, and the sheet-only shape that replaced it hid
  *every* tag behind a tap labelled "Language". This is the hybrid: the
  common filters are one visible tap; the long tail and the counts are one
  more. The earlier objection — a filter the user cannot see is one they
  cannot use — is answered by the sheet still being the complete list, not
  by the row.
- Sorted by count rather than the server's order because the row has room
  for eight and the point of it is the *busiest* tags; the sheet keeps
  whatever order the server sends.
- The old featured treatment (yellow border, "FEATURED" in 9px beside the
  name) competed with the name for the same line and truncated it — a
  featured project's own name was the first thing to be cut. The band gives
  the mark its own row and the name the full width.
- Star count was in the footer meta as text before; it is now a stat with an
  icon beside views, because `sort=stars` orders by it and a sort with no
  visible key reads as arbitrary.
- No link button on the card, though the mock had one. The app has no
  `url_launcher` (see the detail page's copy-to-clipboard rows), so it could
  only copy the URL, and the footer has no width to spare at 320dp with a
  like pill, views and stars already in it. If `url_launcher` is ever added,
  an "Open" button belongs on the detail page first.
- The page title keeps `ExploreTitleMenu` / `YelloWordmark` (ADR-011) rather
  than the plain ink title the mock drew — every tab title uses the brand
  stroke, and changing one page alone would make Showcase the odd one out.
  A subtitle line (the `ExploreDestination.subtitle` copy) was added under it.

**Cost:** the row and the sheet are two surfaces for one filter, and the
row's "insert the selected tag" rule is one more thing to keep in sync with
`ShowcaseCubit.setTech`'s tap-again-to-clear behaviour. `ShimmerProjectCard`
mirrors the standard card only; a featured hero swaps in taller than its
placeholder, which is accepted because there is at most one per list.

**Do not** bring the Featured toggle out of the sheet into the row — it is a
different kind of filter (a boolean, not a facet) and the row is already the
widest thing on the screen. **Do not** raise `kProjectCardTechVisible` past
three without checking a 360dp device: four 24-character tags wrap.

---

## ADR-014 — Chat's new features ride HTTP; the socket vocabulary is decoded but not transported

**Status:** Superseded in part by ADR-017 (the transport is now wired; the
HTTP-first rule for *requests* stands)

Reply, edit, delete, react, attachments, groups and invite cards all go
over `yello-chat`'s HTTP routes (`ChatRoutes`), and the chat screen keeps
its 5-second history poll. Every server → client socket frame the service
documents is modelled as a `ChatEvent` and decoded by `ChatFrameDecoder`
(`chat/data/datasources/`), and `ChatCubit` handles all of them — but
`ChatRepository.watchEvents` still returns an empty stream.

**Why:**

- The service's own guide calls HTTP the fallback "for clients without a
  socket" and says every change is additive, so HTTP alone is a complete,
  supported client. Edit, delete and react each answer with the state the
  screen needs (`200 Message`, `204`, `{ messageId, reactions[] }`), so
  nothing waits on a fan-out frame.
- The socket's `auth` handshake is specified only in the service
  repository's README (`/ws/docs-json` says so explicitly), which this repo
  does not have. Guessing the frame shape and shipping a client that
  cannot be verified on a device is worse than not shipping it.
- Decoding is fully specified — the frame table is the whole contract —
  and unit-testable without a socket (`chat_frame_decoder_test.dart`).
  Keeping it apart from the transport means the day the handshake is
  known, the change is one place: connect, send `auth`, pipe frames
  through `decode`, and the cubit already does the right thing.
- The poll is what delivers other people's edits, deletes and reactions
  meanwhile: `refreshLatest` replaces every local copy with the server's,
  so a tombstone or a new reaction shows within a tick without any new
  code path.

**Cost:** live-only signals — `typing`, `presence`, `conversation.updated`'s
"Alice added Bob" line, `conversation.removed` — do not reach the screen
until the socket does. A removed member finds out on their next request
(404), not instantly. And the poll's cost stands (ADR-010's reasoning
applies here too).

**Do not** wire `dart:io`'s `WebSocket` with a guessed `auth` frame to
close this. Get the README's frame reference first; then the change belongs
in `ChatRepositoryImpl.watchEvents`, nowhere above it.

---

## ADR-015 — Attachment identity is the id; presigned URLs are not state

**Status:** Accepted

`AttachmentEntity`, `GroupInviteCardEntity` and `ConversationEntity` leave
their presigned `url` / `photoUrl` out of `props`, and every image widget
keys the image cache by attachment id (`CachedNetworkImage(cacheKey:
attachment.id)`), not by URL.

**Why:** the links are re-signed on every read and expire after an hour.
The chat screen re-fetches history every 5 seconds, so with URL-keyed
equality every poll would mark every message "changed" and every picture
a cache miss — a full re-download of the transcript's images every tick.
Keyed by id, a poll is a no-op for the image cache and the bubble only
rebuilds when something the user can see changed. `ConversationEntity`
compares `hasPhoto` instead, so a photo being set or removed still counts.

**Cost:** an attachment whose *file* changed under the same id would show
the stale image. The service never does that (a message's files are fixed
at send time; a delete removes them), so this is theoretical.

**Expiry** is handled the other way round: a picture that fails to load
past `urlExpiresAt` asks the cubit for a fresh link (`GET
/ws/attachments/{id}`), guarded per id so a genuinely broken file cannot
loop on the endpoint.

**Group photos and invite-card photos** go through `AppAvatar`, which keys
by URL unless given `cacheKey:`. They carry no id of their own, so the key
is the object's address with the signature stripped
(`presignedObjectKey`, `core/utils/presigned_url.dart`), exposed as
`ConversationEntity.avatarCacheKey` / `GroupInviteCardEntity.photoCacheKey`.
Shipped without it, the chat header re-downloaded the group photo on every
10-second inbox refresh — the exact symptom this ADR exists to prevent.
Any new surface that shows a presigned picture must pass a key.

---

## ADR-016 — An unsend push takes the chat alert down on the conversation, not only the message

**Status:** Accepted

`CHAT_MESSAGE_DELETED` is a data-only push. The notify guide says: find the
alert shown under tag `chat:<conversationId>`, and cancel it *if it is for
that `messageId`*. `PushNotificationService` keeps that record only for
alerts it showed itself (foreground), and for an OS-drawn alert (background
push, where the FCM SDK drew it) cancels on the conversation tag alone.

**Why:** an OS-drawn Android notification exposes its tag and id but not
the `data` it was drawn from, so "is it for this message" cannot be
answered there. The two failure modes are not symmetric: leaving a stale
alert up shows text its sender chose to unsend — exactly what the push
exists to prevent — while taking down a newer alert for the same
conversation costs one tap to rediscover a message that is still there.

**Cost:** in the background path, a newer message's alert in the same
conversation can be dismissed by an older message's unsend. iOS exposes no
id for an OS-drawn alert at all, so only locally shown ones come down
there — the "best effort" the guide asks for.

---

## ADR-017 — The socket is delivery only; every request still goes over HTTP

**Status:** Accepted

`ChatSocket` connects to `wss://…/ws`, authenticates with the stored access
token, and hands raw frames to `ChatRepositoryImpl.watchEvents`, which
filters them to one conversation and decodes them. The only client → server
frames this app sends are `auth` and `typing`. Sending, editing, deleting,
reacting, reading — all of it stays on the HTTP routes.

**Why:**

- The handshake ADR-014 was waiting on turned out to be recoverable from
  the service itself: send an incomplete `auth` frame and its
  `VALIDATION_ERROR` names the missing field (`token`). `tool/ws_probe.dart`
  is that experiment, kept so the next unknown frame can be answered the
  same way. With the handshake known, refusing to connect no longer bought
  anything.
- Typing has no HTTP path at all — it *is* the feature the socket was for.
  Live message, edit, delete and reaction delivery come for free once the
  connection exists, since `ChatCubit` already handled every frame.
- Keeping requests on HTTP keeps one error path (`ErrorHandler` and the
  envelope-free chat body) and one idempotency story (`clientId` on
  `POST …/messages`). A socket `message.send` would add a second way to
  send with a second failure mode (a frame with no reply) for no gain.
- The socket's lifetime is tied to subscription: the first `watchEvents`
  listener opens it, the last one closing it drops the connection. An open
  chat screen is the only thing that needs live delivery today, so nothing
  holds a connection from the Inbox or the shell.

**Cost:** a second long-lived connection per open chat, reconnecting with
backoff on every drop; and one unverified guess — the `typing` frame's
field names (`{ conversationId, isTyping }` out, `userId` +
`isTyping`/`typing` in), which the probe cannot check without a real token.
A wrong name surfaces as a logged `error` frame, not a crash, and is a
one-line fix.

**What it changes elsewhere:** the chat screen's history poll is now a
safety net — 30 s while the socket is up, 5 s when it is not
(`_pollLive` / `_pollFallback`). `ChatState.isLive` is how it knows. The
Inbox is untouched: ADR-010's poll still owns the list, until
`conversation.*` frames are routed to `MessagesCubit` too — the obvious
next step, not taken here.

**Do not** move sends onto the socket for latency. The HTTP round trip is
not what a user waits on; the optimistic bubble is already on screen.

---

## ADR-018 — The date eyebrow is a shared widget, and Inbox carries its unread count on that same line

**Status:** Accepted

Every tab's landing screen — Feed, Explore (Communities and Showcase) and
Inbox — opens with the same uppercase `WEDNESDAY · SEP 22` line above its
title. The widget that draws it lives in `lib/shared/widgets/date_label.dart`,
not on any one page.

**Why:** it started private to `feed_page.dart` as `_DateLabel`, and the
moment a second screen wanted it, `communities_page.dart` reached across a
feature boundary for it with a `package:yello_social_app/features/feed/…`
import of a *page*. Three screens in, that is shared UI by definition
(ADR-001), and `shared/widgets` is where it belongs. The long doc comment
explaining why the label is a separate sliver from `_FeedAppBar` rather
than living inside the `SliverAppBar` moved with it — that history is the
reason the widget has the shape it does, and it was the thing most likely
to be lost in the move.

**Why the unread count folded into the date line on Inbox:** the header slab
already had one `metaMono` eyebrow above the `Inbox` wordmark, spending it on
`3 UNREAD`. Stacking the date above it would have put two mono rows between
the top of the slab and the title, which reads as a stack of labels rather
than one eyebrow. The date line already joins its own parts with `·`, so the
count is appended behind the same separator: `MONDAY · SEP 22 · 3 UNREAD`.
That is what `DateLabel.trailing` is for, and it is the only reason it
exists — it is not a general-purpose slot.

**Cost:** the joined line is the widest thing in the slab's title column,
sharing the row with the compose button, and its longest form is
`WEDNESDAY · SEP 23 · ALL CAUGHT UP`. What is guaranteed is that it wraps
inside its slot rather than throwing a RenderFlex overflow
(`test/shared/widgets/date_label_test.dart`); whether it *needs* to wrap on
a 320 dp phone is **unverified** — a widget test cannot answer it, because
`flutter_test`'s default font gives every glyph a full em of width and so
measures the line far wider than Geist renders it. A trailing string longer
than these two wants a look on a narrow device. **Unverified on-device.**

**`color` exists for one caller.** The slab is dark in *both* themes
(`_onSlab`, see `messages_page.dart`), so it cannot let `DateLabel` read
`AppColors.of(context).ink2` — in a light theme that paints a dark grey on a
dark slab. Everywhere else the default is correct and nothing passes it.

---

## ADR-019 — A tapped post photo opens a full-screen zoomable viewer, owned by the carousel

**Status:** Accepted

Every post photo in the app is drawn by `PostImageCarousel` — the feed card,
a post's own screen, and the repost preview embedded in both. Tapping one now
opens `PhotoViewerPage` (`lib/shared/widgets/photo_viewer_page.dart`): full
screen on black, the photo fit to the screen, pinch and double-tap zoom to 5x,
swipe across the rest of the post's photos, tap or the close button to leave.

**The tap is handled inside the carousel, not passed in.** The old
`PostImageCarousel.onTap` is gone. It had exactly one caller passing anything
(`PostCard`, which opened the post), and the two other surfaces passed
nothing at all — so two of the three places a photo appeared were dead to a
tap. Owning the gesture means a new screen that renders post photos gets the
viewer for free and cannot forget to wire it; the carousel is also the only
thing that knows *which* photo is showing, which is the photo the viewer has
to open on.

**What the feed card's photo tap used to do** was open the post. The header,
the body text and the comment chip still do, and the photo is the one part of
the card that is cropped and scaled down — "expand it" is the more useful
meaning for that tap, and matches what every other social app does with it.

**Why a route and not a dialog:** `showDialog` would have put the viewer
outside `go_router`'s stack, and nothing else in this app navigates
imperatively. It is a normal pushed page (`/photo`, `RouteNames.photoViewer`)
with its own fade transition rather than `_overlayRoute`'s slide-up — a
lightbox belongs over a still screen — and `opaque: false`, so what is behind
keeps painting through the fade.

**It takes `extra`, so it is not deep-linkable.** Photo URLs are long and
plural; they do not fit a path, and there is no id to rebuild them from. A
cold `/photo` therefore renders a "no longer available" state instead of
crashing on a bad cast. Nothing links to it from outside the app, so this
costs nothing.

**No Hero transition — deliberately.** A repost preview and an ordinary card
for the same post can both be on screen in the feed at once, so any tag built
from post id + photo index can legitimately appear twice in one route, which
is a hard framework assertion, not a cosmetic glitch. The fade is cheap and
cannot collide.

**The viewer decodes at full resolution.** It passes no `memCacheWidth`,
unlike the cards, which cap decode at screen width: a screen-width decode
turns to mush at 5x, and showing the photo properly is the entire point of
the screen. One full-size decode at a time is the trade.

**Zoom state lives in the page, not the photo.** `PhotoViewerPage` tracks
whether the *current* photo is zoomed, because that is what decides whether
the `PageView` may scroll — a zoomed photo has to own every horizontal drag,
or panning around it pages to the next photo instead.
`test/shared/widgets/photo_viewer_test.dart` pins that, along with the
counter and the empty state. **The gestures themselves are unverified on
device** — there is no emulator in this sandbox.

---

## ADR-020 — The palette is retuned lighter, and a card's separation comes from the page tone rather than its border

**Status:** Accepted

`AppColors.light` / `AppColors.dark` are no longer a 1:1 lift of the design
source. The retune, token by token:

| Token | Light: was → now | Dark: was → now |
|---|---|---|
| `bg` | `#FFFFFF` → `#FEFCF7` | `#12100A` → `#1A1811` |
| `surf` | `#FFFFFF` (unchanged) | `#1C1A13` → `#24211A` |
| `surf2` | `#F5F2EA` → `#FAF7F0` | `#26231A` → `#2E2B21` |
| `ink` | `#14120C` → `#2A2620` | unchanged |
| `ink2` | `#5C5546` → `#6B6357` | unchanged |
| `ink3` | unchanged | unchanged |
| `line` | 16% ink → **10%** ink | 20% ink → **17%** |
| `line2` | 9% ink → **6%** ink | 10% ink → **8%** |
| `yelb` | `#FFF3CE` → `#FFF8E1` | `#3E3106` → `#473807` |
| `yeld` | `#6B5200` → `#6F5502` | unchanged |
| `onYel` | `#14120C` → `#2A2620` | `#14120C` → `#2A2620` |
| `slot` | `#EDE9DF` → `#F3F0E8` | `#2A261C` → `#322E24` |

**Why:** the borders read as drawn outlines rather than seams — `line` is on
142 call sites, so at 16% ink every card, chip, field and list row in the app
was carrying a visible grey rectangle, and the sum of them is what made a
screen look heavier than it is. Near-black `ink` on pure-white `bg` added
the same hardness to the type.

**The `bg`/`surf` split is what pays for the lighter hairline.** ADR-012
records that `AppColors.light.bg == surf`, and that a card's depth therefore
had to come entirely from `AppShadows.card`. That premise is now gone: the
page is a warm off-white and a card is still pure white, so a surface
separates from the page by tone before either its border or its shadow does
any work. Dropping the hairline to 10% without that split would have left
cards floating on shadow alone. **`AppShadows.card` is unchanged** — the two
tokens now share the job rather than one replacing the other.

**`ink3` is deliberately not lightened.** At `#918A7B` it is 3.4:1 on a card,
which is already the 3:1 floor for placeholder and disabled text. It is the
one token where "lighter" and "readable" point in opposite directions.

**`shell` is deliberately not lightened either.** It is the one surface that
stays dark in *both* themes (ADR-009, the Inbox slab), and everything drawn
on it reads the pinned `AppColors.dark` set. Lightening it would put
near-white ink on a near-white slab. Making the Inbox header light is a
separate change that has to flip `_onSlab` at the same time.

**Cost:** the palette and the design source have diverged, so a future
"sync with the design file" pass will re-darken all of this unless it reads
this ADR first — hence the pointer from `app_colors.dart`'s class comment.
The pure-white `bg` also can no longer be assumed by anything drawing its own
white fill to blend into the page.

**Unverified on-device.** `flutter analyze` and all 140 tests pass, but no
test asserts a colour value and there is no emulator in this sandbox — how
the new hairline reads at 1 physical px on a real screen is a look-at-it
question.

---

## ADR-021 — Feedback, reports, mute and hide live in one `safety` feature, not spread across feed, friends and profile

**Status:** Accepted

The backend shipped four small resources at once — `/feedback`,
`/posts/{id}/reports`, `/users/{id}/mute` and `/posts/{id}/hide`. Each one
has an obvious existing home: hiding and reporting are post actions
(`features/feed`), muting sits beside blocking (`features/friends`), and
feedback is an account-level screen (`features/profile`). They are all in
`lib/features/safety/` instead.

**Why:** the resources are small but they are one story, and splitting them
would have split each of them *twice*. Reporting a post is a feed action;
reading back what happened to that report is a settings screen. Muting
someone is a post-menu action; unmuting them is a list in the same settings
screen. Under the "obvious home" split, `POST …/reports` would live in
`features/feed` and `GET /reports/me` in `features/profile`, with two data
sources, two repositories and two sets of models over one API resource —
and the next person changing the report shape would have to find both.

One `SafetyRepository` over four resources also means one `_run` guard, one
page shape and one place where "these endpoints answer `204`, so do not
unwrap an envelope" is written down.

**What still crosses the boundary:** `FeedCubit` and `PostDetailCubit` each
take `HidePostUseCase` and `MuteUserUseCase`, because *they* own the list a
hidden post or a muted author has to disappear from. That is the same
cross-feature use-case injection `FeedCubit` already does for
`GetMeUseCase`/`GetUserPostsUseCase` from `features/profile` — a Cubit calls
use cases, and whose folder those use cases live in is not the boundary that
matters.

**Cost:** "where is muting?" now has an answer that is not "next to
blocking", which is genuinely surprising the first time. `docs/CODEMAP.md`
and the `VersionedEndpoints` block carry the pointer.

---

## ADR-022 — `ValidationFailure` carries the server's error code

**Status:** Accepted

`ValidationFailure` gained an optional `code`, filled in by
`ErrorHandler._failureForCode` from the backend's own `ErrorCode`. It is null
for the client-side validation a use case does before a request goes out.

**Why:** `REPORT_ALREADY_EXISTS` (409) is a rejection that is not a failure.
It means the viewer already has an open report on that post — which is what
they just asked for — so the sheet should close with "you've already reported
this", not stay open showing red text. Telling it apart from a real rejection
needs the code; the only alternative was matching on `message`, which is
human copy the server may reword at any time (and which the codebase already
warns against in `ApiErrorCodes`'s own doc comment).

`Failure` deliberately carried only a message until now, so that a Cubit
could not start branching on transport details. That reasoning holds for the
*other* failure types — a `ServerFailure` has nothing a caller can act on —
but `ValidationFailure` is by definition the "the user can fix this" case,
and which fix depends on which rejection.

**Scope:** additive and named, so all 38 existing construction sites still
compile unchanged and keep `code: null`. `code` is in `props`, so two
failures with the same message and different codes now compare unequal —
nothing depended on the old behaviour.

**Cost:** it is now possible to branch on a code anywhere a
`ValidationFailure` lands, which would be the wrong thing to do routinely —
the point of the `Failure` types is that most callers only need the message.
Reach for `code` when two rejections need *different* handling, not to
re-derive copy the handler already produced.

---

## ADR-023 — Muting is offered from the post menu, not from the profile

**Status:** Accepted

"Mute an account" is reachable from a post's "···" menu (where it mutes that
post's author) and undone from Settings → Privacy & safety.
`PublicProfilePage` has no mute toggle, even though that is where the Block
button lives and where most people would look first.

**Why:** `GET /v1/users/{id}` has no `isMuted` field, and a mute is
deliberately invisible everywhere else the other user could read — it does
not show up in `friendStatus` either. A toggle has to know its current
state, and the only way to learn it is to page `/v1/users/me/muted` until the
id turns up or the pages run out. That is 1-N extra requests on every profile
open, for a button most visits never touch, and it is wrong whenever the
mute list is longer than the pages scanned.

A menu *action* has no such problem: "Mute @someone" is a one-way verb, the
API is idempotent, and muting someone who is already muted still answers
`204`.

**Cost:** someone who wants to mute a person they are looking at has to find
one of their posts first. If an `isMuted` field ever lands on the user
response, add the toggle and delete this ADR's reasoning —
`docs/BACKEND.md` carries the same note next to the gap.

---

## ADR-024 — The Profile tab's overlap is `Stack`/`Positioned`, not `Transform`

**Status:** Accepted

The Profile tab was restructured to a cover/avatar/details layout (modelled
on a mainstream social profile). The avatar, its camera badge and the compose
bubble all overlap the cover, and all three are tappable — so the overlap is
built with `Stack` + `Positioned`. Nothing is shifted with
`Transform.translate`.

*Amended:* the identity block went back to sitting on a surf card, as it does
on `public_profile_page.dart`, with the avatar straddling the card's top edge.
The mechanism is unchanged — the card is the header `Stack`'s only
non-positioned child, so it is what gives the Stack its height, and the avatar
is still `Positioned` on top of it rather than translated. `ShimmerOwnProfileView`
mirrors the same shape.

**Why:** `RenderTransform.hitTest` inverse-transforms a tap against the
child's *untransformed* box, so a translated widget silently stops accepting
taps past its own edge. This screen already lost a stat tile's tap that way
(see [GOTCHAS.md](GOTCHAS.md)). `Positioned` takes plain doubles and stays
hit-test-safe. `test/features/profile/profile_header_test.dart` pins the two
overlapping tap targets, so a future "tidy-up" back to `Transform` fails the
suite instead of shipping.

**Also decided here:**

- The chips filter only the post list, so they sit directly above it — the
  reference screen puts its chips above its details block, which reads as if
  they filtered that too.
- "add status…" became a composer shortcut, and the personal-details rows use
  name / username / join date / email / bio / account status. There is no
  status, place, school or employer field on this backend, and inventing
  client-side ones would be fiction.
- The connections face-pile renders even at zero connections: Circle is shell
  branch 1 with no bottom-nav button, so that row (and the account menu's
  "Your circle") are the only ways into it.
- The account menu, not a button row, holds everything that isn't done *to*
  this profile — appearance, Circle, Shared posts, Privacy & safety, Send
  feedback, notification preferences, sign-out. That keeps ADR-021's
  separation of the `safety` screens from the profile itself, while dropping
  the four-button row that had started to wrap.
- The Profile tab has its own skeleton, `ShimmerOwnProfileView`, because its
  layout diverged from the public profile's header card; `ShimmerProfileView`
  still serves `public_profile_page.dart`. Two shapes, two skeletons, per
  ADR-013.

**Revisit if:** the API grows real profile-detail fields, or Circle gets its
own nav button.

---

## ADR-025 — Direct reply lives on alerts the app draws, so it needs data-only chat pushes

**Status:** Accepted — client side complete, background coverage waiting on
`yello-notify`.

A chat notification now carries a Reply action: an Android `RemoteInput`
action and, on iOS, a `UNTextInputNotificationAction` under the category
`yello_chat_reply`. The text is sent straight to
`POST /ws/conversations/{id}/messages` from whichever isolate the reply
arrived on, and the alert is rewritten in place with the outcome —
`chat_reply_action.dart` for the action and the send,
`push_notification_service.dart` for the drawing and the two response
handlers.

**Why the send does not go through DI:** a reply typed while the app is not
running is delivered to `flutter_local_notifications`' own background engine.
`sl` is empty there and `bootstrap()` never ran, so `sendChatReply` builds a
`SecureStorageServiceImpl` and a pinned `Dio` itself and re-seeds
`AppConfig` from `AppConfig.defaultBaseUrl` (which is why the base URL is now
a constant rather than a literal in `main.dart`). It reproduces
`AuthInterceptor`'s two rules deliberately — skip a token already known to be
expired, refresh once on a 401 — because the interceptor itself is attached
to a `Dio` that does not exist over there. Both attempts reuse one
`clientId`, so the refresh retry cannot post the reply twice.

**Why this is currently foreground-only:** an action button exists only on a
notification *Dart* drew. Android hands a push that carries its own
`notification` block to the system tray and runs no app code at all — not
`onMessage`, not the background handler — so the alert the user sees when
Yello is closed is the OS's, and nothing can be attached to it. There is no
client-side way around that; it is a property of FCM, not of this app. See
`docs/GOTCHAS.md`.

**What closes the gap** (both on `yello-notify`, both small — the app is
already written for them, and needs no further change when they land):

1. Send `CHAT_MESSAGE` **data-only** — no `notification` block, `title` and
   `body` repeated as `data` keys, Android priority `high`. The background
   handler then draws the alert itself, with the Reply action on it.
   `firebaseMessagingBackgroundHandler` and `_onForegroundMessage` both
   already take their copy from `data` when the block is absent.
2. Set `apns.payload.aps.category` to `yello_chat_reply`. iOS will not accept
   a data-only push as a visible alert, so there the notification block stays
   and the category is what grows the reply field.

*Amended:* a chat alert is drawn with `MessagingStyle` and
`CATEGORY_MESSAGE`, not as plain title/body — that is what makes Android
present it as a conversation with the reply field open rather than a
one-liner with everything folded behind a chevron. `conversationTitle` stays
null because the payload never says whether the conversation is a group, and
setting it makes Android prefix every line with a sender name. How much of
this a device honours is the device's call: One UI's *Notification pop-up
style: Brief* collapses every heads-up to a pill regardless.

*Amended:* a successful reply **clears** the notification (the action carries
`cancelNotification: true`) rather than rewriting it with the sent line. It
also means the shade never sits on the system's progress spinner, which only
resolves when the notification changes or goes. A failed send puts a fresh
alert back carrying the text that didn't go out, so the words are recoverable.

*Amended:* the refresh after a reply goes through `IsolateNameServer`, not
through `_updates` directly. Every action tap is delivered to the plugin's
background dispatcher — even with the app foregrounded — so the handler runs
in an engine that cannot see the service's streams. The running app publishes
a port; the reply pings it. See `docs/GOTCHAS.md`.

**Rejected:** redrawing the OS's alert from the app (cancel id `0`, re-show
with the action). The handler that would do it never runs on Android for a
notification-block push, so there is nothing to redraw from — and where it
does run, iOS, it would double the alert.

**Revisit if:** `yello-notify` starts sending chat pushes data-only (drop the
foreground-only caveat), or iOS background replies to a service-drawn push
turn out to need a Notification Service Extension of their own.

---

## ADR-026 — The Profile tab's chrome collapses into an app bar, driven by a `ValueNotifier` rather than a sliver

**Status:** Accepted.

The Profile tab's menu and search buttons already floated over the cover
photo in a `Positioned` on top of the page's `ListView`. They now sit inside
`_ProfileTopBar`, which fades a `surf` surface, a cast shadow and an
identity — avatar, name, `@username`, entering from the left — in over the
72px of scroll that ends 40px before the header's own name line would reach
the top of the viewport. The buttons do not move.

**Why not a `SliverAppBar`.** The obvious shape is `CustomScrollView` +
a pinned `SliverAppBar` with a `flexibleSpace`, the way `FeedPage` does its
top bar. It does not fit here. The header's avatar straddles the identity
card's top edge with `Stack`/`Positioned` (ADR-024), the cover fades into
`bg` behind it, and the whole thing is one `ListView` on purpose so there is
exactly one scrollable on the screen. Converting to slivers to get a
collapse would mean rebuilding that geometry inside a `FlexibleSpaceBar`'s
`collapseMode`, and `docs/GOTCHAS.md` already records what chasing a
`flexibleSpace` collapse cost on the feed. The bar here is an overlay that
reads the scroll offset; the list underneath is untouched.

**Why a `ValueNotifier` and not `setState`.** The page holds a `ListView`
whose children are the header, the segmented switcher and a column of real
`PostCard`s. A `setState` in the scroll listener rebuilds all of that once
per frame for the length of a flick. The offset goes into a `ValueNotifier`
instead, and only the ~56px bar listens. Two further cuts fall out of that:
the offset is **clamped to the end of the collapse**, so scrolling on past it
writes the same value and `ValueNotifier` stops notifying entirely; and the
two buttons are passed as `ValueListenableBuilder`'s `child`, so they are
built once and handed through every rebuild. The title reads the user from
its own `BlocSelector`, not a `BlocBuilder`, so a scroll frame never re-runs
a whole `ProfileState` comparison.

**Why the collapse threshold lives on `ProfileHeader`.** The hand-off point
is a fact about the header's geometry — cover height, card overlap, avatar
size — not about the bar. `ProfileHeader.nameOffset` derives it from the
constants that already exist there, and the bar subtracts from that. Change
the cover height and the hand-off follows on its own.

**Why the bar grows an `AbsorbPointer`.** The background is a
`BoxDecoration` colour, and a `DecoratedBox` does not hit-test — only
`ColoredBox` is opaque to pointers, and it is opaque at every alpha
including zero. So an opaque-looking bar would have let a tap fall through
to whatever post card was scrolled under it. A `Positioned.fill`
`AbsorbPointer`, switched on only once the bar is no longer fully
transparent, blocks that while leaving the resting state as see-through to
cover drags as it was before.

**The collapsed state's depth cue is a painted shadow, not a `boxShadow`.**
The bar reads as floating — a `surf` surface over the page's `bg` with a
shadow cast onto the list, deliberately the same elevation language
`BottomNavBar` already uses at the other end of the screen (black at 0.08
light / 0.45 dark, 16px blur, 4px offset), plus `AppShadows.card`'s tighter
contact layer to anchor the edge.

It cannot be a `BoxShadow` in this bar's `BoxDecoration`, because that
decoration changes on every scroll frame, and a blurred shadow on a
per-frame decoration is precisely the pattern that crashed Impeller on this
project (`docs/GOTCHAS.md`; ADR-012 sets out where a declared blurred shadow
is still fine — a decoration that only rebuilds with its parent, which this
is not). So `_TopBarShadowPainter` draws it with a `MaskFilter.blur` on a
`Paint` instead: the same animated-blur technique `_ActiveTabIndicatorPainter`
has driven from a running animation since the bottom bar shipped. The painter
clips to the strip *below* the bar, so the blur's top and side falloff never
tints the bar itself at any point in the fade, and the inner `Stack` is
`Clip.none` so the shadow can reach past the bar's own box at all.

*Amended:* this ADR originally shipped with a bottom hairline and no shadow,
on the reasoning that any blurred shadow here was too close to the Impeller
crash to risk. The painter route gets the floating read without going near
the banned pattern, and both modes are verified on-device (Samsung
`R5CX11J4TPR`) — which the hairline version never was.

**The title's `Transform.translate` is not a re-run of ADR-024.** That ADR
bans `Transform` for *tappable* overlaps, because a translated child cannot
hit-test a tap past its own untransformed box. The title is wrapped in an
`IgnorePointer` and takes no taps at all, so the trap does not apply and a
translate is the cheapest way to slide it.

**Revisit if:** the profile ever needs a real collapsing cover (a parallax
or a shrinking image), at which point the sliver rewrite buys something this
overlay cannot give.

---

## ADR-027 — The profile's All / Shared / Saved filters are `SegmentedTabs`, not a chip row

**Status:** Accepted.

`SegmentedTabs` names this screen in its own doc comment as the example of
what it is for, and draws the line: segments are for a choice that is
exclusive and always made, `FilterChipPill` is for independent toggles any
of which may be off. The profile had drifted to a horizontally scrolling row
of bordered pills, which says the wrong thing about a three-way filter where
one is always active. It is now the shared control, with the counts kept in
the labels (`All 12`, `Shared 3`, `Saved 7`).

The horizontal scroll went with it. `SegmentedTabs` splits the width evenly
and each segment already ellipsises, so the reason the row scrolled — three
count-carrying labels outgrowing a narrow screen — is handled inside the
control. `ShimmerOwnProfileView` follows: one full-width 45px pill where it
used to draw three 36px ones, because the skeleton should describe one
control rather than three.

---

## ADR-028 — Settings is its own feature, and App version shows no update check

**Status:** Accepted; the "no update check" half is superseded by ADR-029,
which builds the Updates group against the release channel's published
manifest rather than against an API endpoint. Everything else below stands.

The account menu on the profile (☰) had grown into two different things: a
theme switch that acted in place, three shortcuts to screens that already
had another way in (Your circle, Shared posts), and two real account
screens. It is now one thing — a list where every row opens a screen —
holding Theme, Send feedback, Notification preferences, App version and Log
out.

**The two new screens live in `lib/features/settings/`, not in `profile/`.**
Neither one is about a profile; the only thing tying them to that screen is
the button that opens them. `ThemeCubit` stays in `core/theme` (the root
`MaterialApp` reads it, so it cannot belong to a feature) and grew
`setMode`, replacing `toggle` — with the screen making the choice
explicitly, a caller that flips whatever is current no longer has a user.

**App version reads the device, through the usual layers.** It is a local
read (`package_info_plus` + `device_info_plus`) behind
`AppInfoLocalDataSource` → `AppInfoRepository` → `GetAppBuildInfoUseCase` →
`AppVersionCubit`, the same shape `BookmarksLocalDataSource` already uses
for a device-local feature. The repository skips the `NetworkInfo` gate the
remote-backed ones open with: this data must still resolve with the radio
off. The OS and device rows are best-effort and are simply left out when
`device_info_plus` cannot answer, rather than failing the screen that was
asked for a version number.

**The reference design's "Updates" group is deliberately not built.** It
carries a *Check now* button, a "checked 54 minutes ago" line and a "check
automatically" toggle. The API serves no version resource to compare an
installed build against, and Yello ships through the Play Store and the App
Store, so all three controls could only ever invent their answer — a toggle
nothing reads, a timestamp of a check that never happened. In its place a
"This build" card states what is true (this is the installed build, new ones
come from the store) and a *Copy* button puts the whole diagnostic line on
the clipboard, which is what the version screen is actually opened for.

**What removing the three menu rows costs.** Your circle (shell branch 1)
now has exactly one entry point, the connections row on the profile header —
noted in both places in the code. Shared posts keeps its own `Shared` tab on
the profile, so only the full-screen version is now unreachable from the UI;
its route stays registered. Privacy & safety is still reachable from the
notifications screen and is still where a tapped `REPORT_RESOLVED` push
lands, which is why that route must stay.

**Revisit if:** the app gains enough settings to want a settings *hub*
screen rather than a bottom-sheet menu. (The other revisit condition here
was "the backend grows a latest-version endpoint". ADR-029 took the group
in a different direction — a manifest published with each release — without
the backend growing anything.)

---

## ADR-029 — Yello updates itself from a published manifest, because it is sideloaded

**Status:** Accepted. Supersedes ADR-028's "the Updates group is deliberately
not built".

Yello is not installed from a store. It is handed to people as an APK, which
means every update so far has been a file sent by hand, and a user who never
receives that file simply keeps running an old build forever. The Updates
group ADR-028 declined to build is now built — against the release channel,
not against the API.

**The version check is a static manifest, not an endpoint.** Each release
publishes a `latest.json` beside its APK:

```json
{
  "version": "0.4.0",
  "buildNumber": 3,
  "notes": "What changed, one or two lines.",
  "apkUrl": "https://github.com/Yello-Social-App/yellow-app-flutter/releases/download/v0.4.0/yello-0.4.0.apk",
  "sizeBytes": 63779818
}
```

`AppConfig.updateManifestUrl` points at
`…/releases/latest/download/latest.json`, a permanent redirect onto whatever
the newest release attached — so cutting a version never edits the app. The
API is untouched: it still serves no version resource, and ADR-028's
"revisit if the backend grows a latest-version endpoint" was too narrow a
condition. It did not need one.

**It does not go through `ApiClient`.** The manifest and the APK are fetched
off-host, and `AuthInterceptor` attaches the session bearer token to every
request on that Dio. Pointing it at a download host would hand the session
to whoever runs it, so `AppUpdateRemoteDataSourceImpl` owns a bare `Dio`
with no interceptors. A non-`https` `apkUrl` is refused outright — the file
is about to be executed by the OS installer, so a plaintext hop is a
code-execution hole, not a privacy one.

**The comparison key is the build number, never the version string.** It is
the Android `versionCode`, the one value the platform guarantees increases
between installable builds. Equal build numbers are not an update:
re-installing the running build is the case where Android shows its own
unhelpful "app not installed". An unparseable installed build offers
nothing rather than guessing.

**Installing is three intents of Kotlin, not a package.** `MainActivity`
holds the `yello/installer` channel: where to download to (app-private
cache, so no storage permission), whether `REQUEST_INSTALL_PACKAGES` has
been granted, the OS screen that grants it, and handing the file to the
package installer through a `FileProvider` content URI. Every pub.dev option
in this space bundles its own download stack, which this app already has in
`dio`. A refusal comes back as `false`, not as an error: "install unknown
apps" being off is the ordinary first run, and the card asks for it rather
than reporting a failure.

**Android only.** iOS can install nothing but what the App Store hands it,
so the group is absent there rather than shown with a button that could only
apologise. `AppUpdateCubit` is a singleton provided with
`BlocProvider.value`, because a 60 MB download must survive the user leaving
the App version screen — a factory would close the cubit mid-transfer.

**This only works if every APK is signed with the same key.** Android
refuses an update whose signature differs from the installed app, and the
only way out is uninstalling, which takes the user's data with it. Release
builds previously used the *debug* keystore — per-machine, auto-expiring —
which is fine for `flutter run --release` and fatal for distribution.
`android/app/build.gradle.kts` now reads `android/key.properties` (gitignored,
as is `*.jks`) and falls back to the debug key only when that file is
absent. **A build made without the keystore must not be handed to anyone.**

**Revisit if:** Yello goes to the Play Store, at which point this whole path
is replaced by Play in-app updates (`in_app_update`) — Play policy forbids
an app updating itself and treats `REQUEST_INSTALL_PACKAGES` as a restricted
permission. Also revisit if the update needs to be forced rather than
offered, which would want a `minBuildNumber` field in the manifest and a
gate at startup rather than a card in settings.

---

## ADR-030 — Stories moved onto the real API, keyed by author id, and kept inside the feed feature

**Date:** 2026-09-24 · **Status:** accepted

`/v1/stories` shipped, so the client-side seed that stood in for it
(`StoryLocalDataSource`, an in-memory list whose "seen" flag reset every
app launch) is gone, along with `GetStoriesUseCase` and
`MarkStorySeenUseCase`. `docs/BACKEND.md` listed Stories as a permanent gap;
it no longer is. Ten endpoints are wired: post, rail feed, my stories, one
user's stories, one story, mark viewed, viewers, archive, delete, reply.

**Stories live in `features/feed`, not a feature of their own.** They are
already there, the rail is part of the Home tab, and the alternative meant
moving twelve files to buy a boundary that only the rail ever crosses. What
did get split is the *contract*: `StoryRepository` is separate from
`FeedRepository` rather than adding ten methods to it — the two share
nothing but a screen.

**The viewer route takes an author id, not a rail index.** `/story/:authorId`
replaced `/story/:userIndex`. A rail is a snapshot; a ring whose last story
expires between the render and the tap shifts every index after it, and an
index-keyed route would then play the wrong person's story. `?only=true`
plays that one author's ring (`GET /users/{id}/stories`) instead of
continuing through the rail — the deep-link and open-from-elsewhere shape.
Nothing links to it from a profile yet; the route is the seam for when
something does.

**The rail is two calls, made together.** `/stories/feed` deliberately
excludes your own stories, so "Your story" comes from `/stories/me`.
`StoryRepositoryImpl.getRail` fires both and folds them into one
`StoryRailEntity` whose `all` is your ring first, then the server's order.
`Future.wait` rather than two sequential `await`s: it rethrows the original
exception so `_run`'s `on AppException` still catches it, *and* consumes the
other future's error instead of leaving it unhandled.

**Cover keys map to gradients on the client.** The server stores
`cover-0` … `cover-7` and never a colour, so
`kStoryCoverGradients` is the entire definition of what a text story looks
like — changing a pair restyles every existing story of that cover,
archived ones included, with no migration. An unknown key renders as
`cover-0` rather than a blank frame, so a newer backend adding `cover-8`
degrades instead of breaking.

**Progress ticks are kept out of the page rebuild.** The slide timer emits
~16 times a second. The viewer's `BlocConsumer` has a `buildWhen` that
ignores `progress` outright, and `_ProgressBars` reads it through a
`BlocSelector` — without that, every tick would rebuild the decoded
full-screen photo behind it.

**The heart sends a reply, it does not react.** There are no story
reactions server-side (the contract lists them as not built), so a local
heart would be a button that does nothing off-device. It posts "❤️" through
`POST /stories/{id}/replies`, which is what it visibly does in Messenger
anyway.

**Story replies reach chat as a reference, not content.** `Message.storyReply`
carries `{storyId, storyAuthorId, storyType, storyExpiresAt}` and nothing
else, so the bubble's preview has to fetch the story itself.
`StoryPreviewCubit` is a **singleton** cache keyed by story id: several
replies in one conversation commonly point at the same story, and a
per-bubble fetch would be one request each. It also refuses to spend a
request on a story that is expired and not the viewer's own — that is a
guaranteed `404` — and remembers ids that 404'd so the same bubble never
asks twice.

**`viewCount` and the viewer list are not the same fact.** Names are deleted
48 h after posting while the count survives, so an empty viewers sheet under
"Seen by 23" is correct. The sheet says so in words rather than rendering an
error.

**Revisit if:** highlights, story reactions or video stories land (all three
are listed as not built), or if a `STORY_POSTED` push appears — the rail is
currently re-read on refresh, with no live invalidation.

---

## ADR-031 — A plain tap on the like pill removes any reaction, and the picker holds only real ones

**Date:** 2026-09-25 · **Status:** accepted

Three things about the reaction control were wrong at once, and two of them
came from the same misreading of the endpoint.

**The endpoint is a toggle keyed on the type you send.**
`POST /reactions/{targetType}/{targetId}` decides add / change / remove from
the viewer's *current* reaction: a type they do not have is a **switch**, the
type they do have is a **removal**. There is no `DELETE`. So `toggleLike`
hardcoding `LIKE` meant a plain tap on a post the viewer had reacted to with
😆 read as "change it to LIKE" — the reaction could be cycled but never taken
back without opening the picker and finding the one already-selected tile.
`FeedRepositoryImpl.toggleLike` now echoes `post.viewerReactionType` when
there is one, which is why it takes the whole `PostEntity` and not just an
id. That single change fixes every surface that calls `toggleLike`
(`FeedCubit`, `ProfileCubit`, `PublicProfileCubit`, `SharedPostsCubit`,
`PostDetailCubit`); the two cubits that also predict the result optimistically
had to echo the same type in `_predictReaction`, or the pill flipped to a
heart for a moment before the server's removal landed on top of it.
`CommunityPostCard` already did this (`onReact(viewerReaction ?? like)`),
which is where the shape came from.

**A reaction glyph needs a fixed box.** The affordance swaps between an
`Icon` and a `Text` emoji, and emoji advance widths differ per glyph — `❤️`
is a narrow text-presentation glyph, `😆`/`😮` are wide pictographic ones. Laid
out at natural size, the pill resized every time the reaction changed, which
is what it looked like on-device: a button that grew and shrank depending on
what you had picked. `ReactionGlyphSlot` is a `SizedBox.square` +
`FittedBox(scaleDown)`; `ReactionGlyph` is the heart/emoji pair inside one.
`_Pill` in `post_card.dart` puts *every* icon in the same 15px slot, not just
the reaction one, so the whole action row keeps one height rather than the
pills disagreeing about it. `scaleDown` rather than `contain`: a glyph that
measures wider than its em gets pulled back in, and the smaller ones are not
scaled up to fill the box.

**The 🖕 tile stopped being decorative and became `LOVE`'s glyph.** It
started as a 7th tile that popped the sheet with no value and showed a "sent
into the void" snackbar — a reaction that looked like it had silently
failed. It cannot be a 7th *type*: `ReactionType` on the backend is a closed
enum (re-verified 2026-09-25 against the live `/docs/json`:
`LIKE|LOVE|HAHA|WOW|SAD|ANGRY`), so there is nowhere to store, count or list
one back. So it borrows a real type instead: `ReactionType.love` renders as
🖕 (`ReactionType.emoji`), which is a **display** choice only — it still
travels and counts as `LOVE`. `LOVE` is the one to borrow because this app's
quick-tap already draws a heart for `LIKE`, so ❤️ was the row's least
distinct tile. The cost, accepted knowingly: the reaction is `LOVE` to the
backend and to any client that hasn't made the same swap.

A decorative tile was the alternative and was rejected — a control that
reports success while sending nothing is worse than one that sends a
differently-named reaction.

**The picker floats against the button, it is not a bottom sheet.** A sheet
put the reactions at the opposite end of the screen from the thumb that had
just long-pressed. `showReactionPicker` is now a `PopupRoute` whose rail is
placed by a `SingleChildLayoutDelegate` against the anchor's rect: above it
by default, flipped below when it would cross the top safe area, and slid
along the screen when centring would push it past an edge. It takes the
**button's** context, not the caller's — the three feed call sites pass a
`Builder`'s context or the button's own, since anchoring to the enclosing row
would float the rail above the wrong thing. A `PopupRoute` rather than a bare
`OverlayEntry`: it brings the barrier, back-button dismissal and a return
value, so every call site kept its `await` + `if (picked != null)` shape.

`CommunityPostCard` had a near-copy of the old sheet; it now calls the same
function, so a long press behaves identically on both kinds of post.

The rail has **no drop shadow**, which a floating surface would normally
want: the whole subtree is scaled and faded every frame of the entry
animation, and a blurred `BoxShadow` under that is this project's documented
Impeller crash. A 10% barrier scrim does the separating instead.

**Revisit if:** the backend's `ReactionType` gains a value — the rail is
`for (final type in ReactionType.values)` and already `FittedBox`-guarded for
width, so a 7th tile is one enum case plus its wire mapping. A real 7th type
would also free `LOVE` to go back to ❤️.

---

## ADR-032 — A detail screen hands its entity back on pop; the list swaps that one row

**Status:** Accepted

Every screen that opens a post, a thread or a project pops with the entity it
is holding, and the list that pushed it applies that entity to the matching
row. No list re-fetches on the way back.

- The detail side is a `PopScope<T>` with `canPop: false` and an explicit
  `context.pop(<entity>)`, so the system back gesture carries the result too
  and not just the arrow: `PostDetailPage`, `CommunityPostPage`,
  `ProjectDetailPage`.
- The list side is `final updated = await context.pushNamed<T>(...)`, then
  one apply call: `FeedCubit.replacePost`, `CommunityFeedCubit.applyUpdated`,
  `CommunityDetailCubit.applyUpdated`, `ShowcaseCubit.applyUpdated`,
  `ProfileCubit.applyUpdated`, `PublicProfileCubit.applyUpdated`,
  `SharedPostsCubit.applyUpdated`.
- Every applier swaps in place and no-ops on an id it doesn't hold, so it is
  safe to fire at a list that has already dropped the row (a delete, a hide,
  a mute) and it never re-seeds something that was removed.

**Why:** reacting or commenting changes counts the card underneath is
showing, and nothing was carrying that back. The feed is a
`registerLazySingleton` kept alive across tab switches
([GOTCHAS](GOTCHAS.md#long-lived-singleton-cubits-go-stale)), the communities
timeline is created once per visit to Explore, and a profile list is held by
its page — none of them re-read anything when a push pops. So the row kept
the numbers it had at the moment it was tapped, for as long as the screen
stayed alive: react on the thread, come back, the count has not moved.

**Why not just refresh the list on the way back.** It is one more request per
back-press on a list the user is already looking at, and against a
server-sorted feed (`hot`, `trending`) the refetch can reorder or re-page the
list under the finger that just came back to it — the row you were looking at
moves or disappears. It also cannot fix Saved, which is local
(`shared_preferences`, ADR-007) and not in any list response. The entity that
comes back is already the server's own answer: every mutating call on a detail
screen folds the response into `state.post`, so nothing has to be re-read to
know what the row should now say.

**What it changes elsewhere:**

- `PostEntity.repostedByMe` is *not* taken from the incoming copy. That flag
  is on no wire response (see its doc) — each screen recovers it separately,
  best-effort — so every applier re-derives it from its own `_myRepostIds`,
  the map its own cancel path reads. Trusting someone else's copy is how a
  pill ends up saying "Reposted" with nothing on that screen able to undo it,
  or "Repost" on something already reposted, one tap from a duplicate.
- `_result` in `post_detail_page.dart` returns null once the post is deleted,
  because the delete path has already told the feed to drop the card.
- A nested `RepostedPostPreview` opened from inside a repost still pops its
  result, but nothing applies it: the row in the list is the *repost*, and the
  post that changed is the `originalPost` inside it. Left alone rather than
  half-solved — see the gap noted in GOTCHAS.

**Cost:** a list can now be written back to from a screen it doesn't own, so
an applier that doesn't no-op on an unknown id would resurrect deleted rows.
Keep them id-matched and in-place.

**Do not** add a `refresh()` on pop as well. Two mechanisms for the same
staleness is how they disagree.

---

## ADR-033 — Voice notes record in a full-screen stage, and pause finishes the take

**Status:** Accepted

A voice message is recorded in a `PopupRoute` over the conversation
(`voice_recorder_sheet.dart`), not in the composer: a status line, a 240px
radial meter around an 88px orb, a `m:ss` clock, and discard · stop ·
send. It follows the recorder design the feature was specified from, redrawn
in this app's tokens rather than the mockup's own dark palette (ADR-020 — the
palette here is deliberately not the design file's).

The mic **replaces the send button** when there is nothing to send, rather
than taking a fourth slot in the composer row. At 320dp that row already
holds an attach control and a five-line field; a fourth control is what makes
the field collapse. The swap is driven by the `TextEditingController` rather
than by `ChatState` — the draft is not in the state (only the typing signal
derived from it is), and listening to the controller rebuilds one button
instead of the composer on every keystroke.

**Pause is a stop, and the red button records a new take.** The design shows
pause/resume, and `record` does support both — but a paused `MediaRecorder`
has no readable file on Android, so a paused take cannot be played back,
which is what the design's own "tap to preview" promises. Finishing the take
on pause makes preview work every time, at the cost of a resume that a voice
note has little use for. Send from the recording state stops and uploads in
one tap, so Stop is never a step anyone has to know about.

**The upload happens in the sheet; the message is sent by `ChatCubit`.**
`VoiceRecorderCubit` stops at an uploaded `AttachmentEntity`, and
`ChatCubit.sendVoiceNote` puts the message around it through the same
optimistic `_deliver` path as everything else. A second delivery route would
have had to learn about `clientId` idempotency, retries, reply targets and
the inbox preview all over again. It is deliberately *not* folded into
`send`: a voice note travels alone and carries no draft, so it never enters
`pendingAttachments` with the photos.

**One player for the whole app** (`VoiceNotePlayer`, a DI lazy singleton).
Only one note plays at a time — the service's own client guidance, and what
every messenger does — and a transcript can hold hundreds of bubbles, each of
which would otherwise want a real platform player. Bubbles watch its single
`ValueNotifier` and compare `noteId` against their own. Its `AudioPlayer` is
built on the first play, so a session that never opens a note never opens an
audio session (and a widget test that constructs one never reaches a
platform channel that isn't there).

**What it changes elsewhere:**

- `AttachmentKind` gains `voice`, and `AttachmentEntity` a `VoiceMetaEntity`.
  `isVoice` requires *both* the kind and the metadata: a VOICE attachment the
  server could not measure renders as a file chip rather than as a player
  stuck at 0:00.
- The waveform drawn is always the **server's**, measured from the audio on
  upload — so every device draws a note identically, and a bubble looks right
  before anything is decoded locally.
- `LastMessageKind.voice` gives the inbox row "Sent a voice message", the
  same words `yello-notify` puts in the push, instead of the filename (every
  note on the service is called `voice-message.m4a`).
- Both meters are `CustomPainter`s. Sixty rotated widgets rebuilding twelve
  times a second is the version that drops frames, and an animated blurred
  decoration is this project's documented crash (GOTCHAS).
- `RECORD_AUDIO` / `NSMicrophoneUsageDescription` are asked for when the
  recorder opens, by `record`'s own `hasPermission()`. Someone who never
  sends a voice note is never asked.

**Cost:** three new dependencies (`record`, `just_audio`, `path_provider`)
and a platform surface — microphone and audio focus — this app did not have.
A `503 UNAVAILABLE` from the upload route means the deployment has no bucket
or no ffmpeg; the mic button is still drawn and the failure is a message
rather than a hidden control, which the service's own guidance would rather
we did the other way round.

**Not built, deliberately:** the 1× / 1.5× / 2× speed control from the API's
checklist. It is not in the design, and nothing in it is load-bearing for
sending or hearing a note.
---

## ADR-034 — Chat photos open in the shared viewer, and a re-signed link is a state revision

**Status:** Accepted

A photo in a transcript expands into `PhotoViewerPage` — the same full-screen
viewer a post's photos open into — rather than getting a chat-specific
lightbox. A tap opens the whole message's set on the picture that was tapped,
so a four-photo message is swiped through in the viewer instead of four
separate opens.

**The viewer takes cache keys now, not just URLs.** A post's photo URL is
permanent, so keying the image cache on the URL is free there. A chat
attachment's is presigned and re-signed on **every** history fetch, so the
same file arrives under a different URL every few seconds; keyed on the URL,
expanding a picture would re-download a file that is already on disk. The
chat passes the attachment ids as `PhotoViewerArgs.cacheKeys` — the keys the
transcript's own thumbnails are stored under — so opening one is a cache hit.
Posts pass nothing and keep the old behaviour.

**A stale link is re-signed before the viewer opens**, by
`ChatCubit.viewableImageUrls`, the picture-side twin of `playableVoiceUrl`:
R2 answers 403 past the hour and the viewer would open on its error state.
A message's links are re-signed concurrently, so a four-photo message costs
one round trip.

**Re-signing had to become visible to the UI at all.** It was not:
`AttachmentEntity.props` deliberately exclude the URL (see GOTCHAS), so a
message carrying a freshly signed attachment is `==` the old one, the
`ChatState` is `==` the old one, and `emit` drops equal states — the fetch
happened on every expiry and changed nothing on screen. `ChatState` gains an
`attachmentRevision` counter, bumped in `refreshAttachment`, purely so that
one emit lands; the poll's own re-signing still goes unnoticed, which is what
the excluded prop is for. The thumbnail additionally keys on the URL
(`key: ValueKey(url)`), because `CachedNetworkImageProvider` compares equal
on `cacheKey` alone and would otherwise never re-resolve a picture that 403'd.

**Cost:** one more field on `ChatState`, and a counter is a blunt instrument —
any future code that re-signs a link has to remember to bump it, or land in
the same silence. The alternative, putting the URL back in
`AttachmentEntity.props`, makes every 5-second poll look like a changed
transcript, which is the more expensive mistake.

---

## ADR-035 — A theme is a palette flavor crossed with a brightness, not one of four themes

**Status:** Accepted

The Theme screen now offers four themes: the original pair (ADR-020) and a
second pair lifted from the Yello Design System's own token tables
("Quiet rails" — neutral grey-black layers, one saturated yellow per view).
They are stored as **two axes**, not as a four-valued enum: `ThemeState`
carries an `AppThemeFlavor` and a `ThemeMode`, and `AppColors.resolve`
crosses them.

**Because `MaterialApp` owns one of the axes and not the other.** It picks
between `theme` and `darkTheme` by brightness itself, and has no concept of a
flavor — so the flavor has to be baked into *both* `ThemeData`s before they
are handed over, while the brightness stays `themeMode`'s job. A flat
four-value enum would have to be decomposed back into exactly this shape at
the one place it is consumed, and would make "keep my palette, switch to
dark" two unrelated values instead of one field changing.

**The palettes are a re-point, not a redesign.** Every widget already reads
`AppColors.of(context)`, so a new flavor is two `const AppColors` and nothing
else — no widget changed for this. The cost of that is the token set is the
ceiling: the design system distinguishes `outline-variant` (hairlines on
surfaces) from `outline-strong` (control borders), but this app has a single
`line` token doing both, so `line` takes `outline-variant` — the role it
actually draws most — and `outline-strong` goes unused.

**Three tokens are deliberately not the source table's value**, each noted at
its line in `app_colors.dart`: `line2` (no token exists below
`outline-variant`, so it is derived as the midpoint to the card surface),
`shell` (stays dark in *both* flavors' light sets, because ADR-009's slab
still paints fixed light ink on it), and dark `yelb` (`primary-fixed` sits
within ~1% of `surf` on this palette, which would make a selected chip
invisible, so the `-dim` wash the source offers for exactly this is used).

**The flavor persists under its own key**, `settings.theme_flavor`, holding
an enum `name`. An install that predates it has no value there and
`AppThemeFlavor.fromName` resolves that to `classic`, so upgrading keeps the
theme the device already had.

**Cost:** four palettes to keep honest instead of two, and any token added to
`AppColors` from here on has to be answered four times. Typography is
untouched — the app is already on Geist plus a body face, which is what the
source system asks for — so the flavors differ in colour only.

---

## ADR-036 — The interface draws Cupertino icons, imported with a `show` clause

**Status:** Accepted

Every icon in the app is a `CupertinoIcons` glyph instead of a Material one —
264 call sites across 60 files, swapped one-for-one. `cupertino_icons` was
already a dependency; nothing else about the app became Cupertino, so this is
a glyph change, not a move to `CupertinoApp`, `CupertinoButton` or Cupertino
theming.

**The import is `show CupertinoIcons`, never the bare library.** A file that
imports both `package:flutter/material.dart` and
`package:flutter/cupertino.dart` in full pulls two overlapping widget sets
into one namespace, and the next person to add a widget in that file gets to
resolve the ambiguity. The `show` clause takes the one symbol that is
actually wanted and leaves the rest of Cupertino out of scope, which is also
the honest statement of what this change is.

**Three glyphs have no Cupertino counterpart and are handled, not faked:**

- `Icons.apple` stays Material, in `login_page.dart`. It is a brand mark, not
  an interface icon — there is no Apple logo in `CupertinoIcons`, and an
  approximation on a "Sign in with Apple" button would be wrong.
- `Icons.done_all` (the double check that means *read* in a transcript) has
  no Cupertino equivalent. Sent is `checkmark` and read is
  `checkmark_circle_fill` — the pair still reads as one state escalating into
  the next, which is the only thing the double check was doing.
- `Icons.eco_outlined`, `celebration_outlined` and `cake_outlined` are
  decorative (auth-hero accent bubbles, a birthday row). Cupertino has no
  leaf and no cake, so they take `sparkles` and `gift`.

**The rest of the mapping is one-for-one and semantic, not literal.** Where
Material drew an arrow and Cupertino draws a chevron (`arrow_back` → `back`),
or Material had a `_rounded`/`_outlined` variant Cupertino does not
(`check_rounded` and `check` both → `checkmark`), the destination is the iOS
idiom for the same job rather than the closest-looking shape. Repost is the
one deliberate upgrade: `Icons.repeat` was the media-loop glyph, and
`arrow_2_squarepath` is the one people read as "repost".

**Cost, and what is unverified:** Cupertino glyphs sit on a different optical
grid than Material's 24px one — they generally read lighter and slightly
smaller at the same `size:`. Every `size:` in the app was tuned against
Material. Nothing was re-tuned here, because the sizes have to be judged on a
screen and there is no device attached to this sandbox. Expect a pass over
icon sizes after the first on-device look, concentrated on the small ones
(the 13-14px post-action row) where the weight difference shows most.

---

## ADR-037 — "Not listened to yet" is a local fact, drawn in the unread accent

**Status:** Accepted

A voice note in a transcript now reads as one of two things at a glance:
**unheard** — the play button is brand yellow under an ink ring, the whole
waveform is drawn in `yeld`, the length is ink and bold, and a small yellow
dot sits after it — or **heard**, which is the quiet ink-on-surface bubble
the app already had. That is deliberately the same yellow-disc-plus-ink-ring
language the Inbox uses for an unread row, so one visual vocabulary covers
"not read" and "not listened to" instead of two.

**The waveform's unheard colour is `yeld`, not `yel`.** An unheard note has
no played portion, so a single colour carries the entire waveform: flat
brand yellow is a *fill* token and 3px strokes of it disappear against a
white card, while `yeld` is the accent that is defined to hold contrast as
ink on a light ground (and is the same yellow again in dark).

**The state is stored on-device, not on the server.** `yello-chat` has no
per-attachment playback flag — a message carries read receipts, not "played"
— so `VoiceNotePlaysStore` keeps the heard ids in `shared_preferences`,
exactly as saved posts do. It does not follow the account to another phone,
and it cannot: there is no endpoint to sync it through. This is a permanent
client-side stand-in, not a placeholder.

**Unknown reads as heard.** The store's notifier is `null` until the prefs
read lands, and a bubble treats `null` as heard. The alternative — an empty
set until proven otherwise — flashes the accent across a whole transcript of
notes the user played yesterday, for as long as a disk read takes, on every
cold start.

**A note is heard the moment it starts playing**, marked from
`ChatPage._playVoice` on a successful `toggle`, not on completion. A note
someone listened to half of, or scrubbed to the end of, is not new any more;
waiting for `ProcessingState.completed` leaves both wearing the accent. The
notifier is updated before the prefs write and the write is not awaited, so
the bubble drops out of the accent on the tap rather than after I/O.

**Only an incoming note can be unheard.** On a yellow (own) bubble the style
is never applied: that note is one you recorded, and whether the other side
has played it is a fact the API does not report — inventing a marker for it
would be a lie rather than a gap.

**The stored set is capped at 600 ids, oldest dropped first**, so the key
cannot grow without bound over the life of an install. A note scrolled far
enough back to fall off reads as heard, which is the harmless side of that
trade; a genuinely new note reading as heard is not.

**Cost:** one more DI singleton and one more `ValueListenableBuilder` per
voice bubble, and the heard set is per-device — reinstalling the app, or
opening Yello on a second phone, marks every note new again.
