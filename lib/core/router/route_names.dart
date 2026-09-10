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
}
