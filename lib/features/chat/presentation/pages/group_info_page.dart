import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/extensions/string_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/app_status_snackbar.dart';
import '../../../../shared/widgets/app_warning_dialog.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../friends/domain/entities/friendship_entity.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/participant_entity.dart';
import '../../domain/usecases/chat_usecases.dart';
import '../bloc/group_info_cubit.dart';

/// A group's own screen — name, photo, members and their roles, add /
/// invite, leave. Reached from the chat header. What each role may do is
/// on `ParticipantRole`; the buttons here only hide what the server would
/// refuse anyway.
class GroupInfoPage extends StatelessWidget {
  const GroupInfoPage({super.key, required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<GroupInfoCubit>(param1: conversationId)..load(),
      child: const _GroupInfoView(),
    );
  }
}

class _GroupInfoView extends StatelessWidget {
  const _GroupInfoView();

  Future<void> _rename(BuildContext context, ConversationEntity conversation) async {
    final cubit = context.read<GroupInfoCubit>();
    final title = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: conversation.title ?? ''),
    );
    if (title == null || !context.mounted) return;
    unawaited(cubit.rename(title));
  }

  Future<void> _changePhoto(BuildContext context, ConversationEntity conversation) async {
    final cubit = context.read<GroupInfoCubit>();
    final choice = await showModalBottomSheet<_PhotoChoice>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PhotoSheet(hasPhoto: conversation.hasPhoto),
    );
    if (choice == null || !context.mounted) return;
    switch (choice) {
      case _PhotoChoice.remove:
        unawaited(cubit.removePhoto());
      case _PhotoChoice.gallery || _PhotoChoice.camera:
        final picked = await ImagePicker().pickImage(
          source: choice == _PhotoChoice.camera ? ImageSource.camera : ImageSource.gallery,
          imageQuality: 85,
          maxWidth: AppConstants.postImageMaxDimension,
          maxHeight: AppConstants.postImageMaxDimension,
        );
        if (picked == null || !context.mounted) return;
        unawaited(cubit.setPhoto(File(picked.path)));
    }
  }

  Future<void> _pickPeople(BuildContext context, {required bool invite}) async {
    final cubit = context.read<GroupInfoCubit>();
    unawaited(cubit.loadFriends());
    final picked = await showModalBottomSheet<List<String>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _FriendPickerSheet(
          title: invite ? 'SEND AN INVITE' : 'ADD PEOPLE',
          confirmLabel: invite ? 'Invite' : 'Add',
          single: invite,
        ),
      ),
    );
    if (picked == null || picked.isEmpty || !context.mounted) return;
    if (invite) {
      unawaited(cubit.invite(picked.first));
    } else {
      unawaited(cubit.addMembers(picked));
    }
  }

  Future<void> _leave(BuildContext context) async {
    final cubit = context.read<GroupInfoCubit>();
    final confirmed = await AppWarningDialog.show(
      context,
      title: 'Leave this group?',
      message: cubit.state.isOwner
          ? 'The longest-standing admin takes over as owner. You will need an invite to come back.'
          : 'You will need an invite to come back.',
      confirmLabel: 'Leave',
      icon: Icons.logout,
    );
    if (confirmed && context.mounted) unawaited(cubit.leave());
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cubit = context.read<GroupInfoCubit>();

    return BlocListener<GroupInfoCubit, GroupInfoState>(
      listenWhen: (previous, current) =>
          previous.actionError != current.actionError ||
          previous.notice != current.notice ||
          previous.hasLeft != current.hasLeft,
      listener: (context, state) {
        if (state.hasLeft) {
          // Back to the inbox, past the conversation too — it is 404 for the
          // viewer now. `go` drops both overlays in one step.
          context.goNamed(RouteNames.messages);
          return;
        }
        if (state.actionError != null) AppStatusSnackbar.showError(context, message: state.actionError!);
        if (state.notice != null) AppStatusSnackbar.showSuccess(context, message: state.notice!, title: 'Done');
      },
      child: Scaffold(
        backgroundColor: colors.bg,
        body: SafeArea(
          child: BlocBuilder<GroupInfoCubit, GroupInfoState>(
            buildWhen: (previous, current) =>
                previous.status != current.status ||
                previous.conversation != current.conversation ||
                previous.isSaving != current.isSaving ||
                previous.busyUserIds != current.busyUserIds ||
                previous.errorMessage != current.errorMessage,
            builder: (context, state) {
              final conversation = state.conversation;
              return ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
                children: [
                  Row(
                    children: [
                      AppIconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 12),
                      Text('Group', style: AppTextStyles.titleLg.copyWith(color: colors.ink)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (state.status == GroupInfoStatus.loading && conversation == null)
                    const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator()))
                  else if (state.status == GroupInfoStatus.error && conversation == null)
                    ErrorView(message: state.errorMessage ?? 'Could not load this group.', onRetry: cubit.load)
                  else if (conversation != null) ...[
                    _IdentityCard(
                      conversation: conversation,
                      canManage: state.canManage,
                      busy: state.isSaving,
                      onRename: () => _rename(context, conversation),
                      onChangePhoto: () => _changePhoto(context, conversation),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: 'Add people',
                            icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                            dense: true,
                            fullWidth: true,
                            onPressed: state.isSaving || conversation.participants.length >= groupMaxMembers
                                ? null
                                : () => _pickPeople(context, invite: false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppButton(
                            label: 'Send invite',
                            icon: const Icon(Icons.mail_outline, size: 18),
                            dense: true,
                            fullWidth: true,
                            variant: AppButtonVariant.outline,
                            onPressed: state.isSaving ? null : () => _pickPeople(context, invite: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '${conversation.participants.length} OF $groupMaxMembers MEMBERS',
                      style: AppTextStyles.eyebrow.copyWith(color: colors.ink2),
                    ),
                    const SizedBox(height: 12),
                    _MembersCard(
                      conversation: conversation,
                      myRole: state.myRole,
                      busyUserIds: state.busyUserIds,
                      disabled: state.isSaving,
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      label: 'Leave group',
                      icon: const Icon(Icons.logout, size: 18),
                      variant: AppButtonVariant.danger,
                      fullWidth: true,
                      onPressed: state.isSaving ? null : () => _leave(context),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.conversation,
    required this.canManage,
    required this.busy,
    required this.onRename,
    required this.onChangePhoto,
  });

  final ConversationEntity conversation;
  final bool canManage;
  final bool busy;
  final VoidCallback onRename;
  final VoidCallback onChangePhoto;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surf,
        border: Border.all(color: colors.line, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppShadows.card(context),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AppAvatar(
                initials: conversation.name.initials,
                seed: conversation.avatarSeed,
                imageUrl: conversation.avatarUrl,
                cacheKey: conversation.avatarCacheKey,
                size: 88,
                borderWidth: 1.5,
              ),
              if (canManage)
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: AppIconButton(
                    icon: const Icon(Icons.photo_camera_outlined, size: 16),
                    size: 32,
                    filled: true,
                    borderColor: colors.ink,
                    onPressed: busy ? null : onChangePhoto,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  conversation.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleLg.copyWith(color: colors.ink),
                ),
              ),
              if (canManage) ...[
                const SizedBox(width: 6),
                AppIconButton(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  size: 32,
                  onPressed: busy ? null : onRename,
                ),
              ],
            ],
          ),
          if (busy) ...[
            const SizedBox(height: 10),
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ],
      ),
    );
  }
}

class _MembersCard extends StatelessWidget {
  const _MembersCard({
    required this.conversation,
    required this.myRole,
    required this.busyUserIds,
    required this.disabled,
  });

  final ConversationEntity conversation;
  final ParticipantRole myRole;
  final Set<String> busyUserIds;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // Owner first, then admins, then members — each group by join order.
    final members = [...conversation.participants]
      ..sort((a, b) {
        final byRole = a.role.index.compareTo(b.role.index);
        return byRole != 0 ? byRole : a.joinedAt.compareTo(b.joinedAt);
      });
    return Container(
      decoration: BoxDecoration(
        color: colors.surf,
        border: Border.all(color: colors.line, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppShadows.card(context),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < members.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.only(left: 64),
                child: Divider(height: 1, thickness: 1, color: colors.line2),
              ),
            _MemberRow(
              member: members[i],
              isMe: members[i].userId == conversation.viewerId,
              myRole: myRole,
              busy: busyUserIds.contains(members[i].userId),
              disabled: disabled,
            ),
          ],
        ],
      ),
    );
  }
}

enum _MemberAction { promote, demote, remove }

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.isMe,
    required this.myRole,
    required this.busy,
    required this.disabled,
  });

  final ParticipantEntity member;
  final bool isMe;
  final ParticipantRole myRole;
  final bool busy;
  final bool disabled;

  /// The service's own table, so the menu never offers a 403.
  List<_MemberAction> get _actions {
    if (isMe || member.role == ParticipantRole.owner) return const [];
    return switch (myRole) {
      ParticipantRole.owner => [
          member.role == ParticipantRole.admin ? _MemberAction.demote : _MemberAction.promote,
          _MemberAction.remove,
        ],
      ParticipantRole.admin => member.role == ParticipantRole.member ? const [_MemberAction.remove] : const [],
      ParticipantRole.member => const [],
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cubit = context.read<GroupInfoCubit>();
    final actions = _actions;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      child: Row(
        children: [
          AppAvatar(
            initials: member.displayName.initials,
            seed: member.userId.hashCode.abs(),
            imageUrl: member.avatarUrl,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? '${member.displayName} (you)' : member.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMd.copyWith(color: colors.ink, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(member.role.label.toUpperCase(), style: AppTextStyles.metaMonoSm.copyWith(color: colors.ink2)),
              ],
            ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (actions.isNotEmpty)
            PopupMenuButton<_MemberAction>(
              enabled: !disabled,
              icon: Icon(Icons.more_vert, color: colors.ink2),
              onSelected: (action) => switch (action) {
                _MemberAction.promote => cubit.setRole(member.userId, ParticipantRole.admin),
                _MemberAction.demote => cubit.setRole(member.userId, ParticipantRole.member),
                _MemberAction.remove => cubit.removeMember(member.userId),
              },
              itemBuilder: (_) => [
                for (final action in actions)
                  PopupMenuItem(
                    value: action,
                    child: Text(switch (action) {
                      _MemberAction.promote => 'Make admin',
                      _MemberAction.demote => 'Remove as admin',
                      _MemberAction.remove => 'Remove from group',
                    }),
                  ),
              ],
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});
  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop(title);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Dialog(
      backgroundColor: colors.surf,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: BorderSide(color: colors.line, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('RENAME GROUP', style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLength: groupTitleMaxLength,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              style: AppTextStyles.body.copyWith(color: colors.ink),
              decoration: InputDecoration(
                hintText: 'Group name',
                hintStyle: AppTextStyles.hint.copyWith(color: colors.ink3),
                counterStyle: AppTextStyles.metaMonoSm.copyWith(color: colors.ink3),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.xs),
                  borderSide: BorderSide(color: colors.line, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.xs),
                  borderSide: BorderSide(color: colors.ink, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),
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
                const SizedBox(width: 8),
                Expanded(child: AppButton(label: 'Save', fullWidth: true, onPressed: _submit)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _PhotoChoice { gallery, camera, remove }

class _PhotoSheet extends StatelessWidget {
  const _PhotoSheet({required this.hasPhoto});
  final bool hasPhoto;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    Widget row(IconData icon, String label, _PhotoChoice choice, {bool destructive = false}) {
      final ink = destructive ? colors.red : colors.ink;
      return InkWell(
        onTap: () => Navigator.of(context).pop(choice),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Icon(icon, size: 20, color: ink),
              const SizedBox(width: 14),
              Text(label, style: AppTextStyles.bodyMd.copyWith(color: ink, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surf,
            border: Border.all(color: colors.line, width: 1.5),
            borderRadius: BorderRadius.circular(AppRadii.xl),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              row(Icons.photo_library_outlined, 'Choose from library', _PhotoChoice.gallery),
              row(Icons.photo_camera_outlined, 'Take a photo', _PhotoChoice.camera),
              if (hasPhoto) row(Icons.delete_outline, 'Remove photo', _PhotoChoice.remove, destructive: true),
            ],
          ),
        ),
      ),
    );
  }
}

/// Picks friends who are not yet in the group. Multi-select for adding;
/// single-select for an invite card, which goes to one DM at a time.
class _FriendPickerSheet extends StatefulWidget {
  const _FriendPickerSheet({required this.title, required this.confirmLabel, required this.single});

  final String title;
  final String confirmLabel;
  final bool single;

  @override
  State<_FriendPickerSheet> createState() => _FriendPickerSheetState();
}

class _FriendPickerSheetState extends State<_FriendPickerSheet> {
  final Set<String> _selected = {};

  void _toggle(String userId) {
    setState(() {
      if (!_selected.remove(userId)) {
        if (widget.single) _selected.clear();
        _selected.add(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.7;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: colors.surf,
            border: Border.all(color: colors.line, width: 1.5),
            borderRadius: BorderRadius.circular(AppRadii.xl),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: BlocBuilder<GroupInfoCubit, GroupInfoState>(
            buildWhen: (previous, current) =>
                previous.friends != current.friends ||
                previous.isLoadingFriends != current.isLoadingFriends ||
                previous.conversation != current.conversation,
            builder: (context, state) {
              final candidates = state.friendsNotInGroup;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: AppTextStyles.eyebrow.copyWith(color: colors.ink2)),
                  const SizedBox(height: 12),
                  if (state.isLoadingFriends)
                    const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
                  else if (candidates.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        state.friends.isEmpty
                            ? 'Add some friends first — only friends can be picked here.'
                            : 'All of your friends are already in this group.',
                        style: AppTextStyles.bodySm.copyWith(color: colors.ink2),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: candidates.length,
                        itemBuilder: (context, index) => _FriendPickRow(
                          friend: candidates[index],
                          selected: _selected.contains(candidates[index].userId),
                          onTap: () => _toggle(candidates[index].userId),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: _selected.isEmpty || widget.single
                        ? widget.confirmLabel
                        : '${widget.confirmLabel} (${_selected.length})',
                    fullWidth: true,
                    onPressed: _selected.isEmpty ? null : () => Navigator.of(context).pop(_selected.toList()),
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

class _FriendPickRow extends StatelessWidget {
  const _FriendPickRow({required this.friend, required this.selected, required this.onTap});

  final FriendshipEntity friend;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final name = friend.fullName?.trim().isNotEmpty == true ? friend.fullName!.trim() : friend.username;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.xs),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            AppAvatar(initials: name.initials, seed: friend.userId.hashCode.abs(), imageUrl: friend.avatarUrl, size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMd.copyWith(color: colors.ink, fontWeight: FontWeight.w600),
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? colors.ink : colors.ink3,
            ),
          ],
        ),
      ),
    );
  }
}
