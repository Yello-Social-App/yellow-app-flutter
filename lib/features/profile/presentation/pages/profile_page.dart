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
import '../../../../core/theme/theme_cubit.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/app_status_snackbar.dart';
import '../../../../shared/widgets/app_warning_dialog.dart';
import '../../../../shared/widgets/error_view.dart';
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
    return BlocProvider(create: (_) => sl<ProfileCubit>()..load(), child: const _ProfileView());
  }
}

class _ProfileView extends StatefulWidget {
  const _ProfileView();

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  /// Whether the details card shows its secondary rows. Deliberately local
  /// and ephemeral: nothing outside this screen reads it, and it shouldn't
  /// survive a reload — so it stays out of [ProfileState].
  bool _detailsExpanded = false;

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
                  (state.status == ProfileStatus.loading && state.user == null)) {
                return const ShimmerOwnProfileView();
              }
              if (state.status == ProfileStatus.error && state.user == null) {
                return SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: ErrorView(
                        message: state.errorMessage ?? 'Could not load your profile.',
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
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 112),
                  children: [
                    ProfileHeader(
                      user: user,
                      connections: state.connections,
                      isUploadingImage: state.isUploadingAvatar,
                      detailsExpanded: _detailsExpanded,
                      onToggleDetails: () => setState(() => _detailsExpanded = !_detailsExpanded),
                      onEditAvatar: () => _pickAvatar(context, cubit),
                      onEditCover: () => _pickAvatar(context, cubit, cover: true),
                      onEditProfile: () => _showEditSheet(context, cubit, user),
                      onAddStory: () => context.pushNamed(RouteNames.storyCompose),
                      onCompose: () => context.pushNamed(RouteNames.createPost),
                      // Circle is shell branch 1 and still has no bottom-nav
                      // button of its own (`bottom_nav_bar.dart`), so this and
                      // the account menu's "Your circle" are the only ways
                      // into it.
                      onOpenConnections: () => StatefulNavigationShell.of(context).goBranch(1),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: ProfileDetailsCard(
                        user: user,
                        expanded: _detailsExpanded,
                        onEdit: () => _showEditSheet(context, cubit, user),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // The chips sit directly above the list they filter —
                    // the reference puts them higher, above its details
                    // block, which reads as if they filtered that too.
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: _FilterChips(state: state, onSelect: cubit.selectTab),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Column(
                        children: [
                          _PostList(posts: state.activeTabPosts, tab: state.tab),
                          if (state.tab != ProfileTab.saved && state.hasMorePosts)
                            TextButton(
                              onPressed: state.loadingMorePosts ? null : cubit.loadMorePosts,
                              child: Text(state.loadingMorePosts ? 'Loading…' : 'Load more'),
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
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Row(
                  children: [
                    AppIconButton(
                      icon: const Icon(Icons.menu_rounded),
                      onPressed: () => _openAccountMenu(context),
                    ),
                    const Spacer(),
                    AppIconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => context.pushNamed(RouteNames.createPost),
                    ),
                    const SizedBox(width: 8),
                    AppIconButton(
                      icon: const Icon(Icons.search_rounded),
                      onPressed: () => context.pushNamed(RouteNames.search),
                    ),
                    const SizedBox(width: 8),
                    AppIconButton(
                      icon: const Icon(Icons.more_horiz_rounded),
                      onPressed: () => _openProfileMenu(context, cubit),
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

  /// The reference's hamburger: everything that isn't a profile edit —
  /// appearance, the account-level screens (Privacy & safety, Send feedback),
  /// the ones with no nav button of their own, and sign-out.
  ///
  /// This is where the old four-button row and the Settings sheet it opened
  /// both ended up. The action row on the header is for things you do *to
  /// this profile*; none of these are.
  Future<void> _openAccountMenu(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final action = await _showMenu(context, [
      (
        'theme',
        isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        isDark ? 'Switch to light' : 'Switch to dark',
        null,
      ),
      ('circle', Icons.group_outlined, 'Your circle', null),
      ('shared', Icons.repeat_rounded, 'Shared posts', null),
      ('privacy', Icons.shield_outlined, 'Privacy & safety', 'Your reports and muted accounts'),
      ('feedback', Icons.rate_review_outlined, 'Send feedback', 'Rate a feature and tell us why'),
      ('notifications', Icons.notifications_none_rounded, 'Notification preferences', null),
      ('logout', Icons.logout_rounded, 'Log out', null),
    ]);
    if (action == null || !context.mounted) return;
    switch (action) {
      case 'theme':
        sl<ThemeCubit>().toggle();
      case 'circle':
        StatefulNavigationShell.of(context).goBranch(1);
      case 'shared':
        context.pushNamed(RouteNames.sharedPosts);
      case 'privacy':
        context.pushNamed(RouteNames.privacySafety);
      case 'feedback':
        context.pushNamed(RouteNames.sendFeedback);
      case 'notifications':
        context.pushNamed(RouteNames.notificationPreferences);
      case 'logout':
        await _confirmLogout(context);
    }
  }

  Future<void> _openProfileMenu(BuildContext context, ProfileCubit cubit) async {
    final user = cubit.state.user;
    if (user == null) return;
    final action = await _showMenu(context, [
      ('edit', Icons.edit_outlined, 'Edit profile', null),
      ('avatar', Icons.account_circle_outlined, 'Change profile photo', null),
      ('cover', Icons.image_outlined, 'Change cover photo', null),
    ]);
    if (action == null || !context.mounted) return;
    switch (action) {
      case 'edit':
        _showEditSheet(context, cubit, user);
      case 'avatar':
        await _pickAvatar(context, cubit);
      case 'cover':
        await _pickAvatar(context, cubit, cover: true);
    }
  }

  /// Items are `(value, icon, label, subtitle?)`.
  ///
  /// `useRootNavigator`, same reason as `showPostOptionsSheet`: this opens
  /// from a tab whose Scaffold sits under `MainShellPage`'s floating nav bar,
  /// so a sheet on the nested Navigator would render behind it.
  Future<String?> _showMenu(BuildContext context, List<(String, IconData, String, String?)> items) {
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
              decoration: BoxDecoration(color: colors.line, borderRadius: BorderRadius.circular(AppRadii.pill)),
            ),
            for (final (value, icon, label, subtitle) in items)
              ListTile(
                leading: Icon(icon, color: colors.ink),
                title: Text(label, style: AppTextStyles.body.copyWith(color: colors.ink)),
                subtitle: subtitle == null
                    ? null
                    : Text(subtitle, style: AppTextStyles.metaMonoSm.copyWith(color: colors.ink2)),
                onTap: () => Navigator.pop(context, value),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAvatar(BuildContext context, ProfileCubit cubit, {bool cover = false}) async {
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
            if ((cover ? cubit.state.user?.coverUrl : cubit.state.user?.avatarUrl) != null)
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
        ok = await cubit.updateProfile(removeCover: cover ? true : null, removeAvatar: cover ? null : true);
      } else {
        final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
        if (picked == null || !context.mounted) return;
        ok = cover ? await cubit.updateProfile(cover: File(picked.path)) : await cubit.uploadAvatar(File(picked.path));
      }
      if (!context.mounted) return;
      if (ok) {
        AppStatusSnackbar.showSuccess(context, message: 'Your profile image has been updated.');
      } else {
        AppStatusSnackbar.showError(context, message: cubit.state.errorMessage ?? 'Could not update image.');
      }
    } catch (_) {
      if (context.mounted) {
        AppStatusSnackbar.showError(context, message: 'Could not open this image. Please try again.');
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

  void _showEditSheet(BuildContext context, ProfileCubit cubit, UserEntity user) {
    showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.of(context).bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _EditProfileSheet(cubit: cubit, user: user),
    ).then((saved) {
      if (saved == true && context.mounted) {
        AppStatusSnackbar.showSuccess(context, message: 'Your profile has been updated.');
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
  late final _fullName = TextEditingController(text: widget.user.fullName ?? '');
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
      username: _username.text.trim() == user.username ? null : _username.text.trim(),
      fullName: _fullName.text == (user.fullName ?? '') ? null : _fullName.text.trim(),
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
        _error = widget.cubit.state.errorMessage ?? 'Could not save your changes.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Edit profile', style: AppTextStyles.titleLg.copyWith(color: AppColors.of(context).ink)),
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
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              const SizedBox(height: 16),
              AppButton(label: _saving ? 'Saving…' : 'Save', fullWidth: true, onPressed: _saving ? null : _save),
            ],
          ),
        ),
      ),
    );
  }
}

/// The reference's All / Photos / Reels row, over the three post collections
/// this app actually has.
class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.state, required this.onSelect});
  final ProfileState state;
  final void Function(ProfileTab) onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final chips = [
      (ProfileTab.posts, 'All', state.user?.postsCount ?? state.originalPosts.length),
      (ProfileTab.reposts, 'Shared', state.repostedPosts.length),
      (ProfileTab.saved, 'Saved', state.savedPosts.length),
    ];

    // Horizontally scrollable rather than a plain Row: the labels carry
    // counts, so three chips can outgrow a narrow screen's width and a Row
    // would overflow instead of letting them slide.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (tab, label, count) in chips) ...[
            if (tab != chips.first.$1) const SizedBox(width: 8),
            _Chip(label: '$label $count', selected: state.tab == tab, onTap: () => onSelect(tab), colors: colors),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap, required this.colors});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? colors.yelb : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        side: BorderSide(color: selected ? colors.yel : colors.line, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: AppTextStyles.button.copyWith(color: selected ? colors.yeld : colors.ink2, fontSize: 13),
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
    final colors = AppColors.of(context);
    if (posts.isEmpty) {
      final (title, hint) = switch (tab) {
        ProfileTab.posts => ('NOTHING POSTED YET', 'Your posts will show up here.'),
        ProfileTab.reposts => ('NOTHING SHARED YET', 'Repost something from your feed and it lands here.'),
        ProfileTab.saved => ('NOTHING SAVED YET', 'Tap Save on any post in your feed and it lands here.'),
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
            Text(title, style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
            const SizedBox(height: 8),
            Text(hint, textAlign: TextAlign.center, style: AppTextStyles.bodySm.copyWith(color: colors.ink2)),
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
            onOpen: () => context.pushNamed(RouteNames.postDetail, pathParameters: {'postId': post.id}),
            onLike: () => cubit.toggleLike(post),
            onReact: (type) => cubit.react(post, type),
            onSave: () => cubit.toggleSave(post.id),
            onRepost: () => cubit.toggleRepost(post),
          ),
      ],
    );
  }
}
