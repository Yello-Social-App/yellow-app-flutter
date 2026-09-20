import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/community_post_entity.dart';
import '../../domain/usecases/communities_usecases.dart';

class CreateCommunityPostState extends Equatable {
  const CreateCommunityPostState({this.isSubmitting = false, this.errorMessage});

  final bool isSubmitting;
  final String? errorMessage;

  CreateCommunityPostState copyWith({bool? isSubmitting, String? errorMessage}) {
    return CreateCommunityPostState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [isSubmitting, errorMessage];
}

/// Publishes one new thread. Deliberately tiny: the composer's own draft lives
/// in the page's `TextEditingController`s (nothing needs it to survive a
/// rebuild), so all this owns is the in-flight flag that keeps a double-tapped
/// Publish from creating two threads.
class CreateCommunityPostCubit extends Cubit<CreateCommunityPostState> {
  CreateCommunityPostCubit(this._createPost) : super(const CreateCommunityPostState());

  final CreateCommunityPostUseCase _createPost;

  /// Returns the created thread, or null when it failed — in which case
  /// [CreateCommunityPostState.errorMessage] says why.
  Future<CommunityPostEntity?> publish({
    required String slug,
    required String title,
    required String tag,
    String? body,
  }) async {
    if (state.isSubmitting) return null;
    emit(state.copyWith(isSubmitting: true));

    final result = await _createPost(
      CreateCommunityPostParams(slug: slug, title: title, tag: tag, body: body),
    );
    if (isClosed) return null;

    return result.fold(
      (failure) {
        emit(state.copyWith(isSubmitting: false, errorMessage: failure.message));
        return null;
      },
      (post) {
        emit(state.copyWith(isSubmitting: false));
        return post;
      },
    );
  }
}
