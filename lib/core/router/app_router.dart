import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/chat/presentation/pages/chat_page.dart';
import '../../features/chat/presentation/pages/group_info_page.dart';
import '../../features/chat/presentation/pages/messages_page.dart';
import '../../features/communities/domain/entities/community_entity.dart';
import '../../features/communities/domain/entities/community_post_entity.dart';
import '../../features/communities/presentation/pages/communities_page.dart';
import '../../features/communities/presentation/pages/community_detail_page.dart';
import '../../features/communities/presentation/pages/community_post_page.dart';
import '../../features/communities/presentation/pages/create_community_post_page.dart';
import '../../features/feed/presentation/pages/create_post_page.dart';
import '../../features/feed/presentation/pages/feed_page.dart';
import '../../features/feed/presentation/pages/post_detail_page.dart';
import '../../features/feed/presentation/pages/story_archive_page.dart';
import '../../features/feed/presentation/pages/story_compose_page.dart';
import '../../features/feed/presentation/pages/story_viewer_page.dart';
import '../../features/friends/presentation/pages/friends_page.dart';
import '../../features/notification/presentation/pages/notification_preferences_page.dart';
import '../../features/notification/presentation/pages/notifications_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/public_profile_page.dart';
import '../../features/profile/presentation/pages/shared_posts_page.dart';
import '../../features/safety/presentation/pages/privacy_safety_page.dart';
import '../../features/safety/presentation/pages/send_feedback_page.dart';
import '../../features/search/presentation/pages/search_page.dart';
import '../../features/settings/presentation/pages/app_version_page.dart';
import '../../features/settings/presentation/pages/theme_page.dart';
import '../../features/shell/presentation/pages/main_shell_page.dart';
import '../../features/shell/presentation/pages/splash_page.dart';
import '../../features/showcase/domain/entities/project_entity.dart';
import '../../features/showcase/presentation/pages/project_detail_page.dart';
import '../../features/showcase/presentation/pages/publish_project_page.dart';
import '../../features/showcase/presentation/pages/showcase_page.dart';
import '../../shared/widgets/photo_viewer_page.dart';
import '../security/session_manager.dart';
import 'go_router_refresh_stream.dart';
import 'route_guards.dart';
import 'route_names.dart';

/// App-wide navigation graph.
///
/// The bottom-nav tabs are a [StatefulShellRoute.indexedStack] so each
/// tab keeps its own scroll position / navigation stack when the user
/// switches away and back — matching the mockup's single always-mounted
/// page with a `tab` flag, but through idiomatic go_router state instead of
/// a hand-rolled `IndexedStack`. The mockup's full-screen "overlays" (post
/// detail, chat, story viewer/composer, create-post) are modeled as regular
/// pushed routes with a fade/slide transition, since that's what they
/// visually are: a screen stacked on top of the shell.
///
/// Branch order is load-bearing — `BottomNavBar._slotForBranch` and
/// `MainShellPage`'s `_*Branch` constants index into it: Feed 0, Circle 1,
/// Inbox 2, Signals 3, Profile 4, Explore 5.
class AppRouter {
  AppRouter(RouteGuards guards, SessionManager sessionManager)
      : router = GoRouter(
          initialLocation: '/splash',
          redirect: guards.redirect,
          refreshListenable: GoRouterRefreshStream(sessionManager.sessionState),
          routes: [
            GoRoute(
              path: '/splash',
              name: RouteNames.splash,
              builder: (context, state) => const SplashPage(),
            ),
            GoRoute(
              path: '/login',
              name: RouteNames.login,
              builder: (context, state) => const LoginPage(),
            ),
            GoRoute(
              path: '/register',
              name: RouteNames.register,
              builder: (context, state) => const RegisterPage(),
            ),
            StatefulShellRoute.indexedStack(
              builder: (context, state, shell) => MainShellPage(navigationShell: shell),
              branches: [
                StatefulShellBranch(routes: [
                  GoRoute(
                    path: '/feed',
                    name: RouteNames.feed,
                    builder: (context, state) => const FeedPage(),
                  ),
                ]),
                StatefulShellBranch(routes: [
                  GoRoute(
                    path: '/friends',
                    name: RouteNames.friends,
                    builder: (context, state) => const FriendsPage(),
                  ),
                ]),
                StatefulShellBranch(routes: [
                  GoRoute(
                    path: '/messages',
                    name: RouteNames.messages,
                    builder: (context, state) => const MessagesPage(),
                  ),
                ]),
                StatefulShellBranch(routes: [
                  GoRoute(
                    path: '/notifications',
                    name: RouteNames.notifications,
                    builder: (context, state) => const NotificationsPage(),
                  ),
                ]),
                StatefulShellBranch(routes: [
                  GoRoute(
                    path: '/profile',
                    name: RouteNames.profile,
                    builder: (context, state) => const ProfilePage(),
                  ),
                ]),
                // Explore. Communities and Showcase share one branch so the
                // Explore slot stays lit and the bar stays put whichever of
                // the two the title menu has picked — `ExploreTitleMenu`
                // switches with `goNamed`, which swaps this branch's page in
                // place rather than pushing. `/communities` is declared first
                // so it is the branch's initial location: what a fresh tap on
                // Explore lands on, and what reselecting the tab resets to.
                // `NoTransitionPage` so the swap reads as a tab change, not a
                // page push sliding up over the old one.
                StatefulShellBranch(routes: [
                  GoRoute(
                    path: '/communities',
                    name: RouteNames.communities,
                    pageBuilder: (context, state) =>
                        NoTransitionPage(key: state.pageKey, child: const CommunitiesPage()),
                  ),
                  GoRoute(
                    path: '/showcase',
                    name: RouteNames.showcase,
                    pageBuilder: (context, state) =>
                        NoTransitionPage(key: state.pageKey, child: const ShowcasePage()),
                  ),
                ]),
              ],
            ),
            _overlayRoute(
              path: '/post/:postId',
              name: RouteNames.postDetail,
              builder: (context, state) =>
                  PostDetailPage(postId: state.pathParameters['postId']!),
            ),
            _overlayRoute(
              path: '/user/:userId',
              name: RouteNames.userProfile,
              builder: (context, state) =>
                  PublicProfilePage(userId: state.pathParameters['userId']!),
            ),
            _overlayRoute(
              path: '/chat/:conversationId',
              name: RouteNames.chat,
              builder: (context, state) =>
                  ChatPage(conversationId: state.pathParameters['conversationId']!),
            ),
            // Declared as its own overlay rather than a child of `/chat/:id`
            // so `/chat/:id` stays an exact match — the same shape as
            // `/communities/:slug/new` beside `/communities/:slug`.
            _overlayRoute(
              path: '/chat/:conversationId/info',
              name: RouteNames.groupInfo,
              builder: (context, state) =>
                  GroupInfoPage(conversationId: state.pathParameters['conversationId']!),
            ),
            // Keyed by author id rather than by the rail's index: a ring
            // that expired between the rail rendering and the tap would
            // otherwise open somebody else's story. `?only=true` plays just
            // that author's ring (`GET /users/{id}/stories`) instead of
            // continuing through the whole rail.
            _overlayRoute(
              path: '/story/:authorId',
              name: RouteNames.storyViewer,
              builder: (context, state) => StoryViewerPage(
                authorId: state.pathParameters['authorId']!,
                onlyThisAuthor: state.uri.queryParameters['only'] == 'true',
              ),
            ),
            _overlayRoute(
              path: '/story-compose',
              name: RouteNames.storyCompose,
              builder: (context, state) => const StoryComposePage(),
            ),
            _overlayRoute(
              path: '/story-archive',
              name: RouteNames.storyArchive,
              builder: (context, state) => const StoryArchivePage(),
            ),
            _overlayRoute(
              path: '/create',
              name: RouteNames.createPost,
              builder: (context, state) => const CreatePostPage(),
            ),
            _overlayRoute(
              path: '/search',
              name: RouteNames.search,
              builder: (context, state) => const SearchPage(),
            ),
            _overlayRoute(
              path: '/shared-posts',
              name: RouteNames.sharedPosts,
              builder: (context, state) => const SharedPostsPage(),
            ),
            _overlayRoute(
              path: '/notification-preferences',
              name: RouteNames.notificationPreferences,
              builder: (context, state) => const NotificationPreferencesPage(),
            ),
            _overlayRoute(
              path: '/privacy-safety',
              name: RouteNames.privacySafety,
              builder: (context, state) => const PrivacySafetyPage(),
            ),
            _overlayRoute(
              path: '/feedback',
              name: RouteNames.sendFeedback,
              builder: (context, state) => const SendFeedbackPage(),
            ),
            _overlayRoute(
              path: '/theme',
              name: RouteNames.theme,
              builder: (context, state) => const ThemePage(),
            ),
            _overlayRoute(
              path: '/app-version',
              name: RouteNames.appVersion,
              builder: (context, state) => const AppVersionPage(),
            ),
            // The photo viewer gets its own transition rather than
            // `_overlayRoute`'s slide-up: it is a lightbox over whatever is
            // behind it, so it fades in over a still screen (non-opaque, so
            // the page underneath keeps painting through the fade).
            GoRoute(
              path: '/photo',
              name: RouteNames.photoViewer,
              pageBuilder: (context, state) {
                final args = state.extra;
                return CustomTransitionPage(
                  key: state.pageKey,
                  opaque: false,
                  child: args is PhotoViewerArgs
                      ? PhotoViewerPage(imageUrls: args.imageUrls, initialIndex: args.initialIndex)
                      : const PhotoViewerPage(imageUrls: []),
                  transitionsBuilder: (context, animation, secondary, child) => FadeTransition(
                    opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
                    child: child,
                  ),
                );
              },
            ),
            // The Communities and Showcase *hubs* live in the shell's Explore
            // branch above; everything below them is a full-screen overlay
            // pushed over the shell, like a post detail is for the feed.
            //
            // Declared before '/communities/:slug' is irrelevant here (the
            // depths differ), but the composer does need the community itself
            // for its tag picker: `POST /communities/{slug}/posts` requires a
            // `tag` drawn from that community's own `tags`. Reached without it
            // (a deep link), fall back to the community's screen, where the
            // same composer is one tap away and the tags are loaded.
            _overlayRoute(
              path: '/communities/:slug/new',
              name: RouteNames.createCommunityPost,
              builder: (context, state) {
                final community = state.extra;
                final slug = state.pathParameters['slug']!;
                if (community is! CommunityEntity) return CommunityDetailPage(slug: slug);
                return CreateCommunityPostPage(community: community);
              },
            ),
            _overlayRoute(
              path: '/communities/:slug',
              name: RouteNames.community,
              builder: (context, state) => CommunityDetailPage(slug: state.pathParameters['slug']!),
            ),
            // The thread screen needs the post object, not just its id: there is
            // no `GET /community-posts/{id}` route on the backend, so a thread
            // genuinely cannot be rebuilt from the URL alone.
            _overlayRoute(
              path: '/community-post/:postId',
              name: RouteNames.communityPost,
              builder: (context, state) {
                final post = state.extra;
                if (post is! CommunityPostEntity) return const CommunityPostRouteFallback();
                return CommunityPostPage(post: post);
              },
            ),
            // Must stay ahead of '/showcase/:projectId': go_router matches in
            // declaration order, so the other way round 'new' would be read as
            // a project id.
            _overlayRoute(
              path: '/showcase/new',
              name: RouteNames.publishProject,
              builder: (context, state) => const PublishProjectPage(),
            ),
            _overlayRoute(
              path: '/showcase/:projectId',
              name: RouteNames.project,
              builder: (context, state) {
                final seed = state.extra;
                return ProjectDetailPage(
                  projectId: state.pathParameters['projectId']!,
                  // Only a head start for the header — the screen re-reads
                  // `GET /projects/{id}` either way, so a cold deep link with no
                  // `extra` behaves the same, just with a shimmer first.
                  seed: seed is ProjectEntity ? seed : null,
                );
              },
            ),
          ],
        );

  final GoRouter router;

  static GoRoute _overlayRoute({
    required String path,
    required String name,
    required Widget Function(BuildContext, GoRouterState) builder,
  }) {
    return GoRoute(
      path: path,
      name: name,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: builder(context, state),
        transitionsBuilder: (context, animation, secondary, child) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
                .animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          );
        },
      ),
    );
  }
}
