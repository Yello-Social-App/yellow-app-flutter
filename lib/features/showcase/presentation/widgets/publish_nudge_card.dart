import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';

/// The row that closes a short, unfiltered showcase list: "Shipped something?"
/// with a Publish button.
///
/// With one or two projects the grid is mostly empty page below the last card,
/// and the only way to add to it is the small button in the header. This puts
/// the ask where the eye lands — at the end of the list — and says what a
/// project can carry. It is a prompt, not content: `surf2` fill and no shadow,
/// so it does not read as a third project.
class PublishNudgeCard extends StatelessWidget {
  const PublishNudgeCard({super.key, required this.projectCount, required this.onPublish});

  final int projectCount;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final noun = projectCount == 1 ? 'project' : 'projects';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surf2,
        border: Border.all(color: colors.line, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: colors.yelb, borderRadius: BorderRadius.circular(AppRadii.xs)),
                child: Icon(CupertinoIcons.rocket, size: 22, color: colors.yeld),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Shipped something?', style: AppTextStyles.titleRow.copyWith(color: colors.ink)),
                    const SizedBox(height: 3),
                    Text(
                      'Only $projectCount $noun so far — add yours with a repo, a live link and up to six tech tags.',
                      style: AppTextStyles.bodySm.copyWith(color: colors.ink2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            // Lines the button up under the text, not under the tile.
            padding: const EdgeInsets.only(left: 56),
            child: AppButton(
              label: 'Publish',
              dense: true,
              icon: const Icon(CupertinoIcons.add, size: 14),
              onPressed: onPublish,
            ),
          ),
        ],
      ),
    );
  }
}
