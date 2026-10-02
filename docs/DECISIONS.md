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

**Status:** Accepted — amended by ADR-046 (new `ShimmerBox` look; Inbox,
Circle, Signals and project detail now have their own skeletons, so
`ShimmerListCard` is only `PagedListView`'s fallback)

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
| Profile / public-profile page | `ShimmerOwnProfileView` (`detailRows: 3` on a public profile) |

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

---

## ADR-038 — The green online dot is leased socket presence, folded into the inbox row

**Status:** Accepted

`AppAvatar(showOnlineDot:)`, `ConversationEntity.isOnline` and the chat
header's `ACTIVE NOW` / `OFFLINE` line have all shipped since chat landed,
and all three were dead: presence only arrives on `yello-chat`'s `presence`
frame, and nothing decoded it, so every avatar in the app reported offline.
This wires it.

**Presence is socket-only, and that is a backend fact.** The chat service
lists `presence` among its server → client events and then says the socket
protocol "is not expressible in OpenAPI"; `Participant` carries no
`isOnline`, no `lastSeenAt`, and there is no presence route on any of the
three services. So there is no polling fallback to build — an open WebSocket
is the only way to know, which is what makes the rest of this ADR about
*when* to hold one.

**One set of ids for the whole app**, in `PresenceTracker` beside
`ChatSocket`. Per-screen subscriptions to the frames were the obvious
alternative and are wrong: a roster most likely arrives once, just after
`auth.ok`, so a chat screen opened ten minutes later would see nothing until
somebody's status happened to flip. The tracker holds what was said, and
`watchPresence()` hands a new listener the current set before any change —
the same shape as `watchEvents` yielding `LiveDeliveryChanged` first.

**Absence means "not known to be online", never "offline".** The set is
emptied when the connection drops and when the last watcher leaves, because
a green dot is a claim and this client stops being able to make it. That
asymmetry is why the UI draws a dot for presence and *nothing* for its
absence — and why `ConversationEntity.isOnline`'s doc says so explicitly.

**The dot is folded into the inbox row, not held in a second state.** The
chat header already reads the inbox row first and falls back to
`ChatState.conversation` only for a conversation the inbox has not loaded —
and `ChatCubit.load` writes its own detail into the inbox anyway. So
`MessagesCubit` applying presence to its rows lights the list, the header
rail and the chat header from one place, with no widget touched and no
chance of the three disagreeing. A `PresenceCubit` would have meant
threading a second state into three widgets to reach the same pixels.

**A group never gets a dot.** Its avatar is the group's photo; "one of these
eleven people is around" is not what a dot on a face means.

**The dot is a plain green disc, and the transcript's `checkmark_circle_fill`
was tried here and rejected.** Reusing the "read" glyph is tempting — both are
green, and one shape for two ideas is one thing to learn — but it was built,
looked at on a device, and turned down: **a tick asserts that something was
done, and being online is a state, not an act.** Read the two side by side and
the tick reads as "they replied", which is the one thing it does not mean.
Worth knowing before anyone proposes it again:

- `Icon` paints a single colour, so the tick inside `checkmark_circle_fill` is
  *knocked out* of the disc rather than drawn (confirmed on-device in the
  Showcase tech filter, which uses the same glyph). Straight onto a photo
  avatar the tick shows the photo through it and stops reading as a tick, so
  the glyph would need a `surf` disc behind it and a footprint grown from
  `size * 0.28` to `0.34` to stay legible at the 42 pt header size.
- The plain disc needs none of that. Its 2px `surf` border does the same
  separating job at the smaller size, which is why it was the original design.

**Watching is leased, not always-on** — `watchPresence()` / `releasePresence()`
with a count. The dot is drawn on exactly two surfaces, the Inbox (list and
rail) and the chat header, so a lease is held by `MainShellPage` while the
Inbox branch is on screen, foregrounded and authenticated, and by `ChatCubit`
for the life of a chat screen. This is ADR-010's trade applied to a
connection instead of a request: a socket held open from Feed or Profile
reports presence to a screen that cannot draw it. The count is what matters
for the hand-off — walking from the inbox into a conversation overlaps the
two holders, so the connection survives instead of closing and reconnecting
between them.

**The frame's payload is read tolerantly, like `typing`.** Its shape is in a
service README this repo does not have, so `ChatFrameDecoder.presence` accepts
`{userId, isOnline}`, `{userId, online}`, `{userId, status: "ONLINE"}`, a
batch under `users`, and a bare `{online: [id, …]}` roster; a user named with
no state reads as online, since the frame was sent because something
happened. A frame none of that fits is logged verbatim once per process, so
the real shape is one `adb logcat` line away rather than a debugging session.
**Confirm it on-device and delete the guesses that turn out to be dead.**

**The dot itself was checked on a device**, by forcing `showOnlineDot` on in
the inbox and rail for a throwaway build (reverted): the disc and its ring read
correctly at all three call sizes, over photo avatars, on the dark header slab
and on the light list rows alike. Forcing the flag is the *only* way to see it
today — see the next note for why — so anyone restyling this should expect to
do the same rather than waiting for a dot to appear on its own.

**Verified on-device, 2026-09-26** (emulator-5554, profile build): opening
the Inbox tab opens and holds one socket — a TCP connection to the API host
kept its local port through 48 s of sampling while the 10-second poll's
connections were recycled around it — and switching to another tab closed it.
That is the lease, working end to end, and it is the half that could be
checked with one device. The other half could not: in ~50 s on that live,
authenticated socket the service sent **no `presence` frame at all** — no
roster after `auth.ok`, and no frame the decoder failed to read. So the dot
is client-complete but dark today, and the design's one load-bearing
assumption — that a client which connects late can still learn who is online
— has no snapshot behind it. See `docs/BACKEND.md` for the full finding and
how to re-check it.

**Cost and known gaps:**

- Updates are merged, not replaced, because a delta and a roster cannot be
  told apart without the frame reference. Someone who goes offline in a way
  that *only* shows as their omission from a later roster keeps a dot until
  the connection drops. A single-user `OFFLINE` frame and an `offline: [...]`
  list both clear correctly.
- **Nothing renders until the service actually emits the frame** (see the
  verification note above). That is the honest state of this feature: the
  client is finished and silent, not broken. If `presence` turns out never
  to be sent, the fix is server-side and no amount of client work reaches
  it — which is exactly the kind of gap `docs/BACKEND.md` exists to record
  rather than paper over.
- A chat deep-linked from a push while another tab was last on screen takes
  its own lease, so the header's dot works there; the Inbox rows behind it
  are lit by the same set.
- The socket now opens on the Inbox tab, not only inside a conversation. That
  is one connection while the user is looking at the list, and it closes on
  the next tab switch or when the app is backgrounded.
- `ACTIVE NOW` / `OFFLINE` in the chat header is unchanged copy. With presence
  live, `OFFLINE` is now usually true rather than always — but it still reads
  as an assertion during the moment before the first frame arrives.

---

## ADR-039 — Links in user text are tappable, and a post's links get Open Graph cards

**Status:** Accepted

A web address written into a post, a comment, a chat message or a bio was
dead text. Every external link the app *did* know about — a showcase
project's repo and live URLs, a chat attachment's download link — copied
itself to the clipboard instead of opening, because the app had no launcher.
ADR-014 recorded that omission and said an "Open" affordance would need
`url_launcher` first. This adds it, makes links in user text tappable, and
draws each link in a post as a preview card.

**`url_launcher` is now a dependency**, with `<queries>` entries for
`ACTION_VIEW` on `http` and `https` in the Android manifest. Those entries
are not optional: on API 30+ package visibility is opt-in, and without them
`canLaunchUrl` answers false on a phone that plainly has a browser, so a
tapped link does nothing at all. iOS needs no counterpart for `http(s)`.

**One launcher, one scheme check.** `ExternalLink.open` is the only caller of
`launchUrl` in the app. Everything it opens came out of another user's post,
and `launchUrl` will hand a `javascript:`, `intent:` or `file:` URL to a
platform handler without comment, so the check is an allowlist of `http` and
`https` rather than a list of things to block (OWASP A05/A06). It opens in
`LaunchMode.externalApplication`: this is someone else's page, and it should
be obvious that it is not Yello any more.

**Detection is deliberately conservative** (`LinkScanner`). A false positive
paints part of someone's sentence as tappable, which is worse than missing a
link, so only `http://`, `https://` and a leading `www.` start a match; the
host must carry a dot and a two-character last label; and trailing
punctuation is handed back to the sentence, including a closing bracket the
link never opened. `(see https://a.co/x).` opens `https://a.co/x`, and
`https://en.wikipedia.org/wiki/Dart_(language)` keeps its own bracket.

**`LinkedText` owns its recognizers.** Each link needs a
`TapGestureRecognizer`, recognizers hold resources and must be disposed, and
one built inside `build` leaks one per link per frame on a scrolling feed —
so the widget is stateful and rebuilds them only when its text changes. It
also absorbed the feed's `#hashtag` highlight (formerly `_contentSpans` in
`post_card.dart`), and looks for hashtags only *outside* the links, so a
URL's `#fragment` stays part of the URL.

**Hashtags are still not tappable.** `/search` is people-only and takes no
query parameter, so a tap would have to land somewhere arbitrary. The
highlight is the whole of the feature until there is a tag search to send it
to.

**Previews are fetched on the phone, because no service offers them.**
Neither yello-api, yello-chat nor yello-notify has a link-preview or
unfurl endpoint, so `features/link_preview` reads the page itself and parses
its `og:` tags. Four things follow from the URL being untrusted input and
the fetch running on the reader's device:

- **Its own bare `Dio`, not `ApiClient`'s** — the same reason the update
  channel has one (ADR-029). `AuthInterceptor` attaches the session's bearer
  token to every request it sees, and these go to whatever host an author
  typed into a post.
- **Every hop is vetted** by `PrivateNetworkGuard`, which is why redirects
  are followed by hand rather than by Dio. A post containing
  `http://192.168.0.1/reboot` would otherwise reach an address the *author*
  could never reach: OWASP A01's SSRF shape with the arrow turned around,
  the confused deputy being the reader's phone. The `og:image` a page hands
  back is checked again before it goes near an image widget.
- **The read is capped at 64 KB** and the socket is then closed. The tags
  live in the `<head>`; nothing here should pull a 40 MB page down a
  reader's mobile data.
- **Every string is entity-decoded, whitespace-collapsed and
  length-capped.** It is someone else's markup and it ends up in a widget.

**Regex, not a DOM parser.** The whole job is four strings out of the first
64 KB of a document that is never rendered. The `html` package would be a
new dependency parsing hostile markup for an `og:title`; nothing here is
reinserted into a document, so the usual hazard of regex-parsing HTML —
building a tree — is not in play.

**One cache for the whole app.** `LinkPreviewCubit` is a `registerLazySingleton`
holding URL → card, because the same link appears in the feed row, in the
post's own screen and in a repost's embed. Per-card cubits would fetch that
page once per card and again every time the post scrolled back into view.
`pending` doubles as the in-flight guard (hard rule 9), failures are
remembered so a dead link is not retried on every scroll, and the map is
capped at 120 entries — a singleton with an infinite feed in front of it
otherwise grows for the life of the process.

**Where the cards go:** under the body text on a text post, *under the
photos* on a photo post — the post's own pictures are what the card is for,
and a link card wedged above them reads as the post's main image. Up to
`kMaxLinkPreviews` (3) per body. Not in a repost's embed or a community-feed
row: both are already cards inside cards, capped at a few lines, and their
links still open.

**A failed preview draws nothing**, not an error card. The link is tappable
in the text above either way, and a card that exists only to say it could not
load costs a reader more room than it gives them.

**Cost:**

- A new dependency and two manifest entries, reversing part of ADR-014.
- A fetch per distinct link the reader scrolls past, on their data. Bounded
  by the 64 KB cap, one attempt per URL per session, and a page that answers
  nothing useful is never asked twice.
- The preview quality is whatever a page publishes. Sites that serve `og:`
  tags only to named crawlers will come back empty, and a page that is not
  UTF-8 comes back with mangled accents — no charset decoder, because
  nothing in a `<head>` is load-bearing enough to justify one.
- A link inside a tappable container (a repost embed, a community row) puts
  a span recognizer and the container's own tap in the same gesture arena.
  The innermost should win, which is the behaviour this relies on, and it is
  **unverified on a device** — there is no emulator in the dev sandbox.

---

## ADR-040 — Stickers are their own resource inside the chat feature, and a sticker is the whole message

**Status:** Accepted

`yello-chat` grew a sticker API: make one from a photo, keep it in a personal
library, send it, save someone else's out of a message, and pick from operator
published packs. This records how it is wired, and the four places the
mobile build reads the contract differently from the desktop design it came
with.

**Stickers live in `features/chat/`, not a feature of their own.** They are the
same service behind the same `ApiClient` and the same WebSocket, their paths
belong in `ChatRoutes` (rule 5 — one route holder per service), the picker is
only reachable from the composer, and the sticker rides on `MessageEntity`. A
sibling feature folder would have needed cross-feature imports in both
directions for no boundary anyone was asking for.

**They do get their own repository.** `StickerRepository` is separate from
`ChatRepository` because it needs neither of the two things
`ChatRepositoryImpl` exists to supply: the owner of a sticker is always the
token's user, so there is no viewer id to prime and no `fromMe` to derive, and
a sticker names nobody, so there is nothing for `UserDirectory` to hydrate.
What is left is the network guard and the exception → `Failure` mapping.
`ChatRepository` also did not need eight more methods. Sending stays on
`ChatRepository.sendMessage(stickerId:)` — that is a message, not a sticker.

**A sticker is the whole message.** The server rejects a body or
`attachmentIds` beside a `stickerId`, so `SendMessageUseCase` refuses that
combination rather than letting it become a 400, and `ChatCubit.sendSticker`
is its own path beside `sendVoiceNote` for the same reason that one is: there
is no draft to mix it into and it is sent the instant it is tapped. It follows
that the **composer's sticker button shares the idle slot with the mic** and
disappears as soon as there is something to send. That reads as a width
decision on a 320dp phone, and it is one, but the real reason is that offering
stickers next to a half-typed message offers something the API cannot do.

**One `StickerEntity` for three shapes.** The library, a pack and a message all
carry the same wire object with different fields filled — a message's has no
name and no `isMine`, because the owner's name is never on a message. One type
with empty defaults beat two near-identical ones; whether a sticker on a
message is already yours is the server's answer to `…/sticker/save`
(201 vs 200), not something the message claims.

**The presigned URL is not part of a sticker's identity.** `StickerImage.props`
leave it out, exactly as `AttachmentEntity.props` do (ADR-015): the history
poll re-signs every link, and counting that as a change would make the whole
transcript look new every few seconds. Images cache by sticker **id** and carry
a `ValueKey(url)` so a link that 403'd can resolve again. The recovery is
coarser than an attachment's, because **there is no `GET /ws/stickers/{id}`**:
`ChatCubit.refreshSticker` re-reads the newest history page, takes just the
sticker out of it and bumps `attachmentRevision` so the emit lands.

**`StickersCubit` is a singleton, and says who refreshes it.** Reopening the
picker should draw the grid it drew last time rather than a spinner, which per
`docs/GOTCHAS.md` makes staleness its own problem. Two answers, written on the
class: the picker calls `load()` on **every** open (the packs route is
conditional, so that is usually one 304), and it leases the `sticker.*` frames
while it is on screen. The lease matters — subscribing to `ChatSocket.frames`
is what opens the connection, so an always-on subscription would hold a
WebSocket open from the Inbox tab. Everything this device does to the library
is applied from the response, so neither answer is load-bearing for the device
that made the change; the frames are for the user's *other* sessions, and
because they reach the calling socket too, every branch is idempotent on the
sticker's id.

**Where the mobile build differs from the desktop design:**

- **No drag-and-drop, no paste.** Step one of the creator becomes a tappable
  box over the photo library, plus a camera button a desktop has no use for.
- **The picker is a bottom sheet**, height-bounded rather than fixed, so the
  search keyboard shrinks the grid instead of overflowing a short phone. Tile
  size falls out of the available width — a hard-coded 80dp tile overflows at
  320dp, which is also what a 360dp phone becomes at Android's larger Display
  size setting.
- **Manage a sticker by long press**, not right-click: Send / Rename / Delete,
  and only on a sticker that is actually yours (a pack's answers `404` to
  both).
- **No drop shadow under a sticker.** The design lifts a framed sticker with a
  blurred shadow. A blurred `BoxShadow` in a widget that rebuilds on Cubit
  state crashed this project's renderer, and the transcript rebuilds on every
  poll, so the white frame carries it alone (rule 8). The frame itself goes in
  `foregroundDecoration`, or the edge-to-edge picture paints over it.

**Background removal is handled but currently unreachable.** Every draft comes
back `NO_SUBJECT` with no cut-out because the server has removal switched off
(300 MB of container). The creator therefore defaults to `Keep`, disables
`Remove`, and shows the server's own explanation — and the moment a draft
answers `READY` with a cut-out, the checkerboard preview and the choice appear
with no client change. `StickerCutoutStatus.fromWire` is deliberately strict
about this: only a literal `READY` *with* a cut-out picture counts, because
asking for `REMOVED` without one is a 409.

**Cost:**

- Nine new files in `features/chat/`, and `ChatCubit` gains a ninth usecase.
- The sticker-pack `ETag` lives in the datasource for the life of the process,
  so a pack withdrawn mid-session is not noticed until the app restarts —
  which is the trade the conditional route is for, and withdrawals are rare.
- `refreshSticker` costs a whole history page to recover one link. Guarded per
  sticker id, and only reached from an image that actually failed.
- Search is client-side over the library and the packs, so it only finds
  stickers whose page has been loaded. A 200-sticker library is two pages and
  the second is only fetched when the grid is scrolled, so a name on page two
  is unsearchable until then. No search endpoint exists to do better.
- Every sticker surface is **unverified on a device** — there is no emulator in
  the dev sandbox, and the picker sheet, the grid at 320dp, the keyboard inset
  and the transparent-WebP decode all want a real phone.


---

## ADR-041 — Link previews accompany linked text across the app

**Status:** Accepted. Supersedes ADR-039's placement, three-card cap, and hidden-failure decisions.

`LinkedText` now owns the preview list below its text, so chat, comments, bios,
community rows, repost embeds and descriptions share the same behavior. Existing
post-only lists are removed to avoid duplicate cards, and photo-post previews
now appear immediately below the caption. Showcase repository and live URL rows
also include a preview underneath.

Every distinct detected web URL gets a card. Pages without metadata or accessible
images show a local image placeholder and the host; we do not invent a thumbnail
or send URLs to a third-party screenshot service. Existing guarded, unauthenticated
fetches, per-URL selectors, caching and in-flight deduplication are reused.

Cost: long bodies with many links produce taller content and more preview requests.
Repeated URLs within one body share a card. Device layout and gestures remain
unverified; validation for this change uses local Flutter checks only.

---

## ADR-042 — Calls are socket frames, drawn above the router, with LiveKit behind one wrapper

**Status:** Accepted

1:1 audio and video calls, from `yello-chat`'s Calls API (see
`docs/BACKEND.md`). A new `features/call` slice; the media SDK
(`livekit_client`) lives behind `core/call/call_room.dart`.

**Its own feature, not part of chat.** Stickers went inside chat (ADR-040)
because they only ever appear in a conversation. A call starts from a chat
header but rings on any tab and outlives every screen, and its whole
presentation layer — a cubit that is a singleton, UI that sits above the
router — has nothing in common with chat's. It shares chat's *transport*
(`ChatSocket`, `ChatRoutes`, the same `ApiClient`), which is what
`CallRemoteDataSourceImpl` injects; one connection, not two.

**Requests over the socket, for the first time.** ADR-017 kept every request
on HTTP. Calls cannot: start, accept, decline and end exist only as frames.
Each frame carries a fresh `ref`, and `_request` waits for the first frame
that answers it — the named reply, or an `error` frame echoing the `ref`.
`call.end`/`call.decline` treat five seconds of silence as success, because
ending an already-ended call is documented to produce no frame at all.

**The socket is held app-wide while the app is on screen.** ADR-038 leased
it to the two surfaces that draw a presence dot. A ring can only reach a
connected device, and the service does not push calls to offline devices
yet, so `CallHost` holds a lease whenever the user is signed in and the app
is resumed (or merely `inactive` — a permission prompt or the notification
shade). A live call keeps it regardless of lifecycle. Cost: one idle socket
while the app is open on any tab; that is the price of a phone that rings.

**UI above the router, not a route.** A call route would be torn down by
`goNamed` (a push deep link resets the stack) and would have to be found and
popped from under whatever was pushed over it. `CallHost` sits in
`MaterialApp.router`'s `builder`, beside the router's output in a `Stack`:
full screen, or a pill once minimized. Back is taken by a
`ChildBackButtonDispatcher` with priority (Back = minimize), and Android's
predictive-back question ("will the framework handle Back?") is answered by
catching the router's `NavigationNotification`s and re-sending them with the
call folded in — see `docs/GOTCHAS.md`.

**Recovery offers, it does not rejoin.** After every `auth.ok`,
`GET /ws/calls/active` is compared with what the screen shows. A ringing
call is shown; an ended one closes; but an `ACTIVE` call this device is not
in becomes `CallPhase.interrupted` (Rejoin / End). Rejoining automatically
would be right after a crash and wrong when the call is running on the
user's other device — LiveKit admits one participant per identity, so the
second join would put the first device out of its own call.

**One wrapper per device concern.** `CallRoom` (LiveKit), `CallTones`
(ring and ringback — bundled WAVs from `tool/generate_call_tones.py`, played
as a *ringtone* on Android so silent mode silences it) and `CallKeepAlive`
(the Android foreground service) are each the only place their platform API
is touched — `VoiceRecorder`'s shape — so `CallCubit` is testable with
mocks and no WebRTC.

**A native foreground service, not a package.** Android silences an app's
microphone soon after it leaves the screen — a screen timing out mid-call is
enough — unless a microphone-type foreground service runs. `CallService.kt`
is that and nothing else, behind the `yello/call` channel beside
`yello/installer`, for the reason `MainActivity.kt` already gives: the
packages in this space bundle a background isolate the call does not need.
It is started with `startService` and promotes itself, not with
`startForegroundService`, whose "promote within seconds or die" contract
cannot be met on a first call (Android 14 refuses the promotion until
RECORD_AUDIO is granted, which WebRTC only asks for once it publishes).

**Known gaps:**

- No ring while the app is closed or backgrounded — a server-side push is
  the only fix.
- iOS: no CallKit, and the screen auto-locks during a video call. Call audio
  continues in the background through the `audio` background mode.
  Unverified: there is no iOS build here.
- The caller does not pre-connect to the room while it rings (the guide
  allows it). Joining on `call.accepted` keeps the ringback out of WebRTC's
  audio session; the cost is a second or so before audio flows.
- No proximity sensor: an earpiece call leaves the screen on until it times
  out.

## ADR-043 — The Feed header carries Signals and Inbox; Community is a tab of the feed

**Status:** Accepted.

The Feed's header was restyled to a reference design: brand tile + wordmark on
the left, round Signals and Inbox buttons with unread counts on the right, a
borderless stories row, then **Feed / Community** tabs.

- **Three header actions: Search, Signals, Inbox.** Circle left the header
  and stays reachable from Profile's connections row, now its only entry
  point — see the comment in `profile_page.dart`.
  Inbox duplicates the bottom bar's Chat slot on purpose; the header button
  shows a count, the bar a dot.
- **Community = `GET /community-posts?scope=joined`.** The scope already
  existed on `CommunityFeedCubit`; the feed page provides its own instance,
  lazily, so the Feed tab never pays for the community fetch until the tab is
  first opened. It lives as long as the (kept-alive) Feed page, so re-entering
  the tab refreshes it — otherwise a community joined elsewhere would never
  appear (the long-lived-cubit staleness in `GOTCHAS.md`).
- **One scroll view, two bodies.** Both tabs render into the feed's existing
  `CustomScrollView` under a pinned `SliverPersistentHeader`, rather than a
  `TabBarView`/`NestedScrollView`: the stories row and header scroll away the
  same way on either tab, and `FeedCubit`'s scroll-survives-tab-switch
  behaviour is untouched. The cost is a shared scroll offset between the two
  tabs. Pull-to-refresh and load-more act on whichever tab is showing.
- The date eyebrow stays, as its own sliver above the pinned bar (not inside
  it — see `DateLabel`'s doc comment).

## ADR-044 — Circle returns to the Feed header, in Inbox's place

**Status:** Accepted. Amends ADR-043's header actions.

The Feed header's actions are **Search, Signals, Circle**. The Inbox button
is gone from the header: Inbox already has the bottom bar's Chat slot, so the
header copy was a duplicate, while Circle (branch 1) had no entry point but
Profile's connections row. Circle uses the badge-less header button — there is
no unread count for it — and `AssetConstants.circleIcon`, drawn untinted as
before. Selecting branch 1 triggers no refresh in `MainShellPage`, so a bare
`goBranch(1)` is the whole action.

## ADR-045 — Someone else's profile shares the Profile tab's layout

**Status:** Accepted. Supersedes the "two shapes, two skeletons" bullet of
ADR-024.

`public_profile_page.dart` had kept the old header card (a
`Transform.translate`-shifted card and avatar, a handle pill, three stat
tiles, a hand-rolled pill switcher) after the Profile tab moved on, so tapping
into someone's profile changed the whole shape of the screen. It now builds
from the same pieces as `profile_page.dart`:

- **Header.** `ProfileHeader` and the new `PublicProfileHeader` both render
  through one private `_HeaderFrame` in `profile_header.dart`, so the two can
  no longer drift. The public one has no camera buttons, a plain connections
  count (no face-pile or chevron: there is no endpoint for someone else's
  friends), a posts count where yours shows account status
  (`PublicUserResponse` has no status), and a linkified bio. Its action row
  is supplied by the page: friend action + Message, as two equal buttons in
  the slots Add to story / Edit profile use.
- **Top bar.** The collapsing bar moved out of `profile_page.dart` into
  `ProfileTopBar` (`profile_top_bar.dart`), taking the identity as data
  instead of reading `ProfileCubit`, plus an optional `leading` back button.
  Its Impeller-safe painted shadow (GOTCHAS) moved with it unchanged.
- **Block user** left the header row for a **⋯** menu in the top bar — the
  row is for the two primary actions, as on your own profile.
- **Details / switcher / skeleton.** `ProfileDetailsCard.public` (no email
  row, no "Add your name" prompt), `SegmentedTabs` with All / Shared (no
  Saved — that list is the viewer's own), and `ShimmerOwnProfileView` with
  `detailRows: 3`. `ShimmerProfileView` had no other caller and is deleted.
- The stat tiles are gone: connections moved to the facts line, the shared
  count to its tab label, the join date to the details card. Nothing they
  showed was lost.

**Revisit if:** the API grows a public friends list (the connections row
could then take a face-pile and open it).

---

## ADR-046 — One screen-space shimmer, and a skeleton for every loading state

**Status:** Accepted

`ShimmerBox` was redrawn from scratch; every skeleton built from it
(ADR-013) changes with it. Every loading state that still showed a spinner
or the generic `ShimmerListCard` now has a skeleton shaped like its content.

- **Fill.** A bone is `ink` at 6.5% (light) / 8% (dark) opacity, not a
  palette token. The old `surf2` → `line` → `surf2` gradient was nearly
  invisible on a white `surf` card, and its highlight (`line`, 10% ink) was
  *darker* than its base. In both Quiet Rails palettes it disappeared
  completely. An `ink` wash reads on every surface in all four palettes,
  because `ink` always contrasts with `surf`.
- **Sheen.** A lighter band (`ink` at 2% light / 15% dark), 220px wide and
  leaning 18°, crosses the *screen* in the first 72% of a 1.7s loop, eased,
  then rests. Every bone reads the band from a shared `Stopwatch` and places
  it in global coordinates (`localToGlobal` in paint). So all the bones on
  screen are lit by one diagonal at the same moment, and a skeleton shimmers
  as one surface. Before, each box ran its own controller from whenever it
  was built, and a box's sweep speed depended on its width.
- **Cost model.** Each bone is a leaf `RenderBox` that is its own repaint
  boundary. It keeps a `Ticker` (so it pauses under `TickerMode`, e.g. an
  inactive shell branch) that only calls `markNeedsPaint`: no rebuilds, and
  the card chrome around it is never repainted. Nothing repaints during the
  resting tail. With `MediaQuery.disableAnimations` on, the ticker stops and
  the bone is drawn flat.
- **Shared row tile.** `ShimmerListTile` (in `shared/`) is an avatar + title
  + optional subtitle + optional trailing, with every measurement passed in
  by the call site. This is a deliberate exception to ADR-013's "one
  skeleton file per row". The inbox, Circle, group members, friend pickers,
  reactors, story viewers and reaction breakdown rows differ only in
  numbers. Eight files of the same `Row` would add nothing, and a call site
  that passes the row's padding and avatar size keeps the numbers next to
  the row anyway. Rows with their own chrome still get their own file:
  notification, archive, comment, community comment, chat thread, group
  info, post detail, project detail, preferences, Circle's section card.
- **Load-more.** The feed and the Community timeline show a post skeleton
  instead of a spinner while the next page loads. Small lists (sheets,
  story archive, notifications) keep their small footer spinner, and so do
  buttons and full-bleed media viewers.

**Revisit if:** a screen needs the bones to sit on something other than a
plain surface (a photo, a coloured slab). The translucent `ink` wash will
tint whatever is under it, which is right on cards but might not be on
imagery.

---

## ADR-047 — Group calls reuse the 1:1 flow; the viewer's own roster entry decides

**Status:** Accepted

`yello-chat` added group calls and screen sharing (2026-09-30). ADR-042's
shape stays: one `CallCubit` singleton, UI above the router, LiveKit behind
`CallRoom`. What changed is how the cubit reads a call.

**One state machine, not a second cubit.** A user is still in at most one
call, DM or group, so a separate `GroupCallCubit` would need the same
socket, recovery, keep-alive and ended screen, and would have to coordinate
with the first over "one call at a time". `CallState.kind` says which it is
(known before the server answers, so the screen is right from the first
frame); the phases are the same.

**The viewer's roster entry, not the frame's name, decides.** In a DM,
`call.accepted` means "answered". In a group it reaches every member while
most of them are still being rung, and `call.updated` can mean joined, left,
declined, missed or removed. So group frames go through one method,
`_onRoster`, which switches on phase × `CallEntity.viewerState`: INVITED
keeps ringing, JOINED stays (or starts the join while connecting), anything
else closes the call here. The DM paths are unchanged.

`viewerState` is derived in the mapper from the viewer id the repository
already resolves per subscription (the `isOutgoing` pattern). The repository
now reuses that id for `startCall`/`acceptCall` instead of another
`GET /users/me`, so answering costs no extra round trip; it is cleared with
the subscription, so it cannot outlive a sign-out.

**`CALL_IN_PROGRESS` is handled in the data source.** The guide's answer is
"send `call.accept` for `details.callId` instead" — a transport detail, not
a UI decision. `startCall` resolves with the call the viewer is now JOINED
in, and the cubit joins any `startCall` result that comes back `ACTIVE`. The
chat's call buttons never need to know whether a call is running.

**"Join call" is a per-page cubit.** `ConversationCallCubit` (a factory,
param = conversation id) loads `GET /ws/conversations/{id}/call` and follows
the same frames. It is not folded into `CallCubit`, which tracks the one
call the viewer is *in*; the bar is about a call they are *not* in.

**Tiles come from the LiveKit room, names from the conversation.** The
server's JOINED is not who is connected; the guide says to draw from the
room. The room knows identities (= user ids, per the token), the call knows
ids, and only the conversation knows names and avatars, so
`CallState.members` is resolved once from `GetConversationUseCase`.

**Screen share: Android only, published by hand, 30 fps.**
`setScreenShareEnabled(true)` takes the room's default publish options — the
camera's — so `CallRoom` builds the track and publishes it with the guide's
VP9 `L3T3_KEY` / VP8-backup / maintain-framerate settings at the guide's
slow-machine numbers (a phone encoding its own screen is that machine).
Android needs a MediaProjection consent *and* a `mediaProjection` foreground
service before capture — see `docs/GOTCHAS.md`; `CallService` gains that
type while sharing rather than a second service. iOS needs a Broadcast
Upload Extension, its own target and signing work, so the button is hidden
there. `flutter_webrtc` became a direct dependency for the consent call
alone (`Helper.requestCapturePermission`), at the version LiveKit already
resolves.

**Also fixed on the way:** `CallRoom` mapped every LiveKit disconnect to
`lost`, so `closed` and `replaced` were never produced — a removal from the
group would have been retried as a network drop and then ended with a
`call.end`. `DUPLICATE_IDENTITY` now maps to `replaced`,
`PARTICIPANT_REMOVED`/`ROOM_DELETED` to `closed`.

**Known gaps / unverified:**

- Nothing here has run against a live group call or on a device yet.
- LiveKit identity = user id is inferred from the guide ("as you").
- The group caller does not pre-join the room while it rings (ADR-042's
  choice for DMs); the guide allows it.
- Stopping a share from Android's own status-bar chip is not observed; the
  button reads "sharing" until tapped.
- No screen-share audio (`livekit_client` supports it on the web only).

**Revisit if:** calls grow features only groups have (hand raise,
spotlight, moderation) — then a dedicated presentation cubit for the grid,
fed by `CallCubit`, is cheaper than more branches in `_onRoster`.

---

## ADR-048 — The call UI follows the theme: white in light mode, black in dark

**Status:** Accepted

The call screens were drawn from the dark token set in both themes, on the
reasoning that a call is shown over video and a light screen at night is a
flashlight. Asked for otherwise (2026-09-30): the call UI now follows the
theme — pure white in light mode, pure black in dark — the same
`surf`/`shell` pairing the chat header slab already uses, with the active
theme's tokens for everything drawn on it.

- **One palette, read per widget.** `CallPalette.of(context)` in
  `call_widgets.dart` names the handful of roles the call UI needs
  (background, raised surface, solid disc, tray and its discs, status-bar
  style) on top of `AppColors.of(context)`. The old `onCallColors` constant
  is gone.
- **Full-screen video is the exception.** A 1:1 call draws its name, status
  and controls over the other person's video, under a dark scrim; dark text
  there would vanish into a dark picture. That layer is wrapped in
  `OnVideoTheme`, which swaps in the dark tokens whatever the theme. Group
  tiles don't need it: their badges and name chips carry their own
  translucent black backing.
- **The group tray inverts with the screen.** A light bar with black discs
  on the black screen (the reference image), a soft grey bar (`slot`) with
  dark discs on the white one.

**Revisit if:** people take video calls in light mode at night and find the
white screen harsh — a "keep calls dark" setting would bring the old
behaviour back behind a choice rather than for everyone.

## ADR-049 — Three button variants, picked by importance

**Status:** Accepted

`AppButton` had grown four variants (`primary`, `outline`, `subtle`,
`danger`), and about ten actions skipped it for Material's `TextButton`,
which draws yellow text on the theme's `primary`. Two call sites with the
same role ended up looking different ("Edit profile" was `subtle`,
"Connections" beside it was `outline`). Asked for a single rule
(2026-09-30): primary for the important action, secondary for the rest.

- **`AppButtonVariant { primary, secondary, danger }`.** `secondary` is the
  old `outline` look (transparent, `line` border, `ink` label). `subtle`'s
  `surf` fill was indistinguishable from `outline` on a `surf` card and
  only distinguishable on `bg`, which is not a reason to keep a fourth
  kind. The enum's doc comment is the rule: one `primary` per group,
  `danger` only on the confirm step of something destructive.
- **Every variant greys out when disabled.** Before, only `primary` did;
  a disabled `outline` looked identical to an enabled one.
- **Confirmations go through `AppWarningDialog`.** The five remaining
  `AlertDialog` + `TextButton` confirms (delete post, delete comment ×2,
  remove friend ×2, unblock) moved onto it. It gained `destructive:` so a
  confirm that loses nothing ("Unblock") is `primary`, not red.
- **Loose `TextButton`s became `AppButton(secondary, dense)`.** "Load
  more", "Unmute", "Unblock", "Close", the new-conversation dialog's
  "Cancel". Inside a `ListView` the button is wrapped in `Center`, since
  list children are stretched and a stretched pill left-aligns its label.

Left alone on purpose: the story viewer's "Close" (always drawn on black,
where theme `ink` would vanish), the story archive's view count (a tappable
figure, not an action label), and `AppIconButton` (icon chrome, not a
labelled action).

**Revisit if:** a screen genuinely needs a third level below `secondary`
(an inline text link inside a paragraph, say) — add a `text` variant then,
rather than reaching for `TextButton` again.

## ADR-050 — Ink outline is a flavor, and "how it's drawn" lives in `AppStyle`

**Status:** Accepted

Asked for (2026-09-30) a HushStack-style look — thick outlines, hard offset
shadows — on the app's own colors, fonts and screen structure, selectable
from the Theme screen rather than replacing the current look.

- **A third `AppThemeFlavor`, `ink`.** The Theme screen, `ThemeCubit` and
  persistence already handle flavors, so adding one is a case, not a
  feature. Its palettes (`AppColors.inkLight` / `inkDark`) are the classic
  pair with one change: `line` is solid `ink`. That single token turns every
  existing 1.5px hairline (cards, pills, inputs, tab rows, bubbles) into a
  drawn outline without visiting each call site. `line2` stays faint, so
  dividers *inside* a card remain seams.
- **Drawing lives in a second extension, `AppStyle`.** Colors can't express
  "2px border plus a solid offset", and switching on the flavor in widgets
  would spread one theme's knowledge across the tree. `AppStyle.outlined`,
  `borderWidth` and `hardShadow(...)` sit next to `AppColors` in `ThemeData`.
  `AppShadows.card` returns the hard 5px offset under ink, which restyles
  the ~35 card call sites at once.
- **Every hard shadow has zero blur and is black.** It is a solid copy of
  the shape in the `shell` token (near-black in light, black in dark). It
  started as `ink`, which made it cream under cream outlines in dark mode;
  that read as a glow and was switched to black on request (2026-09-30),
  matching the app's older "shadows are black, never ink" rule. Zero blur
  keeps it clear of the Impeller `BoxShadow` crash (docs/GOTCHAS.md). The
  two chrome pieces on the always-black chat slab keep a visible colour
  instead (search: yellow, compose button: cream), since black would vanish
  there.
- **Chrome that had no border gets `InkOutline`.** `AppIconButton` draws
  only an icon, so the round buttons on Feed, Profile and the chat header
  and composer are wrapped in `InkOutline`, which returns its child
  untouched outside ink. The soft flavors render exactly what they did
  before.
- **Offsets by role:** cards 5, pill containers 4, buttons 3, active chips
  and badges 2. Disabled buttons drop the shadow. The chat inbox search
  field's shadow is yellow, since it sits on the always-dark slab.

**Revisit if:** more screens need outlined chrome than `InkOutline` call
sites comfortably cover. Then give `AppIconButton` an opt-in outlined mode
instead of wrapping it at each use.

## ADR-051 — Incoming-call pushes: the app draws the ring on Android, iOS opens only

**Status:** Accepted

`yello-notify` now pushes `CALL_INCOMING`, `CALL_MISSED` and
`CALL_RING_STOPPED` (docs/BACKEND.md), so a phone can ring with the app in
the background or killed.

- **Android: drawn by the app, from the data-only push**, in
  `core/notifications/call_alert.dart` — its own `yello_incoming_calls` channel (the
  system ringtone at ringtone volume, `max` importance), `FLAG_INSISTENT` so
  it rings until something stops it, `timeoutAfter` at `expiresAt`,
  `CATEGORY_CALL`, a full-screen intent, Decline and Accept. Not a native
  `FirebaseMessagingService` with `CallStyle` as the guide sketches: the
  data-only push already reaches `firebaseMessagingBackgroundHandler` with
  the app killed, and a second native push stack beside `firebase_messaging`
  would fight it for `onMessageReceived`. What is given up is `CallStyle`'s
  look (the plugin cannot build one).
- **Accept goes through the running app, not around it.** It opens the app
  and leaves a pending call id (`PushNotificationService.takePendingCallAnswer`,
  handed on by `CallHost`); `CallCubit.answerFromNotification` answers once
  the socket's own recovery (`GET /ws/calls/active`) shows that call ringing.
  `call.accept` is a socket frame, so answering before the link is up would
  only fail; reusing recovery also covers "the call ended while the app
  started" with a "Call ended" screen.
- **Decline runs headless** in the plugin's background engine over the new
  `POST /ws/calls/{id}/decline`, with the same token handling as the chat
  reply (`background_auth.dart`, shared by both now). Not queued through
  WorkManager as the guide suggests: every answer but a 401 means "done",
  and a network failure leaves the server's 45 s timeout to end the ring as
  missed — no new dependency for that one case.
- **The app on screen draws nothing.** `onMessage` means the socket is
  already ringing in the app; the push is the same call. When the app comes
  forward some other way while a ring is up, `CallHost` takes the drawn ring
  down as soon as the call is live in the app.
- **The activity is not `showWhenLocked`.** The full-screen intent wakes the
  phone to the ring; Accept then asks for an unlock rather than opening the
  whole app over the keyguard for anyone holding the phone.
- **iOS gets the alert and tap-to-open only.** iOS draws the alert itself;
  a tap opens the app, whose recovery rings in-app. The `YELLO_CALL`
  category's buttons are deliberately not registered: neither plugin can
  tell Accept from Decline on an alert iOS drew (docs/GOTCHAS.md), so a
  Decline button would decline nothing. `CALL_RING_STOPPED` cannot remove an
  alert iOS drew either — best effort, as the guide allows.

**Revisit if:** the iOS buttons are wanted — that is native `AppDelegate`
handling of `YELLO_CALL` responses (decline over `URLSession` with the
keychain token, Accept forwarded to Dart), built and checked on a Mac; or
CallKit arrives server-side (VoIP pushes), which replaces the iOS path
outright.

## ADR-052 — A task's state lives in a gitignored scratchpad, driven by five commands

**Status:** Accepted

`/scope` → `/plan` → `/develop` → `/verify` → `/ship` each read and write
one file, `docs/current-task.md`, with three sections: `## Scope`, `## Plan`,
`## Verify`. `/ship` refuses without `Result: pass` and resets the file.

**Why:** ADR-008's docs make *onboarding* cheap, but nothing made *resuming*
cheap — a context reset mid-task meant re-deriving the goal, the files and
how far the work had got from `git diff`. A checklist on disk is the
smallest thing that survives that. It is gitignored because it is one
developer's in-flight state, not history: the durable part of a task already
lands in `CHANGELOG.md`, `docs/DECISIONS.md` and `docs/GOTCHAS.md` at ship.

The five commands sit beside the existing seven rather than replacing them.
`/verify` is `/preflight` narrowed to affected tests plus a `flutter-reviewer`
pass against the scope; `/ship` applies `/changelog`'s and `/adr`'s rules.
Rejected: a `docs/ai/` tree and `.claude/rules/` as in the template this came
from — this repo already has `docs/` and `AGENTS.md` doing those jobs, and a
second home for the same rules is how they drift.

`.claude/settings.json` also denies `git push --force*` and
`git reset --hard*`, so an assistant can't discard work on its own.

**Cost:** one task at a time per checkout — `/scope` overwrites. And the
gate is a convention the commands follow, not something git enforces; a
commit made by hand skips it.

**Revisit if:** two tasks routinely run in one checkout (then key the file
by branch), or the gate needs teeth (then a pre-commit hook, not more prose).

## ADR-053 — A newer build is offered at launch, by a sheet that hands off to App version

**Status:** Accepted. Narrows ADR-029's "a card in settings": the card is
still where an update is downloaded and installed, but it is no longer the
only place one is announced.

ADR-029 left the update check behind a button on the App version screen, so
a user who never opened that screen never learned a newer build existed —
the same "keeps running an old build forever" problem the updater was built
to end. Asked for (2026-10-01): a bottom sheet that appears when a new
version is available, whose "Update now" opens the version screen.

- **The shell checks once per launch.** `MainShellPage` calls
  `AppUpdateCubit.checkOnLaunch()` after its first frame, Android only. The
  shell rather than `bootstrap()` because it needs a `BuildContext` to show
  a sheet, and it only exists once the session is authenticated — nobody is
  prompted over the login screen.
- **`checkOnLaunch` is not `check`.** Nobody asked for it, so it runs once
  per process (a flag on the singleton cubit: logging out and back in
  rebuilds the shell and must not prompt twice), it does nothing unless the
  cubit is `idle`, and a failure returns to `idle` instead of leaving "The
  update check failed" waiting on a screen the user has not opened.
- **It returns the build instead of the shell listening for `available`.**
  A `BlocListener` would also fire for a check the user runs by hand on the
  App version screen, and put the sheet over the card that already says the
  same thing.
- **"Update now" navigates; it does not download.** The sheet resolves to a
  bool and the shell pushes `appVersion`. The cubit is already `available`,
  so the screen opens on the card offering the download. The progress bar,
  the "install unknown apps" permission step and the retry row all live
  there (`UpdateCard`), and a second copy of that state machine in a sheet
  is the thing to avoid.
- **"Maybe later" is remembered for the process only.** The next cold start
  asks again. For a sideloaded app that is the point; persisting the
  dismissal per build would need storage and a usecase for a prompt that is
  one tap to close.
- **The checklist is the manifest's `notes`, split.** `latest.json` carries
  one folded line (`tool/release_manifest.sh`), so `updateHighlights` splits
  it by sentence, or by line when the notes were written one item per line,
  and shows at most three. No notes, no checklist.
- **The call to action is not an `AppButton`.** The design draws it as a
  dark slab with a yellow label, echoing the banner; ADR-049's yellow
  primary would be the second yellow block in a sheet that already has one.
  It is private to the sheet, and flips to the ordinary yellow face on a
  dark theme, where a `shell`-coloured slab would sink into the sheet.
  "Maybe later" is plain text for the same reason — the design's third
  level below `secondary`, which ADR-049 said to revisit when it turned up.

**Cost:** one unauthenticated GET to the release host per launch, on a bare
`Dio` (ADR-029), after the first frame.

**Revisit if:** an update has to be forced (ADR-029's `minBuildNumber`
gate), the prompt proves too frequent (then remember the dismissed build
number), or a second sheet wants the plain-text action (then add
`AppButtonVariant.text` and move both onto it).

## ADR-054 — A new version is announced by a hand-sent FCM push that opens App version

**Status:** Accepted

ADR-053's sheet only reaches someone who opens the app. Asked for
(2026-10-01): a Firebase Cloud Messaging notification for a new version
that, when tapped, goes to the version screen.

- **Sent from the Firebase console, not by `yello-notify`.** The backend has
  no version resource and no broadcast endpoint (`docs/BACKEND.md`), and a
  release is cut by hand anyway. A console campaign reaches every install's
  FCM token with no server change. The step is in README's Releasing.
- **The contract is one data key: `type: APP_UPDATE`.** It joins
  `NotificationTypes` and resolves to `AppVersionDestination` ahead of the
  id ladder, the same way `REPORT_RESOLVED` names a screen rather than a
  thing. The shell opens App version over the Profile tab.
- **The push carries no version.** The screen re-reads `latest.json` when it
  opens, so the announcement cannot disagree with the file it leads to —
  and a push sent before the manifest is live shows "newest build", which
  is why the README orders it after the verify step.
- **A tap re-checks.** `AppUpdateCubit.checkAnnounced()` is `check()` — a
  tap is the user asking, so a failure shows — except that it spends the
  launch check (the sheet over the screen it would lead to is noise) and
  leaves a downloaded file alone. Without it, a warm app would open the
  screen on whatever a check hours ago had concluded.
- **No topic subscription.** A console campaign targets the app itself.
  A topic only earns its place when something other than a person sends
  the push.

**Cost:** it is a manual step that can be forgotten, and the console cannot
target "installs older than build N" without Analytics audiences — everyone
on Android gets it, including people already updated, who land on "You are
on the newest build".

**Revisit if:** releases are automated (then subscribe to an `app_updates`
topic and send from CI through the FCM HTTP v1 API), or `yello-notify`
grows a broadcast type (then it should own this push and its inbox row).

## ADR-055 — A finished call's line in the chat is the app's own, kept on the device

**Status:** Accepted

Reported 2026-10-01: calling someone who declines leaves nothing in the
conversation. Nothing was broken — `yello-chat` writes no call line. A
`Message` has no call field, a finished call creates no message, and no route
lists past calls (`docs/BACKEND.md`, re-checked against `/ws/docs-json`).

- **Noted on the device, as each call ends.** `CallCubit` is the one object
  that hears every `call.ended` while the app is on screen, so it records a
  `CallLogEntry` there — for *every* such frame, not only the call on screen:
  the callee who declined has already closed theirs, and a group call ends
  long after a member left it.
- **The device's own endings are noted without waiting.** Declining, giving
  up while it rings, hanging up a DM and a `BUSY` reply are recorded at once;
  the server's frame for the same call replaces the note (one entry per call
  id), so the line cannot double. Leaving a group call notes nothing — the
  call goes on.
- **`shared_preferences`, one JSON value, newest 200.** The saved-posts
  trade-off again (`BookmarksLocalDataSource`). Cleared on sign-out through
  `CallCubit.reset()`: the entries carry no account id, and a DM's other
  member signing in on the same phone would read them from the wrong side.
- **Its own repository, not three more methods on `CallRepository`.** That
  interface is `yello-chat`; this never touches the network.
- **Drawn by the chat page, merged by time.** `chatThreadRows` slots the
  entries between the loaded messages at the time each call *rang*, and holds
  back one older than the oldest loaded message until that page is pulled in.
  A line is not a `MessageEntity`: it has no sender, no id the server knows,
  and nothing can be done to it.
- **Not a real message sent by the caller.** A "Declined call" text message
  would reach both sides and every device, but it is a message the user never
  wrote — editable, deletable, quotable, counted as unread, pushed as a
  notification — and each client would send its own.

**Cost:** the two sides can disagree (each phone notes only what it heard),
nothing syncs or survives a reinstall, and a call that ended while the app had
no socket — missed with the app closed, declined from the notification —
leaves no line. The inbox row's preview does not mention a call either.

**Revisit if:** `yello-chat` starts writing a call message or grows a call
history route — then delete the local log (`CallLog*`, the two `_log` calls in
`CallCubit`) and render the server's, rather than merging the two. Short of
that, the `CALL_MISSED` push could note a missed call from the background
isolate; it would need the foreground to `reload()` the preferences.

## ADR-056 — A call note that arrives as a text message is recognised by its words

**Status:** Accepted

Reported 2026-10-01: "Cancelled voice call" sits in a thread as an ordinary
bubble from the caller, indistinguishable from something they typed. These are
not ADR-055's lines (those are centred pills, drawn from the on-device log).
They are real `Message`s whose `body` is the note — sent by something other
than this app, with no call field on the wire to say so (`docs/BACKEND.md`).

- **Read from the text.** `callMessageOf` matches the whole body against
  "[lead] voice|audio|video call [tail]" — anchored at both ends, at most 48
  characters, case-insensitive. It is the only signal there is.
- **Only a bare text message qualifies.** A quote, an attachment, a sticker,
  an edit or a tombstone each rule it out: a person wrote those.
- **Still a bubble, on the sender's side.** It is a real message — it has a
  sender, a time, a read state, reactions and a long-press sheet — so it keeps
  its row and only its inside changes: `CallMessageCard` (badge, kind of call,
  what became of it) in a flat `surf2` bubble, never the yellow fill. Turning
  it into ADR-055's centred pill would drop who called, which a group needs.
- **Red means it never connected**, the same reading as `CallLogLine`.
- **Presentation only.** `MessageEntity` gains nothing: a guess from the words
  is not a fact about the message, and the inbox preview, quotes and
  notifications keep showing the text as sent.

**Cost:** a person who types exactly "Missed voice call" gets the card. A
phrasing the pattern does not know stays a plain bubble. And a call this phone
also heard end is drawn twice — the sender's card and ADR-055's pill.

**Revisit if:** `Message` grows a call field — switch `callMessageOf` to it
and drop the pattern; and settle the double line then (ADR-055's "Revisit if").

## ADR-057 — Pchum Ben is a flavor whose ornaments hang off one `AppStyle` flag

**Status:** Accepted

Asked for (2026-10-01) a Khmer Pchum Ben theme, reviewed as a design first
(https://claude.ai/artifact/74hcgTyyQcYRdZBZZfg5hz) and then asked to carry
"more items from the festival" than a recolour.

- **A fourth `AppThemeFlavor`, `pchumBen`**, with `AppColors.pchumBenLight` /
  `pchumBenDark`: rice-white and lacquer, saffron for the brand yellow. The
  palette alone is ADR-035's "two `const AppColors` and nothing else".
- **The decoration is a second `AppStyle` flag, `pchumBen`** — ADR-050's
  route. Widgets ask `AppStyle.of(context).pchumBen`; none switch on the
  flavor. (The Theme screen's own card is the exception: it names the flavor
  it *offers*, whatever the app is wearing.) A plain `bool`, not an ornament
  enum: there is one festival, and a second would be the moment to generalise.
- **All drawing lives in `shared/widgets/pchum_ben_ornaments.dart`.** The
  frieze and the lotus rosette are `CustomPainter`s, because they tile or
  scale to a box. The pictures are SVG strings through `flutter_svg` (already
  a dependency, until now unused), built per call so their colours are the
  active tokens. Static assets were the alternative; they would have needed a
  light and a dark copy of each picture and would not follow a palette retune.
- **Where it shows:** bottom nav (petal plinth, lotus under "+"), Feed
  (skyline by the date, eave and lotus bud on the tabs, greeting card), Chat
  inbox (skyline on the slab, lotus on the sheet lip), Profile (scene on an
  empty cover, mark by "Personal details"), Signals (closing skyline), the
  auth header (wat and palms on the wave). Every other screen is palette
  only.
- **Three places stop being theme-independent, under this flavor only.** The
  nav's "+" takes the flavor's `yel`/`onYel` instead of the fixed brand
  yellow, which clashed beside a saffron indicator. Chat's slab contents take
  `pchumBenDark` instead of the pinned classic dark set (ADR-009 still holds:
  a pinned *dark* set, just this flavor's). The wordmark is left alone.
- **No lotus under an avatar.** A person seated on a lotus reads as a
  religious image; the lotus is kept to buttons, markers and the table.
- **Listed first on the Theme screen**, as drawn. `fromName` still falls back
  to `classic`, so no install changes theme by upgrading.

**Cost:** the flag is checked in ten files; a new screen gets no ornament
until someone adds it. The Khmer name and greeting are hard-coded strings in
`GoogleFonts.moul`, fetched at runtime like every other face here, and were
not checked by a Khmer reader. The auth scene is stretched with the header's
width so the palms stay on the wave, which distorts the wat by up to a tenth.
The eave adds 9px to Feed's pinned tab header.

**Revisit if:** the festival is over — move `pchumBen` to the end of the enum
(order is free; the stored value is the name). Or a second seasonal theme
arrives — then turn the flag into an ornament set and this file into one of
several.
