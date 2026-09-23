import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/app_build_info.dart';
import '../../domain/usecases/get_app_build_info_usecase.dart';

enum AppVersionStatus { initial, loading, loaded, error }

class AppVersionState extends Equatable {
  const AppVersionState({this.status = AppVersionStatus.initial, this.info, this.errorMessage});

  final AppVersionStatus status;
  final AppBuildInfo? info;
  final String? errorMessage;

  @override
  List<Object?> get props => [status, info, errorMessage];
}

/// Backs the App version screen. One read, no refresh loop: the installed
/// build cannot change while the app is running, so the only way this state
/// goes stale is a reinstall, which restarts the process anyway.
///
/// Checking for a newer build is [AppUpdateCubit]'s job, not this one's:
/// it is a network call against the release channel, while everything here
/// must still resolve with the radio off. See ADR-029.
class AppVersionCubit extends Cubit<AppVersionState> {
  AppVersionCubit({required GetAppBuildInfoUseCase getBuildInfo})
    : _getBuildInfo = getBuildInfo,
      super(const AppVersionState());

  final GetAppBuildInfoUseCase _getBuildInfo;

  Future<void> load() async {
    // In-flight guard: `load` is both the initial read and the error view's
    // retry, and the retry button is tappable while the first one runs.
    if (state.status == AppVersionStatus.loading) return;
    emit(const AppVersionState(status: AppVersionStatus.loading));

    final result = await _getBuildInfo(const NoParams());
    if (isClosed) return;
    emit(
      result.fold(
        (failure) => AppVersionState(status: AppVersionStatus.error, errorMessage: failure.message),
        (info) => AppVersionState(status: AppVersionStatus.loaded, info: info),
      ),
    );
  }
}
