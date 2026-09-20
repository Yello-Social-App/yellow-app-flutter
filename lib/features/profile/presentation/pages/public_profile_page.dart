import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/extensions/string_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/app_status_snackbar.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/app_warning_dialog.dart';
import '../../../../shared/widgets/image_placeholder.dart';
import '../../../chat/domain/usecases/chat_usecases.dart';
import '../../../feed/presentation/widgets/post_card.dart';
import '../bloc/public_profile_cubit.dart';

/// Read-only view of someone else's profile (`GET /users/{id}` +
/// `GET /users/{id}/posts`), pushed by tapping an avatar/username anywhere
/// in the app. Safe to push with the viewer's own [userId] too — the cubit
/// resolves that case as [FriendStatus.self] and this page shows a plain
/// "this is you" affordance instead of a friend-action button, rather than
/// every tap site having to know who "you" are first.
class PublicProfilePage extends StatelessWidget {
  const PublicProfilePage({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PublicProfileCubit>(param1: userId)..load(),
      child: const _PublicProfileView(),
    );
  }
}

class _PublicProfileView extends StatelessWidget {
  const _PublicProfileView();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cubit = context.read<PublicProfileCubit>();

    return Scaffold(
      backgroundColor: colors.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: BlocBuilder<PublicProfileCubit, PublicProfileState>(
              builder: (context, state) => _Body(state: state, cubit: cubit),
            ),
          ),
          Positioned(
            top: 12,
            left: 14,
            child: SafeArea(
              bottom: false,
              child: AppIconButton(
                icon: const Icon(Icons.arrow_back),
                size: 38,
                onPressed: () => Navigator.of(context).maybePop(),
                backgroundColor: Colors.black.withValues(alpha: 0.35),
                borderColor: Colors.white.withValues(alpha: 0.5),
                iconColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({required this.state, required this.cubit});
  final PublicProfileState state;
  final PublicProfileCubit cubit;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  bool _showShared = false;
  PublicProfileState get state => widget.state;
  PublicProfileCubit get cubit => widget.cubit;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    if (state.status == PublicProfileStatus.initial ||
        (state.status == PublicProfileStatus.loading && state.user == null)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == PublicProfileStatus.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ErrorView(
            message: state.errorMessage ?? 'Could not load this profile.',
            onRetry: cubit.load,
          ),
        ),
      );
    }

    if (state.blockedByMe) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('You blocked this user.'),
            TextButton(
              onPressed: state.friendActionBusy
                  ? null
                  : () async {
                      final ok = await cubit.setBlocked(false);
                      if (ok) {
                        await cubit.load();
                      } else if (context.mounted) {
                        AppStatusSnackbar.showError(
                          context,
                          message:
                              cubit.state.errorMessage ??
                              'Could not unblock user.',
                        );
                      }
                    },
              child: const Text('Unblock'),
            ),
          ],
        ),
      );
    }
    final user = state.user!;
    final sharedPosts = state.posts.where((post) => post.isRepost).toList();
    final visiblePosts = _showShared
        ? sharedPosts
        : state.posts.where((post) => !post.isRepost).toList();
    final coverShadow = Theme.of(context).brightness == Brightness.dark
        ? Colors.black
        : Colors.white;
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 112),
      children: [
        SizedBox(
          height: 210,
          child: Stack(
            children: [
              Positioned.fill(
                child: user.coverUrl == null
                    ? const ImagePlaceholder()
                    : Image.network(
                        user.coverUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const ImagePlaceholder(),
                      ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.45),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 90,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          colors.bg,
                          coverShadow.withValues(alpha: 0.45),
                          coverShadow.withValues(alpha: 0),
                        ],
                        stops: const [0, 0.35, 1],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -20),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            decoration: BoxDecoration(
              color: colors.surf,
              border: Border.all(color: colors.line, width: 1.5),
              borderRadius: BorderRadius.circular(AppRadii.huge),
            ),
            child: Column(
              children: [
                Transform.translate(
                  offset: const Offset(0, -48),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.surf, width: 6),
                    ),
                    child: AppAvatar(
                      initials: (user.fullName ?? user.username).initials,
                      seed: avatarSeedForId(user.id),
                      imageUrl: user.avatarUrl,
                      size: 96,
                      borderWidth: 3,
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -34),
                  child: Column(
                    children: [
                      Text(
                        user.fullName ?? user.username,
                        style: AppTextStyles.displayLg.copyWith(
                          color: colors.ink,
                        ),
                      ),
                      const SizedBox(height: 11),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: colors.line),
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: Text(
                          user.username.withAtSign.toUpperCase(),
                          style: AppTextStyles.metaMono.copyWith(
                            color: colors.ink2,
                          ),
                        ),
                      ),
                      if ((user.bio ?? '').isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          user.bio!,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodySm.copyWith(
                            color: colors.ink2,
                            fontSize: 14,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        // Match the own-profile AppButtons: a 12px label
                        // with 13px padding above and below (38px normally).
                        child: SizedBox(
                          height:
                              MediaQuery.textScalerOf(
                                context,
                              ).scale(AppTextStyles.button.fontSize!) +
                              26,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _FriendAction(state: state, cubit: cubit),
                              if (state.friendStatus != FriendStatus.self) ...[
                                const SizedBox(width: 8),
                                _MessageAction(
                                  key: ValueKey(user.id),
                                  userId: user.id,
                                ),
                                const SizedBox(width: 8),
                                AppButton(
                                  label: 'Block user',
                                  variant: AppButtonVariant.outline,
                                  onPressed: state.friendActionBusy
                                      ? null
                                      : () async {
                                          final confirmed =
                                              await AppWarningDialog.show(
                                                context,
                                                title: 'Block user?',
                                                message:
                                                    'You will no longer see each other’s profile or posts.',
                                                confirmLabel: 'Block',
                                                cancelLabel: 'Cancel',
                                                icon: Icons.block,
                                              );
                                          if (!confirmed || !context.mounted) {
                                            return;
                                          }
                                          final ok = await cubit.setBlocked(
                                            true,
                                          );
                                          if (!ok && context.mounted) {
                                            AppStatusSnackbar.showError(
                                              context,
                                              message:
                                                  cubit.state.errorMessage ??
                                                  'Could not block user.',
                                            );
                                          }
                                        },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
          child: Column(
            children: [
              Row(
                children: [
                  _StatTile(
                    value: '${user.friendsCount}',
                    label: 'Connections',
                  ),
                  const SizedBox(width: 10),
                  _StatTile(value: '${sharedPosts.length}', label: 'Shared'),
                  const SizedBox(width: 10),
                  _StatTile(value: '${user.createdAt.year}', label: 'Joined'),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: colors.surf,
                  border: Border.all(color: colors.line, width: 1.5),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Row(
                  children: [
                    for (final tab in [
                      (false, 'Post ${user.postsCount}'),
                      (true, 'Shared ${sharedPosts.length}'),
                    ])
                      Expanded(
                        child: Material(
                          color: _showShared == tab.$1
                              ? colors.yel
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                            onTap: () => setState(() => _showShared = tab.$1),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              child: Center(
                                child: Text(
                                  tab.$2.toUpperCase(),
                                  style: AppTextStyles.navLabel.copyWith(
                                    color: _showShared == tab.$1
                                        ? colors.onYel
                                        : colors.ink2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (visiblePosts.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.line, width: 1.5),
                    borderRadius: BorderRadius.circular(AppRadii.xl),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _showShared
                            ? 'NOTHING SHARED YET'
                            : 'NOTHING POSTED YET',
                        style: AppTextStyles.eyebrow.copyWith(
                          color: colors.ink2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _showShared
                            ? "${user.username}'s shared posts will show up here."
                            : "${user.username}'s posts will show up here.",
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySm.copyWith(
                          color: colors.ink2,
                        ),
                      ),
                    ],
                  ),
                )
              else
                for (final post in visiblePosts)
                  PostCard(
                    post: post,
                    onOpen: () => context.pushNamed(
                      RouteNames.postDetail,
                      pathParameters: {'postId': post.id},
                    ),
                    onLike: () => cubit.toggleLike(post),
                    onReact: (type) => cubit.react(post, type),
                    onSave: () => cubit.toggleSave(post.id),
                    onRepost: () => cubit.toggleRepost(post),
                  ),
              if (state.hasMorePosts)
                TextButton(
                  onPressed: state.loadingMorePosts
                      ? null
                      : cubit.loadMorePosts,
                  child: Text(
                    state.loadingMorePosts ? 'Loading…' : 'Load more posts',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MessageAction extends StatefulWidget {
  const _MessageAction({super.key, required this.userId});

  final String userId;

  @override
  State<_MessageAction> createState() => _MessageActionState();
}

class _MessageActionState extends State<_MessageAction> {
  bool _opening = false;

  Future<void> _openChat() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final result = await sl<StartDirectConversationUseCase>()(widget.userId);
      if (!mounted) return;
      await result.fold<Future<void>>(
        (failure) async {
          AppStatusSnackbar.showError(context, message: failure.message);
        },
        (conversation) async {
          await context.pushNamed(
            RouteNames.chat,
            pathParameters: {'conversationId': conversation.id},
          );
        },
      );
    } catch (_) {
      if (mounted) {
        AppStatusSnackbar.showError(
          context,
          message: 'Could not open chat. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: _opening ? 'Opening…' : 'Message',

      onPressed: _opening ? null : _openChat,
    );
  }
}

/// The button (or pair of buttons) under the bio, driven entirely by
/// [PublicProfileState.friendStatus], supplied by the user profile API.
class _FriendAction extends StatelessWidget {
  const _FriendAction({required this.state, required this.cubit});
  final PublicProfileState state;
  final PublicProfileCubit cubit;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final busy = state.friendActionBusy;

    switch (state.friendStatus) {
      case FriendStatus.self:
        return AppButton(
          label: 'This is you — go to your profile',
          variant: AppButtonVariant.outline,

          onPressed: () => context.goNamed(RouteNames.profile),
        );
      case FriendStatus.friends:
        return AppButton(
          label: 'Connections',
          variant: AppButtonVariant.outline,

          onPressed: busy ? null : () => _confirmUnfriend(context),
        );
      case FriendStatus.requestSent:
        return AppButton(
          label: 'Requested',
          variant: AppButtonVariant.outline,

          onPressed: null,
        );
      case FriendStatus.incomingRequest:
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AppButton(
              label: 'Accept',

              onPressed: busy ? null : () => _respond(context, accept: true),
            ),
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              shape: CircleBorder(
                side: BorderSide(color: colors.line, width: 1.5),
              ),
              child: InkWell(
                onTap: busy ? null : () => _respond(context, accept: false),
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: Icon(Icons.close, size: 15, color: colors.ink2),
                ),
              ),
            ),
          ],
        );
      case FriendStatus.none:
        return AppButton(
          label: 'Add Friend',

          onPressed: busy ? null : cubit.sendFriendRequest,
        );
    }
  }

  Future<void> _respond(BuildContext context, {required bool accept}) async {
    final ok = accept
        ? await cubit.acceptIncomingRequest()
        : await cubit.declineIncomingRequest();
    if (!context.mounted || ok) return;
    AppStatusSnackbar.showError(
      context,
      message: accept
          ? 'Could not accept request.'
          : 'Could not decline request.',
    );
  }

  void _confirmUnfriend(BuildContext context) {
    final username = state.user?.username ?? 'this user';
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove $username?'),
        content: const Text("You'll need to send a new request to reconnect."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              cubit.unfriend();
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: colors.surf,
          border: Border.all(color: colors.line, width: 1.5),
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppTextStyles.titleLg.copyWith(color: colors.ink),
            ),
            const SizedBox(height: 7),
            Text(
              label.toUpperCase(),
              style: AppTextStyles.metaMono.copyWith(color: colors.ink2),
            ),
          ],
        ),
      ),
    );
  }
}
