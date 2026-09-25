import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/date_label.dart';
import '../../../../shared/widgets/explore_title_menu.dart';
import '../../../../shared/widgets/paged_list_view.dart';
import '../../../../shared/widgets/segmented_tabs.dart';
import '../../domain/entities/project_entity.dart';
import '../bloc/showcase_cubit.dart';
import '../widgets/project_card.dart';
import '../widgets/publish_nudge_card.dart';
import '../widgets/shimmer_project_card.dart';
import '../widgets/tech_chip_row.dart';
import '../widgets/tech_filter_sheet.dart';

/// A list this short, unfiltered, gets a [PublishNudgeCard] after its last
/// row: with one or two projects the screen is mostly empty page, and the
/// header's Publish button alone was not enough of an invitation.
const int _sparseListMax = 2;

/// The showcase grid — `GET /projects`, sorted from the segmented control and
/// narrowed by tech from the chip row (the busiest facets of
/// `GET /projects/tech`) or the sheet behind it, which lists every facet and
/// holds the Featured toggle.
class ShowcasePage extends StatelessWidget {
  const ShowcasePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(create: (_) => sl<ShowcaseCubit>()..load(), child: const _ShowcaseView());
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
        child: Column(
          children: [
            // Tab chrome, no back arrow: this screen is the Explore branch's
            // other page, reached from the title menu on Communities, and Back
            // means "hop to Feed" as on every tab. Nothing here reads state, so
            // it sits outside every builder below.
            //
            // The date eyebrow is its own full-width row above the title/action
            // row rather than a third line inside the title column, which is
            // the shape Feed and Communities both use.
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 14, 14, 0),
              child: Align(alignment: Alignment.centerLeft, child: DateLabel()),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left-aligned inside the flexible slot so the tap
                        // target hugs the title instead of spanning the gap
                        // up to the Publish button.
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: ExploreTitleMenu(
                            current: ExploreDestination.showcase,
                            fontSize: AppTextStyles.displayXlFontSize - 2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          // Matches the title menu's own inset so the two
                          // lines share a left edge.
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            ExploreDestination.showcase.subtitle,
                            style: AppTextStyles.bodySm.copyWith(color: colors.ink2),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  AppButton(
                    label: 'Publish',
                    dense: true,
                    icon: const Icon(CupertinoIcons.add, size: 14),
                    onPressed: () => _publish(context, cubit),
                  ),
                ],
              ),
            ),
            // Sort takes the whole row; the tech facets get a row of their own
            // below rather than a dropdown squeezed in beside it.
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: BlocSelector<ShowcaseCubit, ShowcaseState, ProjectSort>(
                selector: (state) => state.sort,
                builder: (context, sort) => SegmentedTabs<ProjectSort>(
                  values: ProjectSort.values,
                  current: sort,
                  labelOf: (sort) => sort.label,
                  onSelect: cubit.setSort,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: BlocSelector<ShowcaseCubit, ShowcaseState, (List<TechCountEntity>, String?, bool)>(
                selector: (state) => (state.tech, state.selectedTech, state.featuredOnly),
                builder: (context, facets) {
                  final (tech, selected, featuredOnly) = facets;
                  return TechChipRow(
                    tech: tech,
                    selected: selected,
                    onSelect: cubit.setTech,
                    onOpenSheet: () => showTechFilterSheet(context, cubit),
                    sheetActive: featuredOnly,
                  );
                },
              ),
            ),
            Expanded(
              child: BlocBuilder<ShowcaseCubit, ShowcaseState>(
                builder: (context, state) {
                  final showNudge =
                      state.status == ShowcaseStatus.loaded &&
                      !state.hasMore &&
                      state.selectedTech == null &&
                      !state.featuredOnly &&
                      state.projects.isNotEmpty &&
                      state.projects.length <= _sparseListMax;

                  return RefreshIndicator(
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
                      skeleton: const [ShimmerProjectCard(), ShimmerProjectCard()],
                      itemCount: state.projects.length + (showNudge ? 1 : 0),
                      isLoadingMore: state.isLoadingMore,
                      onLoadMore: cubit.loadMore,
                      itemBuilder: (context, index) {
                        if (index == state.projects.length) {
                          return PublishNudgeCard(
                            projectCount: state.projects.length,
                            onPublish: () => _publish(context, cubit),
                          );
                        }
                        final project = state.projects[index];
                        return ProjectCard(
                          project: project,
                          busy: state.busyIds.contains(project.id),
                          onTap: () => _openProject(context, cubit, project),
                          onToggleLike: () => cubit.toggleLike(project),
                        );
                      },
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

  Future<void> _openProject(BuildContext context, ShowcaseCubit cubit, ProjectEntity project) async {
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
