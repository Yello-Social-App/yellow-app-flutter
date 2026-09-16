import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_avatar.dart';

/// The pill-shaped "What did you notice today?" prompt above the feed that
/// opens the create-post flow.
class CreatePostPrompt extends StatelessWidget {
  const CreatePostPrompt({super.key, required this.onTap, required this.myInitials, this.myAvatarUrl, this.mySeed = 0});

  final VoidCallback onTap;
  final String myInitials;

  /// The signed-in user's real uploaded avatar (falls back to the initials
  /// tile when null/empty, same as `AppAvatar` everywhere else).
  final String? myAvatarUrl;

  /// Palette seed for the initials fallback — pass `avatarSeedForId(userId)`
  /// so this matches the same person's avatar color everywhere else in the
  /// app (post cards, profile page, stories rail).
  final int mySeed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: colors.surf,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      // Floats above the now-flat-white page background — see PostCard's
      // matching shadow for why.
      elevation: 3,
      shadowColor: colors.ink.withValues(alpha: 0.15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Container(
          padding: const EdgeInsets.fromLTRB(7, 7, 12, 7),
          decoration: BoxDecoration(
            border: Border.all(color: colors.line, width: 1.5),
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Row(
            children: [
              AppAvatar(initials: myInitials, seed: mySeed, imageUrl: myAvatarUrl, size: 36),
              const SizedBox(width: 11),
              Expanded(
                child: Text('What did you notice today?', style: AppTextStyles.hint.copyWith(color: colors.ink3)),
              ),
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.surf2,
                  border: Border.all(color: colors.line2),
                ),
                child: Icon(Icons.photo_camera_outlined, size: 15, color: colors.ink2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
