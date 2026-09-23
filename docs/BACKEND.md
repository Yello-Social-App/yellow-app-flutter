# Backend contract

What the app talks to, what it can't, and which gaps are permanent by design.
**Read this before proposing "let's wire X up to the API"** — three features
have no endpoint at all, and that is a backend fact, not an oversight in this
repo.

---

## Three services, one host

| Service | Base | Version segment | Declared in |
|---|---|---|---|
| **yello-api** (core) | `https://api.yello.cachewraith.com` | `/v1/<resource>` | `core/network/api_versioning/versioned_endpoints.dart` |
| **yello-chat** | same host | `/ws/...` (no `/vN`) | `ChatRoutes` in `features/chat/data/datasources/chat_remote_datasource.dart` |
| **yello-notify** | same host | `/notifications/v1/...` — version **after** the resource | `NotifyRoutes` in `features/notification/data/datasources/notification_remote_datasource.dart` |

The base URL is passed in exactly once, from `lib/main.dart` →
`bootstrap(baseUrl:)` → `AppConfig.init`. There is no flavor split.

Chat and notify keep their own route holders precisely because
`EndpointResolver` would prepend `/v1` and produce the wrong path for them.
Don't "unify" them into `VersionedEndpoints`.

- Swagger UI: `/docs` · raw OpenAPI 3.0: `/docs/json?api-docs.json`
- Last verified against the served spec: **v0.2.0, 40 paths / 53 operations,
  2026-09-20** (see the doc comment on `VersionedEndpoints`).
- `yello-chat` spec: `/ws/docs` (Swagger UI), `/ws/docs-json` — last
  verified **v0.1.0, 22 `/ws` paths, 2026-09-22**. `yello-notify` spec:
  `/notifications/docs`.

---

## Response envelope

Success:

```json
{ "success": true, "data": <payload>, "timestamp": "..." }
```

Error:

```json
{ "success": false, "code": "VALIDATION_FAILED", "message": "...",
  "fieldErrors": { "email": "..." }, "path": "...", "timestamp": "..." }
```

Unwrap with `ApiEnvelope` (`core/network/api_envelope.dart`) — never by hand:

| Helper | Payload shape | Used by |
|---|---|---|
| `ApiEnvelope.data` | `{ data: {…} }` | single object |
| `ApiEnvelope.list` | `{ data: […] }` | plain arrays |
| `ApiEnvelope.page` | `{ content, page, size, totalElements, totalPages, last }` | friends, notifications, comments, a user's posts |
| `ApiEnvelope.cursorPage` | `{ content, hasMore, nextCursor }` | `/feed` |

Error codes are mapped to `Failure` types in `core/error/error_handler.dart`.
The server-side vocabulary currently includes:

`ACCESS_DENIED` · `ACCOUNT_NOT_VERIFIED` · `ACCOUNT_SUSPENDED` ·
`ALREADY_REPOSTED` · `COMMUNITY_MEMBERSHIP_REQUIRED` · `EMAIL_ALREADY_USED` ·
`FRIEND_REQUEST_CONFLICT` · `INTERNAL_ERROR` · `INVALID_CREDENTIALS` ·
`INVALID_IMAGE` · `OTP_INVALID` · `OTP_TOO_MANY_ATTEMPTS` ·
`PAYLOAD_TOO_LARGE` · `POST_NOT_VISIBLE` · `RATE_LIMIT_EXCEEDED` ·
`RESET_TOKEN_INVALID` · `RESOURCE_NOT_FOUND` · `TOKEN_EXPIRED` ·
`TOKEN_INVALID` · `TOKEN_REVOKED` · `USERNAME_ALREADY_USED` ·
`USERNAME_CHANGE_COOLDOWN` · `VALIDATION_FAILED` ·
`CANNOT_REPORT_OWN_POST` · `CANNOT_MUTE_SELF` · `REPORT_ALREADY_EXISTS` ·
`REPORT_ALREADY_RESOLVED`

Adding a new code means adding a branch in `ErrorHandler`, not a string
comparison at a call site.

---

## Endpoint catalogue (yello-api v1)

Grouped as declared in `VersionedEndpoints`:

- **Auth** — `/auth/register`, `/auth/verify-otp`, `/auth/resend-otp`,
  `/auth/login`, `/auth/refresh`, `/auth/logout`, `/auth/forgot-password`,
  `/auth/reset-password`
- **Users** — `/users/me`, `/users/{id}`, `/users/{id}/posts`, `/users/search`
- **Posts** — `/posts`, `/posts/{id}`, `/posts/{id}/repost`
- **Comments** — `/posts/{postId}/comments`, `/comments/{id}`
- **Feed** — `/feed` (cursor-paginated)
- **Reactions** — `/reactions/{targetType}/{targetId}`,
  `/reactions/{targetType}/{targetId}/summary`
- **Friends** — `/friends`, `/friends/{userId}`, `/friends/blocked`,
  `/friends/requests`, `/friends/requests/{userId}`(`/accept`,`/decline`),
  `/users/{userId}/block`
- **Communities** — `/communities`, `/communities/{slug}`,
  `/communities/{slug}/membership`, `/communities/{slug}/posts`,
  `/community-posts`, `/community-posts/{postId}/comments`,
  `/community-posts/{postId}/vote`
- **Showcase** — `/projects`, `/projects/{id}`, `/projects/{id}/like`,
  `/projects/{id}/views`, `/projects/tech`
- **Feedback** — `/feedback`, `/feedback/me`
- **Reports** — `/posts/{postId}/reports`, `/reports/me`
  (+ `/admin/reports`, `/admin/reports/{id}` — moderators only, never
  called by this app)
- **Mute** — `/users/{userId}/mute`, `/users/me/muted`
- **Hide** — `/posts/{postId}/hide`

`/users/search` requires `q` of **at least 2 characters** — the server answers
`400 VALIDATION_FAILED` below that, so callers gate on length rather than
firing per keystroke.

### Feedback, reports, mute and hide

Added from the backend's own reference for these features (2026-09-22). Not
yet re-checked against the served OpenAPI document — do that on the next
`/docs` sweep.

| Method | Path | Success | Notes |
|---|---|---|---|
| POST | `/v1/feedback` | `201` `Feedback` | 10/h per user |
| GET | `/v1/feedback/me` | `200` page | newest first |
| POST | `/v1/posts/{postId}/reports` | `201` `PostReport` | 20/h per user |
| GET | `/v1/reports/me` | `200` page | newest first |
| POST/DELETE | `/v1/users/{userId}/mute` | `204` | idempotent, no body |
| GET | `/v1/users/me/muted` | `200` page | most recent first |
| POST/DELETE | `/v1/posts/{postId}/hide` | `204` | idempotent, no body |

- **`204` means there is no body to unwrap.** Mute, unmute, hide, unhide —
  and, since this revision, unfriend — answer `204 No Content`. Reaching for
  `ApiEnvelope.data` on one of those throws *on success*. Every other
  effect-only friendship call (`…/decline`, cancel, block, unblock) still
  answers `200 { user, friendStatus }`, so they are not interchangeable.
- **`DELETE /v1/friends/{userId}` changed** from `200 { user, friendStatus }`
  to `204`. The client already typed it `Future<void>` and never read the
  body, so nothing had to change — treat `204` as `friendStatus: "NONE"`.
- **Feedback `featureId`** is one of `messages`, `stories`, `communities`,
  `showcase`, `compact-mode`, `in-app-updates`, `other`. The last two name
  features Yello does not have; `FeedbackFeature.pickable` is the subset the
  app's own picker offers, while all seven still parse on the way back in.
- **`diagnostics`** (`{appVersion, platform}`, each ≤ 32 chars) is accepted
  and stored but never returned. `SafetyRemoteDataSourceImpl` fills it from
  `package_info_plus` + `dart:io`; anything else in that object is dropped
  server-side.
- **`REPORT_ALREADY_EXISTS` (409) is not a failure.** It means the viewer
  already has an `UNDER_REVIEW` report on that post — which is what they
  asked for. `ReportPostCubit` reads it off `ValidationFailure.code` and
  confirms rather than showing an error. Once a report resolves, the same
  post can be reported again.
- **Reports carry a frozen snapshot** of the post (`authorName`, `excerpt`)
  taken when the report was filed, so the row stays readable after the post
  is hidden or deleted. `postId` goes null once the post is deleted, which
  is why the row is only tappable while it is set.
- **`/v1/admin/reports`** (the moderation queue and its `PATCH`) has no
  client here: it answers `403 ACCESS_DENIED` for every account this app
  signs in. Deliberately absent from `VersionedEndpoints` and
  `SafetyRepository`.

New error codes, all mapped in `ErrorHandler`: `CANNOT_REPORT_OWN_POST`,
`CANNOT_MUTE_SELF`, `REPORT_ALREADY_EXISTS`, `REPORT_ALREADY_RESOLVED`.

---

## yello-chat (`/ws`) — bare JSON, own error body

Responses are the object itself, **no** `{success, data}` envelope; errors
are `{ code, message, details? }` with codes `VALIDATION_ERROR` (400, or
413 for an oversized upload) · `UNAUTHORIZED` · `FORBIDDEN` · `NOT_FOUND` ·
`CONFLICT` · `RATE_LIMITED` · `UNAVAILABLE` · `INTERNAL_ERROR`. `ErrorHandler`
reads `code`/`message` off that body as-is and maps the 4xx family to
`ValidationFailure` so the server's wording reaches the user
(`ChatErrorCodes`). Ids are UUIDs, times ISO 8601. The acting user is always
the token's `sub` — never a body field.

Routes, as declared in `ChatRoutes`:

- **Conversations** — `GET/POST /ws/conversations`, `GET /ws/conversations/{id}`,
  `POST /ws/conversations/{id}/read`
- **Messages** — `GET/POST /ws/conversations/{id}/messages`;
  `PATCH/DELETE …/messages/{messageId}` (sender only — edit is text only,
  delete leaves a tombstone: `deletedAt` set, `body: ""`, files and
  reactions gone); `PUT/DELETE …/messages/{messageId}/reaction` (one
  reaction per user per message; both answer `{ messageId, reactions[] }` —
  replace, don't merge)
- **Attachments** — `POST /ws/conversations/{id}/attachments` (multipart,
  one `file`, ≤ 10 MiB, typed from its bytes: JPEG/PNG/GIF/WebP → `IMAGE`,
  anything else → `FILE`) then send the id in `attachmentIds`;
  `GET /ws/attachments/{id}` for a fresh presigned URL. URLs live an hour
  and are **re-signed on every read** — cache images by attachment id, not
  URL (`_AttachmentThumb` does).
- **Groups** (400 on a DM) — `PATCH /ws/conversations/{id}` (`title`),
  `PUT/DELETE …/photo`, `POST …/members`, `DELETE/PATCH …/members/{userId}`
  (`role: ADMIN | MEMBER`), `POST …/leave`. Roles: any member adds people,
  sends invites and leaves; OWNER or ADMIN renames, changes the photo and
  removes a member; only the OWNER removes an admin or changes roles; the
  owner cannot be removed — on leaving, the longest-standing admin (else
  member) takes over. ≤ 50 people.
- **Invite cards** — `POST /ws/conversations/{id}/invites` (`{ userId }`)
  answers `{ invite, message }`, the card being a normal message in the
  inviter's DM with the invitee (`groupInvite` set, `body: ""`);
  `POST /ws/invites/{id}/accept` (answers the joined conversation) /
  `…/decline`. Only the invitee answers; a second answer is 409.

Limits: message text ≤ 4 000 chars (`CHAT_MESSAGE_MAX_LENGTH`), ≤ 10
attachments per message, ≤ 64-char `clientId` (the idempotency key).

**WebSocket** — `wss://…/ws`, frames `{ event, data }` ≤ 64 KiB, wired
by `ChatSocket` (`chat/data/datasources/chat_socket.dart`). Handshake,
established against the live service with `tool/ws_probe.dart` on
2026-09-22 (the README that documents it is not in this repo):

- the upgrade takes no header; the client sends
  `{ "event": "auth", "data": { "token": "<yello-api access token>" } }`
  **within a few seconds** or the server closes with code 4401
  "authentication timeout";
- success is `auth.ok`; a bad token is `error { code: UNAUTHORIZED,
  message: "Invalid token" }` (`ChatSocket` refreshes once and retries);
- any other frame before auth is `error UNAUTHORIZED "Authenticate first"`;
- `ping` → `pong { ref, serverTime }` works before auth;
- validation failures name the field: `error { code: VALIDATION_ERROR,
  details: { issues: [{ path, message }] } }`.

Server → client: `message.new/sent/updated/deleted/reactions`,
`message.read`, `typing`, `presence`, `conversation.new/updated/removed`,
`group.invite.updated`, `error`, `pong` — `ChatFrameDecoder` maps each to a
`ChatEvent`. Client → server used by this app: `auth`, `typing`
(`{ conversationId, isTyping }` — **the relayed frame's field names are the
one thing the probe could not confirm without a real token**; run
`dart run tool/ws_probe.dart <token>` and the server's validation error
names them). Everything else still goes over HTTP; the socket is delivery,
not a second request path. The chat screen keeps a 30 s history poll as a
safety net while the socket is up and drops to 5 s when it is not.

## yello-notify — what changed with the chat features

- **Chat pushes are push-only.** `CHAT_MESSAGE`, `CHAT_REACTION` and
  `CHAT_MESSAGE_DELETED` are never stored as inbox rows — `GET
  /notifications/v1` does not return them. The `isSignal` filter in
  `NotificationRepositoryImpl` is therefore belt-and-braces, not load-bearing.
- **`CHAT_MESSAGE_DELETED` is data-only** (no notification block). The app
  must find the alert shown under tag `chat:<conversationId>` and cancel it
  when it is for that `messageId` — `PushNotificationService` does, in the
  foreground and in the background isolate. iOS may delay or drop it.
- **Grouping keys** — Android `tag` / iOS `thread-id`: `chat:<conversationId>`
  for messages, `chat.reaction:<messageId>` for reactions, per post / per
  comment / per sender for social types, none for `POST_CREATED`.
- **Android channel** is `yello_default` (manifest meta-data and
  `_androidChannel` agree).
- **Deep links from `data`**, checked in this order: `conversationId` → the
  chat; `postId` (+ `commentId`) → the post; `actorId` alone → that profile.
  `PushDestination.fromData` is that rule; `MainShellPage` follows it. The
  post screen has no scroll-to-comment yet, so `commentId` is carried but
  unused.
- Preferences: `CHAT_MESSAGE` and `CHAT_REACTION` are both mutable types;
  `CHAT_MESSAGE_DELETED` is silent and has no toggle.

### Two more push types (2026-09-22)

- **`REPORT_RESOLVED`** — to the *reporter*, when a moderator decides their
  report. Inbox row **and** visible push. `data` is
  `{type, reportId, status}` and names neither the post, its author, nor who
  decided. Copy is fixed server-side: "We removed a post you reported" /
  "We reviewed a post you reported". The app's whole job on receipt is to
  re-read `GET /v1/reports/me` — which is what `ReportsDestination` opens
  Privacy & safety for. It is in `NotificationTypes.signalTypes` (so it
  shows in Signals and counts toward the badge) but **not** in
  `NotificationTypes.all`: the notify service has not been seen returning it
  from `GET /notifications/v1/preferences`, and a toggle the server drops
  reads as a broken switch. Add it once it appears there.
- **`FRIENDSHIP_CHANGED`** — silent, data-only, never an inbox row. Sent to
  the *other* party when someone unfriends them, declines their request, or
  cancels a request they had sent. `data` is `{type, userId}`. A **block**
  sends nothing, so blocking is never revealed this way.
  `PushNotificationService.friendshipChanges` republishes the `userId`;
  `FriendsPage` refreshes on any of them and `PublicProfilePage` reloads
  only when the id is the profile on screen. Foreground only — a background
  push runs no Dart for it, so the affected screen catches up on its next
  load.

### Direct reply needs two payload changes (2026-09-23)

The app can now send a reply typed straight into the notification — the
Reply action, `chat_reply_action.dart` + `PushNotificationService`, ADR-025.
An action button only exists on an alert *Dart* drew, though, and Android
runs no Dart for a push carrying its own `notification` block (see
`docs/GOTCHAS.md`). So today the Reply button appears only while the app is
foregrounded, and closing that gap is entirely on `yello-notify`:

| Platform | What the service must send | Why |
|---|---|---|
| Android | `CHAT_MESSAGE` **data-only** — no `notification` block, `title` and `body` repeated as `data` keys, `android.priority: "high"` | the only state in which the app is woken to draw the alert itself |
| iOS | keep the notification block, and set `apns.payload.aps.category` to `yello_chat_reply` | iOS won't show a data-only push at all; the category is what grows the reply field |

Nothing else changes: the deep-link keys, the `chat:<conversationId>` tag and
`CHAT_MESSAGE_DELETED` stay exactly as they are, and the app already reads
its copy from `data` when the notification block is absent, so both payload
shapes work today. Verified on-device: **not yet** — no emulator in this
sandbox.

An iOS reply to an alert *the system* drew may additionally need a
Notification Service Extension; unverified, and irrelevant until the
category is being sent.

## Deliberate gaps — do not "fix" these client-side

| Feature | Status | Where |
|---|---|---|
| **Stories** | No `/stories` resource exists. Permanent client-side seed, in-memory only; "seen" resets each app session. | `feed/data/datasources/story_local_datasource.dart` |
| **Saved posts / bookmarks** | No endpoint. Persisted on-device via `shared_preferences`; not synced across devices. | `feed/data/datasources/bookmarks_local_datasource.dart` |
| **Chat** | *Does* have a backend (`yello-chat`, `/ws`, with a socket upgrade on the same path for live delivery). | `chat/data/datasources/chat_remote_datasource.dart` |
| **App updates / version check** | Still no version resource on any of the three services. The app does not ask one: since it is sideloaded rather than installed from a store, the Updates group reads a `latest.json` published beside each release's APK (`AppConfig.updateManifestUrl`, ADR-029). Don't route that through `ApiClient` — it is off-host, and `AuthInterceptor` would attach the session token to it. | `settings/data/datasources/app_update_remote_datasource.dart` |

## Known backend limitations (not solvable in this repo)

- **Comment replies** can be created but no endpoint ever lists them back.
- **Notifications** carry no per-item "already responded" field.
- **Community post threads** cannot be rebuilt from a URL — there is no
  `GET /community-posts/{id}`, which is why `/community-post/:postId` needs
  the post passed via `state.extra` and falls back to
  `CommunityPostRouteFallback` on a cold deep link.
- **Community composer** needs the community object for its tag picker
  (`POST /communities/{slug}/posts` requires a `tag` from that community's own
  `tags`), so `/communities/:slug/new` falls back to the community screen when
  reached without `extra`.
- **Feed-list vs. single-post** endpoints can briefly disagree on reaction
  counts before self-correcting.
- **`yello-chat` `typing` / `presence` payloads** — the frame reference in
  the service README is not in this repo. The `auth` handshake was
  recovered from the server's own validation errors (see above); `typing`
  is sent as `{ conversationId, isTyping }` and read tolerantly
  (`userId` + `isTyping`/`typing`), and `presence` is not decoded at all.
  A wrong guess shows up as an `error` frame in the device log
  (`ChatRepositoryImpl.watchEvents` logs them) and is a one-line fix in
  `ChatFrameDecoder` / `sendTyping`.
- **Group changes are live only** — `conversation.updated` frames are not
  stored as lines in message history, so a rename or member change made
  while the viewer was away leaves no trace in the transcript.
- **Inbox `lastMessage`** carries only `{id, senderId, body, createdAt}`:
  an empty body cannot be told apart as "photo", "invite card" or "deleted"
  from the summary alone (`LastMessageKind` — the client says more only for
  messages it applied itself).
- **Android app badge** — the notify guide asks the app to set the launcher
  badge from `unread-count` itself on Android; nothing in this repo does
  (no badge plugin), so only iOS shows a count.
- **No `isMuted` on a user.** `GET /v1/users/{id}` says nothing about
  whether the viewer has muted them, and the only way to find out is to page
  `/v1/users/me/muted` until the id turns up. That is why
  `PublicProfilePage` has **no** mute toggle: muting is offered from the
  post "···" menu (where the author is the post's author) and undone from
  Settings → Privacy & safety. Add the toggle if an `isMuted` field lands.
- **No "hidden posts" endpoint.** `GET /v1/feed` leaves hidden posts out and
  nothing lists them back, so `DELETE /v1/posts/{id}/hide` has no screen to
  be called from. `UnhidePostUseCase` exists and is registered; it has no
  caller until such an endpoint does.
- **A moderator hiding a post is invisible to its author.** The only signal
  is the reporter's own `REPORT_RESOLVED` push; nothing tells the person who
  wrote it, and no endpoint exposes "this post of yours was hidden".

If a proposed change needs a contract that doesn't exist, **say so** instead
of shipping a client-side workaround that can't actually close the gap.
