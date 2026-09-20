/// Named routes, kept as one catalogue so `context.goNamed(...)` call sites
/// never repeat a path literal that could drift from `app_router.dart`.
abstract final class RouteNames {
  static const String splash = 'splash';
  static const String login = 'login';
  static const String register = 'register';

  // Bottom-nav tabs (StatefulShellRoute branches).
  static const String feed = 'feed';
  static const String friends = 'friends';
  static const String messages = 'messages';
  static const String notifications = 'notifications';
  static const String profile = 'profile';

  // Full-screen overlays, pushed on top of the shell.
  static const String postDetail = 'post-detail';
  static const String userProfile = 'user-profile';
  static const String chat = 'chat';
  static const String storyViewer = 'story-viewer';
  static const String storyCompose = 'story-compose';
  static const String createPost = 'create-post';
  static const String search = 'search';
  static const String sharedPosts = 'shared-posts';
  static const String notificationPreferences = 'notification-preferences';

  // Communities. The `{slug}` path parameter is a community *slug*, never its
  // uuid — that is what every `/communities/...` API route takes.
  static const String communities = 'communities';
  static const String community = 'community';
  static const String createCommunityPost = 'create-community-post';

  /// A community thread. Takes the `CommunityPostEntity` through the route's
  /// `extra`, because the backend has no `GET /community-posts/{id}` to rebuild
  /// it from the id — see `CommunityPostRouteFallback` for what a cold deep
  /// link gets instead.
  static const String communityPost = 'community-post';

  // Showcase. Unlike a community thread, a project *is* fetchable by id, so
  // these routes are fully deep-linkable; `extra` is only a rendering head
  // start.
  static const String showcase = 'showcase';
  static const String project = 'project';
  static const String publishProject = 'publish-project';
}
