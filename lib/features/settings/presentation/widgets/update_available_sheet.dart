import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/app_update.dart';

/// The "A fresh Yello is ready" prompt, shown once per launch when the
/// release channel has a newer build than the one installed (ADR-053).
///
/// Resolves to `true` for "Update now" and to `false` or `null` for "Maybe
/// later", a swipe-down or a tap on the scrim. The sheet only reports the
/// choice: the caller owns the navigation, so this file stays free of the
/// router and of [AppUpdateCubit].
Future<bool?> showUpdateAvailableSheet(BuildContext context, AppUpdate update) {
  final colors = AppColors.of(context);
  return showModalBottomSheet<bool>(
    context: context,
    // Over the bottom nav bar, not inside the shell's body.
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: colors.surf,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xxl))),
    builder: (_) => _UpdateAvailableSheet(update: update),
  );
}

/// Up to three checklist lines out of a manifest's `notes`.
///
/// `tool/release_manifest.sh` folds the changelog's first bullet onto one
/// line, so the usual input is a short paragraph: that is split by sentence.
/// Notes written by hand with one item per line are taken line by line
/// instead, with any list marker dropped.
@visibleForTesting
List<String> updateHighlights(String notes) {
  final lines = notes
      .split('\n')
      .map((line) => line.trim().replaceFirst(RegExp(r'^[-•*]\s*'), ''))
      .where((line) => line.isNotEmpty)
      .toList();
  final items = lines.length == 1 ? lines.single.split(RegExp(r'(?<=[.!?])\s+')) : lines;
  return items.where((item) => item.isNotEmpty).take(3).toList();
}

class _UpdateAvailableSheet extends StatelessWidget {
  const _UpdateAvailableSheet({required this.update});

  final AppUpdate update;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final highlights = updateHighlights(update.notes);

    return SafeArea(
      // Scrollable so a large text scale or a short screen pushes the
      // buttons down instead of overflowing the sheet.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: colors.ink3, borderRadius: BorderRadius.circular(AppRadii.pill)),
              ),
            ),
            const SizedBox(height: 14),
            _Banner(version: update.version),
            const SizedBox(height: 18),
            Text('A fresh Yello is ready', style: AppTextStyles.titleLg.copyWith(color: colors.ink)),
            const SizedBox(height: 8),
            Text(
              'Update now to get the latest features and fixes.',
              style: AppTextStyles.bodyMd.copyWith(color: colors.ink2),
            ),
            if (highlights.isNotEmpty) ...[
              const SizedBox(height: 16),
              for (final (index, line) in highlights.indexed) ...[
                if (index > 0) const SizedBox(height: 10),
                _Highlight(text: line),
              ],
            ],
            const SizedBox(height: 20),
            _UpdateNowButton(onPressed: () => Navigator.of(context).pop(true)),
            const SizedBox(height: 4),
            Center(
              child: InkWell(
                onTap: () => Navigator.of(context).pop(false),
                borderRadius: BorderRadius.circular(AppRadii.pill),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Text(
                    'Maybe later',
                    style: AppTextStyles.bodySm.copyWith(color: colors.ink2, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The dark brand slab at the top of the sheet: a "NEW" chip, the logo tile
/// and the wordmark, over two decorative circles.
///
/// Drawn on `shell`, the one surface that is dark in both themes (ADR-009),
/// so the light ink on it is fixed rather than read from the active theme.
/// Flat fills and a stroke only, no shadows.
class _Banner extends StatelessWidget {
  const _Banner({required this.version});

  final String version;

  static const double _tile = 56;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      height: 136,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: colors.shell, borderRadius: BorderRadius.circular(AppRadii.lg)),
      child: Stack(
        children: [
          Positioned(
            left: -30,
            bottom: -48,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(color: colors.yel.withValues(alpha: 0.18), shape: BoxShape.circle),
            ),
          ),
          Positioned(
            right: -64,
            top: -24,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colors.yel.withValues(alpha: 0.22), width: 1.5),
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: colors.yel, borderRadius: BorderRadius.circular(AppRadii.pill)),
              child: Text(
                'NEW · v$version',
                style: AppTextStyles.metaMonoSm.copyWith(color: colors.onYel, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          Positioned.fill(
            // Nudged down so the mark clears the chip on a narrow sheet.
            top: 18,
            child: Center(
              // Brand art, not copy: it keeps its size at any text scale, and
              // shrinks as one piece if the sheet is ever narrower than it.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: _tile,
                      height: _tile,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: colors.yel, borderRadius: BorderRadius.circular(AppRadii.sm)),
                      child: Text(
                        'y',
                        textScaler: TextScaler.noScaling,
                        style: GoogleFonts.fredoka(
                          fontSize: 40,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          color: colors.onYel,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text.rich(
                      TextSpan(
                        text: 'yello',
                        children: [
                          TextSpan(
                            text: '.',
                            style: TextStyle(color: colors.yel),
                          ),
                        ],
                      ),
                      textScaler: TextScaler.noScaling,
                      style: GoogleFonts.fredoka(
                        fontSize: 40,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dark.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One "what's new" line: a yellow check and the text beside it.
class _Highlight extends StatelessWidget {
  const _Highlight({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(color: colors.yel, shape: BoxShape.circle),
          child: Icon(CupertinoIcons.checkmark_alt, size: 14, color: colors.onYel),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(text, style: AppTextStyles.bodySm.copyWith(color: colors.ink)),
          ),
        ),
      ],
    );
  }
}

/// The sheet's one call to action, drawn as the design has it: a dark slab
/// with a yellow label, echoing the banner above it, rather than
/// `AppButton`'s yellow primary (ADR-053).
///
/// On a dark theme the sheet itself is near-black and that slab would sink
/// into it, so the pair flips to the yellow face every other primary uses.
class _UpdateNowButton extends StatelessWidget {
  const _UpdateNowButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final onDarkSheet = Theme.of(context).brightness == Brightness.dark;
    final face = onDarkSheet ? colors.yel : colors.shell;
    final label = onDarkSheet ? colors.onYel : colors.yel;

    return Material(
      color: face,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Update now', style: AppTextStyles.buttonLg.copyWith(color: label)),
              const SizedBox(width: 8),
              Icon(CupertinoIcons.arrow_right, size: 14, color: label),
            ],
          ),
        ),
      ),
    );
  }
}
