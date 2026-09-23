import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get_it/get_it.dart';

import '../../features/auth/data/datasources/auth_local_datasource.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/domain/usecases/logout_usecase.dart';
import '../../features/auth/domain/usecases/password_reset_usecases.dart';
import '../../features/auth/domain/usecases/register_usecase.dart';
import '../../features/auth/domain/usecases/verify_otp_usecase.dart';
import '../../features/auth/presentation/bloc/auth_cubit.dart';
import '../../features/chat/data/datasources/chat_remote_datasource.dart';
import '../../features/chat/data/datasources/chat_socket.dart';
import '../../features/chat/data/datasources/user_directory.dart';
import '../../features/chat/data/repositories/chat_repository_impl.dart';
import '../../features/chat/domain/repositories/chat_repository.dart';
import '../../features/chat/domain/usecases/chat_usecases.dart';
import '../../features/chat/presentation/bloc/chat_cubit.dart';
import '../../features/chat/presentation/bloc/group_info_cubit.dart';
import '../../features/chat/presentation/bloc/messages_cubit.dart';
import '../../features/communities/data/datasources/communities_remote_datasource.dart';
import '../../features/communities/data/repositories/communities_repository_impl.dart';
import '../../features/communities/domain/entities/community_post_entity.dart';
import '../../features/communities/domain/repositories/communities_repository.dart';
import '../../features/communities/domain/usecases/communities_usecases.dart';
import '../../features/communities/presentation/bloc/communities_cubit.dart';
import '../../features/communities/presentation/bloc/community_detail_cubit.dart';
import '../../features/communities/presentation/bloc/community_feed_cubit.dart';
import '../../features/communities/presentation/bloc/community_post_cubit.dart';
import '../../features/communities/presentation/bloc/create_community_post_cubit.dart';
import '../../features/feed/data/datasources/bookmarks_local_datasource.dart';
import '../../features/feed/data/datasources/feed_remote_datasource.dart';
import '../../features/feed/data/datasources/story_local_datasource.dart';
import '../../features/feed/data/repositories/feed_repository_impl.dart';
import '../../features/feed/domain/entities/post_entity.dart';
import '../../features/feed/domain/repositories/feed_repository.dart';
import '../../features/feed/domain/usecases/add_comment_usecase.dart';
import '../../features/feed/domain/usecases/create_post_usecase.dart';
import '../../features/feed/domain/usecases/delete_comment_usecase.dart';
import '../../features/feed/domain/usecases/delete_post_usecase.dart';
import '../../features/feed/domain/usecases/edit_comment_usecase.dart';
import '../../features/feed/domain/usecases/get_comments_usecase.dart';
import '../../features/feed/domain/usecases/get_feed_usecase.dart';
import '../../features/feed/domain/usecases/get_post_detail_usecase.dart';
import '../../features/feed/domain/usecases/get_post_usecase.dart';
import '../../features/feed/domain/usecases/get_saved_post_ids_usecase.dart';
import '../../features/feed/domain/usecases/get_share_link_usecase.dart';
import '../../features/feed/domain/usecases/get_stories_usecase.dart';
import '../../features/feed/domain/usecases/like_post_usecase.dart';
import '../../features/feed/domain/usecases/mark_story_seen_usecase.dart';
import '../../features/feed/domain/usecases/react_usecases.dart';
import '../../features/feed/domain/usecases/update_post_usecase.dart';
import '../../features/feed/presentation/bloc/create_post_cubit.dart';
import '../../features/feed/presentation/bloc/feed_cubit.dart';
import '../../features/feed/presentation/bloc/post_detail_cubit.dart';
import '../../features/feed/presentation/bloc/reactors_cubit.dart';
import '../../features/feed/presentation/bloc/story_cubit.dart';
import '../../features/friends/data/datasources/friends_remote_datasource.dart';
import '../../features/friends/data/repositories/friends_repository_impl.dart';
import '../../features/friends/domain/repositories/friends_repository.dart';
import '../../features/friends/domain/usecases/friends_usecases.dart';
import '../../features/friends/presentation/bloc/friends_cubit.dart';
import '../../features/notification/data/datasources/notification_remote_datasource.dart';
import '../../features/notification/data/repositories/notification_repository_impl.dart';
import '../../features/notification/domain/repositories/notification_repository.dart';
import '../../features/notification/domain/usecases/notification_usecases.dart';
import '../../features/notification/presentation/bloc/notification_preferences_cubit.dart';
import '../../features/notification/presentation/bloc/notifications_cubit.dart';
import '../../features/profile/data/datasources/profile_remote_datasource.dart';
import '../../features/profile/data/repositories/profile_repository_impl.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/profile/domain/usecases/profile_usecases.dart';
import '../../features/profile/presentation/bloc/profile_cubit.dart';
import '../../features/profile/presentation/bloc/public_profile_cubit.dart';
import '../../features/profile/presentation/bloc/shared_posts_cubit.dart';
import '../../features/safety/data/datasources/safety_remote_datasource.dart';
import '../../features/safety/data/repositories/safety_repository_impl.dart';
import '../../features/safety/domain/repositories/safety_repository.dart';
import '../../features/safety/domain/usecases/safety_usecases.dart';
import '../../features/safety/presentation/bloc/feedback_cubit.dart';
import '../../features/safety/presentation/bloc/privacy_safety_cubit.dart';
import '../../features/safety/presentation/bloc/report_post_cubit.dart';
import '../../features/search/data/datasources/search_remote_datasource.dart';
import '../../features/search/data/repositories/search_repository_impl.dart';
import '../../features/search/domain/repositories/search_repository.dart';
import '../../features/search/domain/usecases/search_users_usecase.dart';
import '../../features/search/presentation/bloc/search_cubit.dart';
import '../../features/settings/data/datasources/apk_installer.dart';
import '../../features/settings/data/datasources/app_info_local_datasource.dart';
import '../../features/settings/data/datasources/app_update_remote_datasource.dart';
import '../../features/settings/data/repositories/app_info_repository_impl.dart';
import '../../features/settings/data/repositories/app_update_repository_impl.dart';
import '../../features/settings/domain/repositories/app_info_repository.dart';
import '../../features/settings/domain/repositories/app_update_repository.dart';
import '../../features/settings/domain/usecases/check_for_update_usecase.dart';
import '../../features/settings/domain/usecases/download_update_usecase.dart';
import '../../features/settings/domain/usecases/get_app_build_info_usecase.dart';
import '../../features/settings/domain/usecases/install_update_usecase.dart';
import '../../features/settings/domain/usecases/open_install_settings_usecase.dart';
import '../../features/settings/presentation/bloc/app_update_cubit.dart';
import '../../features/settings/presentation/bloc/app_version_cubit.dart';
import '../../features/showcase/data/datasources/showcase_remote_datasource.dart';
import '../../features/showcase/data/repositories/showcase_repository_impl.dart';
import '../../features/showcase/domain/entities/project_entity.dart';
import '../../features/showcase/domain/repositories/showcase_repository.dart';
import '../../features/showcase/domain/usecases/showcase_usecases.dart';
import '../../features/showcase/presentation/bloc/project_detail_cubit.dart';
import '../../features/showcase/presentation/bloc/publish_project_cubit.dart';
import '../../features/showcase/presentation/bloc/showcase_cubit.dart';
import '../network/api_client.dart';
import '../network/network_info.dart';
import '../network/token_refresh_service.dart';
import '../notifications/push_notification_service.dart';
import '../router/app_router.dart';
import '../router/route_guards.dart';
import '../security/biometric_auth_service.dart';
import '../security/jwt_manager.dart';
import '../security/root_jailbreak_detector.dart';
import '../security/secure_storage_service.dart';
import '../security/session_manager.dart';
import '../theme/theme_cubit.dart';

/// The app's single [GetIt] instance. Everything — data sources,
/// repositories, use cases, Cubits, the router — is resolved through `sl`
/// (service locator) rather than constructed ad hoc, so a widget's
/// dependencies are swappable in tests via `sl.registerSingleton(fake)`.
final GetIt sl = GetIt.instance;

/// Wires the full dependency graph. Called once from `bootstrap()` (in turn
/// called from `main.dart`), after `AppConfig.init(...)` (several
/// registrations — [ApiClient] in particular — read `AppConfig` statics at
/// construction time).
Future<void> configureDependencies() async {
  _registerCore();
  _registerAuth();
  // Before the feed: `FeedCubit` and `PostDetailCubit` both take safety use
  // cases (hide a post, mute its author). Lazy singletons resolve on first
  // read rather than on registration, so this is about reading order rather
  // than correctness — but keeping the dependency above its dependents
  // saves the next person the check.
  _registerSafety();
  _registerFeed();
  _registerFriends();
  _registerNotifications();
  _registerProfile();
  _registerChat();
  _registerSearch();
  _registerCommunities();
  _registerShowcase();
  _registerSettings();
}

void _registerCore() {
  sl.registerLazySingleton(() => Connectivity());
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));

  sl.registerLazySingleton<SecureStorageService>(() => SecureStorageServiceImpl());
  sl.registerLazySingleton<JwtManager>(() => JwtManagerImpl());
  sl.registerLazySingleton<TokenRefreshService>(() => TokenRefreshServiceImpl(sl()));
  sl.registerLazySingleton<SessionManager>(() => SessionManagerImpl(sl(), sl(), sl()));
  sl.registerLazySingleton<RootJailbreakDetector>(() => RootJailbreakDetectorImpl());
  sl.registerLazySingleton<BiometricAuthService>(() => BiometricAuthServiceImpl());

  sl.registerLazySingleton(
    () => ApiClient(
      secureStorage: sl(),
      jwtManager: sl(),
      sessionManager: sl(),
      networkInfo: sl(),
      tokenRefreshService: sl(),
    ),
  );

  sl.registerLazySingleton(() => RouteGuards(sl()));
  sl.registerLazySingleton(() => AppRouter(sl(), sl()));
  sl.registerLazySingleton(() => ThemeCubit());
}

void _registerAuth() {
  sl.registerLazySingleton<AuthRemoteDataSource>(() => AuthRemoteDataSourceImpl(sl()));
  sl.registerLazySingleton<AuthLocalDataSource>(() => AuthLocalDataSourceImpl());
  sl.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(sl(), sl(), sl(), sl()));

  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton(() => RegisterUseCase(sl()));
  sl.registerLazySingleton(() => VerifyOtpUseCase(sl()));
  sl.registerLazySingleton(() => ResendOtpUseCase(sl()));
  // (authRepository, notificationRepository, secureStorage) — see the
  // usecase's own doc for why logout reaches into the notification feature.
  sl.registerLazySingleton(() => LogoutUseCase(sl(), sl(), sl()));
  sl.registerLazySingleton(() => ForgotPasswordUseCase(sl()));
  sl.registerLazySingleton(() => ResetPasswordUseCase(sl()));

  // Factory: each login/register screen visit gets a fresh flow state.
  sl.registerFactory(
    () => AuthCubit(
      register: sl(),
      verifyOtp: sl(),
      resendOtp: sl(),
      login: sl(),
      logout: sl(),
      forgotPassword: sl(),
      resetPassword: sl(),
    ),
  );
}

void _registerFriends() {
  sl.registerLazySingleton<FriendsRemoteDataSource>(() => FriendsRemoteDataSourceImpl(sl()));
  sl.registerLazySingleton<FriendsRepository>(() => FriendsRepositoryImpl(sl(), sl()));

  sl.registerLazySingleton(() => GetFriendsUseCase(sl()));
  sl.registerLazySingleton(() => GetFriendRequestsUseCase(sl()));
  sl.registerLazySingleton(() => SendFriendRequestUseCase(sl()));
  sl.registerLazySingleton(() => AcceptFriendRequestUseCase(sl()));
  sl.registerLazySingleton(() => DeclineFriendRequestUseCase(sl()));
  sl.registerLazySingleton(() => UnfriendUseCase(sl()));

  // Routes the client previously had no methods for at all, though the
  // backend has always served them. No UI yet — the data layer is ready
  // whenever a "blocked users" screen is.
  sl.registerLazySingleton(() => CancelFriendRequestUseCase(sl()));
  sl.registerLazySingleton(() => GetBlockedUsersUseCase(sl()));
  sl.registerLazySingleton(() => BlockUserUseCase(sl()));
  sl.registerLazySingleton(() => UnblockUserUseCase(sl()));

  sl.registerFactory(
    () => FriendsCubit(getFriends: sl(), getRequests: sl(), acceptRequest: sl(), declineRequest: sl(), unfriend: sl()),
  );
}

void _registerNotifications() {
  // `yello-notify` is a third service on the same host — see `NotifyRoutes`
  // (in the data source below) for why it reuses `ApiClient` but not
  // `VersionedEndpoints`.
  sl.registerLazySingleton<NotificationRemoteDataSource>(() => NotificationRemoteDataSourceImpl(sl()));
  sl.registerLazySingleton<NotificationRepository>(() => NotificationRepositoryImpl(sl(), sl(), sl()));

  sl.registerLazySingleton(() => GetInboxUseCase(sl()));
  sl.registerLazySingleton(() => GetUnreadNotificationCountUseCase(sl()));
  sl.registerLazySingleton(() => MarkNotificationReadUseCase(sl()));
  sl.registerLazySingleton(() => MarkAllNotificationsReadUseCase(sl()));
  sl.registerLazySingleton(() => DeleteNotificationUseCase(sl()));
  sl.registerLazySingleton(() => RegisterDeviceUseCase(sl()));
  sl.registerLazySingleton(() => UnregisterDeviceUseCase(sl()));
  sl.registerLazySingleton(() => GetNotificationPreferencesUseCase(sl()));
  sl.registerLazySingleton(() => UpdateNotificationPreferencesUseCase(sl()));

  // Needs `RegisterDeviceUseCase` (above) and `SecureStorageService` (see
  // `_registerCore`) — resolved lazily, so registration order here doesn't
  // matter, only that both exist somewhere in the graph by the time
  // `bootstrap()` calls `sl<PushNotificationService>().init()`.
  sl.registerLazySingleton<PushNotificationService>(() => PushNotificationServiceImpl(sl(), sl()));

  // Long-lived: backs both the Signals tab *and* the bottom-nav unread
  // badge (`BottomNavBar` resolves the same instance via
  // `sl<NotificationsCubit>()`) — see the cubit's own class doc for why a
  // factory here would silently break that badge.
  sl.registerLazySingleton(
    () => NotificationsCubit(
      getInbox: sl(),
      getUnreadCount: sl(),
      markRead: sl(),
      markAllRead: sl(),
      deleteNotification: sl(),
      acceptFriendRequest: sl(),
      declineFriendRequest: sl(),
      getFriendRequests: sl(),
      getFriends: sl(),
    ),
  );

  // Factory: the settings screen has no reason to keep state once popped.
  sl.registerFactory(() => NotificationPreferencesCubit(getPreferences: sl(), updatePreferences: sl()));
}

void _registerProfile() {
  sl.registerLazySingleton<ProfileRemoteDataSource>(() => ProfileRemoteDataSourceImpl(sl()));
  sl.registerLazySingleton<ProfileRepository>(() => ProfileRepositoryImpl(sl(), sl()));

  sl.registerLazySingleton(() => GetMeUseCase(sl()));
  sl.registerLazySingleton(() => UpdateProfileUseCase(sl()));
  sl.registerLazySingleton(() => GetUserUseCase(sl()));
  sl.registerLazySingleton(() => GetUserPostsUseCase(sl()));
  sl.registerLazySingleton(() => UpdateAvatarUseCase(sl()));

  sl.registerFactory(
    () => ProfileCubit(
      getMe: sl(),
      updateProfile: sl(),
      updateAvatar: sl(),
      getUserPosts: sl(),
      getSavedPostIds: sl(),
      getPost: sl(),
      getFriends: sl(),
      likePost: sl(),
      reactToPost: sl(),
      repost: sl(),
      deletePost: sl(),
      toggleSave: sl(),
    ),
  );

  // Fresh cubit per push, same reasoning as `PostDetailCubit`/
  // `PublicProfileCubit` below — see its own doc comment.
  sl.registerFactory(
    () => SharedPostsCubit(
      getMe: sl(),
      getUserPosts: sl(),
      likePost: sl(),
      reactToPost: sl(),
      toggleSave: sl(),
      repost: sl(),
      deletePost: sl(),
    ),
  );

  // `String` param is the viewed user's id — a fresh cubit per profile push,
  // same convention as `PostDetailCubit` below.
  sl.registerFactoryParam<PublicProfileCubit, String, void>(
    (userId, _) => PublicProfileCubit(
      userId: userId,
      blockUser: sl(),
      unblockUser: sl(),
      getMe: sl(),
      getUser: sl(),
      getUserPosts: sl(),
      getFriends: sl(),
      getFriendRequests: sl(),
      sendFriendRequest: sl(),
      acceptFriendRequest: sl(),
      declineFriendRequest: sl(),
      unfriend: sl(),
      likePost: sl(),
      reactToPost: sl(),
      repost: sl(),
      deletePost: sl(),
      toggleSave: sl(),
    ),
  );
}

void _registerChat() {
  // `yello-chat` is a second service on the same host, so it reuses
  // [ApiClient] — and with it the bearer header and refresh-on-401 — but
  // shares none of yello-api's `/v1` prefix or response envelope. See
  // `ChatRoutes`.
  sl.registerLazySingleton<ChatRemoteDataSource>(() => ChatRemoteDataSourceImpl(sl()));

  // Chat participants arrive as bare user ids; this resolves them to names
  // and avatars through yello-api and caches them for the session.
  sl.registerLazySingleton(() => UserDirectory(sl()));

  // One live connection for the whole app; it opens when a chat screen
  // subscribes and closes when the last one leaves. Authenticates with the
  // stored access token and refreshes it once on rejection.
  sl.registerLazySingleton(() => ChatSocket(secureStorage: sl(), tokenRefresh: sl()));

  // (remote, directory, getMe, networkInfo, socket)
  sl.registerLazySingleton<ChatRepository>(() => ChatRepositoryImpl(sl(), sl(), sl(), sl(), sl()));

  sl.registerLazySingleton(() => GetConversationsUseCase(sl()));
  sl.registerLazySingleton(() => GetConversationUseCase(sl()));
  sl.registerLazySingleton(() => GetMessagesUseCase(sl()));
  sl.registerLazySingleton(() => SendMessageUseCase(sl()));
  sl.registerLazySingleton(() => EditMessageUseCase(sl()));
  sl.registerLazySingleton(() => DeleteMessageUseCase(sl()));
  sl.registerLazySingleton(() => ReactToMessageUseCase(sl()));
  sl.registerLazySingleton(() => UploadAttachmentUseCase(sl()));
  sl.registerLazySingleton(() => RefreshAttachmentUseCase(sl()));
  sl.registerLazySingleton(() => MarkReadUseCase(sl()));
  sl.registerLazySingleton(() => StartDirectConversationUseCase(sl()));
  // No composer for a new group yet — `POST /ws/conversations` with
  // `type: GROUP` is reachable, the UI for it is not. Registered so the
  // Inbox's compose action has its usecase ready when it gets one.
  sl.registerLazySingleton(() => StartGroupConversationUseCase(sl()));

  // Groups and invite cards — every one of these is 400 on a DM.
  sl.registerLazySingleton(() => RenameGroupUseCase(sl()));
  sl.registerLazySingleton(() => SetGroupPhotoUseCase(sl()));
  sl.registerLazySingleton(() => RemoveGroupPhotoUseCase(sl()));
  sl.registerLazySingleton(() => AddGroupMembersUseCase(sl()));
  sl.registerLazySingleton(() => RemoveGroupMemberUseCase(sl()));
  sl.registerLazySingleton(() => ChangeMemberRoleUseCase(sl()));
  sl.registerLazySingleton(() => LeaveGroupUseCase(sl()));
  sl.registerLazySingleton(() => InviteToGroupUseCase(sl()));
  sl.registerLazySingleton(() => AcceptGroupInviteUseCase(sl()));
  sl.registerLazySingleton(() => DeclineGroupInviteUseCase(sl()));

  // Long-lived: the Inbox list (and unread counts) survives tab switches.
  sl.registerLazySingleton(() => MessagesCubit(sl()));

  sl.registerFactoryParam<ChatCubit, String, void>(
    (conversationId, _) => ChatCubit(
      conversationId: conversationId,
      getConversation: sl(),
      getMessages: sl(),
      sendMessage: sl(),
      editMessage: sl(),
      deleteMessage: sl(),
      reactToMessage: sl(),
      uploadAttachment: sl(),
      refreshAttachment: sl(),
      acceptInvite: sl(),
      declineInvite: sl(),
      markRead: sl(),
      repository: sl(),
      inbox: sl(),
    ),
  );

  // Fresh per push, like `ChatCubit`: the group screen's state has no reason
  // to outlive it, and every change it makes is written to `MessagesCubit`
  // for the rest of the app to read. `GetFriendsUseCase` (friends feature)
  // feeds its add/invite pickers — only friends can be picked.
  sl.registerFactoryParam<GroupInfoCubit, String, void>(
    (conversationId, _) => GroupInfoCubit(
      conversationId: conversationId,
      getConversation: sl(),
      rename: sl(),
      setPhoto: sl(),
      removePhoto: sl(),
      addMembers: sl(),
      removeMember: sl(),
      changeRole: sl(),
      leave: sl(),
      invite: sl(),
      getFriends: sl(),
      inbox: sl(),
    ),
  );
}

/// Feedback, post reports, mute and hide — one feature slice over four
/// small `yello-api` resources. The moderator half of reports
/// (`/v1/admin/reports`) has no registration because it has no client: it
/// answers `403 ACCESS_DENIED` for every account this app signs in.
void _registerSafety() {
  sl.registerLazySingleton<SafetyRemoteDataSource>(() => SafetyRemoteDataSourceImpl(sl()));
  sl.registerLazySingleton<SafetyRepository>(() => SafetyRepositoryImpl(sl(), sl()));

  sl.registerLazySingleton(() => SubmitFeedbackUseCase(sl()));
  sl.registerLazySingleton(() => GetMyFeedbackUseCase(sl()));
  sl.registerLazySingleton(() => ReportPostUseCase(sl()));
  sl.registerLazySingleton(() => GetMyReportsUseCase(sl()));
  sl.registerLazySingleton(() => MuteUserUseCase(sl()));
  sl.registerLazySingleton(() => UnmuteUserUseCase(sl()));
  sl.registerLazySingleton(() => GetMutedUsersUseCase(sl()));
  sl.registerLazySingleton(() => HidePostUseCase(sl()));

  // No caller yet: hiding is offered from the post menu, but nothing lists
  // hidden posts to unhide them from — `GET /v1/feed` simply leaves them
  // out and there is no "hidden posts" endpoint to build that screen on.
  // Registered so the route is one screen away, not one layer away. Same
  // reasoning as the friends feature's `GetBlockedUsersUseCase`.
  sl.registerLazySingleton(() => UnhidePostUseCase(sl()));

  // Factories: none of this state should outlive the screen or sheet that
  // opened it — a half-written report or a stale muted list is worse than
  // a fresh fetch.
  sl.registerFactory(() => FeedbackCubit(submitFeedback: sl(), getMyFeedback: sl()));
  sl.registerFactory(() => PrivacySafetyCubit(getMyReports: sl(), getMutedUsers: sl(), unmuteUser: sl()));
  sl.registerFactoryParam<ReportPostCubit, String, void>(
    (postId, _) => ReportPostCubit(postId: postId, reportPost: sl()),
  );
}

void _registerFeed() {
  // Live backend (posts/comments/reactions/reposts/feed).
  sl.registerLazySingleton<FeedRemoteDataSource>(() => FeedRemoteDataSourceImpl(sl()));
  // No backend endpoint exists for either of these (see each class's doc).
  sl.registerLazySingleton<StoryLocalDataSource>(() => StoryLocalDataSourceImpl());
  sl.registerLazySingleton<BookmarksLocalDataSource>(() => BookmarksLocalDataSourceImpl());

  sl.registerLazySingleton<FeedRepository>(() => FeedRepositoryImpl(sl(), sl(), sl(), sl()));

  sl.registerLazySingleton(() => GetFeedUseCase(sl()));
  sl.registerLazySingleton(() => GetStoriesUseCase(sl()));
  sl.registerLazySingleton(() => MarkStorySeenUseCase(sl()));
  sl.registerLazySingleton(() => LikePostUseCase(sl()));
  sl.registerLazySingleton(() => ReactToPostUseCase(sl()));
  sl.registerLazySingleton(() => ReactToCommentUseCase(sl()));
  sl.registerLazySingleton(() => GetReactionSummaryUseCase(sl()));
  sl.registerLazySingleton(() => GetReactorsUseCase(sl()));
  sl.registerLazySingleton(() => RepostUseCase(sl()));
  sl.registerLazySingleton(() => ToggleSaveUseCase(sl()));
  sl.registerLazySingleton(() => GetPostDetailUseCase(sl()));
  sl.registerLazySingleton(() => GetCommentsUseCase(sl()));
  sl.registerLazySingleton(() => GetPostUseCase(sl()));
  sl.registerLazySingleton(() => GetSavedPostIdsUseCase(sl()));
  sl.registerLazySingleton(() => AddCommentUseCase(sl()));
  sl.registerLazySingleton(() => CreatePostUseCase(sl()));
  sl.registerLazySingleton(() => UpdatePostUseCase(sl()));
  sl.registerLazySingleton(() => DeletePostUseCase(sl()));
  sl.registerLazySingleton(() => DeleteCommentUseCase(sl()));
  // `PUT /comments/{id}` — shared by the feed's threads and community
  // threads, since a comment lives on the same `/comments/{id}` resource
  // whichever kind of post it hangs off.
  sl.registerLazySingleton(() => EditCommentUseCase(sl()));
  sl.registerLazySingleton(() => GetShareLinkUseCase(sl()));

  // Long-lived: the whole Home tab's state (posts, stories, like/save
  // toggles) survives tab switches — see `FeedPage`'s `BlocProvider.value`.
  sl.registerLazySingleton(
    () => FeedCubit(
      getFeed: sl(),
      getStories: sl(),
      likePost: sl(),
      reactToPost: sl(),
      repost: sl(),
      toggleSave: sl(),
      getMe: sl(),
      getUserPosts: sl(),
      getReactionSummary: sl(),
      updatePost: sl(),
      deletePost: sl(),
      getShareLink: sl(),
      hidePost: sl(),
      muteUser: sl(),
    ),
  );

  sl.registerFactoryParam<PostDetailCubit, String, void>(
    (postId, _) => PostDetailCubit(
      postId: postId,
      getPostDetail: sl(),
      getComments: sl(),
      addComment: sl(),
      likePost: sl(),
      reactToPost: sl(),
      reactToComment: sl(),
      getReactionSummary: sl(),
      updatePost: sl(),
      deletePost: sl(),
      deleteComment: sl(),
      getShareLink: sl(),
      getMe: sl(),
      repost: sl(),
      getUserPosts: sl(),
      hidePost: sl(),
      muteUser: sl(),
    ),
  );

  // Fresh per open — this list's state has no reason to survive past the
  // sheet that opened it (see the cubit's own doc).
  sl.registerFactoryParam<ReactorsCubit, ({String targetType, String targetId}), ReactionType?>(
    (ids, type) => ReactorsCubit(targetType: ids.targetType, targetId: ids.targetId, type: type, getReactors: sl()),
  );
  sl.registerFactory(() => StoryCubit(sl(), sl()));
  sl.registerFactory(() => CreatePostCubit(sl()));
}

void _registerSearch() {
  sl.registerLazySingleton<SearchRemoteDataSource>(() => SearchRemoteDataSourceImpl(sl()));
  sl.registerLazySingleton<SearchRepository>(() => SearchRepositoryImpl(sl(), sl()));

  sl.registerLazySingleton(() => SearchUsersUseCase(sl()));

  // Factory: a search screen's query and results have no reason to outlive the
  // screen, and the cubit owns a debounce timer it cancels in `close()`.
  sl.registerFactory(() => SearchCubit(searchUsers: sl(), sendFriendRequest: sl()));
}

void _registerCommunities() {
  sl.registerLazySingleton<CommunitiesRemoteDataSource>(() => CommunitiesRemoteDataSourceImpl(sl()));
  sl.registerLazySingleton<CommunitiesRepository>(() => CommunitiesRepositoryImpl(sl(), sl()));

  sl.registerLazySingleton(() => GetCommunitiesUseCase(sl()));
  sl.registerLazySingleton(() => GetCommunityUseCase(sl()));
  sl.registerLazySingleton(() => JoinCommunityUseCase(sl()));
  sl.registerLazySingleton(() => LeaveCommunityUseCase(sl()));
  sl.registerLazySingleton(() => GetCommunityFeedUseCase(sl()));
  sl.registerLazySingleton(() => GetCommunityPostsUseCase(sl()));
  sl.registerLazySingleton(() => CreateCommunityPostUseCase(sl()));
  sl.registerLazySingleton(() => VoteCommunityPostUseCase(sl()));
  sl.registerLazySingleton(() => ReactToCommunityPostUseCase(sl()));
  sl.registerLazySingleton(() => GetCommunityCommentsUseCase(sl()));
  sl.registerLazySingleton(() => AddCommunityCommentUseCase(sl()));

  // All factories: unlike `FeedCubit`, none of these back a tab that has to
  // survive a switch — the whole feature is pushed on top of the shell, so a
  // singleton here would only keep stale lists alive between visits.
  sl.registerFactory(() => CommunitiesCubit(getCommunities: sl(), joinCommunity: sl(), leaveCommunity: sl()));
  sl.registerFactory(() => CommunityFeedCubit(getFeed: sl(), vote: sl(), react: sl()));
  sl.registerFactory(() => CreateCommunityPostCubit(sl()));

  // `String` param is the community's **slug** (not its uuid) — a fresh cubit
  // per community push, same convention as `PublicProfileCubit`.
  sl.registerFactoryParam<CommunityDetailCubit, String, void>(
    (slug, _) => CommunityDetailCubit(
      slug: slug,
      getCommunity: sl(),
      getPosts: sl(),
      joinCommunity: sl(),
      leaveCommunity: sl(),
      vote: sl(),
      react: sl(),
    ),
  );

  // Takes the whole `CommunityPostEntity`, not an id: the backend serves no
  // single community post, so the thread screen is opened with the post it
  // shows. See `CommunitiesRepository`'s class doc.
  sl.registerFactoryParam<CommunityPostCubit, CommunityPostEntity, void>(
    (post, _) => CommunityPostCubit(
      post: post,
      getComments: sl(),
      addComment: sl(),
      vote: sl(),
      react: sl(),
      editComment: sl(),
      deleteComment: sl(),
      getMe: sl(),
    ),
  );
}

void _registerShowcase() {
  sl.registerLazySingleton<ShowcaseRemoteDataSource>(() => ShowcaseRemoteDataSourceImpl(sl()));
  sl.registerLazySingleton<ShowcaseRepository>(() => ShowcaseRepositoryImpl(sl(), sl()));

  sl.registerLazySingleton(() => GetProjectsUseCase(sl()));
  sl.registerLazySingleton(() => GetProjectTechUseCase(sl()));
  sl.registerLazySingleton(() => GetProjectUseCase(sl()));
  sl.registerLazySingleton(() => RecordProjectViewUseCase(sl()));
  sl.registerLazySingleton(() => ToggleProjectLikeUseCase(sl()));
  sl.registerLazySingleton(() => PublishProjectUseCase(sl()));

  sl.registerFactory(() => ShowcaseCubit(getProjects: sl(), getTech: sl(), toggleLike: sl()));
  sl.registerFactory(() => PublishProjectCubit(sl()));

  // (projectId, seed) — the seed is the grid's own entity, passed so the detail
  // header paints before `GET /projects/{id}` answers. Null on a cold deep
  // link, which is why it is the nullable second param rather than required.
  sl.registerFactoryParam<ProjectDetailCubit, String, ProjectEntity?>(
    (projectId, seed) =>
        ProjectDetailCubit(projectId: projectId, seed: seed, getProject: sl(), recordView: sl(), toggleLike: sl()),
  );
}

void _registerSettings() {
  // Which build is installed is read off the device. Whether a newer one
  // exists is read from the release channel's manifest — still not from the
  // API, which has no version resource (`docs/BACKEND.md`, ADR-029).
  sl.registerLazySingleton<AppInfoLocalDataSource>(() => AppInfoLocalDataSourceImpl());
  sl.registerLazySingleton<AppInfoRepository>(() => AppInfoRepositoryImpl(sl()));

  // Its own bare Dio, deliberately not `ApiClient`'s: the manifest and the
  // APK are fetched off-host, and `AuthInterceptor` would attach the
  // session token to both.
  sl.registerLazySingleton<AppUpdateRemoteDataSource>(() => AppUpdateRemoteDataSourceImpl());
  sl.registerLazySingleton<ApkInstaller>(() => ApkInstallerImpl());
  sl.registerLazySingleton<AppUpdateRepository>(() => AppUpdateRepositoryImpl(sl(), sl(), sl(), sl()));

  sl.registerLazySingleton(() => GetAppBuildInfoUseCase(sl()));
  sl.registerLazySingleton(() => CheckForUpdateUseCase(sl()));
  sl.registerLazySingleton(() => DownloadUpdateUseCase(sl()));
  sl.registerLazySingleton(() => InstallUpdateUseCase(sl()));
  sl.registerLazySingleton(() => OpenInstallSettingsUseCase(sl()));

  // Factory: one read per visit. The build cannot change while the process
  // is alive, so there is nothing for a singleton to save.
  sl.registerFactory(() => AppVersionCubit(getBuildInfo: sl()));

  // Singleton, unlike the one above: a 60 MB download has to survive the
  // user leaving the App version screen, and a factory here would close the
  // cubit mid-transfer. Provided with `BlocProvider.value` for that reason.
  sl.registerLazySingleton(
    () => AppUpdateCubit(
      checkForUpdate: sl(),
      downloadUpdate: sl(),
      installUpdate: sl(),
      openInstallSettings: sl(),
    ),
  );
}
