import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:yello_social_app/core/router/route_names.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/image_placeholder.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../friends/domain/entities/friendship_entity.dart';

/// The Profile tab's identity block: a cover, then a surf card holding the
/// name, the at-a-glance facts line, the connections face-pile and the two
/// primary actions — with the avatar straddling the card's top edge, half on
/// the cover and half on the card.
///
/// The avatar's overlap is `Stack`/`Positioned`, never `Transform.translate`:
/// a translated child can't hit-test a tap past its own untransformed box,
/// which is how this screen silently lost a tap target once already
/// (`docs/GOTCHAS.md`). The avatar and its camera badge are both tappable
/// across that overlap, so it has to be Positioned.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.user,
    required this.connections,
    required this.isUploadingImage,
    required this.onEditAvatar,
    required this.onEditCover,
    required this.onEditProfile,
    required this.onAddStory,
    required this.onCompose,
    required this.onOpenConnections,
  });

  final UserEntity user;

  /// First page of the viewer's friends, for the face-pile. Empty while it is
  /// still loading or if the call failed — the row then degrades to the count
  /// alone rather than disappearing.
  final List<FriendshipEntity> connections;

  final bool isUploadingImage;

  final VoidCallback onEditAvatar;
  final VoidCallback onEditCover;
  final VoidCallback onEditProfile;
  final VoidCallback onAddStory;
  final VoidCallback onCompose;
  final VoidCallback onOpenConnections;

  static const double _coverHeight = 196;
  static const double _avatarSize = 112;
  static const double _avatarRing = 5;

  /// How far the identity card's top edge rises above the cover's bottom, so
  /// the cover still shows either side of the card's rounded top corners.
  static const double _cardOverlap = 25;

  /// Where the header's own name line begins, measured from the top of the
  /// enclosing scroll view: the cover, less the card's overlap into it, plus
  /// the half of the avatar that hangs inside the card and the gap under it.
  ///
  /// `ProfilePage`'s collapsing top bar fades its own copy of the name in
  /// against this, so the two are never both legible at once — if the
  /// geometry above changes, that hand-off follows it from here.
  static const double nameOffset = _coverHeight - _cardOverlap + (_avatarSize + _avatarRing * 2) / 2 + 14;

  // static const List<String> _months = [
  //   'January',
  //   'February',
  //   'March',
  //   'April',
  //   'May',
  //   'June',
  //   'July',
  //   'August',
  //   'September',
  //   'October',
  //   'November',
  //   'December',
  // ];

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final fullName = user.fullName?.trim() ?? '';
    final displayName = fullName.isEmpty ? user.username : fullName;
    final bio = user.bio?.trim() ?? '';
    final avatarOuter = _avatarSize + _avatarRing * 2;
    final cardTop = _coverHeight - _cardOverlap;
    // The card's top edge cuts the avatar in half: the upper half sits on
    // the cover, the lower half inside the card.
    final avatarTop = cardTop - avatarOuter / 2;

    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: _coverHeight,
          child: _Cover(url: user.coverUrl),
        ),
        Positioned(
          right: 16,
          top: cardTop - 52,
          child: AppIconButton(
            size: 38,
            icon: const Icon(CupertinoIcons.camera),
            onPressed: isUploadingImage ? null : onEditCover,
          ),
        ),
        // The identity card - the Stack's only non-positioned child, so it
        // is what gives the Stack its height. The explicit infinite width
        // makes it fill the loose width it is handed instead of
        // shrink-wrapping to its widest row.
        SizedBox(
          width: double.infinity,
          child: Padding(
            padding: EdgeInsets.only(top: cardTop),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: colors.surf,
                border: Border.all(color: colors.line, width: 1.5),
                borderRadius: BorderRadius.circular(AppRadii.huge),
                boxShadow: AppShadows.card(context),
              ),
              child: Column(
                children: [
                  // Clears the half of the avatar hanging into the card.
                  SizedBox(height: avatarOuter / 2 + 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        // Balances the chevron on the right, so the name stays optically
                        // centred instead of centred in the leftover space.
                        Expanded(
                          child: Text(
                            displayName,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.displayLg.copyWith(color: colors.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (bio.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Text(
                        bio,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMd.copyWith(color: colors.ink2),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Connections and account status share one line. Status was
                  // a row in the details card while that card was an
                  // expander; with the expander gone it reads better as a
                  // second at-a-glance fact than as a fourth list row.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Flexible on both sides so a large text scale
                        // ellipsises the labels instead of overflowing.
                        Flexible(
                          child: _ConnectionsRow(
                            connections: connections,
                            total: user.friendsCount,
                            onTap: onOpenConnections,
                          ),
                        ),
                        Container(width: 1, height: 18, color: colors.line2),
                        Flexible(child: _AccountStatusRow(status: user.status)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: 'Add to story',
                            fullWidth: true,
                            icon: Icon(CupertinoIcons.add_circled, size: 17, color: colors.onYel),
                            // onPressed: onAddStory,
                            onPressed: () => context.pushNamed(RouteNames.createPost),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppButton(
                            label: 'Edit profile',
                            variant: AppButtonVariant.subtle,
                            fullWidth: true,
                            icon: Icon(CupertinoIcons.pencil, size: 17, color: colors.ink2),
                            onPressed: onEditProfile,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ),
        // Painted after the card so the avatar sits on top of it, and
        // Positioned rather than Transform so the overlap keeps taking taps
        // (ADR-024).
        Positioned(
          left: 0,
          right: 0,
          top: avatarTop,
          child: Center(
            child: _Avatar(
              user: user,
              size: _avatarSize,
              ring: _avatarRing,
              isUploading: isUploadingImage,
              onTap: isUploadingImage ? null : onEditAvatar,
            ),
          ),
        ),
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final width = MediaQuery.sizeOf(context).width;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (url == null || url!.isEmpty)
          const ImagePlaceholder(caption: 'Add a cover')
        else
          CachedNetworkImage(
            imageUrl: url!,
            fit: BoxFit.cover,
            memCacheWidth: (width * dpr).round(),
            errorWidget: (_, _, _) => const ImagePlaceholder(caption: 'Add a cover'),
          ),
        // Top scrim keeps the floating chrome buttons legible over a light
        // cover photo; the bottom one melts the cover into the page so the
        // avatar's lower half sits on flat background.
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: 0.28), Colors.transparent],
                stops: const [0, 0.4],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 84,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [colors.bg, colors.bg.withValues(alpha: 0.75), colors.bg.withValues(alpha: 0)],
                  stops: const [0, 0.35, 1],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.user,
    required this.size,
    required this.ring,
    required this.isUploading,
    required this.onTap,
  });

  final UserEntity user;
  final double size;
  final double ring;
  final bool isUploading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: EdgeInsets.all(ring),
            decoration: BoxDecoration(shape: BoxShape.circle, color: colors.surf),
            child: AppAvatar(
              initials: Formatters.initialsFrom(user.fullName ?? user.username),
              seed: avatarSeedForId(user.id),
              imageUrl: user.avatarUrl,
              size: size,
              borderWidth: 2,
            ),
          ),
          if (isUploading)
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.all(ring),
                child: DecoratedBox(
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.45)),
                  child: const Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    ),
                  ),
                ),
              ),
            )
          else
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.yel,
                  border: Border.all(color: colors.surf, width: 3),
                ),
                child: Icon(CupertinoIcons.camera_fill, size: 16, color: colors.onYel),
              ),
            ),
        ],
      ),
    );
  }
}

/// The reference's "add status…" pill. Yello has no profile-status concept,
/// so it opens the post composer — the nearest thing the backend actually
/// has.
// class _ComposeBubble extends StatelessWidget {
//   const _ComposeBubble({required this.onTap});
//   final VoidCallback onTap;

//   @override
//   Widget build(BuildContext context) {
//     final colors = AppColors.of(context);
//     return Material(
//       color: colors.surf,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(AppRadii.pill),
//         side: BorderSide(color: colors.line, width: 1.5),
//       ),
//       child: InkWell(
//         onTap: onTap,
//         borderRadius: BorderRadius.circular(AppRadii.pill),
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
//           child: Text(
//             'share something…',
//             style: AppTextStyles.hint.copyWith(color: colors.ink2),
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _Fact extends StatelessWidget {
//   const _Fact({required this.icon, required this.label});
//   final IconData icon;
//   final String label;

//   @override
//   Widget build(BuildContext context) {
//     final colors = AppColors.of(context);
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Icon(icon, size: 15, color: colors.ink3),
//         const SizedBox(width: 6),
//         Flexible(
//           child: Text(
//             label,
//             maxLines: 1,
//             overflow: TextOverflow.ellipsis,
//             style: AppTextStyles.bodySm.copyWith(color: colors.ink2),
//           ),
//         ),
//       ],
//     );
//   }
// }

/// The account-status fact, sitting beside [_ConnectionsRow] on the header's
/// facts line. It moved here out of `ProfileDetailsCard` when that card
/// stopped being an expander.
class _AccountStatusRow extends StatelessWidget {
  const _AccountStatusRow({required this.status});

  /// `UserResponse.status`, upper-cased by the API ("ACTIVE").
  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      // Matches _ConnectionsRow's own padding so the divider between them
      // sits centred on equal-height rows.
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.checkmark_shield, size: 16, color: colors.ink3),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Account ${status.toLowerCase()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySm.copyWith(color: colors.ink2),
            ),
          ),
        ],
      ),
    );
  }
}

/// Face-pile plus count, standing in for the reference's "Friends with things
/// in common" row.
///
/// Rendered unconditionally, including at zero connections: Circle (shell
/// branch 1) has no bottom-nav button of its own, and the account menu's
/// "Your circle" item is gone, so this row is now the *only* way back to
/// that screen. Don't make it conditional without adding another entry
/// point first.
class _ConnectionsRow extends StatelessWidget {
  const _ConnectionsRow({required this.connections, required this.total, required this.onTap});

  final List<FriendshipEntity> connections;
  final int total;
  final VoidCallback onTap;

  static const double _faceSize = 30;
  static const double _faceStep = 20;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final faces = connections.take(3).toList();
    final label = total == 0
        ? 'Find your circle'
        : '${Formatters.compactCount(total)} ${total == 1 ? 'connection' : 'connections'}';

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (faces.isNotEmpty) ...[
                SizedBox(
                  height: _faceSize,
                  width: _faceSize + (faces.length - 1) * _faceStep,
                  child: Stack(
                    children: [
                      for (var i = 0; i < faces.length; i++)
                        Positioned(
                          left: i * _faceStep,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: colors.bg, width: 2),
                            ),
                            child: AppAvatar(
                              initials: Formatters.initialsFrom(faces[i].displayName),
                              seed: avatarSeedForId(faces[i].userId),
                              imageUrl: faces[i].avatarUrl,
                              size: _faceSize - 4,
                              borderWidth: 1,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
              ],
              // Flexible so a large text scale shortens the label instead of
              // pushing the chevron off the row.
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySm.copyWith(color: colors.ink2),
                ),
              ),
              const SizedBox(width: 2),
              Icon(CupertinoIcons.chevron_right, size: 18, color: colors.ink3),
            ],
          ),
        ),
      ),
    );
  }
}
