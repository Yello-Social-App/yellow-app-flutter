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
  `/reactions/{targetType}/{targetId}/summary`. The `POST` is a **toggle keyed
  on the type you send**, and there is no `DELETE`: a type the viewer does not
  currently have is a *switch*, the type they do have is a *removal*. So an
  un-react has to echo `viewerReaction` — see ADR-031. `ReactionType` is a
  closed enum: `LIKE|LOVE|HAHA|WOW|SAD|ANGRY` (re-verified 2026-09-25). Note
  the client draws `LOVE` as 🖕, not ❤️ — a display swap only (ADR-031); on
  the wire and in every count it is still `LOVE`.
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
- **Voice notes** — `POST /ws/conversations/{id}/attachments/voice`
  (multipart, one `file`; M4A/MP4, WebM or Ogg, ≤ 5 minutes and ≤ 10 MiB),
  then the same `attachmentIds` send as any attachment. Its own route, not
  the general one: the server transcodes the upload to **mono AAC ~48 kbps
  in M4A** (`audio/mp4`), throws the original away, and measures
  `voice.durationMs` and `voice.waveform` (≤ 64 integers, 0–100) **from the
  audio itself** — a recording posted to `…/attachments` comes back as a
  plain `FILE` with no `voice` block and nothing to draw. `503 UNAVAILABLE`
  means the deployment has no bucket or no ffmpeg: hide the mic. Playback is
  the presigned `url` given straight to the player, no auth header, Range
  supported. Verified against the live service's reference on 2026-09-25.
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
- **Stickers** — a resource of their own, not attachments. Make one with
  `POST /ws/stickers/drafts` (multipart, field **`image`** — *not* `file`;
  PNG/JPEG/WebP by content, ≤ 5 MB, ≤ 4096 px a side and ≤ 16 MP), then
  `POST /ws/stickers` (`{ draftId, background, name }`). The server crops a
  centred square, applies the EXIF orientation, scales to **512 × 512 WebP**,
  drops EXIF/GPS/XMP, keeps only the first frame of an animation, and never
  stores the uploaded bytes. A draft lives an hour, saves **once** (a second
  save is `404` / `DRAFT_NOT_FOUND`), and there are 30 per user per hour
  (`429 RATE_LIMITED`, `Retry-After` plus `details.retryAfterSeconds`).
  Read them with `GET /ws/stickers/mine?limit=&cursor=` (keyset, `limit`
  clamped to 100 — a full library is two pages), `GET /ws/stickers/recent?size=`
  (1–50, default 24; **server-side**, so the app keeps no local Recent, and
  deleted stickers and withdrawn packs drop out on their own) and
  `GET /ws/sticker-packs` (a bare array, no paging, packs in display order).
  Manage them with `PATCH /ws/stickers/{id}` (`{ name }`, ≤ 40 chars, may be
  empty) and `DELETE /ws/stickers/{id}` (204). `POST
  /ws/conversations/{cid}/messages/{mid}/sticker/save` adds someone else's to
  your library — the *same* image, not a copy — answering **201** for a new
  entry and **200** for one already there, which is the only reason the status
  code reaches the UI (`SavedSticker`). Library ceiling 200 (saved-from-message
  ones included); the 201st is `409` / `STICKER_LIMIT_REACHED`.
  `/ws/sticker-packs` is the one conditional route on the service: it sends an
  `ETag` with `Cache-Control: private, no-cache`, and a `304` to a matching
  `If-None-Match` means the cached packs **including their URLs** are still
  good — the same URL is handed out for a whole hour-long window and stays
  valid for at least an hour after you get it. Every other sticker URL is
  re-signed on each read. `StickerRemoteDataSourceImpl` holds that ETag for the
  process, which is why it is a singleton.
- **Sending a sticker** — `stickerId` on the ordinary send (socket or HTTP).
  It goes **alone**: `body` must be empty or absent and `attachmentIds` must be
  absent, and the sticker must be in the caller's library or in a published
  pack (else `404 STICKER_NOT_FOUND`). `clientId` is still the idempotency key.
  Every `Message` gains `sticker` (null unless it is a sticker message, and on
  tombstones — the server drops it with the text); replies gain
  `replyTo.hasSticker` and the conversation list `lastMessage.hasSticker`, so a
  quote can say "Sticker" and a row "Sent a sticker" without fetching anything.
  Editing one is refused (`400 STICKER_NOT_EDITABLE`); reactions, replies and
  unsend work as on any message. An expired sticker URL on a message is fixed
  by re-reading the page — **there is no `GET /ws/stickers/{id}`** to re-sign
  one on its own (`ChatCubit.refreshSticker`). Sticker events
  (`sticker.added` / `updated` / `removed`) reach **all** of the owner's
  sockets, the one that made the request included, so a listener de-duplicates
  on `sticker.id`.

Limits: message text ≤ 4 000 chars (`CHAT_MESSAGE_MAX_LENGTH`), ≤ 10
attachments per message, ≤ 64-char `clientId` (the idempotency key). A voice
note is ≤ 5 minutes (`VOICE_MAX_DURATION_MS`, fixed) and goes **alone** in
its message, as does a sticker. A sticker library holds 200; a sticker name is
≤ 40 characters and may be empty. Deleting the message deletes the audio from storage with it, so
a note still playing out of a bubble that becomes a tombstone is playing a
link that has gone (`ChatCubit._applyDeleted` stops it).

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
`group.invite.updated`, `sticker.added/updated/removed`,
`call.ringing/accepted/ended` (and `call.started`, a reply), `error`, `pong` —
`ChatFrameDecoder` maps each to a `ChatEvent`, except `presence`, which names
people rather than a conversation and so goes to `PresenceTracker` instead of
to any one screen (ADR-038), and the `sticker.*` family, which names the
owner's library rather than a conversation and is read by
`ChatFrameDecoder.stickerEvent` into a `StickerLibraryEvent` for
`StickersCubit` (ADR-040), and the `call.*` family, which `CallFrameDecoder`
reads for `CallCubit` (ADR-042). Client → server used by this app: `auth`,
`call.start/accept/decline/end` (see the calls section below), `typing`
(`{ conversationId, isTyping }` — **the relayed frame's field names are the
one thing the probe could not confirm without a real token**; run
`dart run tool/ws_probe.dart <token>` and the server's validation error
names them). Everything else still goes over HTTP; the socket is delivery,
not a second request path — the call frames excepted, because calls have no
HTTP route to take instead. The chat screen keeps a 30 s history poll as a
safety net while the socket is up and drops to 5 s when it is not.

## yello-chat — calls (added 2026-09-29; groups and screen share 2026-09-30)

Audio and video calls — 1:1, and (since the 2026-09-30 "Group Calls &
Screen Sharing" note) group calls of up to 16. From the service's Calls API reference (an
inkdrop note shared 2026-09-29, written for the Electron client; frame
source of truth server-side is `src/modules/realtime/protocol/protocol.ts`).
**Not yet checked against a live call** — the socket frames are not in the
OpenAPI document, so the first on-device call is the verification.

`yello-chat` decides who may call whom, rings over the chat socket, hands
out LiveKit join tokens and records every call. **Audio and video never go
through it**: they go to LiveKit Cloud, room `call_<callId>` (two people for a
DM, up to 16 for a group). The client is `features/call`; the SDK is `livekit_client`, touched
only in `core/call/call_room.dart` (and the video renderer widget).

| Path | Kind | Notes |
|---|---|---|
| `call.start` `{ref, conversationId, media}` | socket | DM or group. Reply `call.started {ref, call}` to the sending socket only: `RINGING`, or already `ENDED`/`BUSY` (nobody could be rung). A group with a live call answers `CONFLICT` / `CALL_IN_PROGRESS` + `details.callId` — join that one instead |
| `call.accept` `{ref, callId}` | socket | answers a ring **or joins a group call under way** (after declining, missing, leaving, or being added later). First answer → everyone gets `call.accepted`; later joins → `call.updated`. Already JOINED → nothing at all. `CONFLICT` reasons `CALL_FULL` (+`maxParticipants`), `ALREADY_IN_CALL`, none (ended) |
| `call.decline` `{ref, callId}` | socket | only while INVITED. Group: others keep ringing (`call.updated`); `call.ended DECLINED` once nobody is left ringing and nobody answered |
| `call.end` `{ref, callId}` | socket | **leave**. Two or more still in → `call.updated` (you are LEFT), call goes on; fewer → `call.ended`. Not in it / already ended → **silent no-op** |
| `POST /ws/calls/{callId}/decline` | HTTP | decline **with no socket** — the ring notification's Decline button (added 2026-09-30). `204` declined · `409` no longer ringing you · `404` unknown · `403` you are the caller (hang up with `call.end`) · `401` refresh once and retry. Same effect as the `call.decline` frame |
| `POST /ws/calls/{callId}/token` | HTTP | `{serverUrl, roomName, token, expiresAt}` — only for someone **JOINED** (the caller from the start, others after `call.accept`; `409` otherwise). Grants camera, mic, screen share and screen-share audio |
| `GET /ws/calls/active` | HTTP | the call you are JOINED in, else one ringing you, else `{call: null}` — re-read after every socket `auth.ok` |
| `GET /ws/conversations/{id}/call` | HTTP | the conversation's live call or `{call: null}` — the chat's "Join call" bar. `404` for a non-member |

`Call` gained `kind` (`DIRECT`/`GROUP`) and `participants`
(`[{userId, state, joinedAt}]`, initiator first). `state`: `INVITED · JOINED
· DECLINED · MISSED · LEFT · BUSY`; all but JOINED can (re)join a group call.
A member added after the call started is not listed until they join.

Server → client: `call.ringing` (only people being rung), `call.accepted`
(every member — in a group, keep ringing while your own state is INVITED),
**`call.updated`** (roster changed, status did not — every member, and anyone
just removed from the group; read your own entry: INVITED keep ringing,
JOINED stay, anything else close), `call.ended` (every member; `BUSY` to the
caller only). `endReason`: `HANGUP · DECLINED · CANCELLED · MISSED · BUSY ·
FAILED`. `GROUP_CALL_UNSUPPORTED` is never sent any more.
Errors are ordinary `error` frames **carrying the request's `ref`** — that is
the only way to tie one to the frame that caused it, so every call frame
sends a fresh one (`CallRemoteDataSourceImpl._request`). The guide says the
error "carries your ref" without placing it; the client reads it beside
`code` and falls back to `details.ref`. Switch on `code` then
`details.reason` (`CALL_IN_PROGRESS`, `CALL_FULL`, `ALREADY_IN_CALL`), never
on `message`.

Things that bite:

- **The socket is no longer delivery-only.** ADR-017's rule was "requests go
  over HTTP"; calls have no HTTP route for start/accept/decline/end, so those
  four are the first requests this app sends over the socket (ADR-042).
- **In the app, a ring comes over the socket; off screen, as a push.**
  The app holds the socket app-wide while it is on screen (`CallHost`), not
  just from the Inbox. Since 2026-09-30 `yello-notify` also pushes every
  ring (`CALL_INCOMING`, below) to every registered device of everyone
  being rung — online or not — so an open app gets both and ignores the
  push (`call_alert.dart`, `appOnScreen`).
- **One live call per user, across devices.** A second device of the same
  user joining the room puts the first one out (LiveKit `DUPLICATE_IDENTITY`),
  so an `ACTIVE` call found on reconnect is *offered* (Rejoin / End), never
  auto-joined.
- **Room lifetime:** 60 s with nobody in it after creation, 20 s grace after
  the last one leaves; LiveKit's webhook ends an `ACTIVE` call whose room
  emptied (both apps crashed) as `HANGUP`. Ring timeout 45 s → `MISSED`.
- **Rate limit:** 5 `call.start` at once, then 1 per 6 s per user.
- **Token grants:** camera, microphone, screen share and screen-share audio
  — no data channel, no metadata. Anything that is not media goes over the
  chat socket. The token is issued "as you", so a LiveKit participant's
  identity is read as the user id (the call screen's tiles rely on it —
  **unverified against a live group call**).
- **Removed from a group mid-call:** `call.updated` with your state LEFT
  (MISSED if you were being rung), LiveKit disconnects you with
  `PARTICIPANT_REMOVED`, and token requests answer `404`.
- **JOINED is the server's view; who is actually connected comes from the
  LiveKit room.** Tiles are drawn from the room.
- **Limits:** 16 per group call (`CALL_GROUP_MAX_PARTICIPANTS`), 2 per DM,
  one live call per conversation.
- **Screen share quality** is the client's business; the guide targets
  1080p60 VP9 `L3T3_KEY` with a VP8 backup, 5 Mbps, `maintain-framerate`,
  and 30 fps / 3 Mbps for slow machines. The phone uses the slow-machine
  numbers (`CallRoom._screenSharePublish`). Screen-share *audio* is
  browser/Electron-only in `livekit_client` — the app sends video only.

Not built server-side: a "missed call" line in the chat history, recording,
end-to-end encryption.

### Incoming-call pushes (2026-09-30)

From the "Incoming calls from outside the app" frontend guide. Three new
`yello-notify` types, all string-valued `data`, all keyed `call:<callId>`:

| Type | Android | iOS | `data` |
|---|---|---|---|
| `CALL_INCOMING` | **data-only**, HIGH, `ttl` = ring time left | alert, `interruption-level: time-sensitive`, category `YELLO_CALL`, sound `yello_ring.caf`, `apns-collapse-id` | `callId`, `conversationId`, `actorId`, `media`, `callKind`, `expiresAt` (start + 45 s), `title`, `body` |
| `CALL_MISSED` | data-only | alert, same collapse id (replaces the ring by itself) | as above minus `expiresAt` |
| `CALL_RING_STOPPED` | data-only, silent | background (`content-available`) | `callId`, `conversationId`, `reason` `ANSWERED`/`DECLINED` |

- Never sent to the caller. A push that can't arrive before `expiresAt` is
  dropped, so a device never rings for a call that is over — the app also
  checks `expiresAt` itself before drawing.
- Stop ringing on any of: `CALL_MISSED` / `CALL_RING_STOPPED` for the call,
  `expiresAt` passing, the socket showing the call, Accept / Decline.
- Device registration is unchanged; `mutedTypes` accepts the three types.
  The guide's optional "Calls" toggle (`CALL_INCOMING` + `CALL_MISSED`) is
  **not built** — the preferences screen toggles single types only.
- What the app does with each, per platform: `core/notifications/call_alert.dart`
  and ADR-051. iOS's Accept / Decline buttons are not wired, and
  `yello_ring.caf` is not bundled (iOS plays its default sound).

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
shapes work today.

**Confirmed still unsent, on-device 2026-09-26** (Galaxy S24, Yello 0.5.0).
Two live `CHAT_MESSAGE` pushes landed on the same phone minutes apart, and
`dumpsys notification` separates them exactly as this section predicts:

| Yello when it arrived | `id` | `template` | `actions` |
|---|---|---|---|
| in the foreground | `433677888` (`tag.hashCode`) | `MessagingStyle`, `category=msg` | **1** — the Reply action |
| on the home screen | `0` | `BigTextStyle` | **none**, no `RemoteInput` |

The backgrounded one also carried FCM's own launcher `contentIntent`
(`act=MAIN cat=LAUNCHER cmp=.MainActivity`), the signature of an alert the
**OS** drew from a `notification` block. So the client half works and
neither payload change above has landed: Reply exists only while the user is
already looking at the app, which is the one moment they do not need it.
`id` and `template` alone say who drew a given alert — re-check that way
rather than by eye, since a phone may collapse either one to a pill.

An iOS reply to an alert *the system* drew may additionally need a
Notification Service Extension; unverified, and irrelevant until the
category is being sent.

## Stories

**Stories now have a real backend.** `/v1/stories` landed on 2026-09-24 and
replaced the client-side seed this file used to list as a permanent gap.
Routes live in `VersionedEndpoints`; the client is
`feed/data/datasources/story_remote_datasource.dart`.

| # | Method | Path | Success |
|---|---|---|---|
| 1 | POST | `/v1/stories` (JSON **or** multipart) | `201 Story` — 10/min, 100/day |
| 2 | GET | `/v1/stories/feed?page=&size=` | `200 Page<StoryFeedGroup>` |
| 3 | GET | `/v1/stories/me` | `200 Story[]` (bare array, ≤ 100) |
| 4 | GET | `/v1/users/{id}/stories` | `200 Story[]` (bare array) |
| 5 | GET | `/v1/stories/{id}` | `200 Story` |
| 6 | POST | `/v1/stories/{id}/view` | `204` — 120/min |
| 7 | GET | `/v1/stories/{id}/viewers?page=&size=` | `200 Page<StoryViewer>` |
| 8 | GET | `/v1/stories/archive?page=&size=&from=&to=&type=` | `200 Page<Story>` |
| 9 | DELETE | `/v1/stories/{id}` | `204` |
| 10 | POST | `/v1/stories/{id}/replies` | `202 {storyId, recipientId, clientId}` — 30/min |

Things that bite:

- **The multipart field is `image`, singular and unbracketed** — the exact
  opposite of `POST /posts`, which needs `images[]`. One file only.
- **`background` is a key, not a colour.** `cover-0` … `cover-7`; the server
  never stores CSS. The gradients live in
  `feed/presentation/widgets/story_background.dart`, so restyling covers is
  a client release, not a data migration.
- **Image URLs are signed for 15 minutes**, served from R2's S3 API host
  (`<account>.r2.cloudflarestorage.com`), *not* the public media domain.
  They need no auth header. Past `image.urlExpiresAt` the only way to get a
  working URL is re-fetching the story. Cache by
  `presignedObjectKey(url)` — see ADR-015.
- **Your own stories are not in `/stories/feed`.** The rail is
  `/stories/me` + `/stories/feed`, fetched together
  (`StoryRepositoryImpl.getRail`).
- **`viewCount` outlives the viewer list.** Names are deleted 48 h after
  posting while the count is kept, so an empty `viewers` page on an older
  archived story is correct, not an error.
- **A `404` means five different things on purpose** — missing, expired, not
  visible, blocked either way, suspended. Don't try to tell them apart.
- **Error codes** are `RESOURCE_NOT_FOUND` / `RATE_LIMIT_EXCEEDED` /
  `VALIDATION_FAILED` / `INVALID_IMAGE`, plus the new
  `CANNOT_REPLY_TO_OWN_STORY`. An earlier draft of the contract used
  different names for the first three; branch on the ones above.

**Replies cross services.** `POST /v1/stories/{id}/replies` is answered by
yello-api with a `202` and nothing else — the DM is delivered by yello-chat
a moment later as an ordinary `message.new` frame carrying a new
`Message.storyReply` field (`{storyId, storyAuthorId, storyType,
storyExpiresAt}`). Match it back to the optimistic bubble by `clientId`;
reusing the same `clientId` on a retry can never duplicate the message.
Chat stores only that reference, never the story's content, so the bubble's
preview re-fetches the story (`StoryPreviewCubit` caches per id).

Not built server-side: highlights, story reactions, video stories,
close-friends lists, an archive on/off setting, and any live
`STORY_POSTED` push. The rail is re-read on refresh, not pushed.

## Deliberate gaps — do not "fix" these client-side

| Feature | Status | Where |
|---|---|---|
| **Saved posts / bookmarks** | No endpoint. Persisted on-device via `shared_preferences`; not synced across devices. | `feed/data/datasources/bookmarks_local_datasource.dart` |
| **Chat** | *Does* have a backend (`yello-chat`, `/ws`, with a socket upgrade on the same path for live delivery). | `chat/data/datasources/chat_remote_datasource.dart` |
| **Link previews / unfurls** | No preview or unfurl endpoint on any of the three services, and no `og:` metadata on any response. The app reads the linked page itself on the device (ADR-039): a bare Dio with no interceptors, redirects followed by hand so every hop can be checked against `PrivateNetworkGuard`, and the read capped at 64 KB. A server-side unfurler would be strictly better — one fetch per link for everyone instead of one per reader — so if one ever lands, this becomes a data-source swap. | `link_preview/data/datasources/link_preview_remote_datasource.dart` |
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
- **Sticker background removal is switched off server-side.** The route and
  the response shape are final, but every draft currently answers
  `cutoutStatus: "NO_SUBJECT"`, `cutout: null` — the chat container has 300 MB
  and a usable model needs more. There is nothing to do client-side but handle
  both branches, which the creator does: `READY` with a cut-out offers the
  Remove/Keep choice, anything else leaves it on Keep with the server's own
  explanation. It will be switched on with no client change (ADR-040).
- **A sticker URL cannot be re-signed on its own** — there is no
  `GET /ws/stickers/{id}`, so an expired link on a message is recovered by
  re-reading that conversation's history page.
- **`yello-chat` `typing` / `presence` payloads** — the frame reference in
  the service README is not in this repo, and neither shape is expressible
  in OpenAPI, so the served spec lists the event names and stops. The `auth`
  handshake was recovered from the server's own validation errors (see
  above); `typing` is sent as `{ conversationId, isTyping }` and read
  tolerantly (`userId` + `isTyping`/`typing`). A wrong guess on a frame this
  client *sends* shows up as an `error` frame in the device log
  (`ChatRepositoryImpl.watchEvents` logs them) and is a one-line fix in
  `ChatFrameDecoder` / `sendTyping`.

  **`presence` is now decoded**, as of ADR-038 — tolerantly, over
  `{userId, isOnline}`, `{userId, online}`, `{userId, status: "ONLINE"}`, a
  batch under `users`, and a bare `{online: [id, …]}` roster. Every presence
  frame is logged verbatim the first time one arrives in a process
  (`PresenceTracker._onFrame`), so `adb logcat -s flutter | grep presence`
  on a phone with a friend online is the whole investigation. Confirm the
  real shape there and delete the guesses that turn out to be dead.

  **No `presence` frame has ever been observed, on-device 2026-09-26**
  (emulator-5554, Android 17, Yello 0.5.0 profile build, signed in with
  seven conversations). The socket connects and authenticates from the Inbox
  tab and stays up — one TCP connection to the API host held its local port
  across 48 s of sampling while the HTTP poll's connections were recycled
  around it, and it disappeared on switching tabs — and in ~50 s on that
  socket the server sent **nothing** on `presence`: no roster after
  `auth.ok`, no change events, and no frame the decoder failed to read (that
  would have logged). So as of today:

  - **There is no presence snapshot on connect.** Whatever the service does
    send, it does not hand a newly authenticated client the list of who is
    already online. The tracker's set can therefore only ever be built from
    changes seen while connected, which is why a lease held from the Inbox
    (rather than only inside a conversation) is what makes the dot possible
    at all.
  - Whether the service emits presence on *change* is still unknown — it
    needs a second account going online while the log is attached, which no
    single-device check can arrange. Until one is observed, **the green dot
    is client-complete but dark**: nothing renders it, and nothing breaks.
  - Re-run that check the same way (`ss -tn state established` for the
    socket, `logcat -s flutter | grep presence` for the frame) rather than
    by looking at the screen, since an absent dot and an unsent frame look
    identical there.
- **Presence has no HTTP surface.** No route reports who is online, and
  `Participant` carries neither `isOnline` nor `lastSeenAt` (re-checked
  against the served `yello-chat` spec, 2026-09-26). The green online dot is
  therefore only as live as the socket: an open connection is the only way
  to know, so the app leases one while a screen that draws a dot is up
  (ADR-038) and shows nothing — not "offline" — the rest of the time. There
  is no "last seen 5m ago" to build without a server-side field.
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
