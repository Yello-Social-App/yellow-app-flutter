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
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/shimmer_loading.dart';
import '../../domain/entities/friendship_entity.dart';
import '../bloc/friends_cubit.dart';

class FriendsPage extends StatelessWidget {
  const FriendsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<FriendsCubit>()..load(),
      child: const _FriendsView(),
    );
  }
}

class _FriendsView extends StatelessWidget {
  const _FriendsView();

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
            return RefreshIndicator(
              onRefresh: cubit.refresh,
              color: colors.ink,
              backgroundColor: colors.surf,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${state.friends.length} connections',
                          style: AppTextStyles.metaMono.copyWith(color: colors.ink2),
                        ),
                        const SizedBox(height: 8),
                        RichText(
                          text: TextSpan(
                            style: AppTextStyles.displayXl.copyWith(color: colors.ink),
                            children: [
                              const TextSpan(text: 'Circle'),
                              TextSpan(text: '.', style: TextStyle(color: colors.yel)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (state.status == FriendsStatus.loading && state.friends.isEmpty) ...[
                    const ShimmerPostCard(),
                  ] else if (state.status == FriendsStatus.error && state.friends.isEmpty) ...[
                    ErrorView(
                      message: state.errorMessage ?? 'Could not load your circle.',
                      onRetry: cubit.refresh,
                    ),
                  ] else ...[
                    if (state.requests.isNotEmpty) ...[
                      _SectionCard(
                        title: 'REQUESTS · ${state.requests.length}',
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
                      const SizedBox(height: 16),
                    ],
                    _SectionCard(
                      title: 'YOUR PEOPLE',
                      children: [
                        if (state.friends.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'No connections yet — accepted requests show up here.',
                              style: AppTextStyles.bodySm.copyWith(color: colors.ink2),
                            ),
                          )
                        else
                          for (final f in state.friends)
                            _FriendRow(
                              friend: f,
                              busy: state.busyIds.contains(f.userId),
                              onRemove: () => cubit.unfriend(f.userId),
                            ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
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
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.line2))),
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
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.line2))),
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
                    child: Icon(Icons.close, size: 15, color: colors.ink2),
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
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.line2))),
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
            variant: AppButtonVariant.outline,
            dense: true,
            onPressed: busy ? null : () => _confirmRemove(context),
          ),
        ],
      ),
    );
  }

  void _confirmRemove(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove ${friend.username}?'),
        content: const Text("You'll need to send a new request to reconnect."),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onRemove();
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
