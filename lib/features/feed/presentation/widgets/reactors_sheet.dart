import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/extensions/string_extension.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../domain/entities/post_entity.dart';
import '../bloc/reactors_cubit.dart';

/// Opens the paginated "who reacted" list — reached by tapping a row in
/// `showReactionBreakdownSheet`. [type] null means "everyone regardless of
/// reaction type"; non-null filters to just that type, matching the row the
/// viewer tapped. Unlike the fixed-height sheets elsewhere in this app
/// (`reaction_breakdown_sheet.dart`, `reaction_picker_sheet.dart`), this one
/// is a `DraggableScrollableSheet` since the list itself is genuinely
/// paginated/unbounded rather than a fixed handful of rows.
Future<void> showReactorsSheet(
  BuildContext context, {
  required String targetType,
  required String targetId,
  ReactionType? type,
}) {
  final colors = AppColors.of(context);
  return showModalBottomSheet<void>(
    context: context,
    // Same reasoning as the other reaction sheets — see
    // `post_options_sheet.dart`'s `showPostOptionsSheet` doc.
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: colors.surf,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl))),
    builder: (sheetContext) => BlocProvider(
      create: (_) => sl<ReactorsCubit>(param1: (targetType: targetType, targetId: targetId), param2: type)..load(),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _ReactorsSheetBody(scrollController: scrollController, type: type),
      ),
    ),
  );
}

class _ReactorsSheetBody extends StatefulWidget {
  const _ReactorsSheetBody({required this.scrollController, required this.type});

  final ScrollController scrollController;
  final ReactionType? type;

  @override
  State<_ReactorsSheetBody> createState() => _ReactorsSheetBodyState();
}

class _ReactorsSheetBodyState extends State<_ReactorsSheetBody> {
  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  // Same near-bottom-of-scroll trigger as `FeedPage`'s `loadMore`.
  void _onScroll() {
    final position = widget.scrollController.position;
    if (position.pixels > position.maxScrollExtent - 300) {
      context.read<ReactorsCubit>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.type == null ? 'REACTIONS' : '${widget.type!.emoji} ${widget.type!.name.toUpperCase()}',
            style: AppTextStyles.eyebrow.copyWith(color: colors.ink2),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: BlocBuilder<ReactorsCubit, ReactorsState>(
              builder: (context, state) {
                if (state.status == ReactorsStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.status == ReactorsStatus.error && state.reactors.isEmpty) {
                  return Center(
                    child: Text("Couldn't load reactions.", style: AppTextStyles.body.copyWith(color: colors.ink2)),
                  );
                }
                if (state.reactors.isEmpty) {
                  return Center(
                    child: Text('No reactions yet.', style: AppTextStyles.body.copyWith(color: colors.ink2)),
                  );
                }
                return ListView.builder(
                  controller: widget.scrollController,
                  itemCount: state.reactors.length + (state.hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= state.reactors.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final reactor = state.reactors[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: AppAvatar(
                        initials: reactor.username.initials,
                        seed: avatarSeedForId(reactor.userId),
                        imageUrl: reactor.avatarUrl,
                        size: 40,
                      ),
                      title: Text(reactor.username, style: AppTextStyles.body.copyWith(color: colors.ink)),
                      trailing: reactor.reactionType == null
                          ? null
                          : Text(reactor.reactionType!.emoji, style: const TextStyle(fontSize: 20)),
                      onTap: () {
                        Navigator.of(context).pop();
                        context.pushNamed(RouteNames.userProfile, pathParameters: {'userId': reactor.userId});
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
