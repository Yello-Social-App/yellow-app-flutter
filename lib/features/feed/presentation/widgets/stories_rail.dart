import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/extensions/string_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../domain/entities/story_entity.dart';

/// The "STORIES" card at the top of the feed: your own ring (or an
/// add-your-own tile when you have no active story) followed by each
/// friend's ring, in the order `GET /stories/feed` returned them —
/// unseen first, then newest.
class StoriesRail extends StatelessWidget {
  const StoriesRail({
    super.key,
    required this.rail,
    required this.onAddStory,
    required this.onOpenRing,
    this.myAvatarUrl,
    this.myInitials = 'YOU',
  });

  final StoryRailEntity rail;
  final VoidCallback onAddStory;

  /// Opens one author's ring — the id is what the route takes, so a ring
  /// that expired between this build and the tap resolves to whatever the
  /// viewer's own fetch finds rather than to a stale index.
  final void Function(String authorId) onOpenRing;

  /// The signed-in user's avatar, for the "add" tile before they have any
  /// story of their own (once they do, the ring shows their author avatar).
  final String? myAvatarUrl;
  final String myInitials;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final rings = rail.rings;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(
        color: colors.surf,
        border: Border.all(color: colors.line, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        // Floats above the flat-white page background — see PostCard's
        // matching shadow for why.
        boxShadow: AppShadows.card(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text('STORIES', style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
          ),
          SizedBox(
            height: 92,
            // `ListView.builder` rather than a materialized list: the rings
            // are a server page (20) and only four fit on screen.
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: rings.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _MyStoryTile(
                    mine: rail.mine,
                    avatarUrl: myAvatarUrl,
                    initials: myInitials,
                    onAdd: onAddStory,
                    onOpen: () {
                      final author = rail.mine?.author;
                      if (author != null) onOpenRing(author.id);
                    },
                  );
                }
                final ring = rings[index - 1];
                return _RingTile(ring: ring, onTap: () => onOpenRing(ring.author.id));
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The first tile: a plain "+" until you have an active story, then your own
/// ring with a small "+" badge so adding another is still one tap.
class _MyStoryTile extends StatelessWidget {
  const _MyStoryTile({
    required this.mine,
    required this.avatarUrl,
    required this.initials,
    required this.onAdd,
    required this.onOpen,
  });

  final StoryRingEntity? mine;
  final String? avatarUrl;
  final String initials;
  final VoidCallback onAdd;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final ring = mine;

    return GestureDetector(
      onTap: ring == null ? onAdd : onOpen,
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            SizedBox(
              width: 60,
              height: 60,
              // `Stack`/`Positioned` rather than `Transform.translate` for
              // the badge: a translated child only hit-tests inside its
              // untransformed box, which would swallow the tap. See
              // `docs/GOTCHAS.md`.
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (ring == null)
                    Container(
                      width: 60,
                      height: 60,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.surf2,
                        border: Border.all(color: colors.line, width: 1.5),
                      ),
                      child: Icon(CupertinoIcons.add, color: colors.ink3, size: 21),
                    )
                  else
                    AppAvatar(
                      initials: ring.author.displayName.initials,
                      seed: avatarSeedForId(ring.author.id),
                      size: 60,
                      imageUrl: ring.author.avatarUrl,
                      // Your own ring is always fully seen, so it takes the
                      // hairline rather than the yellow highlight.
                      ringColor: colors.line,
                    ),
                  if (ring != null)
                    // Flush with the tile's own 60x60 box, not overhanging
                    // it: a child painted outside its parent's bounds gets
                    // no hits, so an overhang would be a badge whose edge
                    // silently ignores taps.
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: onAdd,
                        child: Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.yel,
                            border: Border.all(color: colors.surf, width: 2),
                          ),
                          child: Icon(CupertinoIcons.add, color: colors.onYel, size: 13),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ring == null ? 'YOU' : 'YOUR STORY',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.metaMono.copyWith(color: colors.ink2),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingTile extends StatelessWidget {
  const _RingTile({required this.ring, required this.onTap});

  final StoryRingEntity ring;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: SizedBox(
          width: 64,
          child: Column(
            children: [
              AppAvatar(
                initials: ring.author.displayName.initials,
                seed: avatarSeedForId(ring.author.id),
                size: 60,
                imageUrl: ring.author.avatarUrl,
                ringColor: ring.hasUnseen ? colors.yel : colors.line,
              ),
              const SizedBox(height: 8),
              Text(
                ring.author.firstName.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.metaMono.copyWith(color: colors.ink2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
