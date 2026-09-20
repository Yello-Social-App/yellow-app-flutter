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
`USERNAME_CHANGE_COOLDOWN` · `VALIDATION_FAILED`

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

`/users/search` requires `q` of **at least 2 characters** — the server answers
`400 VALIDATION_FAILED` below that, so callers gate on length rather than
firing per keystroke.

---

## Deliberate gaps — do not "fix" these client-side

| Feature | Status | Where |
|---|---|---|
| **Stories** | No `/stories` resource exists. Permanent client-side seed, in-memory only; "seen" resets each app session. | `feed/data/datasources/story_local_datasource.dart` |
| **Saved posts / bookmarks** | No endpoint. Persisted on-device via `shared_preferences`; not synced across devices. | `feed/data/datasources/bookmarks_local_datasource.dart` |
| **Chat** | *Does* have a backend (`yello-chat`, `/ws`, with a socket upgrade on the same path for live delivery). | `chat/data/datasources/chat_remote_datasource.dart` |

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

If a proposed change needs a contract that doesn't exist, **say so** instead
of shipping a client-side workaround that can't actually close the gap.
