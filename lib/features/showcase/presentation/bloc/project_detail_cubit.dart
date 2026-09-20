import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/project_entity.dart';
import '../../domain/usecases/showcase_usecases.dart';

enum ProjectDetailStatus { initial, loading, loaded, error }

class ProjectDetailState extends Equatable {
  const ProjectDetailState({
    this.status = ProjectDetailStatus.initial,
    this.project,
    this.isLiking = false,
    this.errorMessage,
  });

  final ProjectDetailStatus status;
  final ProjectEntity? project;
  final bool isLiking;
  final String? errorMessage;

  ProjectDetailState copyWith({
    ProjectDetailStatus? status,
    ProjectEntity? project,
    bool? isLiking,
    String? errorMessage,
  }) {
    return ProjectDetailState(
      status: status ?? this.status,
      project: project ?? this.project,
      isLiking: isLiking ?? this.isLiking,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, project, isLiking, errorMessage];
}

/// One project's screen. Unlike a community thread, a project *does* have a
/// `GET /projects/{id}` route, so this screen is fully deep-linkable and loads
/// from the id alone — [seed] only exists to paint the header immediately when
/// the user arrived from the grid.
class ProjectDetailCubit extends Cubit<ProjectDetailState> {
  ProjectDetailCubit({
    required this.projectId,
    ProjectEntity? seed,
    required GetProjectUseCase getProject,
    required RecordProjectViewUseCase recordView,
    required ToggleProjectLikeUseCase toggleLike,
  })  : _getProject = getProject,
        _recordView = recordView,
        _toggleLike = toggleLike,
        super(
          seed == null
              ? const ProjectDetailState()
              : ProjectDetailState(status: ProjectDetailStatus.loaded, project: seed),
        );

  final String projectId;
  final GetProjectUseCase _getProject;
  final RecordProjectViewUseCase _recordView;
  final ToggleProjectLikeUseCase _toggleLike;

  bool _viewRecorded = false;

  Future<void> load() async {
    await refresh();
    // One view per screen open, after the project is known to exist. The
    // endpoint is rate-limited and the repository swallows its failures, so this
    // is genuinely fire-and-forget.
    if (!_viewRecorded && !isClosed && state.project != null) {
      _viewRecorded = true;
      await _recordView(projectId);
    }
  }

  Future<void> refresh() async {
    // A seeded project means something is already on screen; don't blank it.
    if (state.project == null) emit(state.copyWith(status: ProjectDetailStatus.loading));

    final result = await _getProject(projectId);
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        state.copyWith(
          // With a seed already showing, a failed refresh is a message, not an
          // error page that throws away what the user can already see.
          status: state.project == null ? ProjectDetailStatus.error : ProjectDetailStatus.loaded,
          errorMessage: failure.message,
        ),
      ),
      (project) => emit(state.copyWith(status: ProjectDetailStatus.loaded, project: project)),
    );
  }

  Future<void> toggleLike() async {
    final project = state.project;
    if (project == null || state.isLiking) return;
    emit(state.copyWith(isLiking: true));

    final result = await _toggleLike(project);
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(isLiking: false, errorMessage: failure.message)),
      (updated) => emit(state.copyWith(project: updated, isLiking: false)),
    );
  }
}
