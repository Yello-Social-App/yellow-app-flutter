import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/feedback_entity.dart';
import '../../domain/usecases/safety_usecases.dart';

enum FeedbackStatus { initial, loading, loaded, error }

class FeedbackState extends Equatable {
  const FeedbackState({
    this.status = FeedbackStatus.initial,
    this.recent = const [],
    this.hasMore = false,
    this.isLoadingMore = false,
    this.feature,
    this.rating = 0,
    this.submitting = false,
    this.errorMessage,
  });

  final FeedbackStatus status;

  /// `GET /v1/feedback/me`, newest first — the "your recent feedback" list.
  final List<FeedbackEntity> recent;

  final bool hasMore;
  final bool isLoadingMore;

  /// The composer's current selection. Null / 0 until the user picks, which
  /// is what keeps Send disabled.
  final FeedbackFeature? feature;
  final int rating;

  final bool submitting;

  /// Set for the list's error card *and* for a failed submission; the page
  /// shows the second as a snackbar and never lets it replace rows that are
  /// already on screen.
  final String? errorMessage;

  bool get canSubmit => feature != null && rating >= 1 && rating <= 5 && !submitting;

  FeedbackState copyWith({
    FeedbackStatus? status,
    List<FeedbackEntity>? recent,
    bool? hasMore,
    bool? isLoadingMore,
    FeedbackFeature? feature,
    int? rating,
    bool? submitting,
    String? errorMessage,
  }) {
    return FeedbackState(
      status: status ?? this.status,
      recent: recent ?? this.recent,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      feature: feature ?? this.feature,
      rating: rating ?? this.rating,
      submitting: submitting ?? this.submitting,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, recent, hasMore, isLoadingMore, feature, rating, submitting, errorMessage];
}

/// Backs the Send feedback screen: the composer (pick a feature, rate it
/// 1-5, optionally say why) and the list of what you have already sent.
///
/// A factory in DI — nothing here is worth keeping alive once the screen is
/// popped, and a stale "your recent feedback" list would be the first thing
/// a returning user notices.
class FeedbackCubit extends Cubit<FeedbackState> {
  FeedbackCubit({required SubmitFeedbackUseCase submitFeedback, required GetMyFeedbackUseCase getMyFeedback})
    : _submitFeedback = submitFeedback,
      _getMyFeedback = getMyFeedback,
      super(const FeedbackState());

  final SubmitFeedbackUseCase _submitFeedback;
  final GetMyFeedbackUseCase _getMyFeedback;

  int _page = 0;

  void selectFeature(FeedbackFeature feature) => emit(state.copyWith(feature: feature, errorMessage: null));

  void setRating(int rating) => emit(state.copyWith(rating: rating, errorMessage: null));

  Future<void> load() async {
    emit(state.copyWith(status: FeedbackStatus.loading));
    _page = 0;
    final result = await _getMyFeedback(const SafetyPageParams());
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(status: FeedbackStatus.error, errorMessage: failure.message)),
      (page) => emit(
        state.copyWith(status: FeedbackStatus.loaded, recent: page.items, hasMore: page.hasMore),
      ),
    );
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.status != FeedbackStatus.loaded) return;
    emit(state.copyWith(isLoadingMore: true));
    final result = await _getMyFeedback(SafetyPageParams(page: _page + 1));
    if (isClosed) return;
    result.fold(
      // A failed "load more" keeps the rows already on screen — see
      // `PagedListView`'s doc for why it must not surface as an error card.
      (_) => emit(state.copyWith(isLoadingMore: false)),
      (page) {
        _page++;
        emit(
          state.copyWith(
            isLoadingMore: false,
            hasMore: page.hasMore,
            recent: [...state.recent, ...page.items],
          ),
        );
      },
    );
  }

  /// Sends the composer's current selection. Returns whether it went out,
  /// so the page can clear the note field and confirm. On success the new
  /// row is put straight on top of [FeedbackState.recent] rather than
  /// re-fetching page 0 — the response *is* the row.
  Future<bool> submit({String? note}) async {
    final feature = state.feature;
    if (feature == null || !state.canSubmit) return false;
    emit(state.copyWith(submitting: true, errorMessage: null));

    final result = await _submitFeedback(
      SubmitFeedbackParams(feature: feature, rating: state.rating, note: note),
    );
    if (isClosed) return false;

    return result.fold(
      (failure) {
        emit(state.copyWith(submitting: false, errorMessage: failure.message));
        return false;
      },
      (entry) {
        emit(
          state.copyWith(
            submitting: false,
            rating: 0,
            recent: [entry, ...state.recent],
            // A first successful send on a screen whose list failed to load
            // should still show that row rather than the error card.
            status: FeedbackStatus.loaded,
          ),
        );
        return true;
      },
    );
  }
}
