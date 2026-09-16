import 'api_version.dart';
import 'endpoint_resolver.dart';

/// Endpoint catalogue for the live backend
/// (`https://api.yello.cachewraith.com`, Swagger UI at `/docs`, raw OpenAPI
/// 3.0 document at `/docs/json`). Paths are copied verbatim from that spec —
/// add a new backend capability by adding a line here, never by hardcoding a
/// `/vN/...` string at a call site.
///
/// Verified against the served spec (v0.2.0, 34 routes) on 2026-09-15.
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

  // Posts
  static String posts() => _r.resolve('/posts', ApiVersion.v1);
  static String post(String id) => _r.resolve('/posts/$id', ApiVersion.v1);
  static String repost(String id) => _r.resolve('/posts/$id/repost', ApiVersion.v1);

  // Comments
  static String postComments(String postId) => _r.resolve('/posts/$postId/comments', ApiVersion.v1);
  static String comment(String id) => _r.resolve('/comments/$id', ApiVersion.v1);

  // Reactions — targetType is 'POST' or 'COMMENT'. POST toggles (add /
  // change / remove in one call); GET lists reactors.
  static String reaction(String targetType, String targetId) =>
      _r.resolve('/reactions/$targetType/$targetId', ApiVersion.v1);
  static String reactionSummary(String targetType, String targetId) =>
      _r.resolve('/reactions/$targetType/$targetId/summary', ApiVersion.v1);

  // Feed (cursor-paginated)
  static String feed() => _r.resolve('/feed', ApiVersion.v1);

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
  // NOT SERVED BY THE LIVE BACKEND — every call below returns
  // `404 RESOURCE_NOT_FOUND` today. They are kept because feature code
  // already calls them; delete the caller or ship the route before relying
  // on any of them.
  // ---------------------------------------------------------------------

  /// No avatar-upload route exists. The spec has no write endpoint for
  /// `/users/me` at all — `avatarUrl` is read-only on the `User` schema.
  static String meAvatar() => _r.resolve('/users/me/avatar', ApiVersion.v1);

  /// Notifications are not in the v0.2.0 spec — they land with the
  /// `yello-notify` service, which is not built yet.
  static String notifications() => _r.resolve('/notifications', ApiVersion.v1);
  static String notificationsUnreadCount() => _r.resolve('/notifications/unread-count', ApiVersion.v1);
  static String notificationsReadAll() => _r.resolve('/notifications/read-all', ApiVersion.v1);
  static String notificationRead(String id) => _r.resolve('/notifications/$id/read', ApiVersion.v1);
}
