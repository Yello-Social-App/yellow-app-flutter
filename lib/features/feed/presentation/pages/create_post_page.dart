import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/extensions/string_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_status_snackbar.dart';
import '../../../../shared/widgets/image_placeholder.dart';
import '../../domain/entities/post_entity.dart';
import '../bloc/create_post_cubit.dart';
import '../bloc/feed_cubit.dart';

class CreatePostPage extends StatelessWidget {
  const CreatePostPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(create: (_) => sl<CreatePostCubit>(), child: const _CreatePostView());
  }
}

class _CreatePostView extends StatefulWidget {
  const _CreatePostView();

  @override
  State<_CreatePostView> createState() => _CreatePostViewState();
}

class _CreatePostViewState extends State<_CreatePostView> {
  final _textController = TextEditingController();
  final _picker = ImagePicker();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImages(CreatePostCubit cubit) async {
    final remaining = AppConstants.postMaxImages - cubit.state.images.length;
    if (remaining <= 0) {
      AppStatusSnackbar.showError(context, message: 'You can attach up to ${AppConstants.postMaxImages} photos.');
      return;
    }
    final picked = await _picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: AppConstants.postImageMaxDimension,
      maxHeight: AppConstants.postImageMaxDimension,
      limit: remaining,
    );
    if (picked.isNotEmpty) cubit.addImages(picked.map((x) => File(x.path)).toList());
  }

  void _notAvailableYet(String label) {
    AppStatusSnackbar.showError(context, message: '$label attachments aren\'t available yet.');
  }

  Future<void> _addTag(CreatePostCubit cubit) async {
    final tag = await showDialog<String>(context: context, builder: (_) => const _AddTagDialog());
    if (tag != null && tag.trim().isNotEmpty) cubit.addTag(tag);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cubit = context.read<CreatePostCubit>();
    // Reused straight from the singleton `FeedCubit` (this page is only ever
    // reached from Feed, which already fetched it) rather than adding a
    // second `GetMeUseCase` dependency here just for display — same
    // singleton this file already reaches into below for `prependPost`.
    final me = sl<FeedCubit>().state.me;

    return BlocListener<CreatePostCubit, CreatePostState>(
      listenWhen: (prev, curr) =>
          curr.status == CreatePostStatus.published || curr.status == CreatePostStatus.error,
      listener: (context, state) {
        if (state.status == CreatePostStatus.error) {
          AppStatusSnackbar.showError(context, message: state.errorMessage ?? 'Could not publish your post.');
          return;
        }
        if (state.publishedPost != null) sl<FeedCubit>().prependPost(state.publishedPost!);
        Navigator.of(context).maybePop();
      },
      child: Scaffold(
        backgroundColor: colors.bg,
        body: SafeArea(
          child: BlocBuilder<CreatePostCubit, CreatePostState>(
            builder: (context, state) {
              return Column(
                children: [
                  _TopBar(state: state, onPublish: cubit.publish),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
                          decoration: BoxDecoration(
                            color: colors.surf,
                            border: Border.all(color: colors.line, width: 1.5),
                            borderRadius: BorderRadius.circular(AppRadii.xl),
                          ),
                          child: Row(
                            children: [
                              AppAvatar(
                                initials: me == null ? '' : (me.fullName ?? me.username).initials,
                                seed: me == null ? 0 : avatarSeedForId(me.id),
                                imageUrl: me?.avatarUrl,
                                size: 44,
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      me == null ? 'You' : (me.fullName ?? me.username),
                                      style: AppTextStyles.titleMd.copyWith(color: colors.ink),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'POSTING AS YOURSELF',
                                      style: AppTextStyles.metaMono.copyWith(color: colors.ink2),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        _SectionLabel('WHO CAN SEE THIS'),
                        Row(
                          children: [
                            for (final a in const [
                              (PostVisibility.public, '◉', 'Public'),
                              (PostVisibility.friends, '◈', 'Circle'),
                              (PostVisibility.private, '❖', 'Close'),
                            ])
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(right: a.$1 == PostVisibility.private ? 0 : 7),
                                  child: _AudienceButton(
                                    icon: a.$2,
                                    label: a.$3,
                                    selected: state.visibility == a.$1,
                                    onTap: () => cubit.setVisibility(a.$1),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        _SectionLabel('YOUR WORDS'),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colors.surf,
                            border: Border.all(color: colors.line, width: 1.5),
                            borderRadius: BorderRadius.circular(AppRadii.xl),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _textController,
                                maxLines: 5,
                                minLines: 4,
                                onChanged: cubit.setText,
                                style: AppTextStyles.body.copyWith(fontSize: 18, color: colors.ink),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText:
                                      'What ur\'s stories today? Take your time this one cuz '
                                      'stays on your profile.',
                                  hintStyle: AppTextStyles.body.copyWith(fontSize: 18, color: colors.ink3),
                                ),
                              ),
                              Container(height: 1, color: colors.line2, margin: const EdgeInsets.only(bottom: 12)),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${state.charCount} CHARACTERS',
                                    style: AppTextStyles.metaMono.copyWith(color: colors.ink2),
                                  ),
                                  Text(
                                    state.charCount == 0 ? 'EMPTY' : (state.isShort ? 'SHORT' : 'GOOD LENGTH'),
                                    style: AppTextStyles.metaMono.copyWith(
                                      color: state.charCount > 0 && !state.isShort ? colors.grn : colors.ink2,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        _SectionLabel('MEDIA'),
                        _MediaCardStack(
                          images: state.images,
                          onAddMore: () => _pickImages(cubit),
                          onRemoveAt: cubit.removeImageAt,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            for (final t in [
                              (Icons.photo_camera_outlined, 'Photos', () => _pickImages(cubit)),
                              (Icons.videocam_outlined, 'Video', () => _notAvailableYet('Video')),
                              (Icons.place_outlined, 'Place', () => _notAvailableYet('Place')),
                              (Icons.sentiment_satisfied_outlined, 'Feel', () => _notAvailableYet('Feel')),
                            ])
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(right: t.$2 == 'Feel' ? 0 : 8),
                                  child: Material(
                                    color: colors.surf,
                                    borderRadius: BorderRadius.circular(AppRadii.md),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(AppRadii.md),
                                      onTap: t.$3,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: colors.line, width: 1.5),
                                          borderRadius: BorderRadius.circular(AppRadii.md),
                                        ),
                                        child: Column(
                                          children: [
                                            Icon(t.$1, size: 18, color: colors.ink),
                                            const SizedBox(height: 8),
                                            Text(t.$2, style: AppTextStyles.metaMono.copyWith(color: colors.ink2)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        _SectionLabel('TAGS'),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            // The suggested pool plus any tag the user typed
                            // in via "Add tag" that isn't already in it —
                            // `{...}` de-dupes and keeps pool order first.
                            for (final tag in {...kTagPool, ...state.pickedTags})
                              _TagChip(
                                label: '#$tag',
                                selected: state.pickedTags.contains(tag),
                                onTap: () => cubit.toggleTag(tag),
                              ),
                            _AddTagChip(onTap: () => _addTag(cubit)),
                          ],
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 22),
                          decoration: BoxDecoration(
                            color: colors.surf,
                            border: Border.all(color: colors.line, width: 1.5),
                            borderRadius: BorderRadius.circular(AppRadii.xl),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                                decoration: BoxDecoration(
                                  border: Border(bottom: BorderSide(color: colors.line2)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('BEFORE YOU POST', style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
                                    Text(
                                      '${state.checked.length} OF ${kPrePublishChecks.length}',
                                      style: AppTextStyles.metaMono.copyWith(
                                        color: state.allChecked ? colors.grn : colors.ink2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              for (var i = 0; i < kPrePublishChecks.length; i++)
                                _CheckRow(
                                  label: kPrePublishChecks[i],
                                  checked: state.checked.contains(i),
                                  isLast: i == kPrePublishChecks.length - 1,
                                  onTap: () => cubit.toggleCheck(i),
                                ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(6, 14, 6, 0),
                          child: Text(
                            'Posts stay on your profile until you remove them. Stories '
                            'disappear after 24 hours — use the story button on the feed for '
                            'something quick.',
                            style: AppTextStyles.bodySm.copyWith(color: colors.ink2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The MEDIA preview: picked photos rendered as a fanned card stack (front
/// card centered, the previous/next photo peeking out on either side)
/// instead of a single flat image slot, so multi-photo posts read as a
/// deck you flip through rather than a filmstrip. Swipe left/right cycles
/// the front card through the whole selection, looping at both ends.
class _MediaCardStack extends StatefulWidget {
  const _MediaCardStack({required this.images, required this.onAddMore, required this.onRemoveAt});

  final List<File> images;
  final VoidCallback onAddMore;
  final void Function(int index) onRemoveAt;

  @override
  State<_MediaCardStack> createState() => _MediaCardStackState();
}

class _MediaCardStackState extends State<_MediaCardStack> {
  static const _height = 210.0;
  static const _swipeVelocityThreshold = 120.0;

  int _index = 0;

  @override
  void didUpdateWidget(_MediaCardStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Removing the current (or a lower-index) photo can leave `_index`
    // pointing past the new end of the list — clamp it back on screen.
    if (_index >= widget.images.length) {
      _index = widget.images.isEmpty ? 0 : widget.images.length - 1;
    }
  }

  void _shift(int delta) {
    final len = widget.images.length;
    if (len < 2) return;
    setState(() => _index = (_index + delta) % len);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final images = widget.images;

    if (images.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: SizedBox(
          height: _height,
          child: GestureDetector(
            onTap: widget.onAddMore,
            child: const ImagePlaceholder(caption: 'tap to add photos'),
          ),
        ),
      );
    }

    return SizedBox(
      height: _height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final frontW = constraints.maxWidth * 0.92;
          final peekW = constraints.maxWidth * 0.82;
          final peekDx = (frontW - peekW) / 2 + 16;

          return GestureDetector(
            // A left swipe (negative velocity) advances to the next photo;
            // a right swipe goes back — both loop via `_shift`'s modulo.
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity.abs() < _swipeVelocityThreshold) return;
              _shift(velocity < 0 ? 1 : -1);
            },
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                if (images.length > 1)
                  _PeekCard(
                    image: images[(_index - 1 + images.length) % images.length],
                    width: peekW,
                    height: _height - 16,
                    dx: -peekDx,
                    rotation: -0.08,
                  ),
                if (images.length > 1)
                  _PeekCard(
                    image: images[(_index + 1) % images.length],
                    width: peekW,
                    height: _height - 16,
                    dx: peekDx,
                    rotation: 0.08,
                  ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(animation), child: child),
                  ),
                  child: Container(
                    key: ValueKey(images[_index].path),
                    width: frontW,
                    height: _height,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadii.xl),
                      border: Border.all(color: colors.ink, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(images[_index], fit: BoxFit.cover),
                        if (images.length > 1)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${_index + 1}/${images.length}',
                                style: AppTextStyles.metaMono.copyWith(color: Colors.white, fontSize: 11),
                              ),
                            ),
                          ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: _RoundIconButton(icon: Icons.close, onTap: () => widget.onRemoveAt(_index)),
                        ),
                        if (images.length < AppConstants.postMaxImages)
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: _RoundIconButton(icon: Icons.add_photo_alternate_outlined, onTap: widget.onAddMore),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// One of the two out-of-focus photos fanned behind the front card in
/// [_MediaCardStack], hinting there's more to swipe to on that side.
class _PeekCard extends StatelessWidget {
  const _PeekCard({
    required this.image,
    required this.width,
    required this.height,
    required this.dx,
    required this.rotation,
  });

  final File image;
  final double width;
  final double height;
  final double dx;
  final double rotation;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(dx, 10),
      child: Transform.rotate(
        angle: rotation,
        child: Opacity(
          opacity: 0.7,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.xl),
              border: Border.all(color: Colors.black.withValues(alpha: 0.15), width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.file(image, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.state, required this.onPublish});
  final CreatePostState state;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.line, width: 1.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Material(
            color: colors.surf,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: BorderSide(color: colors.line, width: 1.5),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => Navigator.of(context).maybePop(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Text('Discard', style: AppTextStyles.metaMono.copyWith(color: colors.ink2)),
              ),
            ),
          ),
          Column(
            children: [
              Text('New post', style: AppTextStyles.titleMd.copyWith(color: colors.ink)),
              const SizedBox(height: 6),
              Text('STEP 2 OF 2 · REVIEW', style: AppTextStyles.metaMono.copyWith(fontSize: 10, color: colors.ink2)),
            ],
          ),
          Material(
            color: state.canPublish ? colors.yel : colors.surf2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: BorderSide(color: state.canPublish ? colors.ink : colors.line, width: 1.5),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: state.canPublish ? onPublish : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                child: Text(
                  'PUBLISH',
                  style: AppTextStyles.button.copyWith(color: state.canPublish ? colors.onYel : colors.ink3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Text(label, style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
    );
  }
}

class _AudienceButton extends StatelessWidget {
  const _AudienceButton({required this.icon, required this.label, required this.selected, required this.onTap});
  final String icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: selected ? colors.yel : colors.surf,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        side: BorderSide(color: selected ? colors.ink : colors.line, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Column(
            children: [
              Text(icon, style: TextStyle(fontSize: 15, color: selected ? colors.onYel : colors.ink2)),
              const SizedBox(height: 8),
              Text(label, style: AppTextStyles.metaMono.copyWith(color: selected ? colors.onYel : colors.ink2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: selected ? colors.yel : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: selected ? colors.ink : colors.line, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Text(label, style: AppTextStyles.metaMono.copyWith(color: selected ? colors.onYel : colors.ink2)),
        ),
      ),
    );
  }
}

/// Trailing chip in the TAGS `Wrap`, dashed-style (plain border, no fill)
/// to read as an action rather than a toggle — opens [_AddTagDialog].
class _AddTagChip extends StatelessWidget {
  const _AddTagChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: colors.line, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 14, color: colors.ink2),
              const SizedBox(width: 4),
              Text('Add tag', style: AppTextStyles.metaMono.copyWith(color: colors.ink2)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small text-entry card for typing a custom tag, in the same
/// bordered-card style as [AppWarningDialog] rather than a bare
/// [AlertDialog]. Resolves with the raw typed text (untrimmed/unnormalized —
/// [CreatePostCubit.addTag] does that) on "Add"/submit, or `null` on cancel.
class _AddTagDialog extends StatefulWidget {
  const _AddTagDialog();

  @override
  State<_AddTagDialog> createState() => _AddTagDialogState();
}

class _AddTagDialogState extends State<_AddTagDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        decoration: BoxDecoration(
          color: colors.surf,
          borderRadius: BorderRadius.circular(AppRadii.xxl),
          border: Border.all(color: colors.line),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ADD A TAG', style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLength: kMaxTagLength,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              style: AppTextStyles.body.copyWith(color: colors.ink),
              decoration: InputDecoration(
                prefixText: '#',
                counterText: '',
                hintText: 'yourtag',
                hintStyle: AppTextStyles.body.copyWith(color: colors.ink3),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: colors.line)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: colors.ink)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Cancel',
                    variant: AppButtonVariant.outline,
                    fullWidth: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(label: 'Add', fullWidth: true, onPressed: _submit),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.label, required this.checked, required this.isLast, required this.onTap});
  final String label;
  final bool checked;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: isLast ? null : Border(bottom: BorderSide(color: colors.line2)),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: checked ? colors.yel : Colors.transparent,
                border: Border.all(color: checked ? colors.ink : colors.line, width: 1.5),
              ),
              child: checked ? Icon(Icons.check, size: 14, color: colors.onYel) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: AppTextStyles.bodySm.copyWith(color: colors.ink)),
            ),
          ],
        ),
      ),
    );
  }
}
