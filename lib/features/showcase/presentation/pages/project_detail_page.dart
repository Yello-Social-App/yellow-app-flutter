import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/app_status_snackbar.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/shimmer_loading.dart';
import '../../domain/entities/project_entity.dart';
import '../bloc/project_detail_cubit.dart';

/// One project's screen.
///
/// [seed] is the entity the grid was showing, passed through the route's
/// `extra` so the header paints without a spinner. It is only a head start:
/// `GET /projects/{id}` is always re-read, so arriving here from a cold deep
/// link (no seed) works exactly the same.
class ProjectDetailPage extends StatelessWidget {
  const ProjectDetailPage({super.key, required this.projectId, this.seed});

  final String projectId;
  final ProjectEntity? seed;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ProjectDetailCubit>(param1: projectId, param2: seed)..load(),
      child: const _ProjectDetailView(),
    );
  }
}

class _ProjectDetailView extends StatelessWidget {
  const _ProjectDetailView();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cubit = context.read<ProjectDetailCubit>();

    return BlocBuilder<ProjectDetailCubit, ProjectDetailState>(
      builder: (context, state) {
        final project = state.project;

        // Like the community thread, this pops with what it is holding so the
        // grid underneath picks up a like made here — `canPop: false` is what
        // makes that work for the system back gesture too, not just the button.
        return PopScope<ProjectEntity>(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            context.pop(cubit.state.project);
          },
          child: Scaffold(
            backgroundColor: colors.bg,
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                    child: Row(
                      children: [
                        AppIconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => context.pop(cubit.state.project),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            project?.name ?? 'Project',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.titleLg.copyWith(color: colors.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: cubit.refresh,
                      color: colors.ink,
                      backgroundColor: colors.surf,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
                        children: [
                          // Flattened rather than a nested collection `if`,
                          // whose dangling `else` is legal but genuinely hard
                          // to read.
                          if (project != null)
                            _Body(project: project, isLiking: state.isLiking, cubit: cubit)
                          else if (state.status == ProjectDetailStatus.error)
                            ErrorView(
                              message: state.errorMessage ?? 'Could not load this project.',
                              onRetry: cubit.refresh,
                            )
                          else
                            const ShimmerListCard(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.project, required this.isLiking, required this.cubit});

  final ProjectEntity project;
  final bool isLiking;
  final ProjectDetailCubit cubit;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surf,
            border: Border.all(color: project.isFeatured ? colors.yel : colors.line, width: 1.5),
            borderRadius: BorderRadius.circular(AppRadii.xl),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.surf2,
                      border: Border.all(color: colors.ink, width: 1.5),
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    child: Text(project.emoji, style: const TextStyle(fontSize: 26)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.name,
                          style: AppTextStyles.displayLg.copyWith(color: colors.ink, fontSize: 22),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          project.tagline,
                          style: AppTextStyles.bodySm.copyWith(color: colors.ink2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      [
                        if (project.starCount != null)
                          '★ ${Formatters.compactCount(project.starCount!)}',
                        '${Formatters.compactCount(project.likeCount)} LIKES',
                        '${Formatters.compactCount(project.viewCount)} VIEWS',
                      ].join(' · '),
                      style: AppTextStyles.metaMono.copyWith(color: colors.ink3),
                    ),
                  ),
                  AppButton(
                    label: project.isLiked ? 'Liked' : 'Like',
                    variant: project.isLiked ? AppButtonVariant.subtle : AppButtonVariant.primary,
                    dense: true,
                    icon: Icon(
                      project.isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 14,
                      color: project.isLiked ? colors.red : colors.onYel,
                    ),
                    onPressed: isLiking ? null : cubit.toggleLike,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (project.tech.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('BUILT WITH', style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tech in project.tech)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: colors.surf2,
                    border: Border.all(color: colors.line, width: 1),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(tech, style: AppTextStyles.metaMono.copyWith(color: colors.ink2)),
                ),
            ],
          ),
        ],
        if (project.hasDescription) ...[
          const SizedBox(height: 18),
          Text('ABOUT', style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
          const SizedBox(height: 8),
          Text(project.description, style: AppTextStyles.body.copyWith(color: colors.ink2)),
        ],
        if (project.hasRepo || project.hasLive) ...[
          const SizedBox(height: 18),
          Text('LINKS', style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
          const SizedBox(height: 8),
          // Copy-to-clipboard rather than launching: this app has no
          // `url_launcher` dependency, and adding one for two links is a bigger
          // change than the feature warrants. Same affordance the feed already
          // uses for a post's share link.
          if (project.hasRepo)
            _LinkRow(label: 'REPOSITORY', url: project.repoUrl!, icon: Icons.code),
          if (project.hasLive)
            _LinkRow(label: 'LIVE', url: project.liveUrl!, icon: Icons.open_in_new),
        ],
        const SizedBox(height: 18),
        Text('BY', style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: colors.surf,
            border: Border.all(color: colors.line, width: 1.5),
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.pushNamed(
              RouteNames.userProfile,
              pathParameters: {'userId': project.authorId},
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  AppAvatar(
                    initials: project.authorDisplayName.initials,
                    seed: avatarSeedForId(project.authorId),
                    imageUrl: project.authorAvatarUrl,
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.authorDisplayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.titleMd.copyWith(color: colors.ink),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${project.authorUsername.withAtSign} · SHIPPED ${Formatters.relativeShort(project.createdAt)}',
                          style: AppTextStyles.metaMono.copyWith(color: colors.ink3),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: colors.ink3, size: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.label, required this.url, required this.icon});

  final String label;
  final String url;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colors.surf,
        border: Border.all(color: colors.line, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _copy(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 16, color: colors.ink2),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTextStyles.metaMono.copyWith(color: colors.ink3, fontSize: 9)),
                    const SizedBox(height: 2),
                    Text(
                      url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySm.copyWith(color: colors.ink),
                    ),
                  ],
                ),
              ),
              Icon(Icons.copy_rounded, size: 15, color: colors.ink3),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    AppStatusSnackbar.showSuccess(context, message: 'Link copied to clipboard.');
  }
}
