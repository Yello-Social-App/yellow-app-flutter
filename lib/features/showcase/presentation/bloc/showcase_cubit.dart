import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/project_entity.dart';
import '../../domain/usecases/showcase_usecases.dart';

enum ShowcaseStatus { initial, loading, loaded, error }

class ShowcaseState extends Equatable {
  const ShowcaseState({
    this.status = ShowcaseStatus.initial,
    this.projects = const [],
    this.tech = const [],
    this.sort = ProjectSort.trending,
    this.selectedTech,
    this.featuredOnly = false,
    this.page = 0,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.busyIds = const {},
  });

  final ShowcaseStatus status;
  final List<ProjectEntity> projects;

  /// Filter vocabulary from `GET /projects/tech` — empty until it resolves, and
  /// it resolving is not required for the grid to work.
  final List<TechCountEntity> tech;
  final ProjectSort sort;

  /// Null means no tech filter.
  final String? selectedTech;
  final bool featuredOnly;
  final int page;
  final bool hasMore;
  final bool isLoadingMore;
  final String? errorMessage;

  /// Project ids with an in-flight like/unlike.
  final Set<String> busyIds;

  ShowcaseState copyWith({
    ShowcaseStatus? status,
    List<ProjectEntity>? projects,
    List<TechCountEntity>? tech,
    ProjectSort? sort,
    String? selectedTech,
    bool clearTech = false,
    bool? featuredOnly,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
    String? errorMessage,
    Set<String>? busyIds,
  }) {
    return ShowcaseState(
      status: status ?? this.status,
      projects: projects ?? this.projects,
      tech: tech ?? this.tech,
      sort: sort ?? this.sort,
      // `selectedTech` is itself nullable, so clearing it needs its own flag —
      // null alone would read as "leave it as it was".
      selectedTech: clearTech ? null : (selectedTech ?? this.selectedTech),
      featuredOnly: featuredOnly ?? this.featuredOnly,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: errorMessage,
      busyIds: busyIds ?? this.busyIds,
    );
  }

  @override
  List<Object?> get props => [
    status,
    projects,
    tech,
    sort,
    selectedTech,
    featuredOnly,
    page,
    hasMore,
    isLoadingMore,
    errorMessage,
    busyIds,
  ];
}

/// The showcase grid — `GET /projects`, offset-paged, with the tech facets from
/// `GET /projects/tech` driving the filter row.
class ShowcaseCubit extends Cubit<ShowcaseState> {
  ShowcaseCubit({
    required GetProjectsUseCase getProjects,
    required GetProjectTechUseCase getTech,
    required ToggleProjectLikeUseCase toggleLike,
  })  : _getProjects = getProjects,
        _getTech = getTech,
        _toggleLike = toggleLike,
        super(const ShowcaseState());

  final GetProjectsUseCase _getProjects;
  final GetProjectTechUseCase _getTech;
  final ToggleProjectLikeUseCase _toggleLike;

  int _generation = 0;

  Future<void> load() async {
    if (state.status == ShowcaseStatus.loaded) return;
    await refresh();
  }

  Future<void> refresh() async {
    _generation++;
    final generation = _generation;
    emit(state.copyWith(status: ShowcaseStatus.loading));

    // The facets are cosmetic; start them alongside the grid and never let a
    // failure there hold up or fail the grid itself.
    final techFuture = _getTech(const GetProjectTechParams());
    final result = await _getProjects(
      GetProjectsParams(
        sort: state.sort,
        tech: state.selectedTech,
        featured: state.featuredOnly ? true : null,
      ),
    );
    if (isClosed || generation != _generation) return;

    result.fold(
      (failure) => emit(state.copyWith(status: ShowcaseStatus.error, errorMessage: failure.message)),
      (page) => emit(
        state.copyWith(
          status: ShowcaseStatus.loaded,
          projects: page.projects,
          page: 0,
          hasMore: page.hasMore,
          isLoadingMore: false,
        ),
      ),
    );

    final techResult = await techFuture;
    if (isClosed || generation != _generation) return;
    techResult.fold((_) {}, (tech) => emit(state.copyWith(tech: tech)));
  }

  Future<void> setSort(ProjectSort sort) async {
    if (sort == state.sort) return;
    emit(state.copyWith(sort: sort, projects: const [], status: ShowcaseStatus.loading));
    await _fetchFirstPage();
  }

  /// Pass null, or the already-selected value, to clear the filter.
  Future<void> setTech(String? tech) async {
    final next = tech == state.selectedTech ? null : tech;
    if (next == state.selectedTech) return;
    emit(
      state.copyWith(
        selectedTech: next,
        clearTech: next == null,
        projects: const [],
        status: ShowcaseStatus.loading,
      ),
    );
    await _fetchFirstPage();
  }

  Future<void> toggleFeaturedOnly() async {
    emit(
      state.copyWith(
        featuredOnly: !state.featuredOnly,
        projects: const [],
        status: ShowcaseStatus.loading,
      ),
    );
    await _fetchFirstPage();
  }

  Future<void> _fetchFirstPage() async {
    _generation++;
    final generation = _generation;
    final result = await _getProjects(
      GetProjectsParams(
        sort: state.sort,
        tech: state.selectedTech,
        featured: state.featuredOnly ? true : null,
      ),
    );
    if (isClosed || generation != _generation) return;
    result.fold(
      (failure) => emit(state.copyWith(status: ShowcaseStatus.error, errorMessage: failure.message)),
      (page) => emit(
        state.copyWith(
          status: ShowcaseStatus.loaded,
          projects: page.projects,
          page: 0,
          hasMore: page.hasMore,
          isLoadingMore: false,
        ),
      ),
    );
  }

  Future<void> loadMore() async {
    if (state.status != ShowcaseStatus.loaded || !state.hasMore || state.isLoadingMore) return;

    final generation = _generation;
    final nextPage = state.page + 1;
    emit(state.copyWith(isLoadingMore: true));

    final result = await _getProjects(
      GetProjectsParams(
        sort: state.sort,
        tech: state.selectedTech,
        featured: state.featuredOnly ? true : null,
        page: nextPage,
      ),
    );
    if (isClosed || generation != _generation) return;
    result.fold(
      (_) => emit(state.copyWith(isLoadingMore: false, hasMore: false)),
      (page) => emit(
        state.copyWith(
          projects: [...state.projects, ...page.projects],
          page: nextPage,
          hasMore: page.hasMore,
          isLoadingMore: false,
        ),
      ),
    );
  }

  Future<void> toggleLike(ProjectEntity project) async {
    if (state.busyIds.contains(project.id)) return;
    emit(state.copyWith(busyIds: {...state.busyIds, project.id}));

    final result = await _toggleLike(project);
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        state.copyWith(errorMessage: failure.message, busyIds: {...state.busyIds}..remove(project.id)),
      ),
      (updated) => emit(
        state.copyWith(projects: _replace(updated), busyIds: {...state.busyIds}..remove(project.id)),
      ),
    );
  }

  /// Applies a change made on the detail screen back onto the grid.
  void applyUpdated(ProjectEntity project) => emit(state.copyWith(projects: _replace(project)));

  List<ProjectEntity> _replace(ProjectEntity updated) => [
    for (final project in state.projects)
      if (project.id == updated.id) updated else project,
  ];
}
