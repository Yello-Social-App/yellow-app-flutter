import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/muted_user_entity.dart';
import '../../domain/entities/post_report_entity.dart';
import '../../domain/usecases/safety_usecases.dart';

enum PrivacySafetyStatus { initial, loading, loaded, error }

/// One screen, two independent lists — each with its own status, paging and
/// error, because either endpoint can fail without the other. Flattening
/// them into one status would blank a list that loaded fine.
class PrivacySafetyState extends Equatable {
  const PrivacySafetyState({
    this.reportsStatus = PrivacySafetyStatus.initial,
    this.reports = const [],
    this.reportsHasMore = false,
    this.reportsLoadingMore = false,
    this.reportsError,
    this.mutedStatus = PrivacySafetyStatus.initial,
    this.muted = const [],
    this.mutedHasMore = false,
    this.mutedLoadingMore = false,
    this.mutedError,
    this.unmuting = const {},
  });

  final PrivacySafetyStatus reportsStatus;
  final List<PostReportEntity> reports;
  final bool reportsHasMore;
  final bool reportsLoadingMore;
  final String? reportsError;

  final PrivacySafetyStatus mutedStatus;
  final List<MutedUserEntity> muted;
  final bool mutedHasMore;
  final bool mutedLoadingMore;
  final String? mutedError;

  /// User ids with an unmute in flight — drives the row's disabled state
  /// and is the re-entrancy guard, so a double-tap cannot fire twice.
  final Set<String> unmuting;

  PrivacySafetyState copyWith({
    PrivacySafetyStatus? reportsStatus,
    List<PostReportEntity>? reports,
    bool? reportsHasMore,
    bool? reportsLoadingMore,
    String? reportsError,
    PrivacySafetyStatus? mutedStatus,
    List<MutedUserEntity>? muted,
    bool? mutedHasMore,
    bool? mutedLoadingMore,
    String? mutedError,
    Set<String>? unmuting,
  }) {
    return PrivacySafetyState(
      reportsStatus: reportsStatus ?? this.reportsStatus,
      reports: reports ?? this.reports,
      reportsHasMore: reportsHasMore ?? this.reportsHasMore,
      reportsLoadingMore: reportsLoadingMore ?? this.reportsLoadingMore,
      reportsError: reportsError,
      mutedStatus: mutedStatus ?? this.mutedStatus,
      muted: muted ?? this.muted,
      mutedHasMore: mutedHasMore ?? this.mutedHasMore,
      mutedLoadingMore: mutedLoadingMore ?? this.mutedLoadingMore,
      mutedError: mutedError,
      unmuting: unmuting ?? this.unmuting,
    );
  }

  @override
  List<Object?> get props => [
    reportsStatus,
    reports,
    reportsHasMore,
    reportsLoadingMore,
    reportsError,
    mutedStatus,
    muted,
    mutedHasMore,
    mutedLoadingMore,
    mutedError,
    unmuting,
  ];
}

/// Backs Settings → Privacy & safety: the reports you have filed and their
/// outcomes (`GET /v1/reports/me`), and the accounts you have muted
/// (`GET /v1/users/me/muted`), with unmute in place.
///
/// A factory in DI — both lists are read-mostly and cheap, and a screen
/// re-opened after unmuting someone elsewhere should show the truth rather
/// than a cached list from the last visit.
class PrivacySafetyCubit extends Cubit<PrivacySafetyState> {
  PrivacySafetyCubit({
    required GetMyReportsUseCase getMyReports,
    required GetMutedUsersUseCase getMutedUsers,
    required UnmuteUserUseCase unmuteUser,
  }) : _getMyReports = getMyReports,
       _getMutedUsers = getMutedUsers,
       _unmuteUser = unmuteUser,
       super(const PrivacySafetyState());

  final GetMyReportsUseCase _getMyReports;
  final GetMutedUsersUseCase _getMutedUsers;
  final UnmuteUserUseCase _unmuteUser;

  int _reportsPage = 0;
  int _mutedPage = 0;

  /// Both lists at once: the screen shows one tab at a time, but the other
  /// tab is one tap away and two small requests on open beat a spinner on
  /// every switch.
  Future<void> load() async {
    await Future.wait([loadReports(), loadMuted()]);
  }

  /// Also the `REPORT_RESOLVED` push's handler — a resolved report changes
  /// this list and nothing else.
  Future<void> loadReports() async {
    emit(state.copyWith(reportsStatus: PrivacySafetyStatus.loading));
    _reportsPage = 0;
    final result = await _getMyReports(const SafetyPageParams());
    if (isClosed) return;
    result.fold(
      (failure) => emit(
        state.copyWith(reportsStatus: PrivacySafetyStatus.error, reportsError: failure.message),
      ),
      (page) => emit(
        state.copyWith(
          reportsStatus: PrivacySafetyStatus.loaded,
          reports: page.items,
          reportsHasMore: page.hasMore,
        ),
      ),
    );
  }

  Future<void> loadMoreReports() async {
    if (!state.reportsHasMore || state.reportsLoadingMore || state.reportsStatus != PrivacySafetyStatus.loaded) {
      return;
    }
    emit(state.copyWith(reportsLoadingMore: true));
    final result = await _getMyReports(SafetyPageParams(page: _reportsPage + 1));
    if (isClosed) return;
    result.fold((_) => emit(state.copyWith(reportsLoadingMore: false)), (page) {
      _reportsPage++;
      emit(
        state.copyWith(
          reportsLoadingMore: false,
          reportsHasMore: page.hasMore,
          reports: [...state.reports, ...page.items],
        ),
      );
    });
  }

  Future<void> loadMuted() async {
    emit(state.copyWith(mutedStatus: PrivacySafetyStatus.loading));
    _mutedPage = 0;
    final result = await _getMutedUsers(const SafetyPageParams());
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(mutedStatus: PrivacySafetyStatus.error, mutedError: failure.message)),
      (page) => emit(
        state.copyWith(mutedStatus: PrivacySafetyStatus.loaded, muted: page.items, mutedHasMore: page.hasMore),
      ),
    );
  }

  Future<void> loadMoreMuted() async {
    if (!state.mutedHasMore || state.mutedLoadingMore || state.mutedStatus != PrivacySafetyStatus.loaded) {
      return;
    }
    emit(state.copyWith(mutedLoadingMore: true));
    final result = await _getMutedUsers(SafetyPageParams(page: _mutedPage + 1));
    if (isClosed) return;
    result.fold((_) => emit(state.copyWith(mutedLoadingMore: false)), (page) {
      _mutedPage++;
      emit(
        state.copyWith(
          mutedLoadingMore: false,
          mutedHasMore: page.hasMore,
          muted: [...state.muted, ...page.items],
        ),
      );
    });
  }

  /// Unmutes, then drops the row. Not optimistic: the row disappearing is
  /// the only feedback there is, so it should not be able to disappear for
  /// a request that then failed.
  Future<bool> unmute(String userId) async {
    if (state.unmuting.contains(userId)) return false;
    emit(state.copyWith(unmuting: {...state.unmuting, userId}));

    final result = await _unmuteUser(MuteParams(userId));
    if (isClosed) return false;

    final stillUnmuting = {...state.unmuting}..remove(userId);
    return result.fold(
      (failure) {
        emit(state.copyWith(unmuting: stillUnmuting, mutedError: null));
        return false;
      },
      (_) {
        emit(
          state.copyWith(
            unmuting: stillUnmuting,
            muted: state.muted.where((m) => m.userId != userId).toList(),
          ),
        );
        return true;
      },
    );
  }
}
