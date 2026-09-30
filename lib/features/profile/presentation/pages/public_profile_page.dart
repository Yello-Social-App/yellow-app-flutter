import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/notifications/push_notification_service.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/app_status_snackbar.dart';
import '../../../../shared/widgets/app_warning_dialog.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/segmented_tabs.dart';
import '../../../chat/domain/usecases/chat_usecases.dart';
import '../../../feed/domain/entities/post_entity.dart';
import '../../../feed/presentation/widgets/post_card.dart';
import '../../domain/entities/public_user_entity.dart';
import '../bloc/public_profile_cubit.dart';
import '../widgets/profile_details_card.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_top_bar.dart';
import '../widgets/shimmer_own_profile_view.dart';

/// Read-only view of someone else's profile (`GET /users/{id}` +
/// `GET /users/{id}/posts`), pushed by tapping an avatar/username anywhere
/// in the app. Safe to push with the viewer's own [userId] too — the cubit
/// resolves that case as [FriendStatus.self] and this page shows a plain
/// "go to your profile" affordance instead of a friend-action button, rather
/// than every tap site having to know who "you" are first.
///
/// Laid out exactly like the Profile tab (`profile_page.dart`): the same
/// header frame, details card, segmented switcher, post list and collapsing
/// top bar, so moving between your own profile and someone else's never
/// changes the shape of the screen — only what you can do on it.
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

/// The Profile tab's All / Shared, minus Saved — saved posts are the
/// viewer's own on-device list, not something another profile has.
enum _PublicTab { posts, shared }

class _PublicProfileView extends StatefulWidget {
  const _PublicProfileView();

  @override
  State<_PublicProfileView> createState() => _PublicProfileViewState();
}

class _PublicProfileViewState extends State<_PublicProfileView> {
  StreamSubscription<String>? _friendshipChanges;
  final ScrollController _scrollController = ScrollController();

  /// Drives the collapsing top bar — `ValueNotifier` rather than `setState`
  /// for the same reason as `ProfilePage`'s: a scroll frame repaints the bar
  /// alone instead of every post card underneath it.
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0);

  _PublicTab _tab = _PublicTab.posts;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // A silent `FRIENDSHIP_CHANGED` push naming *this* profile means the
    // Add/Accept/Unfriend button on screen is now wrong — they unfriended
    // the viewer, declined their request, or cancelled one they had sent.
    // Reloading is the only way to find out which: the push carries a user
    // id and nothing else, on purpose. Pushes about anyone else are
    // ignored, so an open profile is not reloaded for unrelated activity.
    _friendshipChanges = sl<PushNotificationService>().friendshipChanges.listen((userId) {
      if (!mounted) return;
      final cubit = context.read<PublicProfileCubit>();
      if (cubit.userId == userId) cubit.load();
    });
  }

  void _onScroll() {
    // The list only exists in the loaded state — while the shimmer, the
    // error view or the blocked notice is up this controller has no position.
    if (!_scrollController.hasClients) return;
    _scrollOffset.value = _scrollController.offset.clamp(0.0, ProfileTopBar.collapseEnd);
  }

  @override
  void dispose() {
    _friendshipChanges?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cubit = context.read<PublicProfileCubit>();

    return Scaffold(
      backgroundColor: colors.bg,
      // Blocking (or an error) swaps the list out for a notice. The list's
      // last offset would otherwise leave the bar collapsed over a screen
      // with no header scrolled away beneath it.
      body: BlocListener<PublicProfileCubit, PublicProfileState>(
        listenWhen: (prev, next) =>
            (!prev.blockedByMe && next.blockedByMe) ||
            (prev.status != PublicProfileStatus.error && next.status == PublicProfileStatus.error),
        listener: (_, _) => _scrollOffset.value = 0,
        child: Stack(
          children: [
            Positioned.fill(
              child: BlocBuilder<PublicProfileCubit, PublicProfileState>(
                builder: (context, state) => _buildBody(context, state, cubit),
              ),
            ),
            // Same floating chrome as the Profile tab, with a back button in
            // front. Buttons are the builder's `child` and the identity is
            // selected outside the scroll listener, so a scroll frame
            // rebuilds the bar and nothing else.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: BlocSelector<PublicProfileCubit, PublicProfileState, PublicUserEntity?>(
                selector: (state) => state.user,
                builder: (context, user) {
                  final fullName = user?.fullName?.trim() ?? '';
                  final identity = user == null
                      ? null
                      : ProfileBarIdentity(
                          id: user.id,
                          displayName: fullName.isEmpty ? user.username : fullName,
                          username: user.username,
                          avatarUrl: user.avatarUrl,
                        );
                  return ValueListenableBuilder<double>(
                    valueListenable: _scrollOffset,
                    child: const _MoreAction(),
                    builder: (context, offset, actions) => ProfileTopBar(
                      offset: offset,
                      identity: identity,
                      leading: AppIconButton(
                        icon: const Icon(CupertinoIcons.back),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      actions: actions!,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, PublicProfileState state, PublicProfileCubit cubit) {
    final colors = AppColors.of(context);

    if (state.status == PublicProfileStatus.initial ||
        (state.status == PublicProfileStatus.loading && state.user == null)) {
      // No email on a public profile, so one details row fewer.
      return const ShimmerOwnProfileView(detailRows: 3);
    }
    if (state.status == PublicProfileStatus.error) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ErrorView(message: state.errorMessage ?? 'Could not load this profile.', onRetry: cubit.load),
          ),
        ),
      );
    }
    if (state.blockedByMe) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('You blocked this user.', style: AppTextStyles.bodyMd.copyWith(color: colors.ink2)),
            const SizedBox(height: 12),
            AppButton(
              label: 'Unblock',
              variant: AppButtonVariant.secondary,
              dense: true,
              onPressed: state.friendActionBusy
                  ? null
                  : () async {
                      final ok = await cubit.setBlocked(false);
                      if (ok) {
                        await cubit.load();
                      } else if (context.mounted) {
                        AppStatusSnackbar.showError(
                          context,
                          message: cubit.state.errorMessage ?? 'Could not unblock user.',
                        );
                      }
                    },
            ),
          ],
        ),
      );
    }

    final user = state.user!;
    final sharedPosts = state.posts.where((post) => post.isRepost).toList();
    final visiblePosts = _tab == _PublicTab.shared ? sharedPosts : state.posts.where((post) => !post.isRepost).toList();

    return RefreshIndicator(
      onRefresh: cubit.load,
      color: colors.ink,
      backgroundColor: colors.surf,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 112),
        children: [
          PublicProfileHeader(
            user: user,
            actions: _ProfileActions(state: state, cubit: cubit),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ProfileDetailsCard.public(user: user),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: SegmentedTabs<_PublicTab>(
              values: _PublicTab.values,
              current: _tab,
              labelOf: (tab) => switch (tab) {
                _PublicTab.posts => 'All ${user.postsCount}',
                _PublicTab.shared => 'Shared ${sharedPosts.length}',
              },
              onSelect: (tab) => setState(() => _tab = tab),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                if (visiblePosts.isEmpty)
                  EmptyStateCard(
                    title: _tab == _PublicTab.shared ? 'NOTHING SHARED YET' : 'NOTHING POSTED YET',
                    hint: _tab == _PublicTab.shared
                        ? "${user.username}'s shared posts will show up here."
                        : "${user.username}'s posts will show up here.",
                  )
                else
                  for (final post in visiblePosts)
                    PostCard(
                      post: post,
                      onOpen: () => _openPost(context, cubit, post.id),
                      onLike: () => cubit.toggleLike(post),
                      onReact: (type) => cubit.react(post, type),
                      onSave: () => cubit.toggleSave(post.id),
                      onRepost: () => cubit.toggleRepost(post),
                    ),
                if (state.hasMorePosts)
                  AppButton(
                    label: state.loadingMorePosts ? 'Loading…' : 'Load more',
                    variant: AppButtonVariant.secondary,
                    dense: true,
                    onPressed: state.loadingMorePosts ? null : cubit.loadMorePosts,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The top bar's trailing button: the "more" menu that Block user moved into
/// from the header's action row, which now holds the same two primary
/// buttons the Profile tab's does. Hidden while there is nothing to act on —
/// loading, error, already blocked, or viewing yourself.
class _MoreAction extends StatelessWidget {
  const _MoreAction();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<PublicProfileCubit, PublicProfileState, bool>(
      selector: (state) =>
          state.user != null &&
          state.status != PublicProfileStatus.error &&
          state.friendStatus != FriendStatus.self &&
          !state.blockedByMe,
      builder: (context, visible) => visible
          ? AppIconButton(icon: const Icon(CupertinoIcons.ellipsis), onPressed: () => _openMenu(context))
          : const SizedBox.shrink(),
    );
  }

  /// `useRootNavigator`, same reason as the Profile tab's account menu: a
  /// sheet on a nested Navigator can render behind the shell's floating nav.
  Future<void> _openMenu(BuildContext context) async {
    final colors = AppColors.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      backgroundColor: colors.surf,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 80,
              height: 4,
              decoration: BoxDecoration(color: colors.line, borderRadius: BorderRadius.circular(AppRadii.pill)),
            ),
            ListTile(
              leading: Icon(CupertinoIcons.nosign, color: colors.ink),
              title: Text('Block user', style: AppTextStyles.body.copyWith(color: colors.ink)),
              subtitle: Text(
                'You will no longer see each other',
                style: AppTextStyles.metaMonoSm.copyWith(color: colors.ink2),
              ),
              onTap: () => Navigator.pop(sheetContext, 'block'),
            ),
          ],
        ),
      ),
    );
    if (action == 'block' && context.mounted) await _confirmBlock(context);
  }

  Future<void> _confirmBlock(BuildContext context) async {
    final cubit = context.read<PublicProfileCubit>();
    final confirmed = await AppWarningDialog.show(
      context,
      title: 'Block user?',
      message: 'You will no longer see each other’s profile or posts.',
      confirmLabel: 'Block',
      cancelLabel: 'Cancel',
      icon: CupertinoIcons.nosign,
    );
    // A friend action still in flight owns the busy flag; `setBlocked` would
    // refuse and this would report a failure that never happened.
    if (!confirmed || !context.mounted || cubit.state.friendActionBusy) return;
    final ok = await cubit.setBlocked(true);
    if (!ok && context.mounted) {
      AppStatusSnackbar.showError(context, message: cubit.state.errorMessage ?? 'Could not block user.');
    }
  }
}

/// The header's action row — two equal buttons, the same shape as the
/// Profile tab's Add to story / Edit profile: the friend action, then
/// Message. Viewing yourself collapses it to one button back to your own tab.
class _ProfileActions extends StatelessWidget {
  const _ProfileActions({required this.state, required this.cubit});
  final PublicProfileState state;
  final PublicProfileCubit cubit;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    if (state.friendStatus == FriendStatus.self) {
      return AppButton(
        label: 'Go to your profile',
        variant: AppButtonVariant.secondary,
        fullWidth: true,
        icon: Icon(CupertinoIcons.person, size: 17, color: colors.ink),
        onPressed: () => context.goNamed(RouteNames.profile),
      );
    }
    return Row(
      children: [
        Expanded(
          child: _FriendAction(state: state, cubit: cubit),
        ),
        const SizedBox(width: 10),
        Expanded(child: _MessageAction(userId: cubit.userId)),
      ],
    );
  }
}

class _MessageAction extends StatefulWidget {
  const _MessageAction({required this.userId});

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
          await context.pushNamed(RouteNames.chat, pathParameters: {'conversationId': conversation.id});
        },
      );
    } catch (_) {
      if (mounted) {
        AppStatusSnackbar.showError(context, message: 'Could not open chat. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: _opening ? 'Opening…' : 'Message',
      variant: AppButtonVariant.secondary,
      fullWidth: true,
      icon: Icon(CupertinoIcons.chat_bubble, size: 17, color: AppColors.of(context).ink2),
      onPressed: _opening ? null : _openChat,
    );
  }
}

/// The primary button of the action row, driven entirely by
/// [PublicProfileState.friendStatus], supplied by the user profile API.
class _FriendAction extends StatelessWidget {
  const _FriendAction({required this.state, required this.cubit});
  final PublicProfileState state;
  final PublicProfileCubit cubit;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final busy = state.friendActionBusy;
    final primaryIcon = busy ? colors.ink3 : colors.onYel;

    switch (state.friendStatus) {
      // `_ProfileActions` renders its own button for this case; kept so the
      // switch stays exhaustive.
      case FriendStatus.self:
        return const SizedBox.shrink();
      case FriendStatus.friends:
        return AppButton(
          label: 'Connections',
          variant: AppButtonVariant.secondary,
          fullWidth: true,
          icon: Icon(CupertinoIcons.person_crop_circle_badge_checkmark, size: 17, color: colors.ink),
          onPressed: busy ? null : () => _confirmUnfriend(context),
        );
      case FriendStatus.requestSent:
        return AppButton(
          label: 'Requested',
          variant: AppButtonVariant.secondary,
          fullWidth: true,
          icon: Icon(CupertinoIcons.clock, size: 17, color: colors.ink),
          onPressed: null,
        );
      case FriendStatus.incomingRequest:
        return Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Accept',
                fullWidth: true,
                icon: Icon(CupertinoIcons.checkmark, size: 17, color: primaryIcon),
                onPressed: busy ? null : () => _respond(context, accept: true),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              shape: CircleBorder(side: BorderSide(color: colors.line, width: 1.5)),
              child: InkWell(
                onTap: busy ? null : () => _respond(context, accept: false),
                customBorder: const CircleBorder(),
                child: SizedBox(width: 38, height: 38, child: Icon(CupertinoIcons.xmark, size: 15, color: colors.ink2)),
              ),
            ),
          ],
        );
      case FriendStatus.none:
        return AppButton(
          label: 'Add Friend',
          fullWidth: true,
          icon: Icon(CupertinoIcons.person_badge_plus, size: 17, color: primaryIcon),
          onPressed: busy ? null : cubit.sendFriendRequest,
        );
    }
  }

  Future<void> _respond(BuildContext context, {required bool accept}) async {
    final ok = accept ? await cubit.acceptIncomingRequest() : await cubit.declineIncomingRequest();
    if (!context.mounted || ok) return;
    AppStatusSnackbar.showError(context, message: accept ? 'Could not accept request.' : 'Could not decline request.');
  }

  Future<void> _confirmUnfriend(BuildContext context) async {
    final username = state.user?.username ?? 'this user';
    final confirmed = await AppWarningDialog.show(
      context,
      title: 'Remove $username?',
      message: "You'll need to send a new request to reconnect.",
      confirmLabel: 'Remove',
      icon: CupertinoIcons.person_badge_minus,
    );
    if (confirmed) cubit.unfriend();
  }
}

/// Opens the post's own screen and applies whatever it pops back onto this
/// row — a reaction or a comment made in there changes counts the card here
/// shows, and nothing re-fetches this list on the way back. See ADR-032.
Future<void> _openPost(BuildContext context, PublicProfileCubit cubit, String postId) async {
  final updated = await context.pushNamed<PostEntity>(RouteNames.postDetail, pathParameters: {'postId': postId});
  if (updated != null) cubit.applyUpdated(updated);
}
