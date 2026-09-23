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
