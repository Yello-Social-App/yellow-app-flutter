import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../../shared/widgets/date_label.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/shimmer_loading.dart';
import '../../../../shared/widgets/yello_wordmark.dart';
import '../../domain/entities/conversation_entity.dart';
import '../bloc/messages_cubit.dart';

/// Colors for everything painted **on the header slab** — never
/// `AppColors.of(context)`.
///
/// The slab is dark in *both* themes, the same call `BottomNavBar` makes with
/// `AppColors.shell`. Its contents therefore can't read the active token set:
/// in dark mode `ink` is near-white, which would paint a white slab carrying
/// white text. They take the dark set unconditionally instead, which is what
/// "on a dark surface" means in this palette.
const AppColors _onSlab = AppColors.dark;

/// How far the conversation sheet rides up over the bottom of the slab, so
/// its rounded top corners read as a sheet laid *on* the slab rather than a
/// second block stacked below it.
const double _sheetOverlap = 24;

/// People in the header rail. It is a browse-by-person shortcut, not a
/// directory — a cap keeps it short enough to scan at a glance.
const int _railLimit = 12;

const EdgeInsets _bodyPadding = EdgeInsets.fromLTRB(14, 12, 14, 28);

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(value: sl<MessagesCubit>()..load(), child: const _MessagesView());
  }
}

class _MessagesView extends StatefulWidget {
  const _MessagesView();

  @override
  State<_MessagesView> createState() => _MessagesViewState();
}

class _MessagesViewState extends State<_MessagesView> {
  final _searchController = TextEditingController();

  /// The query lives in a notifier rather than in `State` so a keystroke
  /// rebuilds only the result slivers. Under `setState` every character
  /// retyped the slab, its rail, and every avatar in it.
  final _query = ValueNotifier<String>('');

  @override
  void dispose() {
    _searchController.dispose();
    _query.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) => _query.value = value.trim().toLowerCase();

  void _clearQuery() {
    _searchController.clear();
    _query.value = '';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cubit = context.read<MessagesCubit>();
    final topInset = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The status-bar strip is slab-coloured in both themes and stays that
      // way while the list scrolls (see the `Stack` below), so light icons
      // are always the correct pairing here.
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: colors.bg,
      ),
      child: Scaffold(
        backgroundColor: colors.bg,
        body: BlocBuilder<MessagesCubit, MessagesState>(
          builder: (context, state) {
            // Built once per state change and reused inside the query
            // builder: an identical widget instance short-circuits
            // `Element.updateChild`, so typing never rebuilds the slab.
            final header = SliverToBoxAdapter(
              child: _HeaderSlab(
                topInset: topInset,
                unreadTotal: state.unreadTotal,
                people: _railPeople(state.conversations),
                controller: _searchController,
                onQueryChanged: _onQueryChanged,
                onClearQuery: _clearQuery,
              ),
            );

            return Stack(
              // Explicit rather than relying on the loose default: this repo
              // has already shipped one bug from a loose Scaffold-slot
              // constraint (`docs/GOTCHAS.md`).
              fit: StackFit.expand,
              children: [
                RefreshIndicator(
                  onRefresh: cubit.refresh,
                  color: colors.ink,
                  backgroundColor: colors.surf,
                  // `SafeArea` can't push the spinner clear of the status bar
                  // from inside a scroll view; the offset has to be given here.
                  edgeOffset: topInset + 8,
                  child: ValueListenableBuilder<String>(
                    valueListenable: _query,
                    builder: (context, query, _) {
                      return CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [header, ..._bodySlivers(state, query, cubit)],
                      );
                    },
                  ),
                ),
                // Keeps the strip behind the status bar slab-coloured once the
                // header itself has scrolled away, so the light icons above
                // never end up on a light background.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: topInset,
                  child: IgnorePointer(child: ColoredBox(color: colors.shell)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// The rail is "browse by person": the most recent conversations, in the
  /// same newest-first order as the list below.
  ///
  /// It deliberately does **not** read `state.onlineNow`. Presence arrives on
  /// a `presence` WebSocket frame that isn't wired yet, so
  /// `ConversationEntity.isOnline` is false for everyone — an active-now rail
  /// renders empty on every device today. `isOnline` still drives the green
  /// dot, so the rail gains presence for free when that socket lands.
  List<ConversationEntity> _railPeople(List<ConversationEntity> conversations) {
    if (conversations.length <= _railLimit) return conversations;
    return conversations.sublist(0, _railLimit);
  }

  List<ConversationEntity> _filter(List<ConversationEntity> all, String query) {
    if (query.isEmpty) return all;
    return all
        .where((c) => c.name.toLowerCase().contains(query) || c.lastMessagePreview.toLowerCase().contains(query))
        .toList(growable: false);
  }

  List<Widget> _bodySlivers(MessagesState state, String query, MessagesCubit cubit) {
    if (state.status == MessagesStatus.loading && state.conversations.isEmpty) {
      return const [
        SliverPadding(
          padding: _bodyPadding,
          sliver: SliverToBoxAdapter(child: ShimmerListCard()),
        ),
      ];
    }

    if (state.status == MessagesStatus.error && state.conversations.isEmpty) {
      return [
        SliverPadding(
          padding: _bodyPadding,
          sliver: SliverToBoxAdapter(
            child: ErrorView(message: state.errorMessage ?? 'Could not load your inbox.', onRetry: cubit.refresh),
          ),
        ),
      ];
    }

    final conversations = _filter(state.conversations, query);
    if (conversations.isEmpty) {
      return [
        SliverPadding(
          padding: _bodyPadding,
          sliver: SliverToBoxAdapter(
            child: query.isEmpty
                ? const EmptyStateCard(
                    title: 'NO CONVERSATIONS YET',
                    hint: 'Start one from a friend’s profile and it will show up here.',
                  )
                : const EmptyStateCard(title: 'NO MATCHES', hint: 'No chat in your inbox matches that search.'),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: _bodyPadding,
        sliver: SliverList.separated(
          itemCount: conversations.length,
          separatorBuilder: (_, _) => const _RowDivider(),
          itemBuilder: (context, index) => _ConversationRow(conversation: conversations[index]),
        ),
      ),
    ];
  }
}

/// The dark brand slab: title, compose action, search, and the people rail —
/// with the conversation sheet's rounded lip laid over its bottom edge.
class _HeaderSlab extends StatelessWidget {
  const _HeaderSlab({
    required this.topInset,
    required this.unreadTotal,
    required this.people,
    required this.controller,
    required this.onQueryChanged,
    required this.onClearQuery,
  });

  final double topInset;
  final int unreadTotal;
  final List<ConversationEntity> people;
  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Stack(
      children: [
        // First child so it paints behind; `Positioned.fill` takes its size
        // from the padded column below, which is the sizing child.
        Positioned.fill(
          child: ClipRect(
            child: CustomPaint(
              painter: _SlabPainter(base: colors.shell, glow: colors.yel),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(18, topInset + 12, 18, _sheetOverlap + 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Same date eyebrow Feed and Explore wear above
                        // their titles, carrying the unread count as its
                        // trailing fact rather than stacking a second mono
                        // row between the date and the wordmark. `_onSlab`
                        // because this is painted on the slab.
                        DateLabel(
                          color: _onSlab.ink2,
                          trailing: unreadTotal == 0 ? 'All caught up' : '$unreadTotal unread',
                        ),
                        const SizedBox(height: 8),
                        const YelloWordmark(fontSize: AppTextStyles.displayXlFontSize, text: 'Inbox'),
                      ],
                    ),
                  ),
                  AppIconButton(
                    icon: const Icon(Icons.edit_outlined),
                    backgroundColor: _onSlab.surf2,
                    borderColor: _onSlab.line,
                    iconColor: _onSlab.ink,
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SlabSearchField(controller: controller, onChanged: onQueryChanged, onClear: onClearQuery),
              if (people.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('BROWSE YOUR CHATS', style: AppTextStyles.eyebrow.copyWith(color: _onSlab.ink2)),
                const SizedBox(height: 14),
                _PeopleRail(people: people),
              ],
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            height: _sheetOverlap,
            decoration: BoxDecoration(
              color: colors.bg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.huge)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Flat fill plus three translucent brand discs — the slab's only decoration.
///
/// Painted rather than stacked as `Container`s, and deliberately **unblurred**:
/// a blurred `BoxShadow` on a rebuilding widget crashes this project's
/// renderer (`docs/GOTCHAS.md`). Same approach as `_ActiveTabIndicatorPainter`
/// in `bottom_nav_bar.dart`.
class _SlabPainter extends CustomPainter {
  const _SlabPainter({required this.base, required this.glow});

  final Color base;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = base;
    canvas.drawRect(Offset.zero & size, paint);

    paint.color = glow.withValues(alpha: 0.10);
    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.10), size.width * 0.26, paint);

    paint.color = glow.withValues(alpha: 0.06);
    canvas.drawCircle(Offset(size.width * 0.08, size.height * 0.52), size.width * 0.32, paint);

    paint.color = glow.withValues(alpha: 0.05);
    canvas.drawCircle(Offset(size.width * 0.58, -size.height * 0.04), size.width * 0.18, paint);
  }

  @override
  bool shouldRepaint(_SlabPainter oldDelegate) => oldDelegate.base != base || oldDelegate.glow != glow;
}

class _SlabSearchField extends StatelessWidget {
  const _SlabSearchField({required this.controller, required this.onChanged, required this.onClear});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Light mode gets the reference's bright pill punched into the dark slab.
    // In dark mode that pill would be the brightest thing on the screen, so
    // the field inverts to the slab's own inset surface instead.
    final fill = isDark ? _onSlab.surf2 : AppColors.light.surf;
    final ink = isDark ? _onSlab.ink : AppColors.light.ink;
    final hintInk = isDark ? _onSlab.ink3 : AppColors.light.ink3;

    final radius = BorderRadius.circular(AppRadii.pill);

    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => FocusScope.of(context).unfocus(),
      style: AppTextStyles.body.copyWith(color: ink),
      cursorColor: ink,
      decoration: InputDecoration(
        hintText: 'Search your messages',
        hintStyle: AppTextStyles.hint.copyWith(color: hintInk),
        prefixIcon: Icon(Icons.search, color: hintInk, size: 20),
        prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            if (value.text.isEmpty) return const SizedBox.shrink();
            return IconButton(
              tooltip: 'Clear search',
              icon: Icon(Icons.close, color: hintInk, size: 18),
              // Bounded so the field's height doesn't jump when the button
              // appears; still a 40px target.
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              padding: EdgeInsets.zero,
              onPressed: onClear,
            );
          },
        ),
        // Without this the decoration's default 48px minimum keeps reserving
        // the clear button's slot even while it is an empty `SizedBox`,
        // permanently narrowing the field by a button's width.
        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: fill,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 15),
        enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: _onSlab.yel, width: 1.5),
        ),
      ),
    );
  }
}

class _PeopleRail extends StatelessWidget {
  const _PeopleRail({required this.people});

  final List<ConversationEntity> people;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: people.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) => _RailAvatar(conversation: people[index]),
      ),
    );
  }
}

class _RailAvatar extends StatelessWidget {
  const _RailAvatar({required this.conversation});

  final ConversationEntity conversation;

  @override
  Widget build(BuildContext context) {
    final unread = conversation.unreadCount > 0;

    return Semantics(
      button: true,
      label: 'Open chat with ${conversation.name}',
      child: GestureDetector(
        onTap: () => context.pushNamed(RouteNames.chat, pathParameters: {'conversationId': conversation.id}),
        child: Center(
          child: AppAvatar(
            initials: conversation.name.initials,
            seed: conversation.avatarSeed,
            imageUrl: conversation.avatarUrl,
            cacheKey: conversation.avatarCacheKey,
            size: 46,
            showOnlineDot: conversation.isOnline,
            // Every avatar carries a ring so unread and read stay the same
            // size in the rail — only its colour changes.
            ringColor: unread ? _onSlab.yel : _onSlab.line,
          ),
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Indented past the avatar so the rule starts at the text column.
      padding: const EdgeInsets.only(left: 68),
      child: Divider(height: 1, thickness: 1, color: AppColors.of(context).line2),
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
    final preview = conversation.lastMessagePreview;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        onTap: () => context.pushNamed(RouteNames.chat, pathParameters: {'conversationId': conversation.id}),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              AppAvatar(
                initials: conversation.name.initials,
                seed: conversation.avatarSeed,
                imageUrl: conversation.avatarUrl,
                cacheKey: conversation.avatarCacheKey,
                size: 48,
                showOnlineDot: conversation.isOnline,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleMd.copyWith(color: colors.ink),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      preview.isEmpty ? 'No messages yet' : preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySm.copyWith(
                        color: unread ? colors.ink : colors.ink3,
                        fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.relativeShort(conversation.lastMessageAt),
                    style: AppTextStyles.metaMono.copyWith(color: unread ? colors.ink : colors.ink3),
                  ),
                  const SizedBox(height: 7),
                  // Reserves the badge's height either way, so a read row and
                  // an unread row are exactly the same height.
                  if (unread) _UnreadBadge(count: conversation.unreadCount) else const SizedBox(height: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.yel,
        // A pill, not `BoxShape.circle`: with `minWidth` and a two-digit count
        // a circle stretches into an ellipse.
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: colors.ink, width: 1.5),
      ),
      child: Text(
        Formatters.compactCount(count),
        style: AppTextStyles.titleSm.copyWith(fontSize: 10, color: colors.onYel),
      ),
    );
  }
}
