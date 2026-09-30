import 'dart:io';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
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
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/app_status_snackbar.dart';
import '../../../../shared/widgets/app_warning_dialog.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/glow_border.dart';
import '../../../../shared/widgets/ink_outline.dart';
import '../../../../shared/widgets/segmented_tabs.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/domain/usecases/logout_usecase.dart';
import '../../../feed/domain/entities/post_entity.dart';
import '../../../feed/presentation/widgets/post_card.dart';
import '../bloc/profile_cubit.dart';
import '../widgets/profile_details_card.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_top_bar.dart';
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
      ProfileTopBar.collapseEnd,
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
                      // button of its own (`bottom_nav_bar.dart`). This and
                      // the Feed header's Circle button are the only ways
                      // into it — keep at least one.
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
                            AppButton(
                              label: state.loadingMorePosts
                                  ? 'Loading…'
                                  : 'Load more',
                              variant: AppButtonVariant.secondary,
                              dense: true,
                              onPressed: state.loadingMorePosts
                                  ? null
                                  : cubit.loadMorePosts,
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
          // scroll frame never re-runs the menu's closure list. The identity
          // is selected outside the scroll listener, so a scroll frame never
          // re-runs a `ProfileState` comparison either.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: BlocSelector<ProfileCubit, ProfileState, UserEntity?>(
              selector: (state) => state.user,
              builder: (context, user) {
                final fullName = user?.fullName?.trim() ?? '';
                final identity = user == null
                    ? null
                    : ProfileBarIdentity(
                        id: user.id,
                        displayName: fullName.isEmpty ? user.username : fullName,
                        username: user.username,
                        avatarUrl: user.avatarUrl,
                      );
                return ValueListenableBuilder<double>(
                  valueListenable: _scrollOffset,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkOutline(
                        child: AppIconButton(
                          icon: const Icon(CupertinoIcons.line_horizontal_3),
                          onPressed: () => _openAccountMenu(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkOutline(
                        child: AppIconButton(
                          icon: const Icon(CupertinoIcons.search),
                          onPressed: () => context.pushNamed(RouteNames.search),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                  builder: (context, offset, actions) =>
                      ProfileTopBar(offset: offset, identity: identity, actions: actions!),
                );
              },
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
        isDark ? CupertinoIcons.moon : CupertinoIcons.sun_max,
        'Theme',
        isDark ? 'Dark' : 'Light',
      ),
      (
        'story-archive',
        CupertinoIcons.book,
        'Story archive',
        'Every story you have posted',
      ),
      (
        'feedback',
        CupertinoIcons.text_bubble,
        'Send feedback',
        'Rate a feature and tell us why',
      ),
      (
        'notifications',
        CupertinoIcons.bell,
        'Notification preferences',
        null,
      ),
      (
        'version',
        CupertinoIcons.info_circle,
        'App version',
        'The build running on this device',
      ),
      ('logout', CupertinoIcons.square_arrow_right, 'Log out', null),
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
              leading: const Icon(CupertinoIcons.photo_on_rectangle),
              title: Text(cover ? 'Choose cover' : 'Choose avatar'),
              onTap: () => Navigator.pop(context, 'choose'),
            ),
            if ((cover
                    ? cubit.state.user?.coverUrl
                    : cubit.state.user?.avatarUrl) !=
                null)
              ListTile(
                leading: const Icon(CupertinoIcons.delete),
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
      icon: CupertinoIcons.square_arrow_right,
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

  /// Outlined like every other field in the app, glowing yellow on focus.
  InputDecoration _decoration(BuildContext context, String label, {String? helper}) {
    final colors = AppColors.of(context);
    final radius = BorderRadius.circular(AppRadii.xs);
    final rest = OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: colors.line, width: 1.5));
    return InputDecoration(
      labelText: label,
      helperText: helper,
      enabledBorder: rest,
      disabledBorder: rest,
      focusedBorder: GlowInputBorder(borderRadius: radius, borderSide: BorderSide(color: colors.yel, width: 1.5)),
    );
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
                decoration: _decoration(
                  context,
                  'Username',
                  helper: 'You can change your username once every 7 days.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _fullName,
                enabled: !_saving,
                maxLength: 100,
                decoration: _decoration(context, 'Full name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bio,
                enabled: !_saving,
                maxLength: 500,
                maxLines: 3,
                decoration: _decoration(context, 'Bio'),
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

/// Renders the active tab's posts as full feed-style cards, in the same
/// single scroll view as the rest of the profile — no nested grid/list of
/// its own, so there's exactly one scrollable for the whole screen.
class _PostList extends StatelessWidget {
  const _PostList({required this.posts, required this.tab});
  final List<PostEntity> posts;
  final ProfileTab tab;

  @override
  Widget build(BuildContext context) {
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
      return EmptyStateCard(title: title, hint: hint);
    }

    final cubit = context.read<ProfileCubit>();
    return Column(
      children: [
        for (final post in posts)
          PostCard(
            post: post,
            onOpen: () => _openPost(context, cubit, post.id),
            onLike: () => cubit.toggleLike(post),
            onReact: (type) => cubit.react(post, type),
            onSave: () => cubit.toggleSave(post.id),
            onRepost: () => cubit.toggleRepost(post),
          ),
      ],
    );
  }
}

/// Opens the post's own screen and applies whatever it pops back onto this
/// row — a reaction or a comment made in there changes counts the card here
/// shows, and nothing re-fetches this list on the way back. See ADR-032.
Future<void> _openPost(BuildContext context, ProfileCubit cubit, String postId) async {
  final updated = await context.pushNamed<PostEntity>(RouteNames.postDetail, pathParameters: {'postId': postId});
  if (updated != null) cubit.applyUpdated(updated);
}
