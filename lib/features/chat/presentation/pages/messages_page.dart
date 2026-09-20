import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/extensions/string_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/shimmer_loading.dart';
import '../../../../shared/widgets/yello_wordmark.dart';
import '../../domain/entities/conversation_entity.dart';
import '../bloc/messages_cubit.dart';

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: sl<MessagesCubit>()..load(),
      child: const _MessagesView(),
    );
  }
}

class _MessagesView extends StatefulWidget {
  const _MessagesView();

  @override
  State<_MessagesView> createState() => _MessagesViewState();
}

class _MessagesViewState extends State<_MessagesView> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cubit = context.read<MessagesCubit>();

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<MessagesCubit, MessagesState>(
          builder: (context, state) {
            final conversations = state.conversations
                .where(
                  (conversation) =>
                      _query.isEmpty ||
                      conversation.name.toLowerCase().contains(_query) ||
                      conversation.lastMessagePreview.toLowerCase().contains(
                        _query,
                      ),
                )
                .toList();
            return RefreshIndicator(
              onRefresh: cubit.refresh,
              color: colors.ink,
              backgroundColor: colors.surf,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${state.unreadTotal} unread',
                                style: AppTextStyles.metaMono.copyWith(
                                  color: colors.ink2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const YelloWordmark(
                                fontSize: AppTextStyles.displayXlFontSize,
                                text: 'Inbox',
                              ),
                            ],
                          ),
                        ),
                        AppIconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) =>
                          setState(() => _query = value.trim().toLowerCase()),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => FocusScope.of(context).unfocus(),
                      style: AppTextStyles.body.copyWith(color: colors.ink),
                      decoration: InputDecoration(
                        hintText: 'Search chats',
                        hintStyle: AppTextStyles.body.copyWith(
                          color: colors.ink3,
                        ),
                        prefixIcon: Icon(Icons.search, color: colors.ink2),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                icon: Icon(Icons.close, color: colors.ink2),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                              ),
                        filled: true,
                        fillColor: colors.surf,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          borderSide: BorderSide(
                            color: colors.line,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          borderSide: BorderSide(color: colors.ink, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  if (state.status == MessagesStatus.loading &&
                      state.conversations.isEmpty)
                    const ShimmerListCard()
                  else if (state.status == MessagesStatus.error &&
                      state.conversations.isEmpty)
                    ErrorView(
                      message:
                          state.errorMessage ?? 'Could not load your inbox.',
                      onRetry: cubit.refresh,
                    )
                  else ...[
                    if (_query.isEmpty && state.onlineNow.isNotEmpty) ...[
                      _ActiveNowRail(conversations: state.onlineNow),
                      const SizedBox(height: 16),
                    ],
                    if (_query.isNotEmpty && conversations.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No matching chats',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodySm.copyWith(
                            color: colors.ink2,
                          ),
                        ),
                      ),
                    for (final c in conversations)
                      _ConversationRow(conversation: c),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ActiveNowRail extends StatelessWidget {
  const _ActiveNowRail({required this.conversations});
  final List<ConversationEntity> conversations;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(
        color: colors.surf,
        border: Border.all(color: colors.line, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'ACTIVE NOW',
              style: AppTextStyles.eyebrow.copyWith(color: colors.ink2),
            ),
          ),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: conversations.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final c = conversations[index];
                return GestureDetector(
                  onTap: () => context.pushNamed(
                    RouteNames.chat,
                    pathParameters: {'conversationId': c.id},
                  ),
                  child: SizedBox(
                    width: 56,
                    child: Column(
                      children: [
                        AppAvatar(
                          initials: c.name.initials,
                          seed: c.avatarSeed,
                          size: 52,
                          showOnlineDot: true,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          c.firstName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.metaMono.copyWith(
                            color: colors.ink2,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.conversation});
  final ConversationEntity conversation;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final unread = conversation.unreadCount > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: unread ? colors.surf : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          onTap: () => context.pushNamed(
            RouteNames.chat,
            pathParameters: {'conversationId': conversation.id},
          ),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: unread ? colors.ink : colors.line,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            child: Row(
              children: [
                AppAvatar(
                  initials: conversation.name.initials,
                  seed: conversation.avatarSeed,
                  size: 48,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation.name,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.titleMd.copyWith(
                                color: colors.ink,
                              ),
                            ),
                          ),
                          Text(
                            Formatters.relativeShort(
                              conversation.lastMessageAt,
                            ),
                            style: AppTextStyles.metaMono.copyWith(
                              color: colors.ink2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation.lastMessagePreview,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodySm.copyWith(
                                color: unread ? colors.ink : colors.ink3,
                              ),
                            ),
                          ),
                          if (unread) ...[
                            const SizedBox(width: 8),
                            Container(
                              constraints: const BoxConstraints(minWidth: 20),
                              height: 20,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: colors.yel,
                                shape: BoxShape.circle,
                                border: Border.all(color: colors.ink),
                              ),
                              child: Text(
                                '${conversation.unreadCount}',
                                style: AppTextStyles.titleSm.copyWith(
                                  fontSize: 10,
                                  color: colors.onYel,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
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
