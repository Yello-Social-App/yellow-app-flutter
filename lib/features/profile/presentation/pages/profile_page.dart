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
import '../../../../shared/extensions/string_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_status_snackbar.dart';
import '../../../../shared/widgets/app_warning_dialog.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/image_placeholder.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/domain/usecases/logout_usecase.dart';
import '../../../feed/domain/entities/post_entity.dart';
import '../../../feed/presentation/widgets/post_card.dart';
import '../bloc/profile_cubit.dart';

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

class _ProfileView extends StatelessWidget {
  const _ProfileView();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cubit = context.read<ProfileCubit>();
    final coverShadow = Theme.of(context).brightness == Brightness.dark
        ? Colors.black
        : Colors.white;

    return Scaffold(
      backgroundColor: colors.bg,
      body: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, state) {
          if (state.status == ProfileStatus.initial ||
              (state.status == ProfileStatus.loading && state.user == null)) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == ProfileStatus.error && state.user == null) {
            return SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ErrorView(
                    message:
                        state.errorMessage ?? 'Could not load your profile.',
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
                SizedBox(
                  height: 210,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: user.coverUrl == null
                            ? const ImagePlaceholder()
                            : Image.network(
                                user.coverUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const ImagePlaceholder(),
                              ),
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.45),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 90,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  colors.bg,
                                  coverShadow.withValues(alpha: 0.45),
                                  coverShadow.withValues(alpha: 0),
                                ],
                                stops: const [0, 0.35, 1],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 24,
                        right: 14,
                        child: IconButton.filled(
                          tooltip: 'Edit cover',
                          onPressed: state.isUploadingAvatar
                              ? null
                              : () => _pickAvatar(context, cubit, cover: true),
                          icon: const Icon(
                            Icons.camera_alt_rounded,
                            size: 20,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -20),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    decoration: BoxDecoration(
                      color: colors.surf,
                      border: Border.all(color: colors.line, width: 1.5),
                      borderRadius: BorderRadius.circular(AppRadii.huge),
                    ),
                    child: Column(
                      children: [
                        Transform.translate(
                          offset: const Offset(0, -48),
                          child: GestureDetector(
                            onTap: state.isUploadingAvatar
                                ? null
                                : () => _pickAvatar(context, cubit),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: colors.surf,
                                      width: 6,
                                    ),
                                  ),
                                  child: AppAvatar(
                                    initials: (user.fullName ?? user.username)
                                        .initials,
                                    seed: avatarSeedForId(user.id),
                                    imageUrl: user.avatarUrl,
                                    size: 96,
                                    borderWidth: 3,
                                  ),
                                ),
                                if (state.isUploadingAvatar)
                                  Positioned.fill(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.black.withValues(
                                          alpha: 0.45,
                                        ),
                                      ),
                                      child: const Center(
                                        child: SizedBox(
                                          width: 26,
                                          height: 26,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: colors.yel,
                                        border: Border.all(
                                          color: colors.ink,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.camera_alt,
                                        size: 15,
                                        color: colors.onYel,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(0, -34),
                          child: Column(
                            children: [
                              Text(
                                user.fullName ?? user.username,
                                style: AppTextStyles.displayLg.copyWith(
                                  color: colors.ink,
                                ),
                              ),
                              const SizedBox(height: 11),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  // vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: colors.line),
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.pill,
                                  ),
                                ),
                                child: Text(
                                  user.username.withAtSign.toUpperCase(),
                                  style: AppTextStyles.metaMono.copyWith(
                                    color: colors.ink2,
                                  ),
                                ),
                              ),
                              if ((user.bio ?? '').isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Text(
                                  user.bio!,
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.bodySm.copyWith(
                                    color: colors.ink2,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AppButton(
                                    label: 'Edit profile',
                                    onPressed: () =>
                                        _showEditSheet(context, cubit, user),
                                    borderColor: colors.ink3,
                                  ),
                                  const SizedBox(width: 8),
                                  BlocBuilder<ThemeCubit, ThemeMode>(
                                    bloc: sl<ThemeCubit>(),
                                    builder: (context, mode) => AppButton(
                                      label: mode == ThemeMode.dark
                                          ? 'Dark'
                                          : 'Light',
                                      variant: AppButtonVariant.outline,
                                      onPressed: () =>
                                          sl<ThemeCubit>().toggle(),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  AppButton(
                                    label: 'Log out',
                                    variant: AppButtonVariant.outline,
                                    onPressed: () => _confirmLogout(context),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  // No `Transform.translate` (or any negative-space trick)
                  // on this block on purpose — it used to be shifted `-70`
                  // to overlap the card above, which is where the
                  // Connections stat tile's tap started silently failing.
                  //
                  // Root cause (2026-09-07, confirmed on Sean's emulator
                  // via adb): `RenderTransform.hitTest` inverse-transforms
                  // an incoming tap and checks it against its child's
                  // *untransformed* size, which can never accept a negative
                  // coordinate — so a transform can only hit-test taps up
                  // to `-offset` px above its natural box, and this card's
                  // real rendered height pushed the actual overlap past
                  // what `-70` could reach back into. Reordering
                  // `Padding`/`Transform` didn't fix it; padding out this
                  // block's own reach with a spacer didn't either. The
                  // natural next move — give the card above a negative
                  // bottom margin so this block could stay in plain,
                  // untransformed (and therefore fully tap-safe) flow —
                  // turned out to be a dead end too: both `Container.margin`
                  // and `Padding.padding` assert non-negative in this
                  // Flutter version (`container.dart:271`,
                  // `shifted_box.dart:134` — confirmed by crashing on both).
                  //
                  // So this block is back to plain flow, with no overlap
                  // into the card at all — a real (small) visual step down
                  // from the original tight design, traded deliberately for
                  // an interactive element that reliably works. A pixel-
                  // perfect version of the overlap is possible via `Stack`
                  // + `Positioned` (Positioned's offsets aren't `EdgeInsets`
                  // and aren't hit-test-unsafe the way `Transform` is), but
                  // needs the card's rendered height to size it correctly —
                  // not implemented here since it wasn't asked for.
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _StatTile(
                            value: '${user.friendsCount}',
                            label: 'Connections',
                            // Circle/friends is shell branch index 1 (see
                            // app_router.dart) — it has no bottom-nav button
                            // right now (bottom_nav_bar.dart), so this stat
                            // is currently the only way back to that screen.
                            onTap: () =>
                                StatefulNavigationShell.of(context).goBranch(1),
                          ),
                          const SizedBox(width: 10),
                          _StatTile(
                            value: '${state.repostedPosts.length}',
                            label: 'Shared',
                            // Same "tap a stat, push a whole screen" pattern
                            // as Connections above — pushes a dedicated
                            // screen (see `shared_posts_page.dart`) with
                            // the same posts as the in-page "Shared" tab
                            // below, since Connections already proved that
                            // pattern reads better than an in-page filter
                            // for content worth a full screen of its own.
                            onTap: () =>
                                context.pushNamed(RouteNames.sharedPosts),
                          ),
                          const SizedBox(width: 10),
                          _StatTile(
                            value: '${user.createdAt.year}',
                            label: 'Joined',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _TabBar(state: state, onSelect: cubit.selectTab),
                      const SizedBox(height: 16),
                      _PostList(posts: state.activeTabPosts, tab: state.tab),
                      if (state.tab != ProfileTab.saved && state.hasMorePosts)
                        TextButton(
                          onPressed: state.loadingMorePosts
                              ? null
                              : cubit.loadMorePosts,
                          child: Text(
                            state.loadingMorePosts ? 'Loading…' : 'Load more',
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

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label, this.onTap});
  final String value;
  final String label;

  /// Null keeps the tile plain/inert (currently just Joined) — [InkWell]
  /// shows no ripple and eats no taps when its `onTap` is null.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Expanded(
      child: Material(
        color: colors.surf,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: colors.line, width: 1.5),
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            child: Column(
              children: [
                Text(
                  value,
                  style: AppTextStyles.titleLg.copyWith(color: colors.ink),
                ),
                const SizedBox(height: 7),
                Text(
                  label.toUpperCase(),
                  style: AppTextStyles.metaMono.copyWith(color: colors.ink2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.state, required this.onSelect});
  final ProfileState state;
  final void Function(ProfileTab) onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final tabs = [
      (
        ProfileTab.posts,
        'Post ${state.user?.postsCount ?? state.originalPosts.length}',
      ),
      (ProfileTab.reposts, 'Shared ${state.repostedPosts.length}'),
      (ProfileTab.saved, 'Saved ${state.savedPosts.length}'),
    ];
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: colors.surf,
        border: Border.all(color: colors.line, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        children: [
          for (final t in tabs)
            Expanded(
              child: Material(
                color: state.tab == t.$1 ? colors.yel : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  onTap: () => onSelect(t.$1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: Center(
                      child: Text(
                        t.$2.toUpperCase(),
                        style: AppTextStyles.navLabel.copyWith(
                          color: state.tab == t.$1 ? colors.onYel : colors.ink2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
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
