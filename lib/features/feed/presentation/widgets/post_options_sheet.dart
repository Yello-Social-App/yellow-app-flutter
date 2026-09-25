import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/extensions/string_extension.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_status_snackbar.dart';
import '../../../../shared/widgets/app_warning_dialog.dart';
import '../../domain/entities/post_entity.dart';

/// The post "···" overflow menu — shared by the feed card and the post
/// detail screen so both present identical actions (copy share link, view
/// reactions, and, gated by [isOwnPost], edit/delete via
/// `PUT`/`DELETE /api/v1/posts/{id}`). Callers own the actual cubit calls
/// (`FeedCubit` or `PostDetailCubit`, whichever owns the post being shown);
/// this only renders the sheet and invokes whichever callback was tapped.
///
/// The three safety actions are the mirror of edit/delete: they only make
/// sense on *someone else's* post, so [isOwnPost] gates them the other way
/// round. They run from least to most drastic — hide this one post, report
/// it, then stop seeing the author entirely — and are separated from the
/// neutral actions above them, so neither group is tapped by muscle memory
/// meant for the other.
Future<void> showPostOptionsSheet(
  BuildContext context, {
  required bool isOwnPost,
  required VoidCallback onCopyLink,
  required VoidCallback onViewReactions,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
  required VoidCallback onHide,
  required VoidCallback onReport,
  required VoidCallback onMute,
  required String authorUsername,
}) {
  final colors = AppColors.of(context);
  return showModalBottomSheet<void>(
    context: context,
    // The Feed screen's own "···" opens this while the floating pill nav bar
    // is on screen — that bar is `MainShellPage`'s `bottomNavigationBar`,
    // painted after (so visually in front of) `body`, which is where each
    // branch's own nested `Navigator` (from `StatefulShellRoute`) lives. A
    // sheet pushed on that nested Navigator is still just paint content
    // inside `body`, so it rendered *behind* the bar. Pushing it on the
    // root Navigator instead escapes `body` entirely, mounting above the
    // whole `MainShellPage` — bar included. See `post_detail_page.dart`'s
    // own menu call for why this is safe there too (a plain pushed route,
    // no nav bar to begin with, so this is a no-op visually).
    useRootNavigator: true,
    backgroundColor: colors.surf,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl))),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 80,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(999)),
          ),
          _MenuTile(
            icon: CupertinoIcons.link,
            label: 'Copy share link',
            onTap: () {
              Navigator.of(sheetContext).pop();
              onCopyLink();
            },
          ),
          _MenuTile(
            icon: CupertinoIcons.smiley,
            label: 'View reactions',
            onTap: () {
              Navigator.of(sheetContext).pop();
              onViewReactions();
            },
          ),
          if (isOwnPost)
            _MenuTile(
              icon: CupertinoIcons.pencil,
              label: 'Edit post',
              onTap: () {
                Navigator.of(sheetContext).pop();
                onEdit();
              },
            ),
          if (isOwnPost)
            _MenuTile(
              icon: CupertinoIcons.delete,
              label: 'Delete post',
              destructive: true,
              onTap: () {
                Navigator.of(sheetContext).pop();
                onDelete();
              },
            ),
          if (!isOwnPost) ...[
            Divider(height: 1, thickness: 1, color: colors.line),
            _MenuTile(
              icon: CupertinoIcons.eye_slash,
              label: 'Hide this post',
              onTap: () {
                Navigator.of(sheetContext).pop();
                onHide();
              },
            ),
            _MenuTile(
              icon: CupertinoIcons.flag,
              label: 'Report post',
              onTap: () {
                Navigator.of(sheetContext).pop();
                onReport();
              },
            ),
            _MenuTile(
              icon: CupertinoIcons.speaker_slash,
              label: 'Mute ${authorUsername.withAtSign}',
              onTap: () {
                Navigator.of(sheetContext).pop();
                onMute();
              },
            ),
          ],
        ],
      ),
    ),
  );
}

/// "Stop seeing posts from @…?" — shared by the feed card and the post
/// detail screen so both explain a mute the same way. Worth confirming
/// where hiding one post is not: a mute is open-ended and silent, and the
/// only way back is a screen most people will never have visited.
Future<bool> confirmMuteAuthor(BuildContext context, String authorUsername) {
  return AppWarningDialog.show(
    context,
    title: 'Mute ${authorUsername.withAtSign}?',
    message: "Their posts stop showing in your feed. They are never told, "
        "and you can undo this in Settings → Privacy & safety.",
    confirmLabel: 'Mute',
    cancelLabel: 'Cancel',
    icon: CupertinoIcons.speaker_slash,
  );
}

/// "Delete this post?" confirmation — shared so the feed card and the post
/// detail screen ask the same way before calling their own `deletePost`.
Future<bool> confirmDeletePost(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete this post?'),
      content: const Text("This can't be undone."),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Delete')),
      ],
    ),
  );
  return confirmed == true;
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.label, required this.onTap, this.destructive = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final color = destructive ? colors.red : colors.ink;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: AppTextStyles.body.copyWith(color: color)),
      onTap: onTap,
    );
  }
}

/// The "EDIT POST" bottom sheet — [onSave] is whichever cubit owns [post]
/// (`FeedCubit.updatePost`/`PostDetailCubit.updatePost`, both `Future<bool>`
/// keyed off their own `postId`); this widget doesn't know or care which.
Future<void> showEditPostSheet(
  BuildContext context, {
  required PostEntity post,
  required Future<bool> Function({String? content, PostVisibility? visibility}) onSave,
}) {
  return showModalBottomSheet<void>(
    context: context,
    // See `showPostOptionsSheet`'s identical comment above — same reason.
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EditPostSheet(post: post, onSave: onSave),
  );
}

class _EditPostSheet extends StatefulWidget {
  const _EditPostSheet({required this.post, required this.onSave});
  final PostEntity post;
  final Future<bool> Function({String? content, PostVisibility? visibility}) onSave;

  @override
  State<_EditPostSheet> createState() => _EditPostSheetState();
}

class _EditPostSheetState extends State<_EditPostSheet> {
  late final _controller = TextEditingController(text: widget.post.content);
  late PostVisibility _visibility = widget.post.visibility;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await widget.onSave(content: _controller.text, visibility: _visibility);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = false);
    AppStatusSnackbar.showError(context, message: 'Could not save changes.');
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
          border: Border.all(color: colors.line, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('EDIT POST', style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: 5,
              minLines: 3,
              style: AppTextStyles.body.copyWith(color: colors.ink),
              decoration: InputDecoration(
                filled: true,
                fillColor: colors.surf,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  borderSide: BorderSide(color: colors.line, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final v in PostVisibility.values)
                  ChoiceChip(
                    label: Text(switch (v) {
                      PostVisibility.public => 'Public',
                      PostVisibility.friends => 'Circle',
                      PostVisibility.private => 'Close',
                    }),
                    selected: _visibility == v,
                    onSelected: (_) => setState(() => _visibility = v),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            AppButton(label: _saving ? 'Saving…' : 'Save changes', fullWidth: true, onPressed: _saving ? null : _save),
          ],
        ),
      ),
    );
  }
}
