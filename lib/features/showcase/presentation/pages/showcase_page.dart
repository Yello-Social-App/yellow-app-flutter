import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/filter_chip_pill.dart';
import '../../../../shared/widgets/paged_list_view.dart';
import '../../domain/entities/project_entity.dart';
import '../bloc/showcase_cubit.dart';
import '../widgets/project_card.dart';

/// The showcase grid — `GET /projects`, with the tech facets from
/// `GET /projects/tech` as the filter row.
class ShowcasePage extends StatelessWidget {
  const ShowcasePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ShowcaseCubit>()..load(),
      child: const _ShowcaseView(),
    );
  }
}

class _ShowcaseView extends StatelessWidget {
  const _ShowcaseView();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cubit = context.read<ShowcaseCubit>();

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<ShowcaseCubit, ShowcaseState>(
          builder: (context, state) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                  child: Row(
                    children: [
                      AppIconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: AppTextStyles.displayXl.copyWith(color: colors.ink, fontSize: 28),
                            children: [
                              const TextSpan(text: 'Built'),
                              TextSpan(text: '.', style: TextStyle(color: colors.yel)),
                            ],
                          ),
                        ),
                      ),
                      AppButton(
                        label: 'Publish',
                        dense: true,
                        icon: const Icon(Icons.add, size: 14),
                        onPressed: () => _publish(context, cubit),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final sort in ProjectSort.values) ...[
                          FilterChipPill(
                            label: sort.label,
                            selected: state.sort == sort,
                            onTap: () => cubit.setSort(sort),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Container(width: 1, height: 22, color: colors.line),
                        const SizedBox(width: 6),
                        FilterChipPill(
                          label: 'Featured',
                          selected: state.featuredOnly,
                          onTap: cubit.toggleFeaturedOnly,
                        ),
                        // The tech vocabulary comes from the server, so these
                        // chips always match what is actually published rather
                        // than a hardcoded list that drifts.
                        for (final tech in state.tech) ...[
                          const SizedBox(width: 6),
                          FilterChipPill(
                            label: tech.name,
                            trailing: '${tech.projectCount}',
                            selected: state.selectedTech == tech.name,
                            onTap: () => cubit.setTech(tech.name),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: cubit.refresh,
                    color: colors.ink,
                    backgroundColor: colors.surf,
                    child: PagedListView(
                      isLoading: state.status == ShowcaseStatus.loading && state.projects.isEmpty,
                      errorMessage: state.status == ShowcaseStatus.error && state.projects.isEmpty
                          ? (state.errorMessage ?? 'Could not load the showcase.')
                          : null,
                      onRetry: cubit.refresh,
                      isEmpty: state.status == ShowcaseStatus.loaded && state.projects.isEmpty,
                      emptyTitle: 'NOTHING SHIPPED YET',
                      emptyHint: state.selectedTech == null && !state.featuredOnly
                          ? 'Be the first to publish a project.'
                          : 'Nothing matches this filter.',
                      itemCount: state.projects.length,
                      isLoadingMore: state.isLoadingMore,
                      onLoadMore: cubit.loadMore,
                      itemBuilder: (context, index) {
                        final project = state.projects[index];
                        return ProjectCard(
                          project: project,
                          busy: state.busyIds.contains(project.id),
                          onTap: () => _openProject(context, cubit, project),
                          onToggleLike: () => cubit.toggleLike(project),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openProject(
    BuildContext context,
    ShowcaseCubit cubit,
    ProjectEntity project,
  ) async {
    // The entity rides along in `extra` so the detail screen can paint its
    // header immediately, but that screen still re-reads
    // `GET /projects/{id}` — unlike a community thread, a project *is*
    // fetchable by id, so a cold deep link works too.
    final updated = await context.pushNamed<ProjectEntity>(
      RouteNames.project,
      pathParameters: {'projectId': project.id},
      extra: project,
    );
    if (updated != null) cubit.applyUpdated(updated);
  }

  Future<void> _publish(BuildContext context, ShowcaseCubit cubit) async {
    final created = await context.pushNamed<ProjectEntity>(RouteNames.publishProject);
    // A refresh rather than a prepend: the grid is server-sorted (trending /
    // stars), so a brand-new project's real position is the server's to decide.
    if (created != null) await cubit.refresh();
  }
}
