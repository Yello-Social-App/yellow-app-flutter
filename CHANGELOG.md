# Changelog

All notable changes to Yello are recorded here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning: [Semantic Versioning](https://semver.org/spec/v2.0.0.html) —
the app version lives in `pubspec.yaml` as `version: <semver>+<build>`.

**Every user-visible change gets an entry under `[Unreleased]` in the same
commit that makes the change.** Categories, in this order: `Added`, `Changed`,
`Deprecated`, `Removed`, `Fixed`, `Security`. Omit empty ones. Write for
someone using the app, not for someone reading the diff — and reference the
file only when it genuinely helps.

---

## [Unreleased]

### Added

- **Hide a post, report it, or mute whoever wrote it.** The "···" menu on
  someone else's post now ends with three new choices. *Hide this post*
  takes it out of your feed for good, on every device you sign in on.
  *Report post* asks what is wrong with it — spam, harassment, hate speech,
  violence, nudity, false information, or something else — with room for a
  sentence of your own; the author is never told who reported them, and
  reporting the same post twice just tells you it is already reported.
  *Mute @someone* stops their posts appearing in your feed without blocking
  them: they can still message you and see your posts, and they are never
  told.
- **Settings → Privacy & safety**, reached from the Settings button on your
  profile. Two lists: every post you have reported, with what a moderator
  decided about it, and every account you have muted, with an Unmute button
  on each. Reports keep a copy of what the post said when you reported it,
  so the entry still makes sense after the post is gone.
- **Send feedback**, also under the Settings button. Pick the part of Yello
  you want to rate — Messages, Stories, Communities, Showcase or something
  else — give it one to five stars, and add a note if you want to say why.
  What you have already sent is listed underneath.
- **You now hear back about posts you report.** When a moderator decides,
  you get a notification saying whether the post was removed, and tapping it
  opens Privacy & safety with the outcome. The notification never says who
  posted it, what it said, or who decided.
- **Tap a post's photo to open it full screen.** Pinch or double-tap to zoom
  in, drag to move around, swipe to the post's other photos, and tap the
  photo or the ✕ to come back. It works everywhere a post photo shows — the
  feed, a post's own screen, and the preview inside a shared post.
- Chat messages can now be **replied to, edited, unsent and reacted to**.
  Long-press a bubble for the menu: a quick row of six emoji (tap the same
  one again to take yours back), Reply, Copy text, Edit (your own text
  messages) and Unsend (your own, removed for everyone — a "Message deleted"
  tombstone stays in place and any reply quoting it says so). Edited
  messages carry an "edited" label; reactions show as tally pills under the
  bubble. Tapping the quoted block on a reply jumps the transcript to the
  original message and flashes it, pulling older history in if it is not
  loaded yet.
- **Photos in chat.** The "+" button in the composer picks from the library
  or camera; pictures show inline, other files show as a chip that copies
  the download link. Up to 10 per message, 10 MB each.
- **Group management.** Tapping a group's header opens its screen: rename,
  set or remove the group photo, add friends, promote or demote admins,
  remove members, and leave. What you can do follows your role — owner,
  admin or member — and the group photo now shows in the Inbox and header.
- **Invite cards.** From a group's screen you can send a friend an invite,
  which lands as a card in your DM with them; the invitee sees Join /
  Decline on it and the group appears in their Inbox on Join.
- A "Reactions to your messages" toggle in notification settings, for the
  push sent when someone first reacts to one of your chat messages.
- **Live chat.** The app now keeps a WebSocket to the chat service while a
  conversation is open: new messages, edits, unsends and reactions from
  the other side appear as they happen instead of on the next 5-second
  poll, and a **typing bubble** — three pulsing dots with the typist's
  avatar, and their name in a group — shows while someone is writing.
  Your own typing is sent the same way (at most once every 3 s, "stopped"
  after 3 s idle or on send).

### Changed

- **Your profile's buttons wrap onto a second line** instead of being
  squeezed, now that there is a fourth one (Settings). On a narrow phone, or
  with a larger Display size set, they lay out over two rows rather than
  running off the edge.
- **Muted accounts disappear from your feed straight away** rather than on
  the next refresh — the posts already on screen go with them.
- **The app is lighter.** Borders are softer hairlines rather than drawn grey
  outlines, the page behind a card is a warm off-white so cards lift on their
  own, body text is a warm charcoal instead of near-black, and chips, tiles
  and image placeholders all sit a shade paler. Dark mode got the same
  treatment from the other side: surfaces come up off near-black to a
  charcoal and its hairlines are less bright.
- Tapping a photo on a feed card now opens that photo full screen instead of
  the post. The rest of the card — the author row, the text and the comment
  button — still opens the post.
- **Explore and Inbox now show today's date above their titles**, the same
  uppercase line the Feed has always carried, so every tab's landing screen
  opens the same way. On Inbox the unread count rides on the end of that
  line ("MONDAY · SEP 22 · 3 UNREAD") instead of sitting on a row of its own.
- A post's own screen now carries the **yello. brand wordmark** as its
  title — the same stroked-and-filled treatment as Circle, Inbox and
  Signals — in place of the plain "POST" label.
- Tapping a push now opens the right screen for every kind, not only a
  chat: a post (or a post's comment thread), or the sender's profile for a
  friend request.
- Unsending a chat message also takes down the phone notification shown
  for it on the recipients' devices (Android; best effort on iOS, which may
  delay or drop the silent push that carries the request).
- **The Signals button now has an animated icon**, which only plays while you
  have an unread notification (it rests on a static frame otherwise) and
  pauses for a beat on the resting frame between rings instead of looping
  back-to-back. The unread red dot moved to sit on the icon itself rather
  than on the edge of its circular button.
- Chat messages are now capped at 4 000 characters, the chat service's own
  limit, instead of the 20 000 the composer allowed before (the service
  would have rejected anything longer).
- The Inbox list is no longer re-fetched every 10 seconds while a
  conversation (or any other full-screen page) is open on top of it. The
  open chat re-fetches its own conversation at that cadence instead — which
  is what read receipts and group changes actually need — and refreshes
  the list once when you leave it.
- A group's photo no longer re-downloads on every refresh.
- **The chat screen shows who is talking.** Incoming messages carry the
  sender's avatar beside the bubble — in DMs and groups alike — and a burst
  of messages from one person groups into a run: the name (in groups) sits
  above the first, the avatar beside the last, with tighter spacing in
  between. The typing indicator sits in the same column, with the peer's
  avatar in a DM.
- **Photos in chat no longer sit in a bordered bubble.** A picture stands on
  its own with rounded corners; with a caption or a reply, the text bubble
  sits above it.
- **Reply quotes now say who they quote.** The quoted block leads with the
  author's name ("You" for your own), shows a small icon when the original
  was an attachment or has since been deleted, and spans the bubble's width
  behind a yellow accent bar — the same shape as the composer's reply
  banner, which now reads "Replying to <name>" instead of just "Replying".

- Project documentation set under `docs/` — `ARCHITECTURE.md`, `CODEMAP.md`,
  `BACKEND.md`, `GOTCHAS.md`, `DECISIONS.md` — plus `AGENTS.md` so every AI
  assistant starts from the same facts and the same read order.
- `tool/codemap.sh`, which regenerates `docs/CODEMAP.md` from the source tree
  (`--check` fails when the committed map is stale).

### Changed

- Loading placeholders now match the screen they're on. Explore (both the
  Communities lists and the Showcase grid), people search and the Profile
  screens each show a shimmer laid out like their own cards — vote column,
  cover band, project tile, result row, or the full profile header with its
  stats and tabs — instead of the same generic avatar-and-block card
  everywhere. Profile, which used to show only a spinner on an empty
  background, now shows the whole page's outline while it loads, so the real
  page appears in place rather than jumping in.
- Explore is now a proper tab. Tapping it in the bottom nav lights it up and
  opens Communities with the bar still on screen, the same way Feed, Inbox
  and Profile do, instead of first asking whether you want Communities or
  Showcase. The title on both screens is a dropdown — tap "Communities" or
  "Showcase" at the top to switch to the other one, and the tab stays lit
  for either. Tapping Explore again returns you to Communities. The back
  arrow those two screens used to carry is gone: Back on them goes to Feed,
  like on every other tab.
- The small uppercase labels — section eyebrows, post meta and timestamps,
  tag pills, counters and the bottom nav labels — are now set in Geist, the
  same face as headings and buttons. They used to be Geist Mono, so the
  whole app is down to two families (Geist and Nunito).
- The Showcase screen has been redesigned. The title now carries its
  "Projects people have shipped" line; sort is a segmented switch (Trending /
  New / Stars) taking the whole row; and the tech filter is a row of chips
  beneath it — All plus the most-used tags — with a button at its end that
  opens the full list as a sheet, project counts included, along with the
  Featured toggle. (The filter used to be a single "Language" dropdown, which
  hid every tag behind a tap and was mislabelled: the tags are frameworks and
  tools as often as languages.) A featured project is now a hero card — a
  yellow-tinted band with the FEATURED mark, the name on its own line and a
  larger tile — instead of a yellow border and a small label squeezed beside
  the name. Every card shows at most three tech tags plus a "+N" count rather
  than wrapping all six; the like button moved down into the footer next to
  the view count, and a project's upstream star count now shows there too, so
  the Stars sort has something visible to sort by. When the list is short
  (one or two projects, no filter), a "Shipped something?" card with a Publish
  button closes it instead of empty page.
- The sort control on the Communities Discover and Joined tabs is now a
  segmented switch — the same control the Latest tab already uses — instead
  of a scrolling row of filter chips, so Popular / New / A-Z all sit on
  screen at once and read as one exclusive choice.
- The Inbox tab has been redesigned. The title, unread count, compose button
  and search now sit on a dark brand slab at the top of the screen, with a
  row of recent people underneath it for jumping straight into a chat, and
  the conversation list laid over the slab's bottom edge as a rounded sheet.
- Inbox rows show a real profile photo when the person has one, instead of
  always falling back to initials.
- The people row at the top of the Inbox lists your most recent chats. It
  previously listed only people shown as online — which is nobody, until
  live presence ships — so it never appeared at all.
- Typing in the Inbox search no longer rebuilds the header and its avatars
  on every keystroke.
- The app no longer checks for new messages and notifications every five
  seconds from whichever tab you happen to be on. It now checks every ten
  seconds while the Inbox is open and every thirty seconds elsewhere, and
  only looks for new Signals on the screens that actually show the Signals
  dot. A push notification still updates both straight away, so nothing
  waits on the timer — this is battery and data the app was spending on
  screens that had nothing to show for it.
- Cards now float. Feed posts, the Stories rail and the "What did you notice
  today?" prompt, community rows and posts, project cards, the profile
  header and stats, connection groups, search results, notification
  settings groups and every post opened on its own screen all sit on a
  deeper two-layer drop shadow instead of the faint smudge they had (or, for
  most of them, none at all), so they read as raised off the page rather
  than drawn onto it. One shared token (`AppShadows.card`) drives all of
  them, so they match — and it stays a proper shadow in dark mode instead of
  turning into a pale glow.

### Fixed

- An Inbox unread badge of 10 or more no longer stretches into an ellipse,
  and counts past 999 read as "1.2K" rather than overflowing.
- A featured Showcase card's yellow band no longer hides the card's outline
  along its top and sides — the hairline now runs all the way round, like on
  every other card.
- `README.md` no longer contains unresolved merge-conflict markers.

---

## [0.2.0] — 2026-09-20

First tagged APK build.

### Added

- Push notifications: Firebase Core + Messaging and local notifications,
  Android/iOS manifest wiring, `core/notifications/push_notification_service.dart`.
- `lib/bootstrap.dart` as the single startup path — config, DI, session
  restore — called from `main.dart`.
- Communities: browse, join/leave, community feed, post composer with tag
  picker, threads and votes.
- Showcase: project list, detail, publishing, likes, view counts, tech filter.
- User search (`/users/search`).
- Reactor list on a post's reaction breakdown.

### Changed

- Consolidated three competing DI files (`injection1`, `injection_1`,
  `injection_2`) into a single `lib/core/di/injection.dart`.
- Expanded `VersionedEndpoints` to cover the v0.2.0 spec (40 paths /
  53 operations).

### Fixed

- Reaction and post field mapping realigned with the updated API contract.
- Error handling widened to the server's full error-code vocabulary in
  `core/error/error_handler.dart`.

---

## [0.1.1] — 2026-09-16

### Changed

- API base URL moved to the live host, passed once from `main.dart` through
  `bootstrap(baseUrl:)`.

### Fixed

- Assorted bug fixes carried by PR #2.

---

## [0.1.0] — 2026-09-10

### Added

- Initial app: auth (register, OTP verification, login, password reset),
  feed with cursor pagination, post detail and comments, reactions, stories
  rail, friends and requests, chat, notifications, profile, and the
  five-tab shell.
- Clean Architecture skeleton, `get_it` DI, `go_router` routing, `dio` client
  with auth/retry/error/logging interceptors, JWT + secure storage + biometric
  and root/jailbreak checks.

[Unreleased]: https://github.com/hushstack/yellow-app-flutter/compare/main...HEAD
