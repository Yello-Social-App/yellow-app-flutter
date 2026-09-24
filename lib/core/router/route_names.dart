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

  /// A group's own screen (name, photo, members, roles, leave) — pushed over
  /// the chat from its header. DMs have no such screen.
  static const String groupInfo = 'group-info';
  static const String storyViewer = 'story-viewer';
  static const String storyCompose = 'story-compose';
  static const String storyArchive = 'story-archive';
  static const String createPost = 'create-post';
  static const String search = 'search';

  /// The full-screen photo viewer, opened by tapping a post photo. Takes its
  /// URLs through `extra` (`PhotoViewerArgs`) — photo URLs are too long and
  /// too plural for the path, so this one is not deep-linkable by design.
  static const String photoViewer = 'photo-viewer';

  static const String sharedPosts = 'shared-posts';
  static const String notificationPreferences = 'notification-preferences';

  /// Settings → Privacy & safety: the reports you filed and their outcomes,
  /// plus the accounts you have muted. Also where a tapped
  /// `REPORT_RESOLVED` push lands — see `ReportsDestination`.
  static const String privacySafety = 'privacy-safety';

  static const String sendFeedback = 'send-feedback';

  /// Account menu → Theme: the light/dark choice, which used to be a toggle
  /// in the menu itself.
  static const String theme = 'theme';

  /// Account menu → App version: the installed build and the device facts a
  /// support reply asks for. Shows no update check — the API has no version
  /// resource, see `docs/BACKEND.md`.
  static const String appVersion = 'app-version';

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
