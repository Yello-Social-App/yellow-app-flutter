import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:yello_social_app/core/router/route_names.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_style.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/extensions/context_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/image_placeholder.dart';
import '../../../../shared/widgets/ink_outline.dart';
import '../../../../shared/widgets/linked_text.dart';
import '../../../../shared/widgets/pchum_ben_ornaments.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../friends/domain/entities/friendship_entity.dart';
import '../../domain/entities/public_user_entity.dart';

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
///
/// [PublicProfileHeader] is the same layout for someone else's profile; both
/// build on [_HeaderFrame], so the two screens cannot drift apart again.
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
  /// `ProfileTopBar` fades its own copy of the name in against this, so the
  /// two are never both legible at once — if the geometry above changes, that
  /// hand-off follows it from here. [PublicProfileHeader] shares the geometry,
  /// so this holds for both profile screens.
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

    return _HeaderFrame(
      coverUrl: user.coverUrl,
      coverCaption: 'Add a cover',
      coverAction: InkOutline(
        child: AppIconButton(
          size: 38,
          icon: const Icon(CupertinoIcons.camera),
          onPressed: isUploadingImage ? null : onEditCover,
        ),
      ),
      avatar: _Avatar(
        userId: user.id,
        name: user.fullName ?? user.username,
        imageUrl: user.avatarUrl,
        size: _avatarSize,
        ring: _avatarRing,
        isUploading: isUploadingImage,
        editable: true,
        onTap: isUploadingImage ? null : onEditAvatar,
      ),
      displayName: displayName,
      bio: bio.isEmpty
          ? null
          : Text(bio, textAlign: TextAlign.center, style: AppTextStyles.bodyMd.copyWith(color: colors.ink2)),
      // Connections and account status share one line. Status was a row in
      // the details card while that card was an expander; with the expander
      // gone it reads better as a second at-a-glance fact than as a fourth
      // list row.
      facts: [
        _ConnectionsRow(connections: connections, total: user.friendsCount, onTap: onOpenConnections),
        _FactRow(icon: CupertinoIcons.checkmark_shield, label: 'Account ${user.status.toLowerCase()}'),
      ],
      actions: Row(
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
              variant: AppButtonVariant.secondary,
              fullWidth: true,
              icon: Icon(CupertinoIcons.pencil, size: 17, color: colors.ink2),
              onPressed: onEditProfile,
            ),
          ),
        ],
      ),
    );
  }
}

/// Someone else's identity block, in exactly [ProfileHeader]'s shape — same
/// cover, same avatar straddling the same card, same name / bio / facts /
/// actions order — so another user's profile reads as the same screen as your
/// own.
///
/// What differs is only what a viewer can't do or doesn't have: no camera
/// buttons (the cover and avatar aren't theirs to edit), a connections count
/// with no face-pile or chevron (the API has no "someone else's friends" list
/// to show or open), a posts count where the own header shows account status
/// (`PublicUserResponse` carries no status), and a linkified bio.
///
/// [actions] is built by the page: it is the friend / message row, which
/// needs the page's cubit, and this widget stays a plain layout.
class PublicProfileHeader extends StatelessWidget {
  const PublicProfileHeader({super.key, required this.user, required this.actions});

  final PublicUserEntity user;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final fullName = user.fullName?.trim() ?? '';
    final displayName = fullName.isEmpty ? user.username : fullName;
    final bio = user.bio?.trim() ?? '';

    return _HeaderFrame(
      coverUrl: user.coverUrl,
      avatar: _Avatar(
        userId: user.id,
        name: displayName,
        imageUrl: user.avatarUrl,
        size: ProfileHeader._avatarSize,
        ring: ProfileHeader._avatarRing,
      ),
      displayName: displayName,
      bio: bio.isEmpty
          ? null
          : LinkedText(
              text: bio,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMd.copyWith(color: colors.ink2),
            ),
      facts: [
        _ConnectionsRow(connections: const [], total: user.friendsCount),
        _FactRow(
          icon: CupertinoIcons.square_grid_2x2,
          label: '${Formatters.compactCount(user.postsCount)} ${user.postsCount == 1 ? 'post' : 'posts'}',
        ),
      ],
      actions: actions,
    );
  }
}

/// The layout both headers share: cover, identity card, and the avatar
/// straddling the card's top edge. Everything that differs between viewing
/// yourself and viewing someone else comes in as a parameter.
class _HeaderFrame extends StatelessWidget {
  const _HeaderFrame({
    required this.coverUrl,
    this.coverCaption,
    this.coverAction,
    required this.avatar,
    required this.displayName,
    this.bio,
    required this.facts,
    required this.actions,
  });

  final String? coverUrl;

  /// The empty-cover placeholder's caption — an invitation on your own
  /// profile; null keeps the placeholder's generic default on someone else's.
  final String? coverCaption;

  /// Sits on the cover's bottom-right corner, just above the card.
  final Widget? coverAction;

  final Widget avatar;
  final String displayName;
  final Widget? bio;

  /// The at-a-glance facts line, divided by hairlines.
  final List<Widget> facts;

  final Widget actions;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    const avatarOuter = ProfileHeader._avatarSize + ProfileHeader._avatarRing * 2;
    const cardTop = ProfileHeader._coverHeight - ProfileHeader._cardOverlap;
    // The card's top edge cuts the avatar in half: the upper half sits on
    // the cover, the lower half inside the card.
    const avatarTop = cardTop - avatarOuter / 2;

    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: ProfileHeader._coverHeight,
          child: _Cover(url: coverUrl, caption: coverCaption),
        ),
        if (coverAction != null) Positioned(right: 16, top: cardTop - 52, child: coverAction!),
        // The identity card - the Stack's only non-positioned child, so it
        // is what gives the Stack its height. The explicit infinite width
        // makes it fill the loose width it is handed instead of
        // shrink-wrapping to its widest row.
        SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.only(top: cardTop),
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
                  const SizedBox(height: avatarOuter / 2 + 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      displayName,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.displayLg.copyWith(color: colors.ink),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (bio != null) ...[
                    const SizedBox(height: 12),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: bio),
                  ],
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Flexible on every side so a large text scale
                        // ellipsises the labels instead of overflowing.
                        for (var i = 0; i < facts.length; i++) ...[
                          if (i > 0) Container(width: 1, height: 18, color: colors.line2),
                          Flexible(child: facts[i]),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: actions),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ),
        // Painted after the card so the avatar sits on top of it, and
        // Positioned rather than Transform so the overlap keeps taking taps
        // (ADR-024).
        Positioned(left: 0, right: 0, top: avatarTop, child: Center(child: avatar)),
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.url, this.caption});
  final String? url;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final width = MediaQuery.sizeOf(context).width;

    // What stands in for a cover that isn't there. Under Pchum Ben that is
    // the festival scene rather than the "drop an image" slot (ADR-057); the
    // camera button on the cover still says how to add one.
    final Widget placeholder;
    if (AppStyle.of(context).pchumBen) {
      placeholder = ColoredBox(color: colors.slot, child: const PchumBenCoverScene());
    } else {
      placeholder = caption == null ? const ImagePlaceholder() : ImagePlaceholder(caption: caption!);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (url == null || url!.isEmpty)
          placeholder
        else
          CachedNetworkImage(
            imageUrl: url!,
            color: context.imageBackdrop,
            colorBlendMode: BlendMode.dstOver,
            fit: BoxFit.cover,
            memCacheWidth: (width * dpr).round(),
            errorWidget: (_, _, _) => placeholder,
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
    required this.userId,
    required this.name,
    required this.imageUrl,
    required this.size,
    required this.ring,
    this.isUploading = false,
    this.editable = false,
    this.onTap,
  });

  final String userId;
  final String name;
  final String? imageUrl;
  final double size;
  final double ring;
  final bool isUploading;

  /// Shows the yellow camera badge — your own avatar only.
  final bool editable;
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
              initials: Formatters.initialsFrom(name),
              seed: avatarSeedForId(userId),
              imageUrl: imageUrl,
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
          else if (editable)
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

/// One icon-and-label fact on the header's facts line, beside
/// [_ConnectionsRow]: account status on your own profile (it moved here out
/// of `ProfileDetailsCard` when that card stopped being an expander), the
/// posts count on someone else's.
class _FactRow extends StatelessWidget {
  const _FactRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

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
          Icon(icon, size: 16, color: colors.ink3),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
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
///
/// With no [onTap] — someone else's profile — it is a plain count: no
/// chevron, no ink, and "0 connections" rather than the own-profile prompt.
class _ConnectionsRow extends StatelessWidget {
  const _ConnectionsRow({required this.connections, required this.total, this.onTap});

  final List<FriendshipEntity> connections;
  final int total;
  final VoidCallback? onTap;

  static const double _faceSize = 30;
  static const double _faceStep = 20;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final faces = connections.take(3).toList();
    final label = total == 0 && onTap != null
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
              if (onTap != null) ...[
                const SizedBox(width: 2),
                Icon(CupertinoIcons.chevron_right, size: 18, color: colors.ink3),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
