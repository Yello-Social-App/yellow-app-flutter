import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yello_social_app/core/error/failures.dart';
import 'package:yello_social_app/core/usecase/usecase.dart';
import 'package:yello_social_app/features/settings/domain/entities/app_update.dart';
import 'package:yello_social_app/features/settings/domain/usecases/check_for_update_usecase.dart';
import 'package:yello_social_app/features/settings/domain/usecases/download_update_usecase.dart';
import 'package:yello_social_app/features/settings/domain/usecases/install_update_usecase.dart';
import 'package:yello_social_app/features/settings/domain/usecases/open_install_settings_usecase.dart';
import 'package:yello_social_app/features/settings/presentation/bloc/app_update_cubit.dart';

class _MockCheck extends Mock implements CheckForUpdateUseCase {}

class _MockDownload extends Mock implements DownloadUpdateUseCase {}

class _MockInstall extends Mock implements InstallUpdateUseCase {}

class _MockOpenSettings extends Mock implements OpenInstallSettingsUseCase {}

const _update = AppUpdate(
  version: '0.4.0',
  buildNumber: 3,
  apkUrl: 'https://example.test/yello-0.4.0.apk',
  notes: 'Faster feed.',
  sizeBytes: 61 * 1024 * 1024,
);

void main() {
  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(const DownloadUpdateParams(update: _update));
    registerFallbackValue(const InstallUpdateParams(''));
  });

  late _MockCheck check;
  late _MockDownload download;
  late _MockInstall install;
  late _MockOpenSettings openSettings;

  setUp(() {
    check = _MockCheck();
    download = _MockDownload();
    install = _MockInstall();
    openSettings = _MockOpenSettings();
  });

  AppUpdateCubit build() => AppUpdateCubit(
    checkForUpdate: check,
    downloadUpdate: download,
    installUpdate: install,
    openInstallSettings: openSettings,
  );

  // The comparison is on the build number, not the version string — it is
  // the one value Android itself guarantees increases between installable
  // builds.
  group('AppUpdate.isNewerThan', () {
    test('a higher build number is an update', () => expect(_update.isNewerThan('2'), isTrue));

    test('the same build number is not', () => expect(_update.isNewerThan('3'), isFalse));

    test('a higher installed build is not', () => expect(_update.isNewerThan('4'), isFalse));

    test('an unreadable installed build offers nothing', () => expect(_update.isNewerThan('nightly'), isFalse));

    test('the size label drops when the manifest gave no size', () {
      expect(_update.sizeLabel, '61.0 MB');
      expect(const AppUpdate(version: '1', buildNumber: 1, apkUrl: 'https://x').sizeLabel, isEmpty);
    });
  });

  test('a check that finds nothing lands on upToDate, not on an error', () async {
    when(() => check(any())).thenAnswer((_) async => const Right(null));

    final cubit = build();
    await cubit.check();

    expect(cubit.state.status, AppUpdateStatus.upToDate);
    expect(cubit.state.update, isNull);
    await cubit.close();
  });

  test('a check that finds a build lands on available with it attached', () async {
    when(() => check(any())).thenAnswer((_) async => const Right(_update));

    final cubit = build();
    await cubit.check();

    expect(cubit.state.status, AppUpdateStatus.available);
    expect(cubit.state.update, _update);
    await cubit.close();
  });

  test('a failed check keeps the failure message for the retry row', () async {
    when(() => check(any())).thenAnswer((_) async => const Left(NetworkFailure('No internet connection.')));

    final cubit = build();
    await cubit.check();

    expect(cubit.state.status, AppUpdateStatus.error);
    expect(cubit.state.errorMessage, 'No internet connection.');
    await cubit.close();
  });

  // The user asked for an update, not for a file, so a finished download
  // goes straight into the OS installer.
  test('a finished download hands the file to the installer on its own', () async {
    when(() => check(any())).thenAnswer((_) async => const Right(_update));
    when(() => download(any())).thenAnswer((_) async => const Right('/cache/updates/yello-0.4.0-3.apk'));
    when(() => install(any())).thenAnswer((_) async => const Right(true));

    final cubit = build();
    await cubit.check();
    await cubit.download();

    expect(cubit.state.status, AppUpdateStatus.readyToInstall);
    expect(cubit.state.filePath, '/cache/updates/yello-0.4.0-3.apk');
    expect(cubit.state.progress, 1);
    verify(() => install(const InstallUpdateParams('/cache/updates/yello-0.4.0-3.apk'))).called(1);
    await cubit.close();
  });

  // An OS that has not been told Yello may install apps is the ordinary
  // first run, and must read as a permission prompt rather than a failure.
  test('an installer the OS refuses lands on needsPermission, not error', () async {
    when(() => check(any())).thenAnswer((_) async => const Right(_update));
    when(() => download(any())).thenAnswer((_) async => const Right('/cache/updates/yello.apk'));
    when(() => install(any())).thenAnswer((_) async => const Right(false));

    final cubit = build();
    await cubit.check();
    await cubit.download();

    expect(cubit.state.status, AppUpdateStatus.needsPermission);
    expect(cubit.state.filePath, '/cache/updates/yello.apk');
    await cubit.close();
  });

  test('a failed download surfaces the message and keeps the update', () async {
    when(() => check(any())).thenAnswer((_) async => const Right(_update));
    when(() => download(any())).thenAnswer((_) async => const Left(ServerFailure('The download stopped.')));

    final cubit = build();
    await cubit.check();
    await cubit.download();

    expect(cubit.state.status, AppUpdateStatus.error);
    expect(cubit.state.errorMessage, 'The download stopped.');
    expect(cubit.state.update, _update, reason: 'the retry button needs the build it was going to fetch');
    verifyNever(() => install(any()));
    await cubit.close();
  });

  test('download does nothing when no check has found a build', () async {
    final cubit = build();
    await cubit.download();

    expect(cubit.state.status, AppUpdateStatus.idle);
    verifyNever(() => download(any()));
    await cubit.close();
  });

  test('install does nothing before there is a downloaded file', () async {
    final cubit = build();
    await cubit.install();

    verifyNever(() => install(any()));
    await cubit.close();
  });
}
