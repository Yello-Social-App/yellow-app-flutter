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
import '../bloc/app_version_cubit.dart';
import '../widgets/settings_card.dart';

/// Account menu → App version: which build of Yello is installed here, plus
/// the device facts a support reply asks for next.
///
/// The reference design pairs this with an "Updates" group — a check-now
/// button, a last-checked time, an auto-check toggle. None of that is here,
/// on purpose: the API serves no version resource to compare against and the
/// app ships through the stores, so each of those controls would have to
/// invent its answer. The group that replaces it says only what is true and
/// points at the store. See `docs/BACKEND.md`.
class AppVersionPage extends StatelessWidget {
  const AppVersionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(create: (_) => sl<AppVersionCubit>()..load(), child: const _AppVersionView());
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
                AppIconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).maybePop()),
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

  /// Where a newer build actually comes from on this platform — the one
  /// thing about updates this screen can state without guessing.
  String get _storeName => info.platform == 'iOS' ? 'App Store' : 'Play Store';

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
                child: Icon(Icons.check_rounded, size: 20, color: colors.grn),
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
                      'Build ${info.buildNumber} is the one installed on this device. '
                      'New versions arrive through the $_storeName.',
                      style: AppTextStyles.metaMonoSm.copyWith(color: colors.ink2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
              icon: const Icon(Icons.copy_rounded, size: 14),
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
