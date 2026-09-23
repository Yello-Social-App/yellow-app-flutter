<!-- GENERATED FILE — do not edit by hand. Run: bash tool/codemap.sh -->

# Code map

Index of every meaningful file in `lib/`, so you can jump straight to the
right one instead of searching. **Read this before opening source files.**

- Generated from commit `4a80307`
- `lib/`: 260 Dart files · `test/`: 25 test files
- Regenerate: `bash tool/codemap.sh` · Staleness check: `bash tool/codemap.sh --check`

Layer rule (see [ARCHITECTURE.md](ARCHITECTURE.md)): `presentation` → `domain/usecases`
→ `domain/repositories` (interface) → `data/repositories` (impl) → `data/datasources`.
A Cubit never touches a repository or a data source directly.

---

## Entry points

- `lib/main.dart`
- `lib/bootstrap.dart`
- `lib/app.dart`

---

## Routes

Declared in `lib/core/router/app_router.dart`; names live in
`lib/core/router/route_names.dart`; the redirect guard is
`lib/core/router/route_guards.dart`.

| Path | Route name | Page widget |
|---|---|---|
| `/splash` | `splash` | `SplashPage` |
| `/login` | `login` | `LoginPage` |
| `/register` | `register` | `RegisterPage / MainShellPage` |
| `/feed` | `feed` | `FeedPage` |
| `/friends` | `friends` | `FriendsPage` |
| `/messages` | `messages` | `MessagesPage` |
| `/notifications` | `notifications` | `NotificationsPage` |
| `/profile` | `profile` | `ProfilePage` |
| `/communities` | `communities` | `NoTransitionPage / CommunitiesPage` |
| `/showcase` | `showcase` | `NoTransitionPage / ShowcasePage` |
| `/post/:postId` | `postDetail` | `PostDetailPage` |
| `/user/:userId` | `userProfile` | `PublicProfilePage` |
| `/chat/:conversationId` | `chat` | `ChatPage` |
| `/chat/:conversationId/info` | `groupInfo` | `GroupInfoPage` |
| `/story/:userIndex` | `storyViewer` | `StoryViewerPage` |
| `/story-compose` | `storyCompose` | `StoryComposePage` |
| `/create` | `createPost` | `CreatePostPage` |
| `/search` | `search` | `SearchPage` |
| `/shared-posts` | `sharedPosts` | `SharedPostsPage` |
| `/notification-preferences` | `notificationPreferences` | `NotificationPreferencesPage` |
| `/privacy-safety` | `privacySafety` | `PrivacySafetyPage` |
| `/feedback` | `sendFeedback` | `SendFeedbackPage` |
| `/photo` | `photoViewer` | `CustomTransitionPage / PhotoViewerPage` |
| `/communities/:slug/new` | `createCommunityPost` | `CommunityDetailPage / CreateCommunityPostPage` |
| `/communities/:slug` | `community` | `CommunityDetailPage` |
| `/community-post/:postId` | `communityPost` | `CommunityPostRouteFallback / CommunityPostPage` |
| `/showcase/new` | `publishProject` | `PublishProjectPage` |
| `/showcase/:projectId` | `project` | `ProjectDetailPage` |
| `ath` | `` | `CustomTransitionPage` |

---

## Dependency injection

All wiring is hand-written in `lib/core/di/injection.dart` (no build_runner).
`registerLazySingleton` vs `registerFactory` is a deliberate call per type —
the file's own comments explain each one; read them before changing a lifetime.

### Singletons (`registerLazySingleton`)

- `AcceptFriendRequestUseCase`
- `AcceptGroupInviteUseCase`
- `AddCommentUseCase`
- `AddCommunityCommentUseCase`
- `AddGroupMembersUseCase`
- `ApiClient`
- `AppRouter`
- `AuthLocalDataSource`
- `AuthRemoteDataSource`
- `AuthRepository`
- `BiometricAuthService`
- `BlockUserUseCase`
- `BookmarksLocalDataSource`
- `CancelFriendRequestUseCase`
- `ChangeMemberRoleUseCase`
- `ChatRemoteDataSource`
- `ChatRepository`
- `ChatSocket`
- `CommunitiesRemoteDataSource`
- `CommunitiesRepository`
- `Connectivity`
- `CreateCommunityPostUseCase`
- `CreatePostUseCase`
- `DeclineFriendRequestUseCase`
- `DeclineGroupInviteUseCase`
- `DeleteCommentUseCase`
- `DeleteMessageUseCase`
- `DeleteNotificationUseCase`
- `DeletePostUseCase`
- `EditCommentUseCase`
- `EditMessageUseCase`
- `FeedCubit`
- `FeedRemoteDataSource`
- `FeedRepository`
- `ForgotPasswordUseCase`
- `FriendsRemoteDataSource`
- `FriendsRepository`
- `GetBlockedUsersUseCase`
- `GetCommentsUseCase`
- `GetCommunitiesUseCase`
- `GetCommunityCommentsUseCase`
- `GetCommunityFeedUseCase`
- `GetCommunityPostsUseCase`
- `GetCommunityUseCase`
- `GetConversationUseCase`
- `GetConversationsUseCase`
- `GetFeedUseCase`
- `GetFriendRequestsUseCase`
- `GetFriendsUseCase`
- `GetInboxUseCase`
- `GetMeUseCase`
- `GetMessagesUseCase`
- `GetMutedUsersUseCase`
- `GetMyFeedbackUseCase`
- `GetMyReportsUseCase`
- `GetNotificationPreferencesUseCase`
- `GetPostDetailUseCase`
- `GetPostUseCase`
- `GetProjectTechUseCase`
- `GetProjectUseCase`
- `GetProjectsUseCase`
- `GetReactionSummaryUseCase`
- `GetReactorsUseCase`
- `GetSavedPostIdsUseCase`
- `GetShareLinkUseCase`
- `GetStoriesUseCase`
- `GetUnreadNotificationCountUseCase`
- `GetUserPostsUseCase`
- `GetUserUseCase`
- `HidePostUseCase`
- `InviteToGroupUseCase`
- `JoinCommunityUseCase`
- `JwtManager`
- `LeaveCommunityUseCase`
- `LeaveGroupUseCase`
- `LikePostUseCase`
- `LoginUseCase`
- `LogoutUseCase`
- `MarkAllNotificationsReadUseCase`
- `MarkNotificationReadUseCase`
- `MarkReadUseCase`
- `MarkStorySeenUseCase`
- `MessagesCubit`
- `MuteUserUseCase`
- `NetworkInfo`
- `NotificationRemoteDataSource`
- `NotificationRepository`
- `NotificationsCubit`
- `ProfileRemoteDataSource`
- `ProfileRepository`
- `PublishProjectUseCase`
- `PushNotificationService`
- `ReactToCommentUseCase`
- `ReactToCommunityPostUseCase`
- `ReactToMessageUseCase`
- `ReactToPostUseCase`
- `RecordProjectViewUseCase`
- `RefreshAttachmentUseCase`
- `RegisterDeviceUseCase`
- `RegisterUseCase`
- `RemoveGroupMemberUseCase`
- `RemoveGroupPhotoUseCase`
- `RenameGroupUseCase`
- `ReportPostUseCase`
- `RepostUseCase`
- `ResendOtpUseCase`
- `ResetPasswordUseCase`
- `RootJailbreakDetector`
- `RouteGuards`
- `SafetyRemoteDataSource`
- `SafetyRepository`
- `SearchRemoteDataSource`
- `SearchRepository`
- `SearchUsersUseCase`
- `SecureStorageService`
- `SendFriendRequestUseCase`
- `SendMessageUseCase`
- `SessionManager`
- `SetGroupPhotoUseCase`
- `ShowcaseRemoteDataSource`
- `ShowcaseRepository`
- `StartDirectConversationUseCase`
- `StartGroupConversationUseCase`
- `StoryLocalDataSource`
- `SubmitFeedbackUseCase`
- `ThemeCubit`
- `ToggleProjectLikeUseCase`
- `ToggleSaveUseCase`
- `TokenRefreshService`
- `UnblockUserUseCase`
- `UnfriendUseCase`
- `UnhidePostUseCase`
- `UnmuteUserUseCase`
- `UnregisterDeviceUseCase`
- `UpdateAvatarUseCase`
- `UpdateNotificationPreferencesUseCase`
- `UpdatePostUseCase`
- `UpdateProfileUseCase`
- `UploadAttachmentUseCase`
- `UserDirectory`
- `VerifyOtpUseCase`
- `VoteCommunityPostUseCase`

### Factories (`registerFactory`)

A new instance per injection point — screen-scoped state that should reset
on re-entry.

- `AuthCubit`
- `CommunitiesCubit`
- `CommunityFeedCubit`
- `CreateCommunityPostCubit`
- `CreatePostCubit`
- `FeedbackCubit`
- `FriendsCubit`
- `NotificationPreferencesCubit`
- `PrivacySafetyCubit`
- `ProfileCubit`
- `PublishProjectCubit`
- `SearchCubit`
- `SharedPostsCubit`
- `ShowcaseCubit`
- `StoryCubit`

---

## Features

### Auth — `lib/features/auth`

**Cubits + States**

- `lib/features/auth/presentation/bloc/auth_cubit.dart` — AuthState, AuthCubit

**Pages**

- `lib/features/auth/presentation/pages/login_page.dart` — LoginPage
- `lib/features/auth/presentation/pages/register_page.dart` — RegisterPage

**Widgets**

- `lib/features/auth/presentation/widgets/auth_form_field.dart` — AuthFormField
- `lib/features/auth/presentation/widgets/auth_hero.dart` — AuthHero
- `lib/features/auth/presentation/widgets/otp_code_field.dart` — OtpCodeField
- `lib/features/auth/presentation/widgets/toggle_switch.dart` — ToggleSwitch

**Usecases**

- `lib/features/auth/domain/usecases/login_usecase.dart` — LoginParams, LoginUseCase
- `lib/features/auth/domain/usecases/logout_usecase.dart` — LogoutUseCase
- `lib/features/auth/domain/usecases/password_reset_usecases.dart` — ForgotPasswordUseCase, ResetPasswordParams, ResetPasswordUseCase
- `lib/features/auth/domain/usecases/register_usecase.dart` — RegisterParams, RegisterUseCase
- `lib/features/auth/domain/usecases/verify_otp_usecase.dart` — VerifyOtpParams, VerifyOtpUseCase, ResendOtpUseCase

**Entities**

- `lib/features/auth/domain/entities/registration_result.dart` — RegistrationResult
- `lib/features/auth/domain/entities/user_entity.dart` — UserEntity

**Repository interfaces**

- `lib/features/auth/domain/repositories/auth_repository.dart`

**Repository implementations**

- `lib/features/auth/data/repositories/auth_repository_impl.dart` — AuthRepositoryImpl

**Models (JSON ⇄ entity)**

- `lib/features/auth/data/models/user_model.dart` — UserModel

**Data sources**

- `lib/features/auth/data/datasources/auth_local_datasource.dart` — AuthLocalDataSourceImpl
- `lib/features/auth/data/datasources/auth_remote_datasource.dart` — TokenPair, RegistrationResponse, VerifyOtpResult, AuthRemoteDataSourceImpl

### Chat — `lib/features/chat`

**Cubits + States**

- `lib/features/chat/presentation/bloc/chat_cubit.dart` — ChatState, ChatCubit
- `lib/features/chat/presentation/bloc/group_info_cubit.dart` — GroupInfoState, GroupInfoCubit
- `lib/features/chat/presentation/bloc/messages_cubit.dart` — MessagesState, MessagesCubit

**Pages**

- `lib/features/chat/presentation/pages/chat_page.dart` — ChatPage
- `lib/features/chat/presentation/pages/group_info_page.dart` — GroupInfoPage
- `lib/features/chat/presentation/pages/messages_page.dart` — MessagesPage

**Usecases**

- `lib/features/chat/domain/usecases/chat_usecases.dart` — CursorParams, GetConversationsUseCase, GetConversationUseCase, GetMessagesParams, GetMessagesUseCase, SendMessageParams, SendMessageUseCase, EditMessageParams, EditMessageUseCase, MessageRefParams, DeleteMessageUseCase, ReactToMessageParams, ReactToMessageUseCase, UploadAttachmentParams, UploadAttachmentUseCase, RefreshAttachmentUseCase, MarkReadParams, MarkReadUseCase, StartDirectConversationUseCase, StartGroupParams, StartGroupConversationUseCase, RenameGroupParams, RenameGroupUseCase, SetGroupPhotoParams, SetGroupPhotoUseCase, RemoveGroupPhotoUseCase, GroupMembersParams, AddGroupMembersUseCase, GroupMemberParams, RemoveGroupMemberUseCase, ChangeMemberRoleParams, ChangeMemberRoleUseCase, LeaveGroupUseCase, InviteToGroupUseCase, AcceptGroupInviteUseCase, DeclineGroupInviteUseCase

**Entities**

- `lib/features/chat/domain/entities/attachment_entity.dart` — AttachmentEntity
- `lib/features/chat/domain/entities/conversation_entity.dart` — LastMessageEntity, ConversationChange, ConversationEntity
- `lib/features/chat/domain/entities/group_invite_entity.dart` — GroupInviteCardEntity, GroupInviteEntity, GroupInviteResult
- `lib/features/chat/domain/entities/message_entity.dart` — ReplyPreviewEntity, ReactionEntity, MessageEntity
- `lib/features/chat/domain/entities/participant_entity.dart` — ParticipantEntity

**Repository interfaces**

- `lib/features/chat/domain/repositories/chat_repository.dart` — ConversationsPage, MessagesPage, TypingChanged, LiveDeliveryChanged, MessageArrived, MessageUpdated, MessageDeleted, MessageReactionsChanged, MessagesRead, ConversationUpdated, ConversationRemoved, GroupInviteUpdated

**Repository implementations**

- `lib/features/chat/data/repositories/chat_repository_impl.dart` — ChatRepositoryImpl

**Models (JSON ⇄ entity)**

- `lib/features/chat/data/models/conversation_model.dart` — ConversationPage
- `lib/features/chat/data/models/group_invite_model.dart`
- `lib/features/chat/data/models/message_model.dart` — MessagePage

**Data sources**

- `lib/features/chat/data/datasources/chat_frame_decoder.dart`
- `lib/features/chat/data/datasources/chat_local_datasource.dart`
- `lib/features/chat/data/datasources/chat_remote_datasource.dart` — ChatRemoteDataSourceImpl
- `lib/features/chat/data/datasources/chat_socket.dart` — ChatSocket
- `lib/features/chat/data/datasources/user_directory.dart` — UserDirectory

### Communities — `lib/features/communities`

**Cubits + States**

- `lib/features/communities/presentation/bloc/communities_cubit.dart` — CommunitiesState, CommunitiesCubit
- `lib/features/communities/presentation/bloc/community_detail_cubit.dart` — CommunityDetailState, CommunityDetailCubit
- `lib/features/communities/presentation/bloc/community_feed_cubit.dart` — CommunityFeedState, CommunityFeedCubit
- `lib/features/communities/presentation/bloc/community_post_cubit.dart` — CommunityPostState, CommunityPostCubit
- `lib/features/communities/presentation/bloc/create_community_post_cubit.dart` — CreateCommunityPostState, CreateCommunityPostCubit

**Pages**

- `lib/features/communities/presentation/pages/communities_page.dart` — CommunitiesPage
- `lib/features/communities/presentation/pages/community_detail_page.dart` — CommunityDetailPage
- `lib/features/communities/presentation/pages/community_post_page.dart` — CommunityPostPage, CommunityPostRouteFallback
- `lib/features/communities/presentation/pages/create_community_post_page.dart` — CreateCommunityPostPage

**Widgets**

- `lib/features/communities/presentation/widgets/community_post_card.dart` — CommunityPostCard
- `lib/features/communities/presentation/widgets/shimmer_community_card.dart` — ShimmerCommunityCard
- `lib/features/communities/presentation/widgets/shimmer_community_post_card.dart` — ShimmerCommunityPostCard
- `lib/features/communities/presentation/widgets/vote_arrow_icon.dart` — VoteArrowIcon

**Usecases**

- `lib/features/communities/domain/usecases/communities_usecases.dart` — GetCommunitiesParams, GetCommunitiesUseCase, CommunitySlugParams, GetCommunityUseCase, JoinCommunityUseCase, LeaveCommunityUseCase, CommunityFeedParams, GetCommunityFeedUseCase, CommunityPostsParams, GetCommunityPostsUseCase, CreateCommunityPostParams, CreateCommunityPostUseCase, VoteCommunityPostParams, VoteCommunityPostUseCase, ReactToCommunityPostParams, ReactToCommunityPostUseCase, CommunityCommentsParams, GetCommunityCommentsUseCase, AddCommunityCommentParams, AddCommunityCommentUseCase

**Entities**

- `lib/features/communities/domain/entities/community_entity.dart` — CommunityEntity, CommunitySummaryEntity
- `lib/features/communities/domain/entities/community_post_entity.dart` — CommunityPostEntity, CommunityPostVoteResult

**Repository interfaces**

- `lib/features/communities/domain/repositories/communities_repository.dart` — CommunitiesPage, CommunityPostsPage, CommunityCommentsPage

**Repository implementations**

- `lib/features/communities/data/repositories/communities_repository_impl.dart` — CommunitiesRepositoryImpl

**Models (JSON ⇄ entity)**

- `lib/features/communities/data/models/community_model.dart` — CommunityModel, CommunitySummaryModel
- `lib/features/communities/data/models/community_post_model.dart` — CommunityPostModel, CommunityPostVoteResultModel

**Data sources**

- `lib/features/communities/data/datasources/communities_remote_datasource.dart` — CommunitiesRemoteDataSourceImpl

### Feed — `lib/features/feed`

**Cubits + States**

- `lib/features/feed/presentation/bloc/create_post_cubit.dart` — CreatePostState, CreatePostCubit
- `lib/features/feed/presentation/bloc/feed_cubit.dart` — FeedState, FeedCubit
- `lib/features/feed/presentation/bloc/post_detail_cubit.dart` — PostDetailState, PostDetailCubit
- `lib/features/feed/presentation/bloc/reactors_cubit.dart` — ReactorsState, ReactorsCubit
- `lib/features/feed/presentation/bloc/story_cubit.dart` — StoryState, StoryCubit

**Pages**

- `lib/features/feed/presentation/pages/create_post_page.dart` — CreatePostPage
- `lib/features/feed/presentation/pages/feed_page.dart` — FeedPage
- `lib/features/feed/presentation/pages/post_detail_page.dart` — PostDetailPage
- `lib/features/feed/presentation/pages/story_compose_page.dart` — StoryComposePage
- `lib/features/feed/presentation/pages/story_viewer_page.dart` — StoryViewerPage

**Widgets**

- `lib/features/feed/presentation/widgets/create_post_prompt.dart` — CreatePostPrompt
- `lib/features/feed/presentation/widgets/post_card.dart` — PostCard, RepostedPostPreview
- `lib/features/feed/presentation/widgets/post_image_carousel.dart` — PostImageCarousel
- `lib/features/feed/presentation/widgets/post_options_sheet.dart` — confirmDeletePost(), confirmMuteAuthor(), showEditPostSheet(), showPostOptionsSheet()
- `lib/features/feed/presentation/widgets/reaction_breakdown_sheet.dart` — showReactionBreakdownSheet()
- `lib/features/feed/presentation/widgets/reaction_picker_sheet.dart` — showReactionPicker()
- `lib/features/feed/presentation/widgets/reactors_sheet.dart` — showReactorsSheet()
- `lib/features/feed/presentation/widgets/stories_rail.dart` — StoriesRail

**Usecases**

- `lib/features/feed/domain/usecases/add_comment_usecase.dart` — AddCommentParams, AddCommentUseCase
- `lib/features/feed/domain/usecases/create_post_usecase.dart` — CreatePostParams, CreatePostUseCase
- `lib/features/feed/domain/usecases/delete_comment_usecase.dart` — DeleteCommentUseCase
- `lib/features/feed/domain/usecases/delete_post_usecase.dart` — DeletePostUseCase
- `lib/features/feed/domain/usecases/edit_comment_usecase.dart` — EditCommentParams, EditCommentUseCase
- `lib/features/feed/domain/usecases/get_comments_usecase.dart` — GetCommentsParams, GetCommentsUseCase
- `lib/features/feed/domain/usecases/get_feed_usecase.dart` — GetFeedParams, GetFeedUseCase
- `lib/features/feed/domain/usecases/get_post_detail_usecase.dart` — PostDetail, GetPostDetailUseCase
- `lib/features/feed/domain/usecases/get_post_usecase.dart` — GetPostUseCase
- `lib/features/feed/domain/usecases/get_saved_post_ids_usecase.dart` — GetSavedPostIdsUseCase
- `lib/features/feed/domain/usecases/get_share_link_usecase.dart` — GetShareLinkUseCase
- `lib/features/feed/domain/usecases/get_stories_usecase.dart` — GetStoriesUseCase
- `lib/features/feed/domain/usecases/like_post_usecase.dart` — PostIdParams, LikePostUseCase, RepostParams, RepostUseCase, ToggleSaveUseCase
- `lib/features/feed/domain/usecases/mark_story_seen_usecase.dart` — MarkStorySeenUseCase
- `lib/features/feed/domain/usecases/react_usecases.dart` — ReactToPostParams, ReactToPostUseCase, ReactToCommentParams, ReactToCommentUseCase, GetReactionSummaryParams, GetReactionSummaryUseCase, GetReactorsParams, GetReactorsUseCase
- `lib/features/feed/domain/usecases/update_post_usecase.dart` — UpdatePostParams, UpdatePostUseCase

**Entities**

- `lib/features/feed/domain/entities/comment_entity.dart` — CommentEntity
- `lib/features/feed/domain/entities/post_entity.dart` — PostEntity
- `lib/features/feed/domain/entities/reaction_breakdown.dart` — ReactionBreakdown
- `lib/features/feed/domain/entities/reactor_entity.dart` — ReactorEntity
- `lib/features/feed/domain/entities/story_entity.dart` — StorySegmentEntity, StoryEntity

**Repository interfaces**

- `lib/features/feed/domain/repositories/feed_repository.dart` — FeedPage, CommentsPage, ReactorsPage

**Repository implementations**

- `lib/features/feed/data/repositories/feed_repository_impl.dart` — FeedRepositoryImpl

**Models (JSON ⇄ entity)**

- `lib/features/feed/data/models/comment_model.dart` — CommentModel
- `lib/features/feed/data/models/post_model.dart` — PostModel
- `lib/features/feed/data/models/reactor_model.dart` — ReactorModel
- `lib/features/feed/data/models/story_model.dart` — StorySegmentModel, StoryModel

**Data sources**

- `lib/features/feed/data/datasources/bookmarks_local_datasource.dart` — BookmarksLocalDataSourceImpl
- `lib/features/feed/data/datasources/feed_remote_datasource.dart` — ReactionSummary, FeedRemoteDataSourceImpl
- `lib/features/feed/data/datasources/story_local_datasource.dart` — StoryLocalDataSourceImpl

### Friends — `lib/features/friends`

**Cubits + States**

- `lib/features/friends/presentation/bloc/friends_cubit.dart` — FriendsState, FriendsCubit

**Pages**

- `lib/features/friends/presentation/pages/friends_page.dart` — FriendsPage

**Usecases**

- `lib/features/friends/domain/usecases/friends_usecases.dart` — PageParams, GetFriendsUseCase, GetFriendRequestsUseCase, GetBlockedUsersUseCase, UserIdParams, SendFriendRequestUseCase, CancelFriendRequestUseCase, RequestIdParams, AcceptFriendRequestUseCase, DeclineFriendRequestUseCase, UnfriendUseCase, BlockUserUseCase, UnblockUserUseCase

**Entities**

- `lib/features/friends/domain/entities/friendship_entity.dart` — FriendshipEntity

**Repository interfaces**

- `lib/features/friends/domain/repositories/friends_repository.dart` — FriendsPage

**Repository implementations**

- `lib/features/friends/data/repositories/friends_repository_impl.dart` — FriendsRepositoryImpl

**Models (JSON ⇄ entity)**

- `lib/features/friends/data/models/friendship_model.dart` — FriendshipModel

**Data sources**

- `lib/features/friends/data/datasources/friends_remote_datasource.dart` — FriendsRemoteDataSourceImpl

### Notification — `lib/features/notification`

**Cubits + States**

- `lib/features/notification/presentation/bloc/notification_preferences_cubit.dart` — NotificationPreferencesState, NotificationPreferencesCubit
- `lib/features/notification/presentation/bloc/notifications_cubit.dart` — NotificationsState, NotificationsCubit

**Pages**

- `lib/features/notification/presentation/pages/notification_preferences_page.dart` — NotificationPreferencesPage
- `lib/features/notification/presentation/pages/notifications_page.dart` — NotificationsPage

**Usecases**

- `lib/features/notification/domain/usecases/notification_usecases.dart` — GetInboxParams, GetInboxUseCase, GetUnreadNotificationCountUseCase, MarkNotificationReadUseCase, MarkAllNotificationsReadUseCase, DeleteNotificationUseCase, RegisterDeviceParams, RegisterDeviceUseCase, UnregisterDeviceUseCase, GetNotificationPreferencesUseCase, UpdateNotificationPreferencesParams, UpdateNotificationPreferencesUseCase

**Entities**

- `lib/features/notification/domain/entities/device_entity.dart` — DeviceEntity
- `lib/features/notification/domain/entities/notification_entity.dart` — NotificationEntity, NotificationsPage
- `lib/features/notification/domain/entities/notification_preferences_entity.dart` — NotificationPreferencesEntity

**Repository interfaces**

- `lib/features/notification/domain/repositories/notification_repository.dart`

**Repository implementations**

- `lib/features/notification/data/repositories/notification_repository_impl.dart` — NotificationRepositoryImpl

**Models (JSON ⇄ entity)**

- `lib/features/notification/data/models/device_model.dart` — DeviceModel
- `lib/features/notification/data/models/notification_model.dart` — NotificationModel
- `lib/features/notification/data/models/notification_preferences_model.dart` — NotificationPreferencesModel

**Data sources**

- `lib/features/notification/data/datasources/notification_remote_datasource.dart` — NotificationInboxPageResult, NotificationRemoteDataSourceImpl

### Profile — `lib/features/profile`

**Cubits + States**

- `lib/features/profile/presentation/bloc/profile_cubit.dart` — ProfileState, ProfileCubit
- `lib/features/profile/presentation/bloc/public_profile_cubit.dart` — PublicProfileState, PublicProfileCubit
- `lib/features/profile/presentation/bloc/shared_posts_cubit.dart` — SharedPostsState, SharedPostsCubit

**Pages**

- `lib/features/profile/presentation/pages/profile_page.dart` — ProfilePage
- `lib/features/profile/presentation/pages/public_profile_page.dart` — PublicProfilePage
- `lib/features/profile/presentation/pages/shared_posts_page.dart` — SharedPostsPage

**Widgets**

- `lib/features/profile/presentation/widgets/profile_details_card.dart` — ProfileDetailsCard
- `lib/features/profile/presentation/widgets/profile_header.dart` — ProfileHeader
- `lib/features/profile/presentation/widgets/shimmer_own_profile_view.dart` — ShimmerOwnProfileView
- `lib/features/profile/presentation/widgets/shimmer_profile_view.dart` — ShimmerProfileView

**Usecases**

- `lib/features/profile/domain/usecases/profile_usecases.dart` — GetMeUseCase, UpdateProfileParams, UpdateProfileUseCase, UpdateAvatarUseCase, GetUserUseCase, GetUserPostsParams, GetUserPostsUseCase

**Entities**

- `lib/features/profile/domain/entities/public_user_entity.dart` — PublicUserEntity

**Repository interfaces**

- `lib/features/profile/domain/repositories/profile_repository.dart` — UserPostsPage

**Repository implementations**

- `lib/features/profile/data/repositories/profile_repository_impl.dart` — ProfileRepositoryImpl

**Models (JSON ⇄ entity)**

- `lib/features/profile/data/models/public_user_model.dart` — PublicUserModel

**Data sources**

- `lib/features/profile/data/datasources/profile_remote_datasource.dart` — ProfileRemoteDataSourceImpl

### Safety — `lib/features/safety`

**Cubits + States**

- `lib/features/safety/presentation/bloc/feedback_cubit.dart` — FeedbackState, FeedbackCubit
- `lib/features/safety/presentation/bloc/privacy_safety_cubit.dart` — PrivacySafetyState, PrivacySafetyCubit
- `lib/features/safety/presentation/bloc/report_post_cubit.dart` — ReportPostState, ReportPostCubit

**Pages**

- `lib/features/safety/presentation/pages/privacy_safety_page.dart` — PrivacySafetyPage
- `lib/features/safety/presentation/pages/send_feedback_page.dart` — SendFeedbackPage

**Widgets**

- `lib/features/safety/presentation/widgets/report_post_sheet.dart` — showReportPostSheet()

**Usecases**

- `lib/features/safety/domain/usecases/safety_usecases.dart` — SafetyPageParams, SubmitFeedbackParams, SubmitFeedbackUseCase, GetMyFeedbackUseCase, ReportPostParams, ReportPostUseCase, GetMyReportsUseCase, MuteParams, MuteUserUseCase, UnmuteUserUseCase, GetMutedUsersUseCase, HidePostParams, HidePostUseCase, UnhidePostUseCase

**Entities**

- `lib/features/safety/domain/entities/feedback_entity.dart` — FeedbackEntity
- `lib/features/safety/domain/entities/muted_user_entity.dart` — MutedUserEntity
- `lib/features/safety/domain/entities/post_report_entity.dart` — ReportedPostSnapshot, PostReportEntity

**Repository interfaces**

- `lib/features/safety/domain/repositories/safety_repository.dart` — FeedbackPage, ReportsPage, MutedUsersPage

**Repository implementations**

- `lib/features/safety/data/repositories/safety_repository_impl.dart` — SafetyRepositoryImpl

**Models (JSON ⇄ entity)**

- `lib/features/safety/data/models/feedback_model.dart` — FeedbackModel
- `lib/features/safety/data/models/muted_user_model.dart` — MutedUserModel
- `lib/features/safety/data/models/post_report_model.dart` — PostReportModel

**Data sources**

- `lib/features/safety/data/datasources/safety_remote_datasource.dart` — SafetyRemoteDataSourceImpl

### Search — `lib/features/search`

**Cubits + States**

- `lib/features/search/presentation/bloc/search_cubit.dart` — SearchState, SearchCubit

**Pages**

- `lib/features/search/presentation/pages/search_page.dart` — SearchPage

**Widgets**

- `lib/features/search/presentation/widgets/shimmer_search_result_row.dart` — ShimmerSearchResultRow

**Usecases**

- `lib/features/search/domain/usecases/search_users_usecase.dart` — SearchUsersParams, SearchUsersUseCase

**Entities**

- `lib/features/search/domain/entities/user_search_result_entity.dart` — UserSearchResultEntity

**Repository interfaces**

- `lib/features/search/domain/repositories/search_repository.dart` — UserSearchPage

**Repository implementations**

- `lib/features/search/data/repositories/search_repository_impl.dart` — SearchRepositoryImpl

**Models (JSON ⇄ entity)**

- `lib/features/search/data/models/user_search_result_model.dart` — UserSearchResultModel

**Data sources**

- `lib/features/search/data/datasources/search_remote_datasource.dart` — SearchRemoteDataSourceImpl

### Shell — `lib/features/shell`

**Pages**

- `lib/features/shell/presentation/pages/main_shell_page.dart` — MainShellPage
- `lib/features/shell/presentation/pages/splash_page.dart` — SplashPage

**Widgets**

- `lib/features/shell/presentation/widgets/bottom_nav_bar.dart` — BottomNavBar

### Showcase — `lib/features/showcase`

**Cubits + States**

- `lib/features/showcase/presentation/bloc/project_detail_cubit.dart` — ProjectDetailState, ProjectDetailCubit
- `lib/features/showcase/presentation/bloc/publish_project_cubit.dart` — PublishProjectState, PublishProjectCubit
- `lib/features/showcase/presentation/bloc/showcase_cubit.dart` — ShowcaseState, ShowcaseCubit

**Pages**

- `lib/features/showcase/presentation/pages/project_detail_page.dart` — ProjectDetailPage
- `lib/features/showcase/presentation/pages/publish_project_page.dart` — PublishProjectPage
- `lib/features/showcase/presentation/pages/showcase_page.dart` — ShowcasePage

**Widgets**

- `lib/features/showcase/presentation/widgets/project_card.dart` — ProjectCard
- `lib/features/showcase/presentation/widgets/publish_nudge_card.dart` — PublishNudgeCard
- `lib/features/showcase/presentation/widgets/shimmer_project_card.dart` — ShimmerProjectCard
- `lib/features/showcase/presentation/widgets/tech_chip_row.dart` — TechChipRow
- `lib/features/showcase/presentation/widgets/tech_filter_sheet.dart` — showTechFilterSheet()

**Usecases**

- `lib/features/showcase/domain/usecases/showcase_usecases.dart` — GetProjectsParams, GetProjectsUseCase, GetProjectTechParams, GetProjectTechUseCase, GetProjectUseCase, RecordProjectViewUseCase, ToggleProjectLikeUseCase, PublishProjectParams, PublishProjectUseCase

**Entities**

- `lib/features/showcase/domain/entities/project_entity.dart` — ProjectEntity, TechCountEntity, ProjectLikeResult

**Repository interfaces**

- `lib/features/showcase/domain/repositories/showcase_repository.dart` — ProjectsPage

**Repository implementations**

- `lib/features/showcase/data/repositories/showcase_repository_impl.dart` — ShowcaseRepositoryImpl

**Models (JSON ⇄ entity)**

- `lib/features/showcase/data/models/project_model.dart` — ProjectModel, TechCountModel, ProjectLikeResultModel

**Data sources**

- `lib/features/showcase/data/datasources/showcase_remote_datasource.dart` — ShowcaseRemoteDataSourceImpl

---

## Core (cross-cutting)


**`lib/core/config`**

- `lib/core/config/app_config.dart`

**`lib/core/constants`**

- `lib/core/constants/api_constants.dart`
- `lib/core/constants/app_constants.dart`
- `lib/core/constants/asset_constants.dart`

**`lib/core/di`**

- `lib/core/di/injection.dart` — configureDependencies()

**`lib/core/error`**

- `lib/core/error/error_handler.dart`
- `lib/core/error/exceptions.dart` — AppException, ServerException, NetworkException, TimeoutException, CacheException, UnauthorizedException
- `lib/core/error/failures.dart` — ServerFailure, NetworkFailure, TimeoutFailure, CacheFailure, AuthFailure, ValidationFailure, SecurityFailure, UnknownFailure

**`lib/core/network`**

- `lib/core/network/api_client.dart` — ApiClient
- `lib/core/network/api_envelope.dart` — PageEnvelope, CursorEnvelope
- `lib/core/network/api_result.dart`
- `lib/core/network/api_versioning/api_version.dart`
- `lib/core/network/api_versioning/endpoint_resolver.dart` — EndpointResolver
- `lib/core/network/api_versioning/versioned_endpoints.dart`
- `lib/core/network/interceptors/auth_interceptor.dart` — AuthInterceptor
- `lib/core/network/interceptors/error_interceptor.dart` — AppErrorInterceptor
- `lib/core/network/interceptors/logging_interceptor.dart` — LoggingInterceptor
- `lib/core/network/interceptors/retry_interceptor.dart` — RetryInterceptor
- `lib/core/network/network_info.dart` — NetworkInfoImpl
- `lib/core/network/token_refresh_service.dart` — TokenRefreshServiceImpl

**`lib/core/notifications`**

- `lib/core/notifications/push_notification_service.dart` — ConversationDestination, PostDestination, ProfileDestination, ReportsDestination, PushNotificationServiceImpl, cancelChatNotification(), chatNotificationTag(), firebaseMessagingBackgroundHandler()

**`lib/core/router`**

- `lib/core/router/app_router.dart` — AppRouter
- `lib/core/router/go_router_refresh_stream.dart` — GoRouterRefreshStream
- `lib/core/router/route_guards.dart` — RouteGuards
- `lib/core/router/route_names.dart`

**`lib/core/security`**

- `lib/core/security/biometric_auth_service.dart` — BiometricAuthServiceImpl
- `lib/core/security/certificate_pinning.dart`
- `lib/core/security/input_sanitizer.dart`
- `lib/core/security/jwt_manager.dart` — JwtManagerImpl
- `lib/core/security/root_jailbreak_detector.dart` — DeviceIntegrityReport, RootJailbreakDetectorImpl
- `lib/core/security/secure_storage_service.dart` — SecureStorageServiceImpl
- `lib/core/security/session_manager.dart` — SessionManagerImpl

**`lib/core/theme`**

- `lib/core/theme/app_colors.dart` — AppColors
- `lib/core/theme/app_text_styles.dart`
- `lib/core/theme/app_theme.dart`
- `lib/core/theme/theme_cubit.dart` — ThemeCubit

**`lib/core/usecase`**

- `lib/core/usecase/usecase.dart` — NoParams

**`lib/core/utils`**

- `lib/core/utils/formatters.dart`
- `lib/core/utils/logger.dart`
- `lib/core/utils/presigned_url.dart` — presignedObjectKey()
- `lib/core/utils/responsive.dart`
- `lib/core/utils/validators.dart`

---

## Shared

**`lib/shared/extensions`**

- `lib/shared/extensions/context_extension.dart`
- `lib/shared/extensions/string_extension.dart`

**`lib/shared/models`**

- `lib/shared/models/paginated_response.dart` — PaginatedResponse

**`lib/shared/widgets`**

- `lib/shared/widgets/app_avatar.dart` — AppAvatar, avatarSeedForId()
- `lib/shared/widgets/app_button.dart` — AppButton
- `lib/shared/widgets/app_icon_button.dart` — AppIconButton
- `lib/shared/widgets/app_status_snackbar.dart`
- `lib/shared/widgets/app_warning_dialog.dart` — AppWarningDialog
- `lib/shared/widgets/date_label.dart` — DateLabel
- `lib/shared/widgets/error_view.dart` — ErrorView, EmptyStateCard
- `lib/shared/widgets/explore_title_menu.dart` — ExploreTitleMenu
- `lib/shared/widgets/filter_chip_pill.dart` — FilterChipPill
- `lib/shared/widgets/filter_dropdown_pill.dart` — FilterDropdownPill
- `lib/shared/widgets/image_placeholder.dart` — ImagePlaceholder
- `lib/shared/widgets/paged_list_view.dart` — PagedListView
- `lib/shared/widgets/photo_viewer_page.dart` — PhotoViewerArgs, PhotoViewerPage, openPhotoViewer()
- `lib/shared/widgets/responsive_content.dart` — ResponsiveContent
- `lib/shared/widgets/segmented_tabs.dart` — SegmentedTabs
- `lib/shared/widgets/shimmer_loading.dart` — ShimmerBox, ShimmerListCard, ShimmerPostCard
- `lib/shared/widgets/yello_wordmark.dart` — YelloWordmark

---

## Tests

- `test/core/network/error_handler_test.dart`
- `test/core/notifications/push_destination_test.dart`
- `test/core/security/input_sanitizer_test.dart`
- `test/core/security/jwt_manager_test.dart`
- `test/core/security/session_manager_test.dart`
- `test/core/utils/presigned_url_test.dart`
- `test/features/auth/domain/login_usecase_test.dart`
- `test/features/chat/chat_cubit_actions_test.dart`
- `test/features/chat/chat_frame_decoder_test.dart`
- `test/features/chat/chat_socket_test.dart`
- `test/features/chat/loading_test.dart`
- `test/features/chat/message_mapper_test.dart`
- `test/features/feed/feed_cubit_test.dart`
- `test/features/feed/post_detail_cubit_test.dart`
- `test/features/feed/story_compose_page_test.dart`
- `test/features/profile/profile_cubit_test.dart`
- `test/features/profile/profile_details_card_test.dart`
- `test/features/profile/profile_header_test.dart`
- `test/features/profile/shared_posts_cubit_test.dart`
- `test/features/safety/safety_cubits_test.dart`
- `test/features/shell/bottom_nav_bar_test.dart`
- `test/features/showcase/showcase_widgets_test.dart`
- `test/helpers/mock_data.dart`
- `test/shared/widgets/date_label_test.dart`
- `test/shared/widgets/photo_viewer_test.dart`
- `test/shared/widgets/shimmer_skeletons_test.dart`

