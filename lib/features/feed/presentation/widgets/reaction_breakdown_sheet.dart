import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/reaction_breakdown.dart';
import 'reactors_sheet.dart';

/// Opens the "View reactions" sheet from the post overflow menu — the one
/// place this app calls the dedicated `GET .../summary` endpoint rather than
/// relying on the counts a post/comment already carries, since it's meant
/// as an on-demand, always-fresh breakdown. [fetch] is called once the
/// sheet opens (typically `PostDetailCubit.getReactionSummary`). [targetType]
/// / [targetId] identify the same target [fetch] closes over — needed here
/// too so a tapped row can open `showReactorsSheet` for the actual list of
/// users behind that count.
Future<void> showReactionBreakdownSheet(
  BuildContext context, {
  required Future<ReactionBreakdown?> Function() fetch,
  required String targetType,
  required String targetId,
}) {
  final colors = AppColors.of(context);
  return showModalBottomSheet<void>(
    context: context,
    // Opened from the post overflow menu while the floating pill nav bar is
    // on screen — see `post_options_sheet.dart`'s `showPostOptionsSheet` for
    // why this needs the root navigator rather than the branch's own nested
    // one, or the sheet paints behind that bar instead of over it.
    useRootNavigator: true,
    backgroundColor: colors.surf,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl))),
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('REACTIONS', style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
            const SizedBox(height: 14),
            FutureBuilder<ReactionBreakdown?>(
              future: fetch(),
              builder: (tileContext, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final breakdown = snapshot.data;
                if (breakdown == null || breakdown.total == 0) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      breakdown == null ? "Couldn't load reactions." : 'No reactions yet.',
                      style: AppTextStyles.body.copyWith(color: colors.ink2),
                    ),
                  );
                }
                final entries = breakdown.counts.entries.where((e) => e.value > 0).toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final entry in entries)
                      InkWell(
                        // Pop via `tileContext` (inside this sheet's own
                        // subtree — see `reaction_picker_sheet.dart` for why
                        // that's the safe context to pop with), then reopen
                        // using the outer `context` this function was
                        // called with, which is still mounted underneath.
                        onTap: () {
                          Navigator.of(tileContext).pop();
                          if (context.mounted) {
                            showReactorsSheet(context, targetType: targetType, targetId: targetId, type: entry.key);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Text(entry.key.emoji, style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 10),
                              Text(
                                entry.key.name[0].toUpperCase() + entry.key.name.substring(1),
                                style: AppTextStyles.body.copyWith(color: colors.ink),
                              ),
                              const Spacer(),
                              Text('${entry.value}', style: AppTextStyles.titleSm.copyWith(color: colors.ink2)),
                              const SizedBox(width: 6),
                              Icon(Icons.chevron_right, size: 18, color: colors.ink2),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}
