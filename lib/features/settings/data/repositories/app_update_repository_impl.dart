import 'package:dartz/dartz.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/app_update.dart';
import '../../domain/repositories/app_update_repository.dart';
import '../datasources/apk_installer.dart';
import '../datasources/app_info_local_datasource.dart';
import '../datasources/app_update_remote_datasource.dart';

class AppUpdateRepositoryImpl implements AppUpdateRepository {
  AppUpdateRepositoryImpl(this._remote, this._local, this._installer, this._networkInfo);

  final AppUpdateRemoteDataSource _remote;

  /// The installed build to compare against comes from the same local
  /// source the App version screen reads, so the two can never disagree
  /// about what is running.
  final AppInfoLocalDataSource _local;

  final ApkInstaller _installer;
  final NetworkInfo _networkInfo;

  Future<Either<Failure, T>> _run<T>(Future<T> Function() body, {bool needsNetwork = true}) async {
    if (needsNetwork && !await _networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(await body());
    } on AppException catch (e) {
      return Left(ErrorHandler.toFailure(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, AppUpdate?>> checkForUpdate() => _run(() async {
    final published = await _remote.fetchManifest();
    if (published == null) return null;

    final installed = await _local.getBuildInfo();
    return published.isNewerThan(installed.buildNumber) ? published : null;
  });

  @override
  Future<Either<Failure, String>> download(AppUpdate update, {void Function(double progress)? onProgress}) =>
      _run(() async {
        final directory = await _installer.updateDirectory();
        // Named for the build, so a stale file from an abandoned download
        // can never be handed to the installer as if it were this one.
        final target = '$directory/yello-${update.version}-${update.buildNumber}.apk';
        return _remote.downloadApk(update, target, onProgress: onProgress);
      });

  /// No network gate: the file is already on disk, and an install that
  /// starts as the connection drops must not be blocked.
  @override
  Future<Either<Failure, bool>> install(String filePath) =>
      _run(() => _installer.install(filePath), needsNetwork: false);

  @override
  Future<Either<Failure, void>> openInstallSettings() =>
      _run(_installer.openInstallPermissionSettings, needsNetwork: false);
}
