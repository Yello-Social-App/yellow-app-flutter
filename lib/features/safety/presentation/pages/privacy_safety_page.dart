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
import '../../../../shared/extensions/string_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/app_status_snackbar.dart';
import '../../../../shared/widgets/paged_list_view.dart';
import '../../../../shared/widgets/segmented_tabs.dart';
import '../../domain/entities/muted_user_entity.dart';
import '../../domain/entities/post_report_entity.dart';
import '../bloc/privacy_safety_cubit.dart';

enum _SafetyTab { reports, muted }

/// Settings → Privacy & safety: the reports you have filed and how they
/// were decided, and the accounts whose posts you have muted.
///
/// Also where a tapped `REPORT_RESOLVED` push lands — the push deliberately
/// carries nothing about the post or its author, so the outcome is only
/// readable here, from `GET /v1/reports/me`.
class PrivacySafetyPage extends StatelessWidget {
  const PrivacySafetyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PrivacySafetyCubit>()..load(),
      child: const _PrivacySafetyView(),
    );
  }
}

class _PrivacySafetyView extends StatefulWidget {
  const _PrivacySafetyView();

  @override
  State<_PrivacySafetyView> createState() => _PrivacySafetyViewState();
}

class _PrivacySafetyViewState extends State<_PrivacySafetyView> {
  _SafetyTab _tab = _SafetyTab.reports;

  Future<void> _unmute(PrivacySafetyCubit cubit, MutedUserEntity user) async {
    final ok = await cubit.unmute(user.userId);
    if (!mounted) return;
    if (ok) {
      AppStatusSnackbar.showSuccess(context, message: '${user.displayName} is unmuted.');
    } else {
      AppStatusSnackbar.showError(context, message: 'Could not unmute ${user.displayName}.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cubit = context.read<PrivacySafetyCubit>();

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Row(
                children: [
                  AppIconButton(
                    icon: const Icon(CupertinoIcons.back),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 12),
                  Text('Privacy & safety', style: AppTextStyles.titleLg.copyWith(color: colors.ink)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
              child: SegmentedTabs<_SafetyTab>(
                values: _SafetyTab.values,
                current: _tab,
                labelOf: (tab) => tab == _SafetyTab.reports ? 'Your reports' : 'Muted',
                onSelect: (tab) => setState(() => _tab = tab),
              ),
            ),
            Expanded(
              child: BlocBuilder<PrivacySafetyCubit, PrivacySafetyState>(
                builder: (context, state) => switch (_tab) {
                  _SafetyTab.reports => PagedListView(
                    isLoading: state.reportsStatus == PrivacySafetyStatus.loading && state.reports.isEmpty,
                    errorMessage: state.reports.isEmpty ? state.reportsError : null,
                    onRetry: cubit.loadReports,
                    isEmpty: state.reports.isEmpty,
                    emptyTitle: 'No reports',
                    emptyHint: "Posts you report show up here with what a moderator decided.",
                    itemCount: state.reports.length,
                    isLoadingMore: state.reportsLoadingMore,
                    onLoadMore: cubit.loadMoreReports,
                    itemBuilder: (context, index) => _ReportRow(report: state.reports[index]),
                  ),
                  _SafetyTab.muted => PagedListView(
                    isLoading: state.mutedStatus == PrivacySafetyStatus.loading && state.muted.isEmpty,
                    errorMessage: state.muted.isEmpty ? state.mutedError : null,
                    onRetry: cubit.loadMuted,
                    isEmpty: state.muted.isEmpty,
                    emptyTitle: 'Nobody muted',
                    emptyHint: "Muting takes someone's posts out of your feed. They are never told.",
                    itemCount: state.muted.length,
                    isLoadingMore: state.mutedLoadingMore,
                    onLoadMore: cubit.loadMoreMuted,
                    itemBuilder: (context, index) {
                      final user = state.muted[index];
                      return _MutedRow(
                        user: user,
                        busy: state.unmuting.contains(user.userId),
                        onUnmute: () => _unmute(cubit, user),
                      );
                    },
                  ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.report});

  final PostReportEntity report;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final snapshot = report.post;
    final statusColor = switch (report.status) {
      ReportStatus.underReview => colors.ink2,
      ReportStatus.actionTaken => colors.grn,
      ReportStatus.noViolation => colors.ink3,
    };
    // The post can be gone by the time its report resolves, which nulls
    // `postId` — the snapshot stays readable either way, so the row is
    // only tappable while there is something to open.
    final postId = report.postId;

    return InkWell(
      onTap: postId == null
          ? null
          : () => context.pushNamed(RouteNames.postDetail, pathParameters: {'postId': postId}),
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surf,
          border: Border.all(color: colors.line, width: 1.5),
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    report.reason.label,
                    style: AppTextStyles.bodySm.copyWith(color: colors.ink, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  Formatters.relativeShort(report.resolvedAt ?? report.createdAt),
                  style: AppTextStyles.metaMonoSm.copyWith(color: colors.ink3),
                ),
              ],
            ),
            if (snapshot?.authorName != null) ...[
              const SizedBox(height: 4),
              Text(
                'Posted by ${snapshot!.authorName}',
                style: AppTextStyles.metaMonoSm.copyWith(color: colors.ink2),
              ),
            ],
            if ((snapshot?.excerpt ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                snapshot!.excerpt!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySm.copyWith(color: colors.ink2),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              report.status.label,
              style: AppTextStyles.metaMonoSm.copyWith(color: statusColor, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _MutedRow extends StatelessWidget {
  const _MutedRow({required this.user, required this.busy, required this.onUnmute});

  final MutedUserEntity user;
  final bool busy;
  final VoidCallback onUnmute;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surf,
        border: Border.all(color: colors.line, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Row(
        children: [
          AppAvatar(
            initials: Formatters.initialsFrom(user.displayName),
            seed: avatarSeedForId(user.userId),
            size: 40,
            imageUrl: user.avatarUrl,
            cacheKey: user.userId,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySm.copyWith(color: colors.ink, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${user.username.withAtSign} · muted ${Formatters.relativeShort(user.since)}',
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.metaMonoSm.copyWith(color: colors.ink2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: busy ? null : onUnmute,
            child: Text(busy ? 'Unmuting…' : 'Unmute'),
          ),
        ],
      ),
    );
  }
}
