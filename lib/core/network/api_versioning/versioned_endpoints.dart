import 'api_version.dart';
import 'endpoint_resolver.dart';

/// Endpoint catalogue for the live backend
/// (`https://api.yello.cachewraith.com`, Swagger UI at `/docs`, raw OpenAPI
/// 3.0 document at `/docs/json?api-docs.json`). Paths are copied verbatim
/// from that spec — add a new backend capability by adding a line here,
/// never by hardcoding a `/vN/...` string at a call site.
///
/// Verified against the served spec (v0.2.0, 40 paths / 53 operations) on
/// 2026-09-20. The previous sweep (2026-09-15) saw 34 routes; Communities,
/// Showcase, community-post comments and `/users/search` have landed since.
///
/// The feedback / reports / mute / hide block below came from the backend's
/// own reference for those features (2026-09-22) rather than from that
/// sweep, so it has **not** been re-checked against the served OpenAPI
/// document — re-verify it on the next `/docs` pass.
///
/// Notifications are **not** here — `yello-notify` is a separate service
/// whose version segment sits after the resource name (`/notifications/v1`,
/// not `/v1/notifications`), so `EndpointResolver` would prepend the wrong
/// prefix. See `NotifyRoutes` in
/// `features/notification/data/datasources/notification_remote_datasource.dart`,
/// same pattern as `ChatRoutes` for `yello-chat`.
abstract final class VersionedEndpoints {
  static final EndpointResolver _r = EndpointResolver();

  // Auth
  static String register() => _r.resolve('/auth/register', ApiVersion.v1);
  static String verifyOtp() => _r.resolve('/auth/verify-otp', ApiVersion.v1);
  static String resendOtp() => _r.resolve('/auth/resend-otp', ApiVersion.v1);
  static String login() => _r.resolve('/auth/login', ApiVersion.v1);
  static String refresh() => _r.resolve('/auth/refresh', ApiVersion.v1);
  static String logout() => _r.resolve('/auth/logout', ApiVersion.v1);
  static String forgotPassword() => _r.resolve('/auth/forgot-password', ApiVersion.v1);
  static String resetPassword() => _r.resolve('/auth/reset-password', ApiVersion.v1);

  // Users
  static String me() => _r.resolve('/users/me', ApiVersion.v1);
  static String user(String id) => _r.resolve('/users/$id', ApiVersion.v1);
  static String userPosts(String id) => _r.resolve('/users/$id/posts', ApiVersion.v1);

  /// `GET /users/search?q=&page=&size=` — active users by name or username.
  /// `q` is required and must be at least 2 characters; the server answers
  /// `400 VALIDATION_FAILED` below that, so callers gate on length rather
  /// than firing a request per keystroke.
  static String usersSearch() => _r.resolve('/users/search', ApiVersion.v1);

  // Posts
  static String posts() => _r.resolve('/posts', ApiVersion.v1);
  static String post(String id) => _r.resolve('/posts/$id', ApiVersion.v1);
  static String repost(String id) => _r.resolve('/posts/$id/repost', ApiVersion.v1);

  // Comments — POST/GET on a post's collection, PUT/DELETE on one comment.
  static String postComments(String postId) => _r.resolve('/posts/$postId/comments', ApiVersion.v1);
  static String comment(String id) => _r.resolve('/comments/$id', ApiVersion.v1);

  // Reactions — targetType is 'POST', 'COMMENT' or 'COMMUNITY_POST'. POST
  // toggles (add / change / remove in one call); GET lists reactors.
  static String reaction(String targetType, String targetId) =>
      _r.resolve('/reactions/$targetType/$targetId', ApiVersion.v1);
  static String reactionSummary(String targetType, String targetId) =>
      _r.resolve('/reactions/$targetType/$targetId/summary', ApiVersion.v1);

  // Feed (cursor-paginated)
  static String feed() => _r.resolve('/feed', ApiVersion.v1);

  // ---------------------------------------------------------------------
  // Stories. Added 2026-09-24 from the backend's own Stories reference;
  // like the feedback/reports block above, this has **not** yet been
  // re-checked against the served OpenAPI document — re-verify on the next
  // `/docs` pass. Everything here is page-number-paginated (`page`/`size`),
  // never cursor-paged, except the two plain-array reads (`/stories/me`
  // and `/users/{id}/stories`), which take no paging at all.
  // ---------------------------------------------------------------------

  /// `POST` one story — JSON for a `TEXT` story, `multipart/form-data`
  /// (field `image`, singular and unbracketed, unlike `/posts`' `images[]`)
  /// for an `IMAGE` one. Capped at 10/min and 100/day per user.
  static String stories() => _r.resolve('/stories', ApiVersion.v1);

  /// `GET /stories/feed?page=&size=` — friends' active stories grouped by
  /// author (`Page<StoryFeedGroup>`). Your own stories are **not** in it;
  /// [storiesMe] is the first ring.
  static String storyFeed() => _r.resolve('/stories/feed', ApiVersion.v1);

  /// `GET /stories/me` — your own active stories, oldest first. A bare
  /// array (≤ 100), not a page, and the only read where `viewCount` is set.
  static String storiesMe() => _r.resolve('/stories/me', ApiVersion.v1);

  /// `GET /stories/archive?page=&size=&from=&to=&type=` — your own stories
  /// including expired ones, newest first. Owner-only by definition.
  static String storyArchive() => _r.resolve('/stories/archive', ApiVersion.v1);

  /// `GET /users/{id}/stories` — one user's active stories you may see, a
  /// bare array. Friends get `FRIENDS`+`PUBLIC`, anyone else `PUBLIC` only.
  static String userStories(String userId) => _r.resolve('/users/$userId/stories', ApiVersion.v1);

  /// `GET` one story (deep link, or to re-sign an expired image URL),
  /// `DELETE` one you own. A story that expired answers `404` for everyone
  /// but its owner, who keeps reading it from the archive.
  static String story(String storyId) => _r.resolve('/stories/$storyId', ApiVersion.v1);

  /// `POST` — marks the story seen by you. `204`, idempotent, and a no-op
  /// on your own story. 120/min per user.
  static String storyView(String storyId) => _r.resolve('/stories/$storyId/view', ApiVersion.v1);

  /// `GET /stories/{id}/viewers?page=&size=` — owner only; anyone else gets
  /// `404` (not `403`, so the story's existence is never confirmed). The
  /// list is dropped 48 h after posting while `viewCount` survives.
  static String storyViewers(String storyId) => _r.resolve('/stories/$storyId/viewers', ApiVersion.v1);

  /// `POST /stories/{id}/replies` — `202 Accepted`. yello-api checks the
  /// story and the friendship, then yello-chat delivers it as an ordinary
  /// DM carrying `Message.storyReply`; the message itself arrives over the
  /// chat socket a moment later, not in this response. 30/min per user.
  static String storyReplies(String storyId) => _r.resolve('/stories/$storyId/replies', ApiVersion.v1);

  // Friends
  static String friends() => _r.resolve('/friends', ApiVersion.v1);
  static String friendRequests() => _r.resolve('/friends/requests', ApiVersion.v1);
  static String friendsBlocked() => _r.resolve('/friends/blocked', ApiVersion.v1);

  /// POST sends a request, DELETE cancels one you sent — same path, and
  /// note the segment is the *other user's* id, not a friend-request id.
  static String sendFriendRequest(String userId) => _r.resolve('/friends/requests/$userId', ApiVersion.v1);

  /// POST only (not PUT). Segment is the requesting user's id.
  static String acceptFriendRequest(String userId) =>
      _r.resolve('/friends/requests/$userId/accept', ApiVersion.v1);

  /// POST only (not PUT). Segment is the requesting user's id.
  static String declineFriendRequest(String userId) =>
      _r.resolve('/friends/requests/$userId/decline', ApiVersion.v1);

  static String unfriend(String userId) => _r.resolve('/friends/$userId', ApiVersion.v1);

  /// POST blocks, DELETE unblocks — same path.
  static String userBlock(String userId) => _r.resolve('/users/$userId/block', ApiVersion.v1);

  // ---------------------------------------------------------------------
  // Feedback, reports, mute and hide. Added 2026-09-22 from the backend's
  // own reference for these four features; the moderator queue
  // (`/admin/reports`) is deliberately absent — it answers
  // `403 ACCESS_DENIED` for every account this app signs in, so there is
  // nothing for a client route to call. See `docs/BACKEND.md`.
  // ---------------------------------------------------------------------

  /// `POST` one feature rating (1-5, optional note), `GET /feedback/me` for
  /// your own, newest first (offset-paged). Submitting is capped at 10 per
  /// hour per user — over that is `429 RATE_LIMIT_EXCEEDED`.
  static String feedback() => _r.resolve('/feedback', ApiVersion.v1);
  static String myFeedback() => _r.resolve('/feedback/me', ApiVersion.v1);

  /// `POST /posts/{postId}/reports` — one open report per post per user;
  /// a second one while the first is `UNDER_REVIEW` is
  /// `409 REPORT_ALREADY_EXISTS`. Capped at 20 per hour.
  static String postReports(String postId) => _r.resolve('/posts/$postId/reports', ApiVersion.v1);

  /// `GET /reports/me` — your reports and their outcomes (offset-paged).
  static String myReports() => _r.resolve('/reports/me', ApiVersion.v1);

  /// POST mutes, DELETE unmutes — same path, both `204` with no body, and
  /// both idempotent. A mute is never visible to the other user: it shows
  /// up in no `friendStatus` and in nothing else they can read.
  static String userMute(String userId) => _r.resolve('/users/$userId/mute', ApiVersion.v1);

  /// `GET /users/me/muted` — who you have muted, most recent first
  /// (offset-paged).
  static String mutedUsers() => _r.resolve('/users/me/muted', ApiVersion.v1);

  /// POST hides, DELETE unhides — same path, both `204` with no body, and
  /// both idempotent. Hiding takes the post out of *your* `/feed` only; it
  /// is not a report and the author is never told.
  static String postHide(String postId) => _r.resolve('/posts/$postId/hide', ApiVersion.v1);

  // ---------------------------------------------------------------------
  // Communities. Every `{community}` segment is the community's **slug**
  // (`^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$`, 3-32 chars), not a uuid — unlike
  // `{post}` on the community-post routes, which is a uuid.
  // ---------------------------------------------------------------------

  /// `GET /communities?q=&membership=&sort=&page=&size=` (offset-paged).
  static String communities() => _r.resolve('/communities', ApiVersion.v1);

  static String community(String slug) => _r.resolve('/communities/$slug', ApiVersion.v1);

  /// POST joins, DELETE leaves — same path, both returning the updated
  /// `Community` (so `isMember`/`memberCount` need no follow-up GET).
  static String communityMembership(String slug) =>
      _r.resolve('/communities/$slug/membership', ApiVersion.v1);

  /// `GET /community-posts?scope=&sort=&size=&cursor=` — the cross-community
  /// timeline. Cursor-paged, like `/feed`, not offset-paged.
  static String communityPostFeed() => _r.resolve('/community-posts', ApiVersion.v1);

  /// `GET` one community's posts (cursor-paged), `POST` to start a thread in
  /// it. Posting requires membership — otherwise
  /// `403 COMMUNITY_MEMBERSHIP_REQUIRED`.
  static String communityPosts(String slug) => _r.resolve('/communities/$slug/posts', ApiVersion.v1);

  /// `PUT` with `{value: -1 | 0 | 1}` — an absolute vote, not a delta, so
  /// clearing a vote means sending `0` rather than re-sending the same value.
  static String communityPostVote(String postId) =>
      _r.resolve('/community-posts/$postId/vote', ApiVersion.v1);

  /// `GET` (offset-paged, replies nested) / `POST` a comment on a community
  /// post. Separate from [postComments] — a community post is not a `Post`.
  static String communityPostComments(String postId) =>
      _r.resolve('/community-posts/$postId/comments', ApiVersion.v1);

  // ---------------------------------------------------------------------
  // Showcase (projects).
  // ---------------------------------------------------------------------

  /// `GET /projects?sort=&tech=&featured=&page=&size=` (offset-paged),
  /// `POST /projects` to publish one.
  static String projects() => _r.resolve('/projects', ApiVersion.v1);

  static String project(String id) => _r.resolve('/projects/$id', ApiVersion.v1);

  /// `GET /projects/tech?limit=` — most-used tech names, **not paged**: the
  /// envelope's `data` is a bare array, so read it with `ApiEnvelope.list`
  /// rather than `ApiEnvelope.page`.
  static String projectsTech() => _r.resolve('/projects/tech', ApiVersion.v1);

  /// `POST` — fire-and-forget view counter, answers `204` with no body.
  /// Rate-limited server-side, so a repeat within the window is a `429`
  /// rather than a second counted view.
  static String projectViews(String id) => _r.resolve('/projects/$id/views', ApiVersion.v1);

  /// POST likes, DELETE unlikes — same path, both returning `ProjectLike`.
  static String projectLike(String id) => _r.resolve('/projects/$id/like', ApiVersion.v1);
}
