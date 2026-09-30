import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/extensions/string_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../domain/entities/story_entity.dart';

/// The stories row at the top of the feed: your own tile ("Your story")
/// followed by each friend's ring, in the order `GET /stories/feed` returned
/// them — unseen first, then newest.
///
/// A bare row sitting on the page background, not a card: it lives directly
/// under the app bar and above the Feed / Community tabs, the way the
/// reference header lays it out, so a card border here would read as one more
/// box between the masthead and the tabs.
class StoriesRail extends StatelessWidget {
  const StoriesRail({
    super.key,
    required this.rail,
    required this.onAddStory,
    required this.onOpenRing,
    this.myAvatarUrl,
    this.myInitials = 'YOU',
    this.mySeed = 0,
  });

  final StoryRailEntity rail;
  final VoidCallback onAddStory;

  /// Opens one author's ring — the id is what the route takes, so a ring
  /// that expired between this build and the tap resolves to whatever the
  /// viewer's own fetch finds rather than to a stale index.
  final void Function(String authorId) onOpenRing;

  /// The signed-in user's avatar, for "Your story" before they have any
  /// story of their own (once they do, the ring shows their author avatar).
  final String? myAvatarUrl;
  final String myInitials;
  final int mySeed;

  static const _avatarSize = 58.0;

  @override
  Widget build(BuildContext context) {
    final rings = rail.rings;
    return SizedBox(
      height: 92,
      // `ListView.builder` rather than a materialized list: the rings are a
      // server page (20) and only five fit on screen.
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: rings.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _MyStoryTile(
              mine: rail.mine,
              avatarUrl: myAvatarUrl,
              initials: myInitials,
              seed: mySeed,
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
    );
  }
}

/// The first tile: always your own face with a small "+" badge. With no
/// active story the whole tile opens the composer; once you have one, the
/// avatar plays it and the badge still adds another in one tap.
class _MyStoryTile extends StatelessWidget {
  const _MyStoryTile({
    required this.mine,
    required this.avatarUrl,
    required this.initials,
    required this.seed,
    required this.onAdd,
    required this.onOpen,
  });

  final StoryRingEntity? mine;
  final String? avatarUrl;
  final String initials;
  final int seed;
  final VoidCallback onAdd;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final ring = mine;
    const outer = StoriesRail._avatarSize + 6;

    return GestureDetector(
      onTap: ring == null ? onAdd : onOpen,
      child: SizedBox(
        width: 68,
        child: Column(
          children: [
            SizedBox.square(
              dimension: outer,
              // `Stack`/`Positioned` rather than `Transform.translate` for
              // the badge: a translated child only hit-tests inside its
              // untransformed box, which would swallow the tap. See
              // `docs/GOTCHAS.md`.
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AppAvatar(
                    initials: ring?.author.displayName.initials ?? initials,
                    seed: ring == null ? seed : avatarSeedForId(ring.author.id),
                    size: StoriesRail._avatarSize,
                    imageUrl: ring?.author.avatarUrl ?? avatarUrl,
                    // Your own ring is always fully seen, so it takes the
                    // hairline rather than the yellow highlight; with no
                    // story at all the ring is still laid out (transparent)
                    // so this tile lines up with its neighbours.
                    ringColor: ring == null ? Colors.transparent : colors.line,
                  ),
                  // Flush with the tile's own box, not overhanging it: a
                  // child painted outside its parent's bounds gets no hits,
                  // so an overhang would be a badge whose edge silently
                  // ignores taps.
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
            const SizedBox(height: 6),
            Text(
              'Your story',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySm.copyWith(color: colors.ink, fontSize: 12),
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
        padding: const EdgeInsets.only(left: 10),
        child: SizedBox(
          width: 68,
          child: Column(
            children: [
              AppAvatar(
                initials: ring.author.displayName.initials,
                seed: avatarSeedForId(ring.author.id),
                size: StoriesRail._avatarSize,
                imageUrl: ring.author.avatarUrl,
                ringColor: ring.hasUnseen ? colors.yel : colors.line,
              ),
              const SizedBox(height: 6),
              Text(
                ring.author.username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySm.copyWith(color: colors.ink, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
