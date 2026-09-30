import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/app_status_snackbar.dart';
import '../../../../shared/widgets/glow_border.dart';
import '../../domain/entities/sticker_entity.dart';
import '../../domain/usecases/sticker_usecases.dart';
import '../bloc/sticker_creator_cubit.dart';

/// What the creator hands back: the saved sticker, and whether the user asked
/// for it to go out straight away ("Save and send") or just to be kept.
typedef CreatedSticker = ({StickerEntity sticker, bool send});

/// Opens "Create a sticker" and returns the sticker that was saved, or null
/// if the user backed out.
///
/// The caller decides what to do with it — the picker puts it in `My stickers`
/// and, for [CreatedSticker.send], closes and sends. Nothing is sent from
/// here: a sticker message is `ChatCubit`'s to make, the same division as the
/// voice recorder, which also stops at "the thing exists on the server".
Future<CreatedSticker?> showStickerCreator(BuildContext context) => showModalBottomSheet<CreatedSticker>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (_) => BlocProvider(create: (_) => sl<StickerCreatorCubit>(), child: const _StickerCreatorSheet()),
);

class _StickerCreatorSheet extends StatefulWidget {
  const _StickerCreatorSheet();

  @override
  State<_StickerCreatorSheet> createState() => _StickerCreatorSheetState();
}

class _StickerCreatorSheetState extends State<_StickerCreatorSheet> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Picks a picture and uploads it as a draft.
  ///
  /// Downscaled on the way out through the app's one "how big a picked
  /// picture may be" number: 1600 px a side is comfortably inside the sticker
  /// route's own 4096 px / 16 MP ceiling, and keeps a phone camera's output
  /// well under 5 MB — both of which would otherwise come back as a 400 after
  /// the upload had already happened.
  Future<void> _pick(ImageSource source) async {
    final cubit = context.read<StickerCreatorCubit>();
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: AppConstants.postImageMaxDimension,
      maxHeight: AppConstants.postImageMaxDimension,
    );
    if (picked == null || !mounted) return;
    await cubit.usePicture(File(picked.path));
  }

  Future<void> _save({required bool send}) async {
    final sticker = await context.read<StickerCreatorCubit>().save();
    if (sticker == null || !mounted) return;
    Navigator.of(context).pop((sticker: sticker, send: send));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return BlocConsumer<StickerCreatorCubit, StickerCreatorState>(
      listenWhen: (previous, current) => previous.actionError != current.actionError && current.actionError != null,
      listener: (context, state) => AppStatusSnackbar.showError(context, message: state.actionError!),
      builder: (context, state) {
        final cubit = context.read<StickerCreatorCubit>();
        final editing = state.step == StickerCreatorStep.edit || state.step == StickerCreatorStep.saving;
        return SafeArea(
          top: false,
          child: Padding(
            // The name field sits low in the sheet, so the keyboard inset is
            // added here rather than left to Scaffold — a modal sheet gets
            // none of that for free.
            padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + MediaQuery.viewInsetsOf(context).bottom),
            child: Container(
              decoration: BoxDecoration(
                color: colors.surf,
                border: Border.all(color: colors.line, width: 1.5),
                borderRadius: BorderRadius.circular(AppRadii.xl),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(
                      title: editing ? 'Make it a sticker' : 'Create a sticker',
                      subtitle: editing
                          ? "It's saved to My stickers, so you can send it again any time."
                          : 'Use a photo or any picture, up to 5 MB.',
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: switch (state.step) {
                        StickerCreatorStep.pick => _PickStep(
                          error: state.pickError,
                          onChoose: () => _pick(ImageSource.gallery),
                          onCamera: () => _pick(ImageSource.camera),
                        ),
                        StickerCreatorStep.uploading => const _UploadingStep(),
                        StickerCreatorStep.edit ||
                        StickerCreatorStep.saving => _EditStep(
                          state: state,
                          nameController: _nameController,
                          onName: cubit.setName,
                          onBackground: cubit.setBackground,
                          onChangePicture: cubit.changePicture,
                          onSave: () => _save(send: false),
                          onSaveAndSend: () => _save(send: true),
                        ),
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleMd.copyWith(color: colors.ink)),
                const SizedBox(height: 3),
                Text(subtitle, style: AppTextStyles.bodySm.copyWith(color: colors.ink2)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AppIconButton(
            icon: const Icon(CupertinoIcons.xmark),
            size: 36,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}

/// Step one: choose a picture. The design's drop zone, minus the dropping —
/// on a phone the box itself is the "browse" control, and the camera is the
/// second source a desktop does not have.
class _PickStep extends StatelessWidget {
  const _PickStep({required this.error, required this.onChoose, required this.onCamera});

  final String? error;
  final VoidCallback onChoose;
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bad = error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: colors.surf2,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: InkWell(
            onTap: onChoose,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: Container(
              height: 176,
              decoration: BoxDecoration(
                border: Border.all(color: bad ? colors.red : colors.line, width: 1.5),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    bad ? CupertinoIcons.exclamationmark_triangle : CupertinoIcons.photo_on_rectangle,
                    size: 28,
                    color: bad ? colors.red : colors.ink2,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    bad ? "That picture won't work" : 'Choose a picture',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.titleSm.copyWith(color: colors.ink),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    error ?? 'PNG, JPG or WebP. Anything with one person, pet or thing works best.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySm.copyWith(color: bad ? colors.red : colors.ink2),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Photo library',
                variant: AppButtonVariant.secondary,
                dense: true,
                fullWidth: true,
                icon: const Icon(CupertinoIcons.photo_on_rectangle, size: 16),
                onPressed: onChoose,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppButton(
                label: 'Camera',
                variant: AppButtonVariant.secondary,
                dense: true,
                fullWidth: true,
                icon: const Icon(CupertinoIcons.camera, size: 16),
                onPressed: onCamera,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The gap between the pick and the edit step: the server is cropping,
/// scaling, stripping metadata and — once removal is switched on — cutting the
/// subject out.
class _UploadingStep extends StatelessWidget {
  const _UploadingStep();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      height: 176,
      decoration: BoxDecoration(
        color: colors.surf2,
        border: Border.all(color: colors.line, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)),
          const SizedBox(height: 14),
          Text('Making your sticker…', style: AppTextStyles.titleSm.copyWith(color: colors.ink)),
        ],
      ),
    );
  }
}

/// Step two: preview it, choose the background, name it, save it.
class _EditStep extends StatelessWidget {
  const _EditStep({
    required this.state,
    required this.nameController,
    required this.onName,
    required this.onBackground,
    required this.onChangePicture,
    required this.onSave,
    required this.onSaveAndSend,
  });

  final StickerCreatorState state;
  final TextEditingController nameController;
  final ValueChanged<String> onName;
  final ValueChanged<StickerBackground> onBackground;
  final VoidCallback onChangePicture;
  final VoidCallback onSave;
  final VoidCallback onSaveAndSend;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final busy = state.step == StickerCreatorStep.saving;
    final removed = state.background == StickerBackground.removed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Preview(image: state.preview, transparent: removed),
        if (!state.canRemoveBackground) ...[
          const SizedBox(height: 12),
          // The server's own words for it, so the creator and the API describe
          // the same outcome the same way.
          const _Notice(
            text: "There's no clear subject to cut out, so the background stays. "
                'A picture with one person, pet or thing works best.',
          ),
        ],
        const SizedBox(height: 16),
        Text('BACKGROUND', style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
        const SizedBox(height: 8),
        _BackgroundChoice(
          background: state.background,
          canRemove: state.canRemoveBackground && !busy,
          onSelect: onBackground,
        ),
        const SizedBox(height: 16),
        Text('NAME (OPTIONAL)', style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
        const SizedBox(height: 8),
        TextField(
          controller: nameController,
          onChanged: onName,
          enabled: !busy,
          maxLength: stickerNameMaxLength,
          textInputAction: TextInputAction.done,
          style: AppTextStyles.hint.copyWith(color: colors.ink),
          decoration: InputDecoration(
            hintText: 'Mochi with his stick',
            hintStyle: AppTextStyles.hint.copyWith(color: colors.ink3),
            helperText: 'Helps you find it in search.',
            helperStyle: AppTextStyles.metaMonoSm.copyWith(color: colors.ink3),
            counterText: '',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.xs),
              borderSide: BorderSide(color: colors.line, width: 1.5),
            ),
            focusedBorder: GlowInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.xs),
              borderSide: BorderSide(color: colors.yel, width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.xs),
              borderSide: BorderSide(color: colors.line, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton(
            label: 'Change picture',
            variant: AppButtonVariant.secondary,
            dense: true,
            icon: const Icon(CupertinoIcons.photo, size: 16),
            onPressed: busy ? null : onChangePicture,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Save',
                variant: AppButtonVariant.secondary,
                dense: true,
                fullWidth: true,
                onPressed: busy ? null : onSave,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: AppButton(
                label: busy ? 'Saving…' : 'Save and send',
                dense: true,
                fullWidth: true,
                onPressed: busy ? null : onSaveAndSend,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The draft, at the size it will be sent at.
///
/// A cut-out sits on a checkerboard so its transparency reads as transparency
/// rather than as "white bits"; a kept picture sits on the plain surface with
/// the white frame the app draws around it, which is exactly what the bubble
/// will show.
class _Preview extends StatelessWidget {
  const _Preview({required this.image, required this.transparent});

  final StickerImage? image;
  final bool transparent;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final url = image?.url ?? '';
    Widget picture = url.isEmpty
        ? Center(child: Icon(CupertinoIcons.smiley, size: 48, color: colors.ink3))
        : CachedNetworkImage(
            key: ValueKey(url),
            imageUrl: url,
            fit: transparent ? BoxFit.contain : BoxFit.cover,
            memCacheWidth: (168 * MediaQuery.devicePixelRatioOf(context)).round(),
            placeholder: (_, _) => const Center(
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            errorWidget: (_, _, _) => Center(child: Icon(CupertinoIcons.smiley, size: 48, color: colors.ink3)),
          );

    if (!transparent && url.isNotEmpty) {
      picture = Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadii.md)),
        foregroundDecoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 5),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        clipBehavior: Clip.antiAlias,
        child: picture,
      );
    }

    return Container(
      height: 216,
      decoration: BoxDecoration(color: colors.surf2, borderRadius: BorderRadius.circular(AppRadii.sm)),
      // In the foreground: the checkerboard fills edge to edge (docs/GOTCHAS.md).
      foregroundDecoration: BoxDecoration(
        border: Border.all(color: colors.line, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        painter: transparent ? _CheckerPainter(light: colors.surf2, dark: colors.line) : null,
        child: Center(child: SizedBox.square(dimension: 168, child: picture)),
      ),
    );
  }
}

/// The "transparent here" checkerboard. A `CustomPainter` rather than a
/// gradient stack, and static — nothing here blurs or animates, which is the
/// one thing this project's renderer has crashed on (`docs/GOTCHAS.md`).
class _CheckerPainter extends CustomPainter {
  const _CheckerPainter({required this.light, required this.dark});

  final Color light;
  final Color dark;

  /// Square side, in logical pixels — the design's 20px checker, tightened for
  /// a phone-sized well.
  static const double cell = 12;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = light);
    final paint = Paint()..color = dark;
    final columns = (size.width / cell).ceil();
    final rows = (size.height / cell).ceil();
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        if ((row + column).isEven) continue;
        canvas.drawRect(Rect.fromLTWH(column * cell, row * cell, cell, cell), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerPainter oldDelegate) => oldDelegate.light != light || oldDelegate.dark != dark;
}

/// Why the background is staying. An explanation, not an error — the sticker
/// saves fine either way — so it wears the surface treatment rather than the
/// red one.
class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surf2,
        border: Border(left: BorderSide(color: colors.yel, width: 3)),
        borderRadius: BorderRadius.circular(AppRadii.xs),
      ),
      child: Text(text, style: AppTextStyles.bodySm.copyWith(color: colors.ink2)),
    );
  }
}

/// Remove / Keep. Its own control rather than `SegmentedTabs`, which has no
/// disabled segment — and a disabled segment is this control's normal state
/// for as long as background removal is switched off server-side.
class _BackgroundChoice extends StatelessWidget {
  const _BackgroundChoice({required this.background, required this.canRemove, required this.onSelect});

  final StickerBackground background;
  final bool canRemove;
  final ValueChanged<StickerBackground> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: colors.surf,
        border: Border.all(color: colors.line, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        children: [
          _Segment(
            icon: CupertinoIcons.wand_stars,
            label: 'Remove',
            selected: background == StickerBackground.removed,
            enabled: canRemove,
            onTap: () => onSelect(StickerBackground.removed),
          ),
          _Segment(
            icon: CupertinoIcons.photo,
            label: 'Keep',
            selected: background == StickerBackground.kept,
            enabled: true,
            onTap: () => onSelect(StickerBackground.kept),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.icon,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final ink = !enabled ? colors.ink3 : (selected ? colors.onYel : colors.ink2);
    return Expanded(
      child: Material(
        color: selected ? colors.yel : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15, color: ink),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.navLabel.copyWith(color: ink),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
