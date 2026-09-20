import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/project_entity.dart';
import '../../domain/usecases/showcase_usecases.dart';

class PublishProjectState extends Equatable {
  const PublishProjectState({this.isSubmitting = false, this.errorMessage});

  final bool isSubmitting;
  final String? errorMessage;

  PublishProjectState copyWith({bool? isSubmitting, String? errorMessage}) {
    return PublishProjectState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [isSubmitting, errorMessage];
}

/// Publishes one project. As with the community composer, the form's draft
/// lives in the page's controllers; this owns only the in-flight flag that
/// stops a double-tapped Publish from creating two projects.
class PublishProjectCubit extends Cubit<PublishProjectState> {
  PublishProjectCubit(this._publish) : super(const PublishProjectState());

  final PublishProjectUseCase _publish;

  /// Returns the created project, or null on failure — in which case
  /// [PublishProjectState.errorMessage] says why.
  Future<ProjectEntity?> publish({
    required String name,
    required String tagline,
    required String emoji,
    required List<String> tech,
    String? repoUrl,
    String? liveUrl,
  }) async {
    if (state.isSubmitting) return null;
    emit(state.copyWith(isSubmitting: true));

    final result = await _publish(
      PublishProjectParams(
        name: name,
        tagline: tagline,
        emoji: emoji,
        tech: tech,
        repoUrl: repoUrl,
        liveUrl: liveUrl,
      ),
    );
    if (isClosed) return null;

    return result.fold(
      (failure) {
        emit(state.copyWith(isSubmitting: false, errorMessage: failure.message));
        return null;
      },
      (project) {
        emit(state.copyWith(isSubmitting: false));
        return project;
      },
    );
  }
}
