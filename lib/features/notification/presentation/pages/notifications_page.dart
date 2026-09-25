import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/app_status_snackbar.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/shimmer_loading.dart';
import '../../../../shared/widgets/yello_wordmark.dart';
import '../../domain/entities/notification_entity.dart';
import '../bloc/notifications_cubit.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<NotificationsCubit>.value(
      value: sl<NotificationsCubit>()..load(),
      child: const _NotificationsView(),
    );
  }
}

/// Icon shown for each wire `type` — `title`/`body` are the backend's own
/// frozen display text now (see `NotificationEntity`'s doc), so this glyph
/// is purely decorative context, not something that needs to describe the
/// event on its own.
IconData _iconFor(String type) => switch (type) {
  NotificationTypes.postCreated => CupertinoIcons.square_grid_2x2,
  NotificationTypes.postCommented || NotificationTypes.commentReplied => CupertinoIcons.bubble_left,
  NotificationTypes.commentReacted || NotificationTypes.postReacted => CupertinoIcons.heart,
  NotificationTypes.postReposted => CupertinoIcons.arrow_2_squarepath,
  NotificationTypes.friendRequestReceived => CupertinoIcons.person_add,
  NotificationTypes.friendRequestAccepted => CupertinoIcons.person,
  NotificationTypes.reportResolved => CupertinoIcons.shield,
  _ => CupertinoIcons.bell,
};

/// Pushes whatever screen [notification]'s `data` map points at — the same
/// deep-link keys a tapped push notification would carry (see the service
/// doc's "Deep-link keys by type" table). A type with nothing to navigate to
/// (or a payload missing the key it usually has — read defensively) is a
/// silent no-op rather than an error.
void _openDeepLink(BuildContext context, NotificationEntity notification) {
  switch (notification.type) {
    case NotificationTypes.postCreated:
    case NotificationTypes.postCommented:
    case NotificationTypes.commentReplied:
    case NotificationTypes.postReposted:
    case NotificationTypes.postReacted:
    case NotificationTypes.commentReacted:
      final postId = notification.data['postId'];
      if (postId != null) context.pushNamed(RouteNames.postDetail, pathParameters: {'postId': postId});
    case NotificationTypes.friendRequestReceived:
    case NotificationTypes.friendRequestAccepted:
      final actorId = notification.actorId;
      if (actorId != null) context.pushNamed(RouteNames.userProfile, pathParameters: {'userId': actorId});
    case NotificationTypes.reportResolved:
      // No `postId` to open, by design: the row names neither the post nor
      // its author. Privacy & safety is where the outcome is readable —
      // the same place `ReportsDestination` sends a tapped push.
      context.pushNamed(RouteNames.privacySafety);
  }
}

/// Runs an accept/decline call and surfaces a snackbar only on failure —
/// same "silent on success, snackbar on failure" convention as
/// `post_detail_page.dart`'s `_confirmDeletePost`/`_shareLink`.
Future<void> _respondToFriendRequest(
  BuildContext context,
  NotificationsCubit cubit,
  NotificationEntity notification, {
  required bool accept,
}) async {
  final ok = accept ? await cubit.acceptFriendRequest(notification) : await cubit.declineFriendRequest(notification);
  if (!context.mounted || ok) return;
  AppStatusSnackbar.showError(context, message: accept ? 'Could not accept request.' : 'Could not decline request.');
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
            final loadingEmpty = state.status == NotificationsStatus.loading && state.items.isEmpty;
            final errorEmpty = state.status == NotificationsStatus.error && state.items.isEmpty;
            final showLoadMoreFooter = state.hasMore && state.items.isNotEmpty;

            // header(1) + body/rows + optional load-more footer(1).
            final bodyCount = loadingEmpty || errorEmpty || state.items.isEmpty ? 1 : state.items.length;
            final itemCount = 1 + bodyCount + (showLoadMoreFooter ? 1 : 0);

            return RefreshIndicator(
              onRefresh: cubit.refresh,
              color: colors.ink,
              backgroundColor: colors.surf,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                itemCount: itemCount,
                itemBuilder: (context, index) {
                  if (index == 0) return _Header(state: state, cubit: cubit);
                  final bodyIndex = index - 1;

                  if (bodyIndex < bodyCount && (loadingEmpty || errorEmpty || state.items.isEmpty)) {
                    if (loadingEmpty) return const ShimmerListCard();
                    if (errorEmpty) {
                      return ErrorView(message: state.errorMessage ?? 'Could not load your notifications.', onRetry: cubit.refresh);
                    }
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        "Nothing yet — you'll see likes, comments, reposts, friends' posts and friend requests here.",
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySm.copyWith(color: colors.ink2),
                      ),
                    );
                  }

                  if (bodyIndex < bodyCount) {
                    final n = state.items[bodyIndex];
                    return _DismissibleNotificationRow(
                      key: ValueKey(n.id),
                      notification: n,
                      cubit: cubit,
                      busy: state.busyRequestIds.contains(n.id),
                      outcome: state.respondedRequestIds[n.id],
                    );
                  }

                  // Load-more footer.
                  if (!state.isLoadingMore) {
                    WidgetsBinding.instance.addPostFrameCallback((_) => cubit.loadMore());
                  }
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state, required this.cubit});
  final NotificationsState state;
  final NotificationsCubit cubit;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
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
                const YelloWordmark(fontSize: AppTextStyles.displayXlFontSize, text: 'Signals'),
              ],
            ),
          ),
          AppIconButton(
            icon: const Icon(CupertinoIcons.gear),
            onPressed: () => context.pushNamed(RouteNames.notificationPreferences),
            size: 38,
          ),
          const SizedBox(width: 8),
          AppButton(
            label: 'Mark read',
            variant: AppButtonVariant.outline,
            dense: true,
            onPressed: state.unreadCount == 0 ? null : cubit.markAllRead,
          ),
        ],
      ),
    );
  }
}

class _DismissibleNotificationRow extends StatelessWidget {
  const _DismissibleNotificationRow({
    super.key,
    required this.notification,
    required this.cubit,
    required this.busy,
    required this.outcome,
  });

  final NotificationEntity notification;
  final NotificationsCubit cubit;
  final bool busy;
  final bool? outcome;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Dismissible(
      key: ValueKey('dismiss-${notification.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => cubit.deleteNotification(notification),
      background: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(color: colors.red, borderRadius: BorderRadius.circular(AppRadii.lg)),
          child: const Icon(CupertinoIcons.delete, color: Colors.white),
        ),
      ),
      child: _NotificationRow(
        notification: notification,
        onTap: () {
          cubit.openNotification(notification);
          _openDeepLink(context, notification);
        },
        busy: busy,
        outcome: outcome,
        onAccept: () => _respondToFriendRequest(context, cubit, notification, accept: true),
        onDecline: () => _respondToFriendRequest(context, cubit, notification, accept: false),
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
    final showRequestActions = notification.isFriendRequestReceived;

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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: colors.surf2, shape: BoxShape.circle),
                  child: Icon(_iconFor(notification.type), size: 18, color: colors.ink2),
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
                if (notification.aggregateCount > 1)
                  Positioned(
                    left: -4,
                    bottom: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: colors.ink,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Text(
                        '${notification.aggregateCount}',
                        style: AppTextStyles.metaMonoSm.copyWith(color: colors.bg),
                      ),
                    ),
                  ),
              ],
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
                      Text(
                        notification.title,
                        style: AppTextStyles.titleMd.copyWith(color: colors.ink),
                      ),
                      if (notification.body.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          notification.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySm.copyWith(color: colors.ink2),
                        ),
                      ],
                      const SizedBox(height: 7),
                      Text(
                        // `updatedAt`, not `createdAt` — it's last activity
                        // (bumped by aggregation), which is what "how long
                        // ago" should mean for a row that collapsed several
                        // events. See `NotificationEntity.updatedAt`'s doc.
                        Formatters.relativeShort(notification.updatedAt),
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
                                    child: Icon(CupertinoIcons.xmark, size: 15, color: colors.ink2),
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
          Icon(accepted ? CupertinoIcons.checkmark : CupertinoIcons.xmark, size: 13, color: colors.ink2),
          const SizedBox(width: 6),
          Text(accepted ? 'Accepted' : 'Declined', style: AppTextStyles.button.copyWith(color: colors.ink2)),
        ],
      ),
    );
  }
}
