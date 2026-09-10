import 'api_version.dart';
import 'endpoint_resolver.dart';

/// Endpoint catalogue for the live backend
/// (`https://dev.yello-api.cachewraith.com`, spec at `/v3/api-docs`). Paths
/// are copied verbatim from that OpenAPI spec — add a new backend
/// capability by adding a line here, never by hardcoding a `/api/vN/...`
/// string at a call site.
abstract final class VersionedEndpoints {
  static final EndpointResolver _r = EndpointResolver();

  // Auth
  static String register() => _r.resolve('/auth/register', ApiVersion.v1);
  static String verifyOtp() => _r.resolve('/auth/verify-otp', ApiVersion.v1);
  static String login() => _r.resolve('/auth/login', ApiVersion.v1);
  static String refresh() => _r.resolve('/auth/refresh', ApiVersion.v1);
  static String logout() => _r.resolve('/auth/logout', ApiVersion.v1);
  static String forgotPassword() => _r.resolve('/auth/forgot-password', ApiVersion.v1);
  static String resetPassword() => _r.resolve('/auth/reset-password', ApiVersion.v1);

  // Users
  static String me() => _r.resolve('/users/me', ApiVersion.v1);
  static String meAvatar() => _r.resolve('/users/me/avatar', ApiVersion.v1);
  static String user(String id) => _r.resolve('/users/$id', ApiVersion.v1);
  static String userPosts(String id) => _r.resolve('/users/$id/posts', ApiVersion.v1);

  // Posts
  static String posts() => _r.resolve('/posts', ApiVersion.v1);
  static String post(String id) => _r.resolve('/posts/$id', ApiVersion.v1);
  static String repost(String id) => _r.resolve('/posts/$id/repost', ApiVersion.v1);
  static String shareLink(String id) => _r.resolve('/posts/$id/share-link', ApiVersion.v1);

  // Comments
  static String postComments(String postId) => _r.resolve('/posts/$postId/comments', ApiVersion.v1);
  static String comment(String id) => _r.resolve('/comments/$id', ApiVersion.v1);

  // Reactions — targetType is 'POST' or 'COMMENT'.
  static String reaction(String targetType, String targetId) =>
      _r.resolve('/reactions/$targetType/$targetId', ApiVersion.v1);
  static String reactionSummary(String targetType, String targetId) =>
      _r.resolve('/reactions/$targetType/$targetId/summary', ApiVersion.v1);

  // Feed (cursor-paginated)
  static String feed() => _r.resolve('/feed', ApiVersion.v1);

  // Friends
  static String friends() => _r.resolve('/friends', ApiVersion.v1);
  static String friendRequests() => _r.resolve('/friends/requests', ApiVersion.v1);
  static String sendFriendRequest(String userId) => _r.resolve('/friends/requests/$userId', ApiVersion.v1);
  static String acceptFriendRequest(String id) => _r.resolve('/friends/requests/$id/accept', ApiVersion.v1);
  static String declineFriendRequest(String id) => _r.resolve('/friends/requests/$id/decline', ApiVersion.v1);
  static String unfriend(String userId) => _r.resolve('/friends/$userId', ApiVersion.v1);

  // Notifications
  static String notifications() => _r.resolve('/notifications', ApiVersion.v1);
  static String notificationsUnreadCount() => _r.resolve('/notifications/unread-count', ApiVersion.v1);
  static String notificationsReadAll() => _r.resolve('/notifications/read-all', ApiVersion.v1);
  static String notificationRead(String id) => _r.resolve('/notifications/$id/read', ApiVersion.v1);
}
