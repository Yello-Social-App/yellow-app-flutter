import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/post_entity.dart';
import '../../domain/entities/reactor_entity.dart';
import '../../domain/usecases/react_usecases.dart';

enum ReactorsStatus { initial, loading, loadingMore, loaded, error }

class ReactorsState extends Equatable {
  const ReactorsState({
    this.status = ReactorsStatus.initial,
    this.reactors = const [],
    this.hasMore = false,
    this.page = 0,
    this.errorMessage,
  });

  final ReactorsStatus status;
  final List<ReactorEntity> reactors;
  final bool hasMore;
  final int page;
  final String? errorMessage;

  ReactorsState copyWith({
    ReactorsStatus? status,
    List<ReactorEntity>? reactors,
    bool? hasMore,
    int? page,
    String? errorMessage,
  }) {
    return ReactorsState(
      status: status ?? this.status,
      reactors: reactors ?? this.reactors,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, reactors, hasMore, page, errorMessage];
}

/// Backs the paginated "who reacted" sheet (`showReactorsSheet`) —
/// `GET /reactions/{targetType}/{targetId}`, optionally filtered to one
/// [ReactionType] (the row the viewer tapped in the reaction-breakdown
/// sheet). Fresh per open via `registerFactoryParam`, same convention as
/// `PostDetailCubit` (see `injection.dart`) — this list's state has no
/// reason to survive past the sheet that opened it.
class ReactorsCubit extends Cubit<ReactorsState> {
  ReactorsCubit({
    required String targetType,
    required String targetId,
    required ReactionType? type,
    required GetReactorsUseCase getReactors,
  }) : _targetType = targetType,
       _targetId = targetId,
       _type = type,
       _getReactors = getReactors,
       super(const ReactorsState());

  final String _targetType;
  final String _targetId;
  final ReactionType? _type;
  final GetReactorsUseCase _getReactors;

  Future<void> load() async {
    emit(state.copyWith(status: ReactorsStatus.loading));
    final result = await _getReactors(
      GetReactorsParams(targetType: _targetType, targetId: _targetId, type: _type, page: 0),
    );
    result.fold(
      (failure) => emit(state.copyWith(status: ReactorsStatus.error, errorMessage: failure.message)),
      (page) =>
          emit(state.copyWith(status: ReactorsStatus.loaded, reactors: page.reactors, hasMore: page.hasMore, page: 0)),
    );
  }

  /// No-op if a page is already in flight or the last page was reached —
  /// same missing-guard shape this codebase already had a real bug from
  /// elsewhere (double-tap double-firing a reaction), just for pagination
  /// instead of a mutating tap.
  Future<void> loadMore() async {
    if (state.status == ReactorsStatus.loadingMore || !state.hasMore) return;
    emit(state.copyWith(status: ReactorsStatus.loadingMore));
    final nextPage = state.page + 1;
    final result = await _getReactors(
      GetReactorsParams(targetType: _targetType, targetId: _targetId, type: _type, page: nextPage),
    );
    result.fold(
      (failure) => emit(state.copyWith(status: ReactorsStatus.loaded, errorMessage: failure.message)),
      (page) => emit(
        state.copyWith(
          status: ReactorsStatus.loaded,
          reactors: [...state.reactors, ...page.reactors],
          hasMore: page.hasMore,
          page: nextPage,
        ),
      ),
    );
  }
}
