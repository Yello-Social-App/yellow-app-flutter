import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/app_status_snackbar.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../domain/entities/app_build_info.dart';
import '../bloc/app_update_cubit.dart';
import '../bloc/app_version_cubit.dart';
import '../widgets/settings_card.dart';
import '../widgets/update_card.dart';

/// Account menu → App version: which build of Yello is installed here, plus
/// the device facts a support reply asks for next.
///
/// Paired with the Updates group the reference design asks for — check,
/// download, install. It answers from the release channel's `latest.json`,
/// not from the API, which still serves no version resource
/// (`docs/BACKEND.md`); [AppConfig.updateManifestUrl] is where that channel
/// lives and ADR-029 is why it works this way.
///
/// Android only. An iOS build cannot install anything but what the App
/// Store hands it, so the group is simply absent there rather than shown
/// with a button that could only apologise.
class AppVersionPage extends StatelessWidget {
  const AppVersionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<AppVersionCubit>()..load()),
        // `.value`, because `AppUpdateCubit` is a singleton: a download
        // that is running must not be closed by popping this screen.
        // Not auto-checked on open either — an update check is a network
        // call the user did not ask for, and this screen's first job is to
        // answer "what am I running?" offline.
        BlocProvider.value(value: sl<AppUpdateCubit>()),
      ],
      child: const _AppVersionView(),
    );
  }
}

class _AppVersionView extends StatelessWidget {
  const _AppVersionView();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cubit = context.read<AppVersionCubit>();

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
          children: [
            Row(
              children: [
                AppIconButton(icon: const Icon(CupertinoIcons.back), onPressed: () => Navigator.of(context).maybePop()),
                const SizedBox(width: 12),
                Text('App version', style: AppTextStyles.titleLg.copyWith(color: colors.ink)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'See which build of Yello you are running, and the details support will ask for.',
              style: AppTextStyles.bodySm.copyWith(color: colors.ink2),
            ),
            const SizedBox(height: 20),
            BlocBuilder<AppVersionCubit, AppVersionState>(
              builder: (context, state) {
                if (state.status == AppVersionStatus.error) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: ErrorView(
                      message: state.errorMessage ?? 'Could not read the details of this build.',
                      onRetry: cubit.load,
                    ),
                  );
                }
                final info = state.info;
                if (info == null) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return _Loaded(info: info);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.info});

  final AppBuildInfo info;

  /// Android installs Yello from a file and updates through the group
  /// below; iOS can only be updated by the App Store.
  bool get _isSideloaded => info.platform != 'iOS';

  /// Everything a bug report needs, on one line, in the order a human reads
  /// it. Rows the device would not tell us are left out rather than pasted
  /// as empty fields.
  String get _clipboardText => [
    '${info.appName} ${info.versionLabel}',
    info.packageName,
    if (info.osVersion.isNotEmpty) info.osVersion,
    if (info.deviceModel.isNotEmpty) info.deviceModel,
  ].join(' · ');

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _clipboardText));
    if (!context.mounted) return;
    AppStatusSnackbar.showSuccess(context, title: 'Copied', message: 'Your build details are on the clipboard.');
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('THIS BUILD', style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
        const SizedBox(height: 12),
        SettingsCard(
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: colors.grn.withValues(alpha: 0.14), shape: BoxShape.circle),
                child: Icon(CupertinoIcons.checkmark, size: 20, color: colors.grn),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${info.appName} ${info.version}',
                      style: AppTextStyles.bodySm.copyWith(color: colors.ink, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _isSideloaded
                          ? 'Build ${info.buildNumber} is the one installed on this device. '
                                'Updates are fetched below.'
                          : 'Build ${info.buildNumber} is the one installed on this device. '
                                'New versions arrive through the App Store.',
                      style: AppTextStyles.metaMonoSm.copyWith(color: colors.ink2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (Platform.isAndroid) ...[const SizedBox(height: 20), const UpdateCard()],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text('ABOUT', style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
            ),
            AppButton(
              label: 'Copy',
              variant: AppButtonVariant.outline,
              dense: true,
              icon: const Icon(CupertinoIcons.doc_on_doc, size: 14),
              onPressed: () => _copy(context),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SettingsCard(
          // Zero padding so each row's rule runs the full width of the card,
          // the way the reference's About group draws them.
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (index, row) in <(String, String)>[
                ('App version', info.version),
                ('Build number', info.buildNumber),
                ('Package', info.packageName),
                if (info.osVersion.isNotEmpty) ('Platform', info.osVersion),
                if (info.deviceModel.isNotEmpty) ('Device', info.deviceModel),
              ].indexed) ...[
                if (index > 0) Divider(height: 1, thickness: 1, color: colors.line),
                _AboutRow(label: row.$1, value: row.$2),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One `label … value` line of the About group.
class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodySm.copyWith(color: colors.ink, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTextStyles.metaMonoSm.copyWith(color: colors.ink2),
            ),
          ),
        ],
      ),
    );
  }
}
