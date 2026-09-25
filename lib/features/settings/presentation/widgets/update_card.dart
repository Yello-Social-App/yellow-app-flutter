import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_button.dart';
import '../bloc/app_update_cubit.dart';
import 'settings_card.dart';

/// The Updates group on the App version screen — check, download, install,
/// all in one card, because Yello is sideloaded and there is no store to
/// hand the job to (ADR-029).
///
/// Android only; the page gates it on `Platform.isAndroid`.
///
/// One card that swaps its body per status rather than a list of rows: at
/// any moment exactly one of these is true, and each one has exactly one
/// button worth offering.
class UpdateCard extends StatelessWidget {
  const UpdateCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('UPDATES', style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
        const SizedBox(height: 12),
        SettingsCard(
          child: BlocBuilder<AppUpdateCubit, AppUpdateState>(builder: (context, state) => _Body(state: state)),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});

  final AppUpdateState state;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cubit = context.read<AppUpdateCubit>();
    final update = state.update;

    return switch (state.status) {
      AppUpdateStatus.checking => const _Row(
        icon: _Spinner(),
        title: 'Checking for updates',
        body: 'Asking the update channel what the newest build is.',
      ),

      AppUpdateStatus.upToDate => _Row(
        icon: _Badge(icon: CupertinoIcons.checkmark, color: colors.grn),
        title: 'You are on the newest build',
        body: 'Nothing newer has been published yet.',
        action: AppButton(label: 'Check again', variant: AppButtonVariant.outline, dense: true, onPressed: cubit.check),
      ),

      AppUpdateStatus.available when update != null => _Row(
        icon: _Badge(icon: CupertinoIcons.arrow_down, color: colors.yeld),
        title: 'Yello ${update.version} is available',
        body: update.notes.isEmpty ? 'Build ${update.buildNumber} is ready to install.' : update.notes,
        action: AppButton(
          label: update.sizeLabel.isEmpty ? 'Download' : 'Download (${update.sizeLabel})',
          dense: true,
          icon: const Icon(CupertinoIcons.arrow_down_to_line, size: 14),
          onPressed: cubit.download,
        ),
      ),

      AppUpdateStatus.downloading => _Downloading(progress: state.progress, version: update?.version ?? ''),

      AppUpdateStatus.readyToInstall => _Row(
        icon: _Badge(icon: CupertinoIcons.device_phone_portrait, color: colors.grn),
        title: 'Downloaded — finish in the installer',
        body: 'Android takes over from here. If the installer did not open, tap Install again.',
        action: AppButton(label: 'Install', dense: true, onPressed: cubit.install),
      ),

      AppUpdateStatus.needsPermission => _Row(
        icon: _Badge(icon: CupertinoIcons.lock, color: colors.yeld),
        title: 'Android needs your permission',
        body:
            'Allow Yello to install apps, then come back and tap Install. '
            'You only have to do this once.',
        action: AppButton(label: 'Open settings', dense: true, onPressed: cubit.openInstallSettings),
      ),

      AppUpdateStatus.error => _Row(
        icon: _Badge(icon: CupertinoIcons.exclamationmark_circle, color: colors.red),
        title: 'The update check failed',
        body: state.errorMessage ?? 'Could not reach the update channel.',
        action: AppButton(label: 'Try again', variant: AppButtonVariant.outline, dense: true, onPressed: cubit.check),
      ),

      // `idle`, plus the `available` case with no update attached — which
      // cannot happen, but still has to build something.
      _ => _Row(
        icon: _Badge(icon: CupertinoIcons.refresh, color: colors.ink2),
        title: 'Check for a newer build',
        body: 'Yello is installed from a file, so updates are fetched here rather than from a store.',
        action: AppButton(label: 'Check now', variant: AppButtonVariant.outline, dense: true, onPressed: cubit.check),
      ),
    };
  }
}

/// Icon, two lines of copy, and at most one button — the shape every status
/// above fills in.
class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, required this.body, this.action});

  final Widget icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            icon,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.bodySm.copyWith(color: colors.ink, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(body, style: AppTextStyles.metaMonoSm.copyWith(color: colors.ink2)),
                ],
              ),
            ),
          ],
        ),
        if (action != null) ...[const SizedBox(height: 12), Align(alignment: Alignment.centerLeft, child: action)],
      ],
    );
  }
}

class _Downloading extends StatelessWidget {
  const _Downloading({required this.progress, required this.version});

  final double progress;
  final String version;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final percent = (progress * 100).clamp(0, 100).toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                version.isEmpty ? 'Downloading…' : 'Downloading Yello $version',
                style: AppTextStyles.bodySm.copyWith(color: colors.ink, fontWeight: FontWeight.w600),
              ),
            ),
            Text('$percent%', style: AppTextStyles.metaMonoSm.copyWith(color: colors.ink2)),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            // A server that sends no content length leaves this at 0 — an
            // indeterminate bar is honest there, a 0% bar is not.
            value: progress > 0 ? progress : null,
            minHeight: 6,
            backgroundColor: colors.line,
            valueColor: AlwaysStoppedAnimation<Color>(colors.yel),
          ),
        ),
        const SizedBox(height: 8),
        Text('Keep Yello open until this finishes.', style: AppTextStyles.metaMonoSm.copyWith(color: colors.ink2)),
      ],
    );
  }
}

/// The 36px circle every row leads with — a flat tint, no blurred shadow:
/// this card rebuilds on every progress tick, and a blurred `BoxShadow` on
/// a widget that rebuilds is what crashed Impeller on this project
/// (`docs/GOTCHAS.md`).
class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
    child: Icon(icon, size: 20, color: color),
  );
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 36,
    height: 36,
    child: Center(
      child: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.of(context).ink2),
      ),
    ),
  );
}
