import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/extensions/string_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_status_snackbar.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/shimmer_loading.dart';
import '../../domain/entities/notification_entity.dart';
import '../bloc/notifications_cubit.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<NotificationsCubit>()..load(),
      child: const _NotificationsView(),
    );
  }
}

/// Maps the backend's opaque `type` string to a human verb — falls back
/// gracefully for any value the backend introduces that the client doesn't
/// know about yet.
String _verbFor(String type) => switch (type.toUpperCase()) {
      'REACTION' || 'LIKE' => 'reacted to your post',
      'FOLLOW' || 'FRIEND_REQUEST' => 'sent you a friend request',
      'FRIEND_ACCEPT' => 'accepted your friend request',
      'COMMENT' => 'commented on your post',
      'MENTION' => 'mentioned you',
      'REPOST' => 'reposted your post',
      _ => 'sent you a notification',
    };

/// Runs an accept/decline call and surfaces a snackbar only on failure —
/// same "silent on success, snackbar on failure" convention as
/// `post_detail_page.dart`'s `_confirmDeletePost`/`_shareLink`.
Future<void> _respondToFriendRequest(
  BuildContext context,
  NotificationsCubit cubit,
  NotificationEntity notification, {
  required bool accept,
}) async {
  final ok = accept
      ? await cubit.acceptFriendRequest(notification)
      : await cubit.declineFriendRequest(notification);
  if (!context.mounted || ok) return;
  AppStatusSnackbar.showError(
    context,
    message: accept ? 'Could not accept request.' : 'Could not decline request.',
  );
}

class _NotificationsView extends StatelessWidget {
  const _NotificationsView();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cubit = context.read<NotificationsCubit>();

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<NotificationsCubit, NotificationsState>(
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
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('This week', style: AppTextStyles.metaMono.copyWith(color: colors.ink2)),
                              const SizedBox(height: 8),
                              RichText(
                                text: TextSpan(
                                  style: AppTextStyles.displayXl.copyWith(color: colors.ink),
                                  children: [
                                    const TextSpan(text: 'Signals'),
                                    TextSpan(text: '.', style: TextStyle(color: colors.yel)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        AppButton(
                          label: 'Mark read',
                          variant: AppButtonVariant.outline,
                          dense: true,
                          onPressed: state.unreadCount == 0 ? null : cubit.markAllRead,
                        ),
                      ],
                    ),
                  ),
                  if (state.status == NotificationsStatus.loading && state.notifications.isEmpty)
                    const ShimmerPostCard()
                  else if (state.status == NotificationsStatus.error && state.notifications.isEmpty)
                    ErrorView(
                      message: state.errorMessage ?? 'Could not load your notifications.',
                      onRetry: cubit.refresh,
                    )
                  else if (state.notifications.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        "Nothing yet — you'll see reactions, comments and requests here.",
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySm.copyWith(color: colors.ink2),
                      ),
                    )
                  else
                    for (final n in state.notifications)
                      _NotificationRow(
                        notification: n,
                        onTap: () => cubit.openNotification(n),
                        busy: state.busyRequestIds.contains(n.id),
                        outcome: state.respondedRequestIds[n.id],
                        onAccept: () => _respondToFriendRequest(context, cubit, n, accept: true),
                        onDecline: () => _respondToFriendRequest(context, cubit, n, accept: false),
                      ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.notification,
    required this.onTap,
    required this.busy,
    required this.outcome,
    required this.onAccept,
    required this.onDecline,
  });

  final NotificationEntity notification;
  final VoidCallback onTap;

  /// Whether an accept/decline call for this notification is in flight.
  final bool busy;

  /// `null` = not yet responded to this session; `true` = accepted;
  /// `false` = declined. See `NotificationsState.respondedRequestIds`.
  final bool? outcome;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final unread = !notification.read;
    // Used to also require `targetId != null` here, on the theory that a
    // null target meant nothing to act on. Dropped 2026-09-07: `targetId`
    // turned out not to track actionability at all (see
    // `NotificationsCubit._resolveRequestId` — it was non-null on a request
    // that had *already* been accepted). Every friend-request notification
    // gets the action row now; `NotificationsCubit.refresh()` precomputes
    // `respondedRequestIds` for ones already resolved, so those render the
    // outcome chip below instead of live buttons.
    final showRequestActions = notification.isFriendRequestType;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: unread ? colors.surf : Colors.transparent,
          border: Border.all(color: unread ? colors.ink : colors.line, width: 1.5),
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        clipBehavior: Clip.antiAlias,
        // The avatar is a sibling tap target (jumps to the actor's profile),
        // not nested inside the row's own `InkWell` below — two nested
        // `InkWell`s with independent `onTap`s would share one gesture arena
        // and could resolve ambiguously, so it sits outside it instead.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () =>
                  context.pushNamed(RouteNames.userProfile, pathParameters: {'userId': notification.actorId}),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AppAvatar(
                    initials: notification.actorUsername.initials,
                    seed: avatarSeedForId(notification.actorId),
                    imageUrl: notification.actorAvatarUrl,
                    size: 44,
                  ),
                  if (unread)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.yel,
                          border: Border.all(color: colors.ink, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: AppTextStyles.bodySm.copyWith(fontSize: 13, color: colors.ink),
                          children: [
                            TextSpan(
                              text: notification.actorUsername,
                              style: AppTextStyles.titleSm.copyWith(fontSize: 13, color: colors.ink),
                            ),
                            TextSpan(text: ' ${_verbFor(notification.type)}'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '${Formatters.relativeShort(notification.createdAt)} · ${notification.type.toUpperCase()}',
                        style: AppTextStyles.metaMono.copyWith(color: colors.ink2),
                      ),
                      if (showRequestActions) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (outcome != null)
                              _RequestOutcomeChip(accepted: outcome!)
                            else ...[
                              AppButton(label: 'Accept', dense: true, onPressed: busy ? null : onAccept),
                              const SizedBox(width: 8),
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
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Replaces a friend-request row's Accept/reject buttons once acted on this
/// session — deliberately muted (no active-button look) since it's a status,
/// not something else to tap.
class _RequestOutcomeChip extends StatelessWidget {
  const _RequestOutcomeChip({required this.accepted});
  final bool accepted;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: colors.line, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(accepted ? Icons.check : Icons.close, size: 13, color: colors.ink2),
          const SizedBox(width: 6),
          Text(
            accepted ? 'Accepted' : 'Declined',
            style: AppTextStyles.button.copyWith(color: colors.ink2),
          ),
        ],
      ),
    );
  }
}
