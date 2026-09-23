import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/app_update.dart';
import '../../domain/usecases/check_for_update_usecase.dart';
import '../../domain/usecases/download_update_usecase.dart';
import '../../domain/usecases/install_update_usecase.dart';
import '../../domain/usecases/open_install_settings_usecase.dart';

enum AppUpdateStatus {
  /// Nothing asked yet — the card shows its "Check now" button.
  idle,
  checking,

  /// The check succeeded and this build is the published one.
  upToDate,

  /// A newer build exists and has not been downloaded yet.
  available,
  downloading,

  /// The APK is on disk; the OS installer has not been handed it yet, or
  /// the user came back from it without installing.
  readyToInstall,

  /// The download finished but the OS will not let Yello install packages
  /// until the user turns that on.
  needsPermission,
  error,
}

class AppUpdateState extends Equatable {
  const AppUpdateState({
    this.status = AppUpdateStatus.idle,
    this.update,
    this.progress = 0,
    this.filePath,
    this.errorMessage,
  });

  final AppUpdateStatus status;

  /// The published build, once a check has found one.
  final AppUpdate? update;

  /// 0.0–1.0 while [AppUpdateStatus.downloading].
  final double progress;

  /// Where the downloaded APK landed, once there is one.
  final String? filePath;

  final String? errorMessage;

  bool get isBusy => status == AppUpdateStatus.checking || status == AppUpdateStatus.downloading;

  AppUpdateState copyWith({
    AppUpdateStatus? status,
    AppUpdate? update,
    double? progress,
    String? filePath,
    String? errorMessage,
  }) => AppUpdateState(
    status: status ?? this.status,
    update: update ?? this.update,
    progress: progress ?? this.progress,
    filePath: filePath ?? this.filePath,
    // Never carried forward: every transition either sets a fresh message
    // or has none, and a stale one would outlive the failure it described.
    errorMessage: errorMessage,
  );

  @override
  List<Object?> get props => [status, update, progress, filePath, errorMessage];
}

/// Backs the Updates group on the App version screen: check, download,
/// install — the whole sideload path, since Yello is installed from an APK
/// rather than from a store (ADR-029).
///
/// Android only. The page builds this group behind a `Platform.isAndroid`
/// check, so nothing here has an iOS branch to get wrong.
class AppUpdateCubit extends Cubit<AppUpdateState> {
  AppUpdateCubit({
    required CheckForUpdateUseCase checkForUpdate,
    required DownloadUpdateUseCase downloadUpdate,
    required InstallUpdateUseCase installUpdate,
    required OpenInstallSettingsUseCase openInstallSettings,
  }) : _checkForUpdate = checkForUpdate,
       _downloadUpdate = downloadUpdate,
       _installUpdate = installUpdate,
       _openInstallSettings = openInstallSettings,
       super(const AppUpdateState());

  final CheckForUpdateUseCase _checkForUpdate;
  final DownloadUpdateUseCase _downloadUpdate;
  final InstallUpdateUseCase _installUpdate;
  final OpenInstallSettingsUseCase _openInstallSettings;

  Future<void> check() async {
    // In-flight guard — "Check now" and "Try again" are the same call and
    // both stay tappable while one runs.
    if (state.isBusy) return;
    emit(const AppUpdateState(status: AppUpdateStatus.checking));

    final result = await _checkForUpdate(const NoParams());
    if (isClosed) return;
    emit(
      result.fold(
        (failure) => AppUpdateState(status: AppUpdateStatus.error, errorMessage: failure.message),
        (update) => update == null
            ? const AppUpdateState(status: AppUpdateStatus.upToDate)
            : AppUpdateState(status: AppUpdateStatus.available, update: update),
      ),
    );
  }

  Future<void> download() async {
    final update = state.update;
    if (update == null || state.isBusy) return;
    emit(state.copyWith(status: AppUpdateStatus.downloading, progress: 0));

    final result = await _downloadUpdate(
      DownloadUpdateParams(
        update: update,
        onProgress: (progress) {
          // The download outlives the screen if the user pops it mid-way.
          if (isClosed || state.status != AppUpdateStatus.downloading) return;
          emit(state.copyWith(progress: progress));
        },
      ),
    );
    if (isClosed) return;

    await result.fold(
      (failure) async => emit(state.copyWith(status: AppUpdateStatus.error, errorMessage: failure.message)),
      (path) async {
        emit(state.copyWith(status: AppUpdateStatus.readyToInstall, filePath: path, progress: 1));
        // Straight into the OS installer: the user asked for an update, not
        // for a file. The extra tap only exists when the OS refuses.
        await install();
      },
    );
  }

  /// Hands the downloaded APK to the OS. Lands on
  /// [AppUpdateStatus.needsPermission] when "install unknown apps" is off —
  /// which is the common first run, not an error.
  Future<void> install() async {
    final path = state.filePath;
    if (path == null) return;

    final result = await _installUpdate(InstallUpdateParams(path));
    if (isClosed) return;
    emit(
      result.fold(
        (failure) => state.copyWith(status: AppUpdateStatus.error, errorMessage: failure.message),
        (launched) =>
            state.copyWith(status: launched ? AppUpdateStatus.readyToInstall : AppUpdateStatus.needsPermission),
      ),
    );
  }

  /// Sends the user to the OS permission screen. The app is backgrounded by
  /// it, so the result is read by tapping Install again on return rather
  /// than by watching for a callback that Android does not send.
  Future<void> openInstallSettings() => _openInstallSettings(const NoParams());
}
