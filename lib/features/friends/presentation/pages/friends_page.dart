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
import '../../../../shared/extensions/string_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_warning_dialog.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/underline_tabs.dart';
import '../../../../shared/widgets/yello_wordmark.dart';
import '../../domain/entities/friendship_entity.dart';
import '../bloc/friends_cubit.dart';
import '../widgets/shimmer_friends_section.dart';

class FriendsPage extends StatelessWidget {
  const FriendsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(create: (_) => sl<FriendsCubit>()..load(), child: const _FriendsView());
  }
}

class _FriendsView extends StatefulWidget {
  const _FriendsView();

  @override
  State<_FriendsView> createState() => _FriendsViewState();
}

class _FriendsViewState extends State<_FriendsView> {
  StreamSubscription<String>? _friendshipChanges;

  _CircleTab _tab = _CircleTab.friends;

  @override
  void initState() {
    super.initState();
    // `FRIENDSHIP_CHANGED` is a silent push: someone unfriended the viewer,
    // declined their request, or cancelled one they had sent, and nothing
    // is shown for it. This list is one of the two screens that would
    // otherwise keep showing the old state until it was left and re-entered
    // — the other is `PublicProfilePage`. Foreground only, by the nature of
    // the push; a backgrounded app reloads on its next `load()` anyway.
    _friendshipChanges = sl<PushNotificationService>().friendshipChanges.listen((_) {
      if (mounted) context.read<FriendsCubit>().refresh();
    });
  }

  @override
  void dispose() {
    _friendshipChanges?.cancel();
    super.dispose();
  }

  /// Circle is a kept-alive shell branch and its cubit only loads once, so a
  /// request sent (or a block made) from someone's profile would never reach
  /// the Requests or Blocked tab. Switching tabs brings every list current (without blanking them — the
  /// loading/error bodies only take over while a tab's list is empty).
  void _selectTab(_CircleTab tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
    final cubit = context.read<FriendsCubit>();
    if (cubit.state.status == FriendsStatus.loaded) unawaited(cubit.refresh());
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cubit = context.read<FriendsCubit>();

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<FriendsCubit, FriendsState>(
          builder: (context, state) {
            final empty = switch (_tab) {
              _CircleTab.friends => state.friends.isEmpty,
              _CircleTab.requests => state.requests.isEmpty && state.sentRequests.isEmpty,
              _CircleTab.blocked => state.blocked.isEmpty,
            };
            return RefreshIndicator(
              onRefresh: cubit.refresh,
              color: colors.ink,
              backgroundColor: colors.surf,
              child: CustomScrollView(
                // Always scrollable, so pull-to-refresh works on a short list.
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // The title and the tab row sit on `surf` as one header
                  // block, the way Feed's do; the lists stay on `bg`.
                  SliverToBoxAdapter(
                    child: ColoredBox(
                      color: colors.surf,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${state.friends.length} connections',
                              style: AppTextStyles.metaMono.copyWith(color: colors.ink2),
                            ),
                            const SizedBox(height: 8),
                            const YelloWordmark(fontSize: AppTextStyles.displayXlFontSize, text: 'Circle'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: UnderlineTabsDelegate<_CircleTab>(
                      values: _CircleTab.values,
                      current: _tab,
                      labelOf: (tab) => tab.labelFor(state),
                      onSelect: _selectTab,
                      colors: colors,
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                    sliver: SliverList.list(
                      children: [
                        if (state.status == FriendsStatus.loading && empty)
                          const ShimmerFriendsSection()
                        else if (state.status == FriendsStatus.error && empty)
                          ErrorView(
                            message: state.errorMessage ?? 'Could not load your circle.',
                            onRetry: cubit.refresh,
                          )
                        else
                          ...switch (_tab) {
                            _CircleTab.friends => _friendsBody(state, cubit),
                            _CircleTab.requests => _requestsBody(state, cubit),
                            _CircleTab.blocked => _blockedBody(state, cubit),
                          },
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _friendsBody(FriendsState state, FriendsCubit cubit) {
    if (state.friends.isEmpty) {
      return const [EmptyStateCard(title: 'NO CONNECTIONS YET', hint: 'People you add each other with show up here.')];
    }
    return [
      _SectionCard(
        title: 'YOUR PEOPLE',
        children: [
          for (final f in state.friends)
            _FriendRow(friend: f, busy: state.busyIds.contains(f.userId), onRemove: () => cubit.unfriend(f.userId)),
        ],
      ),
    ];
  }

  List<Widget> _requestsBody(FriendsState state, FriendsCubit cubit) {
    if (state.requests.isEmpty && state.sentRequests.isEmpty) {
      return const [
        EmptyStateCard(
          title: 'NO PENDING REQUESTS',
          hint: "Requests you send, and ones sent to you, wait here until they're answered.",
        ),
      ];
    }
    return [
      if (state.requests.isNotEmpty)
        _SectionCard(
          title: 'RECEIVED · ${state.requests.length}',
          children: [
            for (final r in state.requests)
              _RequestRow(
                request: r,
                busy: state.busyIds.contains(r.id),
                onAccept: () => cubit.accept(r.id),
                onDecline: () => cubit.decline(r.id),
              ),
          ],
        ),
      if (state.requests.isNotEmpty && state.sentRequests.isNotEmpty) const SizedBox(height: 16),
      if (state.sentRequests.isNotEmpty)
        _SectionCard(
          title: 'SENT · ${state.sentRequests.length}',
          children: [
            for (final r in state.sentRequests)
              _SentRequestRow(
                request: r,
                busy: state.busyIds.contains(r.userId),
                onCancel: () => cubit.cancel(r.userId),
              ),
          ],
        ),
    ];
  }

  List<Widget> _blockedBody(FriendsState state, FriendsCubit cubit) {
    if (state.blocked.isEmpty) {
      return const [
        EmptyStateCard(title: 'NO ONE BLOCKED', hint: 'People you block from their profile are listed here.'),
      ];
    }
    return [
      _SectionCard(
        title: 'BLOCKED · ${state.blocked.length}',
        children: [
          for (final b in state.blocked)
            _BlockedRow(user: b, busy: state.busyIds.contains(b.userId), onUnblock: () => cubit.unblock(b.userId)),
        ],
      ),
    ];
  }
}

/// Circle's three tabs: people you're connected with, requests still
/// waiting on an answer in either direction, and people you've blocked.
enum _CircleTab {
  friends,
  requests,
  blocked;

  /// Requests carries the count waiting on *you*, so it shows from the
  /// Friends tab too — the only nudge that someone asked to connect.
  String labelFor(FriendsState state) => switch (this) {
    friends => 'Friends',
    requests => state.requests.isEmpty ? 'Requests' : 'Requests · ${state.requests.length}',
    blocked => 'Blocked',
  };
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surf,
        border: Border.all(color: colors.line, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: AppShadows.card(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.line2)),
            ),
            child: Text(title, style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.request, required this.busy, required this.onAccept, required this.onDecline});
  final FriendshipEntity request;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.line2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.md),
              onTap: () => context.pushNamed(RouteNames.userProfile, pathParameters: {'userId': request.userId}),
              child: Row(
                children: [
                  AppAvatar(
                    initials: request.username.initials,
                    seed: avatarSeedForId(request.userId),
                    imageUrl: request.avatarUrl,
                    size: 46,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(request.username, style: AppTextStyles.titleMd.copyWith(color: colors.ink)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              AppButton(label: 'Accept', dense: true, onPressed: busy ? null : onAccept),
              const SizedBox(width: 6),
              Material(
                color: Colors.transparent,
                shape: CircleBorder(side: BorderSide(color: colors.line, width: 1.5)),
                child: InkWell(
                  onTap: busy ? null : onDecline,
                  customBorder: const CircleBorder(),
                  child: SizedBox(
                    width: 34,
                    height: 34,
                    child: Icon(CupertinoIcons.xmark, size: 15, color: colors.ink2),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A request the viewer sent and is still waiting on — Cancel withdraws it.
class _SentRequestRow extends StatelessWidget {
  const _SentRequestRow({required this.request, required this.busy, required this.onCancel});
  final FriendshipEntity request;
  final bool busy;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.line2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.md),
              onTap: () => context.pushNamed(RouteNames.userProfile, pathParameters: {'userId': request.userId}),
              child: Row(
                children: [
                  AppAvatar(
                    initials: request.username.initials,
                    seed: avatarSeedForId(request.userId),
                    imageUrl: request.avatarUrl,
                    size: 46,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(request.username, style: AppTextStyles.titleMd.copyWith(color: colors.ink)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          AppButton(label: 'Cancel', variant: AppButtonVariant.secondary, dense: true, onPressed: busy ? null : onCancel),
        ],
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({required this.friend, required this.busy, required this.onRemove});
  final FriendshipEntity friend;
  final bool busy;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.line2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.md),
              onTap: () => context.pushNamed(RouteNames.userProfile, pathParameters: {'userId': friend.userId}),
              child: Row(
                children: [
                  AppAvatar(
                    initials: friend.username.initials,
                    seed: avatarSeedForId(friend.userId),
                    imageUrl: friend.avatarUrl,
                    size: 46,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(friend.username, style: AppTextStyles.titleMd.copyWith(color: colors.ink)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          AppButton(
            label: 'Remove',
            variant: AppButtonVariant.secondary,
            dense: true,
            onPressed: busy ? null : () => _confirmRemove(context),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final confirmed = await AppWarningDialog.show(
      context,
      title: 'Remove ${friend.username}?',
      message: "You'll need to send a new request to reconnect.",
      confirmLabel: 'Remove',
      icon: CupertinoIcons.person_badge_minus,
    );
    if (confirmed) onRemove();
  }
}

/// Someone the viewer blocked. Not tappable: a blocked profile answers `404`
/// like a missing one (see `docs/BACKEND.md`), so there is nothing to open.
class _BlockedRow extends StatelessWidget {
  const _BlockedRow({required this.user, required this.busy, required this.onUnblock});
  final FriendshipEntity user;
  final bool busy;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.line2)),
      ),
      child: Row(
        children: [
          AppAvatar(
            initials: user.username.initials,
            seed: avatarSeedForId(user.userId),
            imageUrl: user.avatarUrl,
            size: 46,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(user.username, style: AppTextStyles.titleMd.copyWith(color: colors.ink)),
          ),
          const SizedBox(width: 8),
          AppButton(
            label: 'Unblock',
            variant: AppButtonVariant.secondary,
            dense: true,
            onPressed: busy ? null : () => _confirmUnblock(context),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmUnblock(BuildContext context) async {
    final confirmed = await AppWarningDialog.show(
      context,
      title: 'Unblock ${user.username}?',
      message: "They'll be able to see your profile and send you requests again.",
      confirmLabel: 'Unblock',
      icon: CupertinoIcons.lock_open,
      destructive: false,
    );
    if (confirmed) onUnblock();
  }
}
