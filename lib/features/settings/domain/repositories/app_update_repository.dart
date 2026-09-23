import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/app_update.dart';

abstract interface class AppUpdateRepository {
  /// Reads the published update manifest. `Right(null)` is a successful
  /// check that found nothing newer — distinct from a `Left`, which means
  /// the check itself failed and the user should be offered a retry.
  Future<Either<Failure, AppUpdate?>> checkForUpdate();

  /// Downloads [update]'s APK, reporting 0.0–1.0 through [onProgress], and
  /// resolves with the local file path the installer should be handed.
  Future<Either<Failure, String>> download(AppUpdate update, {void Function(double progress)? onProgress});

  /// Hands [filePath] to the system package installer. `Right(false)` means
  /// the OS has not granted this app permission to install packages yet —
  /// the caller sends the user to that settings screen rather than showing
  /// an error.
  Future<Either<Failure, bool>> install(String filePath);

  /// Opens the OS screen where "install unknown apps" is granted for Yello.
  /// Resolves when the screen is launched, not when the user decides.
  Future<Either<Failure, void>> openInstallSettings();
}
