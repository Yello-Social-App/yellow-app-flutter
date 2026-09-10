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
import '../../../../shared/widgets/image_placeholder.dart';
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
      body: SafeArea(
        child: BlocBuilder<PublicProfileCubit, PublicProfileState>(
          builder: (context, state) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                  child: Row(
                    children: [
                      AppIconButton(
                        icon: const Icon(Icons.arrow_back),
                        size: 38,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 11),
                      Text('PROFILE', style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
                    ],
                  ),
                ),
                Expanded(
                  child: _Body(state: state, cubit: cubit),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.cubit});
  final PublicProfileState state;
  final PublicProfileCubit cubit;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    if (state.status == PublicProfileStatus.loading && state.user == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == PublicProfileStatus.error && state.user == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ErrorView(message: state.errorMessage ?? 'Could not load this profile.', onRetry: cubit.load),
        ),
      );
    }

    final user = state.user!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
      children: [
        SizedBox(
          height: 150,
          child: Stack(
            children: [
              const Positioned.fill(child: ImagePlaceholder()),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withValues(alpha: 0.45), Colors.transparent],
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
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
                      Text(user.fullName ?? user.username, style: AppTextStyles.displayLg.copyWith(color: colors.ink)),
                      const SizedBox(height: 11),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          border: Border.all(color: colors.line),
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: Text(
                          user.username.withAtSign.toUpperCase(),
                          style: AppTextStyles.metaMono.copyWith(color: colors.ink2),
                        ),
                      ),
                      if ((user.bio ?? '').isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          user.bio!,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodySm.copyWith(color: colors.ink2, fontSize: 14),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _FriendAction(state: state, cubit: cubit),
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
                  _StatTile(value: '${state.posts.length}', label: 'Posts'),
                  const SizedBox(width: 10),
                  _StatTile(value: '${user.createdAt.year}', label: 'Joined'),
                ],
              ),
              const SizedBox(height: 20),
              if (state.posts.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.line, width: 1.5),
                    borderRadius: BorderRadius.circular(AppRadii.xl),
                  ),
                  child: Column(
                    children: [
                      Text('NOTHING POSTED YET', style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
                      const SizedBox(height: 8),
                      Text(
                        "${user.username}'s posts will show up here.",
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySm.copyWith(color: colors.ink2),
                      ),
                    ],
                  ),
                )
              else
                for (final post in state.posts)
                  PostCard(
                    post: post,
                    onOpen: () => context.pushNamed(RouteNames.postDetail, pathParameters: {'postId': post.id}),
                    onLike: () => cubit.toggleLike(post),
                    onReact: (type) => cubit.react(post, type),
                    onSave: () => cubit.toggleSave(post.id),
                    onRepost: () => cubit.toggleRepost(post),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The button (or pair of buttons) under the bio, driven entirely by
/// [PublicProfileState.friendStatus]. Note there's no backend endpoint to
/// list requests *you've* sent, so [FriendStatus.requestSent] is a
/// local/session-only flag — see the cubit's doc comment.
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
          dense: true,
          onPressed: () => context.goNamed(RouteNames.profile),
        );
      case FriendStatus.friends:
        return AppButton(
          label: 'Friends',
          variant: AppButtonVariant.outline,
          dense: true,
          onPressed: busy ? null : () => _confirmUnfriend(context),
        );
      case FriendStatus.requestSent:
        return AppButton(label: 'Requested', variant: AppButtonVariant.outline, dense: true, onPressed: null);
      case FriendStatus.incomingRequest:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppButton(label: 'Accept', dense: true, onPressed: busy ? null : () => _respond(context, accept: true)),
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              shape: CircleBorder(side: BorderSide(color: colors.line, width: 1.5)),
              child: InkWell(
                onTap: busy ? null : () => _respond(context, accept: false),
                customBorder: const CircleBorder(),
                child: SizedBox(width: 34, height: 34, child: Icon(Icons.close, size: 15, color: colors.ink2)),
              ),
            ),
          ],
        );
      case FriendStatus.none:
        return AppButton(label: 'Add Friend', dense: true, onPressed: busy ? null : cubit.sendFriendRequest);
    }
  }

  Future<void> _respond(BuildContext context, {required bool accept}) async {
    final ok = accept ? await cubit.acceptIncomingRequest() : await cubit.declineIncomingRequest();
    if (!context.mounted || ok) return;
    AppStatusSnackbar.showError(
      context,
      message: accept ? 'Could not accept request.' : 'Could not decline request.',
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
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
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
            Text(value, style: AppTextStyles.titleLg.copyWith(color: colors.ink)),
            const SizedBox(height: 7),
            Text(label.toUpperCase(), style: AppTextStyles.metaMono.copyWith(color: colors.ink2)),
          ],
        ),
      ),
    );
  }
}
