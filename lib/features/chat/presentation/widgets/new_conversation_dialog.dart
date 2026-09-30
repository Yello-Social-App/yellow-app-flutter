import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/extensions/string_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/glow_border.dart';
import '../../../friends/domain/entities/friendship_entity.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/usecases/chat_usecases.dart';
import '../bloc/new_conversation_cubit.dart';
import '../../../../shared/widgets/shimmer_loading.dart';

/// The Inbox's "New message" dialog. Pick one friend to open the DM, or two
/// or more and name them to create a group. Resolves to the conversation to
/// open, or null when dismissed.
Future<ConversationEntity?> showNewConversationDialog(BuildContext context) {
  return showDialog<ConversationEntity>(
    context: context,
    builder: (_) => BlocProvider(
      create: (_) => sl<NewConversationCubit>()..loadFriends(),
      child: const _NewConversationDialog(),
    ),
  );
}

class _NewConversationDialog extends StatefulWidget {
  const _NewConversationDialog();

  @override
  State<_NewConversationDialog> createState() => _NewConversationDialogState();
}

class _NewConversationDialogState extends State<_NewConversationDialog> {
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();

  /// Insertion-ordered, so the group's member list follows the picking order.
  final Set<String> _selected = {};
  String _query = '';

  bool get _isGroup => _selected.length >= 2;

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _toggle(String userId) {
    setState(() {
      if (!_selected.remove(userId)) _selected.add(userId);
    });
  }

  List<FriendshipEntity> _filter(List<FriendshipEntity> friends) {
    if (_query.isEmpty) return friends;
    return friends
        .where((f) => f.displayName.toLowerCase().contains(_query) || f.username.toLowerCase().contains(_query))
        .toList(growable: false);
  }

  Future<void> _submit() async {
    final navigator = Navigator.of(context);
    final conversation = await context.read<NewConversationCubit>().start(
          memberIds: _selected.toList(),
          title: _nameController.text,
        );
    if (conversation != null && mounted) navigator.pop(conversation);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Dialog(
      backgroundColor: colors.surf,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.xxl),
        side: BorderSide(color: colors.line, width: 1.5),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
          child: BlocBuilder<NewConversationCubit, NewConversationState>(
            builder: (context, state) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('New message', style: AppTextStyles.titleLg.copyWith(color: colors.ink)),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(CupertinoIcons.xmark, size: 18, color: colors.ink2),
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Two or more people make a group — give it a name.',
                    style: AppTextStyles.bodySm.copyWith(color: colors.ink2),
                  ),
                  const SizedBox(height: 16),
                  _DialogField(
                    controller: _searchController,
                    icon: CupertinoIcons.search,
                    hint: 'Search friends',
                    textInputAction: TextInputAction.search,
                    onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
                  ),
                  // Only asked for once the pick is actually a group, so a
                  // one-person pick never looks like it needs a name.
                  AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: _isGroup
                        ? Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: _DialogField(
                              controller: _nameController,
                              icon: CupertinoIcons.person_2,
                              hint: 'Group name',
                              maxLength: groupTitleMaxLength,
                              textInputAction: TextInputAction.done,
                              onChanged: (_) => setState(() {}),
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  const SizedBox(height: 12),
                  Flexible(child: _buildList(state, colors)),
                  if (state.errorMessage != null && state.status == NewConversationStatus.loaded) ...[
                    const SizedBox(height: 12),
                    Text(state.errorMessage!, style: AppTextStyles.bodySm.copyWith(color: colors.red)),
                  ],
                  const SizedBox(height: 18),
                  _buildActions(state, colors),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildList(NewConversationState state, AppColors colors) {
    Widget message(String text, {VoidCallback? onRetry}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text, textAlign: TextAlign.center, style: AppTextStyles.bodySm.copyWith(color: colors.ink2)),
              if (onRetry != null) ...[
                const SizedBox(height: 10),
                AppButton(label: 'Retry', variant: AppButtonVariant.secondary, dense: true, onPressed: onRetry),
              ],
            ],
          ),
        );

    switch (state.status) {
      case NewConversationStatus.loading:
        // The loaded list's own well and row geometry, so friends land in place.
        return DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surf2,
            border: Border.all(color: colors.line2),
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, width) in const [104.0, 132.0, 88.0].indexed) ...[
                if (i > 0) Divider(height: 1, thickness: 1, color: colors.line2),
                ShimmerListTile(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  leading: const ShimmerBox(width: 20, height: 20, borderRadius: 5),
                  avatarSize: 34,
                  titleWidth: width,
                  titleHeight: 13,
                  subtitleWidth: width * 0.7,
                  subtitleHeight: 10,
                  lineGap: 6,
                ),
              ],
            ],
          ),
        );
      case NewConversationStatus.error:
        return message(
          state.errorMessage ?? 'Could not load your friends.',
          onRetry: context.read<NewConversationCubit>().loadFriends,
        );
      case NewConversationStatus.loaded:
        if (state.friends.isEmpty) {
          return message('Add some friends first — only friends can be picked here.');
        }
        final friends = _filter(state.friends);
        if (friends.isEmpty) return message('No friends match that search.');
        return DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surf2,
            border: Border.all(color: colors.line2),
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: friends.length,
              separatorBuilder: (_, _) => Divider(height: 1, thickness: 1, color: colors.line2),
              itemBuilder: (context, index) {
                final friend = friends[index];
                return _FriendRow(
                  friend: friend,
                  selected: _selected.contains(friend.userId),
                  onTap: state.isCreating ? null : () => _toggle(friend.userId),
                );
              },
            ),
          ),
        );
    }
  }

  Widget _buildActions(NewConversationState state, AppColors colors) {
    final String label;
    if (state.isCreating) {
      label = _isGroup ? 'Creating…' : 'Opening…';
    } else if (_isGroup) {
      label = 'Create group';
    } else {
      label = 'Message';
    }
    final ready = _selected.isNotEmpty && (!_isGroup || _nameController.text.trim().isNotEmpty);

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        AppButton(
          label: 'Cancel',
          variant: AppButtonVariant.secondary,
          dense: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 8),
        AppButton(
          label: label,
          dense: true,
          onPressed: ready && !state.isCreating ? _submit : null,
        ),
      ],
    );
  }
}

/// The dialog's inset text field: search and group name share it.
class _DialogField extends StatelessWidget {
  const _DialogField({
    required this.controller,
    required this.icon,
    required this.hint,
    required this.onChanged,
    this.textInputAction,
    this.maxLength,
  });

  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final ValueChanged<String> onChanged;
  final TextInputAction? textInputAction;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      borderSide: BorderSide(color: colors.line2),
    );

    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: textInputAction,
      maxLength: maxLength,
      style: AppTextStyles.body.copyWith(color: colors.ink),
      cursorColor: colors.ink,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.hint.copyWith(color: colors.ink3),
        prefixIcon: Icon(icon, size: 18, color: colors.ink3),
        prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        // The title's length limit is enforced, not advertised — a counter
        // under a one-line field is noise at this size.
        counterText: '',
        filled: true,
        fillColor: colors.surf2,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        enabledBorder: border,
        focusedBorder: GlowInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          borderSide: BorderSide(color: colors.yel, width: 1.5),
        ),
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({required this.friend, required this.selected, required this.onTap});

  final FriendshipEntity friend;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final name = friend.displayName;

    return Semantics(
      checked: selected,
      label: name,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              _CheckBox(checked: selected),
              const SizedBox(width: 14),
              AppAvatar(
                initials: name.initials,
                seed: friend.userId.hashCode.abs(),
                imageUrl: friend.avatarUrl,
                size: 34,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMd.copyWith(color: colors.ink, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${friend.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySm.copyWith(color: colors.ink3, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A square yellow check, as in the design — Material's `Checkbox` would
/// bring its own 48px tap target and theme colours into the row.
class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: checked ? colors.yel : Colors.transparent,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: checked ? colors.yel : colors.ink3, width: 1.5),
      ),
      child: checked ? Icon(Icons.check_rounded, size: 15, color: colors.onYel) : null,
    );
  }
}
