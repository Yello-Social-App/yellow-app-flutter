import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/app_status_snackbar.dart';
import '../../../../shared/widgets/app_warning_dialog.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/segmented_tabs.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/domain/usecases/logout_usecase.dart';
import '../../../feed/domain/entities/post_entity.dart';
import '../../../feed/presentation/widgets/post_card.dart';
import '../bloc/profile_cubit.dart';
import '../widgets/profile_details_card.dart';
import '../widgets/profile_header.dart';
import '../widgets/shimmer_own_profile_view.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ProfileCubit>()..load(),
      child: const _ProfileView(),
    );
  }
}

class _ProfileView extends StatefulWidget {
  const _ProfileView();

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  final ScrollController _scrollController = ScrollController();

  /// Drives the collapsing top bar. Held in a `ValueNotifier` rather than
  /// `setState` so a scroll frame repaints the bar alone — a `setState` here
  /// would rebuild the header, the segments and every post card underneath
  /// them, once per frame, for the whole gesture.
  ///
  /// Clamped to the end of the collapse: scrolling on past that point keeps
  /// writing the same value, which `ValueNotifier` does not notify for, so
  /// the bar stops rebuilding entirely once it is fully collapsed.
  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    // The list only exists in the loaded state — while the shimmer or the
    // error view is up this controller has no position to read.
    if (!_scrollController.hasClients) return;
    _scrollOffset.value = _scrollController.offset.clamp(
      0.0,
      _ProfileTopBar.collapseEnd,
    );
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cubit = context.read<ProfileCubit>();

    return Scaffold(
      backgroundColor: colors.bg,
      body: Stack(
        children: [
          BlocBuilder<ProfileCubit, ProfileState>(
            builder: (context, state) {
              if (state.status == ProfileStatus.initial ||
                  (state.status == ProfileStatus.loading &&
                      state.user == null)) {
                return const ShimmerOwnProfileView();
              }
              if (state.status == ProfileStatus.error && state.user == null) {
                return SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: ErrorView(
                        message:
                            state.errorMessage ??
                            'Could not load your profile.',
                        onRetry: cubit.refresh,
                      ),
                    ),
                  ),
                );
              }

              final user = state.user!;
              return RefreshIndicator(
                onRefresh: cubit.refresh,
                color: colors.ink,
                backgroundColor: colors.surf,
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 112),
                  children: [
                    ProfileHeader(
                      user: user,
                      connections: state.connections,
                      isUploadingImage: state.isUploadingAvatar,
                      onEditAvatar: () => _pickAvatar(context, cubit),
                      onEditCover: () =>
                          _pickAvatar(context, cubit, cover: true),
                      onEditProfile: () => _showEditSheet(context, cubit, user),
                      onAddStory: () =>
                          context.pushNamed(RouteNames.storyCompose),
                      onCompose: () => context.pushNamed(RouteNames.createPost),
                      // Circle is shell branch 1 and still has no bottom-nav
                      // button of its own (`bottom_nav_bar.dart`). Since the
                      // account menu's "Your circle" item was removed, this
                      // is the *only* way into it — don't take it away
                      // without adding another entry point first.
                      onOpenConnections: () =>
                          StatefulNavigationShell.of(context).goBranch(1),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: ProfileDetailsCard(
                        user: user,
                        onEdit: () => _showEditSheet(context, cubit, user),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // The switcher sits directly above the list it filters —
                    // the reference puts it higher, above its details block,
                    // which reads as if it filtered that too.
                    //
                    // `SegmentedTabs`, not a chip row: the three are
                    // mutually exclusive and one of them is always on, which
                    // is exactly the distinction that widget's doc draws
                    // between itself and `FilterChipPill`. It names this
                    // screen as its own example; the loose pills this
                    // replaced had drifted away from that.
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: SegmentedTabs<ProfileTab>(
                        values: ProfileTab.values,
                        current: state.tab,
                        labelOf: (tab) => switch (tab) {
                          ProfileTab.posts =>
                            'All ${state.user?.postsCount ?? state.originalPosts.length}',
                          ProfileTab.reposts =>
                            'Shared ${state.repostedPosts.length}',
                          ProfileTab.saved =>
                            'Saved ${state.savedPosts.length}',
                        },
                        onSelect: cubit.selectTab,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Column(
                        children: [
                          _PostList(
                            posts: state.activeTabPosts,
                            tab: state.tab,
                          ),
                          if (state.tab != ProfileTab.saved &&
                              state.hasMorePosts)
                            TextButton(
                              onPressed: state.loadingMorePosts
                                  ? null
                                  : cubit.loadMorePosts,
                              child: Text(
                                state.loadingMorePosts
                                    ? 'Loading…'
                                    : 'Load more',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // Chrome floats over the cover rather than scrolling with it, so
          // the menu and search stay reachable in every state — including the
          // error one above, which renders no header at all.
          //
          // The two buttons ride along as the builder's `child`: they are
          // built once, here, and handed to every rebuild untouched, so a
          // scroll frame never re-runs the menu's closure list.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: ValueListenableBuilder<double>(
              valueListenable: _scrollOffset,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIconButton(
                    icon: const Icon(Icons.menu_rounded),
                    onPressed: () => _openAccountMenu(context),
                  ),
                  const SizedBox(width: 8),
                  AppIconButton(
                    icon: const Icon(Icons.search_rounded),
                    onPressed: () => context.pushNamed(RouteNames.search),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              builder: (context, offset, actions) =>
                  _ProfileTopBar(offset: offset, actions: actions!),
            ),
          ),
        ],
      ),
    );
  }

  /// The reference's hamburger: everything that isn't a profile edit — the
  /// account-level screens (Theme, Send feedback, Notification preferences,
  /// App version) and sign-out.
  ///
  /// This is where the old four-button row and the Settings sheet it opened
  /// both ended up. The action row on the header is for things you do *to
  /// this profile*; none of these are.
  ///
  /// Every item here opens a screen of its own. Theme used to flip the mode
  /// from this list; it now opens the Theme screen, which is the only place
  /// the choice is made.
  Future<void> _openAccountMenu(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final action = await _showMenu(context, [
      (
        'theme',
        isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
        'Theme',
        isDark ? 'Dark' : 'Light',
      ),
      (
        'story-archive',
        Icons.auto_stories_outlined,
        'Story archive',
        'Every story you have posted',
      ),
      (
        'feedback',
        Icons.rate_review_outlined,
        'Send feedback',
        'Rate a feature and tell us why',
      ),
      (
        'notifications',
        Icons.notifications_none_rounded,
        'Notification preferences',
        null,
      ),
      (
        'version',
        Icons.info_outline_rounded,
        'App version',
        'The build running on this device',
      ),
      ('logout', Icons.logout_rounded, 'Log out', null),
    ]);
    if (action == null || !context.mounted) return;
    switch (action) {
      case 'theme':
        context.pushNamed(RouteNames.theme);
      case 'story-archive':
        context.pushNamed(RouteNames.storyArchive);
      case 'feedback':
        context.pushNamed(RouteNames.sendFeedback);
      case 'notifications':
        context.pushNamed(RouteNames.notificationPreferences);
      case 'version':
        context.pushNamed(RouteNames.appVersion);
      case 'logout':
        await _confirmLogout(context);
    }
  }

  /// Items are `(value, icon, label, subtitle?)`.
  ///
  /// `useRootNavigator`, same reason as `showPostOptionsSheet`: this opens
  /// from a tab whose Scaffold sits under `MainShellPage`'s floating nav bar,
  /// so a sheet on the nested Navigator would render behind it.
  Future<String?> _showMenu(
    BuildContext context,
    List<(String, IconData, String, String?)> items,
  ) {
    final colors = AppColors.of(context);
    return showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      backgroundColor: colors.surf,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 80,
              height: 4,
              decoration: BoxDecoration(
                color: colors.line,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
            ),
            for (final (value, icon, label, subtitle) in items)
              ListTile(
                leading: Icon(icon, color: colors.ink),
                title: Text(
                  label,
                  style: AppTextStyles.body.copyWith(color: colors.ink),
                ),
                subtitle: subtitle == null
                    ? null
                    : Text(
                        subtitle,
                        style: AppTextStyles.metaMonoSm.copyWith(
                          color: colors.ink2,
                        ),
                      ),
                onTap: () => Navigator.pop(context, value),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAvatar(
    BuildContext context,
    ProfileCubit cubit, {
    bool cover = false,
  }) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(cover ? 'Choose cover' : 'Choose avatar'),
              onTap: () => Navigator.pop(context, 'choose'),
            ),
            if ((cover
                    ? cubit.state.user?.coverUrl
                    : cubit.state.user?.avatarUrl) !=
                null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(cover ? 'Remove cover' : 'Remove avatar'),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    try {
      bool ok;
      if (action == 'remove') {
        ok = await cubit.updateProfile(
          removeCover: cover ? true : null,
          removeAvatar: cover ? null : true,
        );
      } else {
        final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery,
        );
        if (picked == null || !context.mounted) return;
        ok = cover
            ? await cubit.updateProfile(cover: File(picked.path))
            : await cubit.uploadAvatar(File(picked.path));
      }
      if (!context.mounted) return;
      if (ok) {
        AppStatusSnackbar.showSuccess(
          context,
          message: 'Your profile image has been updated.',
        );
      } else {
        AppStatusSnackbar.showError(
          context,
          message: cubit.state.errorMessage ?? 'Could not update image.',
        );
      }
    } catch (_) {
      if (context.mounted) {
        AppStatusSnackbar.showError(
          context,
          message: 'Could not open this image. Please try again.',
        );
      }
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await AppWarningDialog.show(
      context,
      title: 'Log out?',
      message: "You'll need to sign in again to continue using Yello.",
      confirmLabel: 'Log out',
      cancelLabel: 'Cancel',
      icon: Icons.logout_rounded,
    );
    if (confirmed) sl<LogoutUseCase>()(const NoParams());
  }

  void _showEditSheet(
    BuildContext context,
    ProfileCubit cubit,
    UserEntity user,
  ) {
    showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.of(context).bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditProfileSheet(cubit: cubit, user: user),
    ).then((saved) {
      if (saved == true && context.mounted) {
        AppStatusSnackbar.showSuccess(
          context,
          message: 'Your profile has been updated.',
        );
      }
    });
  }
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.cubit, required this.user});
  final ProfileCubit cubit;
  final UserEntity user;
  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final _username = TextEditingController(text: widget.user.username);
  late final _fullName = TextEditingController(
    text: widget.user.fullName ?? '',
  );
  late final _bio = TextEditingController(text: widget.user.bio ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _fullName.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final user = widget.user;
    final ok = await widget.cubit.updateProfile(
      username: _username.text.trim() == user.username
          ? null
          : _username.text.trim(),
      fullName: _fullName.text == (user.fullName ?? '')
          ? null
          : _fullName.text.trim(),
      bio: _bio.text == (user.bio ?? '') ? null : _bio.text.trim(),
      clearFullName: _fullName.text.trim().isEmpty && user.fullName != null,
      clearBio: _bio.text.trim().isEmpty && user.bio != null,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error =
            widget.cubit.state.errorMessage ?? 'Could not save your changes.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Edit profile',
                style: AppTextStyles.titleLg.copyWith(
                  color: AppColors.of(context).ink,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _username,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  helperText: 'You can change your username once every 7 days.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _fullName,
                enabled: !_saving,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bio,
                enabled: !_saving,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Bio'),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              AppButton(
                label: _saving ? 'Saving…' : 'Save',
                fullWidth: true,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The reference's All / Photos / Reels row, over the three post collections
/// this app actually has.
/// The Profile tab's floating chrome, and the app bar it turns into.
///
/// Below [collapseStart] this is exactly what it has always been: two
/// transparent buttons over the cover photo. Across the stretch of scroll
/// where the header's own name is sliding up behind it, a background, a
/// hairline and an identity — avatar and name, entering from the left — fade
/// in together, so the screen keeps saying whose profile this is once the
/// header has gone. The buttons themselves never move.
///
/// The collapsed state floats: a `surf` surface over the page's `bg` with a
/// soft shadow cast onto the list, the same elevation language `BottomNavBar`
/// already uses at the other end of the screen.
///
/// That shadow is painted by [_TopBarShadowPainter], **not** put in this
/// `BoxDecoration`. The decoration here changes on every scroll frame, and a
/// blurred `BoxShadow` on a per-frame decoration is the exact shape that
/// crashed this project's Impeller renderer on-device — whereas a
/// `MaskFilter.blur` inside a `CustomPainter` is the animated-blur pattern
/// `_ActiveTabIndicatorPainter` has shipped safely all along
/// (`docs/GOTCHAS.md`).
class _ProfileTopBar extends StatelessWidget {
  const _ProfileTopBar({required this.offset, required this.actions});

  /// Current scroll offset, already clamped to [collapseEnd] by the page.
  final double offset;

  /// The menu and search buttons, built once by the page.
  final Widget actions;

  /// The scroll range the collapse plays over. It ends 40px before the
  /// header's own name line ([ProfileHeader.nameOffset]) would reach the top
  /// of the viewport — by then that line is behind this bar — and runs for
  /// the 72px before that, so the hand-off happens while the header's name is
  /// on its way out rather than after it has already gone.
  static const double collapseEnd = ProfileHeader.nameOffset - 40;
  static const double collapseStart = collapseEnd - 72;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final t = Curves.easeOut.transform(
      ((offset - collapseStart) / (collapseEnd - collapseStart)).clamp(
        0.0,
        1.0,
      ),
    );

    // `Clip.none` so the painter below can cast past the bar's own box —
    // the whole point of the shadow is the part that falls on the list.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Once the bar is opaque it has to swallow pointers too, or a tap
        // lands on whichever post card happens to be scrolled underneath it.
        // A `BoxDecoration` colour does not hit-test (only `ColoredBox`
        // does), so the barrier is explicit — and switched off entirely at
        // rest, leaving the transparent state as see-through to drags as it
        // was before.
        Positioned.fill(child: AbsorbPointer(absorbing: t > 0)),
        CustomPaint(
          painter: _TopBarShadowPainter(
            progress: t,
            isDark: Theme.of(context).brightness == Brightness.dark,
          ),
          // `DecoratedBox`, not `Container(color:)`: a `ColoredBox` is opaque
          // to hit-testing at every alpha including zero, which would have
          // the resting bar eating drags over the cover photo.
          child: DecoratedBox(
            decoration: BoxDecoration(color: colors.surf.withValues(alpha: t)),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Row(
                  children: [
                    Expanded(child: _CollapsedTitle(progress: t)),
                    actions,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The collapsed bar's drop shadow, painted rather than declared.
///
/// `MaskFilter.blur` on a `Paint` is the one animated-blur technique this
/// project trusts on Android — `_ActiveTabIndicatorPainter` has driven one
/// from a running animation since the bottom bar shipped. A blurred
/// `BoxShadow` in a `BoxDecoration` that changes every frame is the shape
/// that crashed Impeller here, and this bar's decoration does change every
/// frame, so the shadow could not live there.
///
/// Values track `BottomNavBar`'s floating shadow (black at 0.08 light / 0.45
/// dark, 16px blur, 4px offset) so both ends of the screen lift by the same
/// amount, with `AppShadows.card`'s second contact layer added to anchor the
/// edge. Black rather than the `ink` token on purpose: `ink` is near-white in
/// dark mode and would paint a glow instead of a shadow.
class _TopBarShadowPainter extends CustomPainter {
  const _TopBarShadowPainter({required this.progress, required this.isDark});

  final double progress;
  final bool isDark;

  /// How far below the bar the shadow is allowed to reach.
  static const double _reach = 28;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    // Everything is clipped to the strip *below* the bar, so the blur's top
    // and side falloff never tints the bar itself — only the edge it casts
    // onto the list shows, at any point in the fade.
    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(0, size.height, size.width, size.height + _reach),
    );

    void cast(double alpha, double blur, double dy) {
      canvas.drawRect(
        // Grown past the canvas on the top and sides so only the bottom
        // edge's falloff is ever in frame.
        Rect.fromLTRB(-blur, -blur, size.width + blur, size.height + dy),
        Paint()
          ..color = Colors.black.withValues(alpha: alpha * progress)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
      );
    }

    cast(isDark ? 0.45 : 0.08, 16, 4);
    cast(isDark ? 0.30 : 0.05, 4, 1.5);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TopBarShadowPainter old) =>
      old.progress != progress || old.isDark != isDark;
}

/// The app bar's identity: the avatar and the name, sliding in from the left
/// and fading up as [progress] runs 0 → 1.
///
/// `Transform.translate` is safe for that slide only because this is inert:
/// ADR-024's hit-test trap — a translated child cannot take a tap past its
/// own untransformed box — bites tappable overlaps, and this one is wrapped
/// in an `IgnorePointer` so it never takes a tap at all.
///
/// Scoped to its own `BlocSelector` on `state.user`: the bar above rebuilds
/// on every scroll frame, and a `BlocBuilder` there would re-run a full
/// `ProfileState` comparison that often for the two fields this reads.
class _CollapsedTitle extends StatelessWidget {
  const _CollapsedTitle({required this.progress});

  final double progress;

  static const double _avatarSize = 32;

  @override
  Widget build(BuildContext context) {
    if (progress == 0) return const SizedBox.shrink();
    final colors = AppColors.of(context);

    return BlocSelector<ProfileCubit, ProfileState, UserEntity?>(
      selector: (state) => state.user,
      builder: (context, user) {
        // The loading and error states render no header, so there is no
        // identity to promote up here either — the buttons then stand alone,
        // exactly as they did before this bar existed.
        if (user == null) return const SizedBox.shrink();
        final fullName = user.fullName?.trim() ?? '';
        final displayName = fullName.isEmpty ? user.username : fullName;

        return IgnorePointer(
          child: Opacity(
            opacity: progress,
            child: Transform.translate(
              offset: Offset(-20 * (1 - progress), 0),
              child: Row(
                children: [
                  AppAvatar(
                    initials: Formatters.initialsFrom(displayName),
                    seed: avatarSeedForId(user.id),
                    imageUrl: user.avatarUrl,
                    size: _avatarSize,
                    borderWidth: 1.5,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.titleRow.copyWith(
                            color: colors.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '@${user.username}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.metaMonoSm.copyWith(
                            color: colors.ink2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Renders the active tab's posts as full feed-style cards, in the same
/// single scroll view as the rest of the profile — no nested grid/list of
/// its own, so there's exactly one scrollable for the whole screen.
class _PostList extends StatelessWidget {
  const _PostList({required this.posts, required this.tab});
  final List<PostEntity> posts;
  final ProfileTab tab;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    if (posts.isEmpty) {
      final (title, hint) = switch (tab) {
        ProfileTab.posts => (
          'NOTHING POSTED YET',
          'Your posts will show up here.',
        ),
        ProfileTab.reposts => (
          'NOTHING SHARED YET',
          'Repost something from your feed and it lands here.',
        ),
        ProfileTab.saved => (
          'NOTHING SAVED YET',
          'Tap Save on any post in your feed and it lands here.',
        ),
      };
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 30),
        decoration: BoxDecoration(
          border: Border.all(color: colors.line, width: 1.5),
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: AppTextStyles.eyebrow.copyWith(color: colors.ink2),
            ),
            const SizedBox(height: 8),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySm.copyWith(color: colors.ink2),
            ),
          ],
        ),
      );
    }

    final cubit = context.read<ProfileCubit>();
    return Column(
      children: [
        for (final post in posts)
          PostCard(
            post: post,
            onOpen: () => context.pushNamed(
              RouteNames.postDetail,
              pathParameters: {'postId': post.id},
            ),
            onLike: () => cubit.toggleLike(post),
            onReact: (type) => cubit.react(post, type),
            onSave: () => cubit.toggleSave(post.id),
            onRepost: () => cubit.toggleRepost(post),
          ),
      ],
    );
  }
}
