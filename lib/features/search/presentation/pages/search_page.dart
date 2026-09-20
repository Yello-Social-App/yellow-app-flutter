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
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_icon_button.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/shimmer_loading.dart';
import '../../../feed/domain/entities/reactor_entity.dart' show FriendRelationStatus;
import '../../domain/entities/user_search_result_entity.dart';
import '../bloc/search_cubit.dart';

/// People search, backed by the real `GET /users/search` endpoint.
///
/// This used to filter the already-loaded feed and conversation list
/// client-side, because the backend had no search route of any kind. It does
/// now — users only (there is still no post, community or project search), so
/// this screen searches people and says so, rather than implying it covers
/// everything.
class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(create: (_) => sl<SearchCubit>(), child: const _SearchView());
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView();

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Pages in the next results while the list nears its end — the same
  /// `ScrollUpdateNotification`-free approach the feed uses, kept here on the
  /// controller since this list is a plain `ListView` rather than slivers.
  bool _onScroll(ScrollNotification notification) {
    if (notification is! ScrollUpdateNotification) return false;
    final metrics = notification.metrics;
    if (metrics.axis != Axis.vertical) return false;
    if (metrics.pixels >= metrics.maxScrollExtent - 400) {
      context.read<SearchCubit>().loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cubit = context.read<SearchCubit>();

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: Row(
                children: [
                  AppIconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: colors.surf,
                        border: Border.all(color: colors.line, width: 1.5),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              autofocus: true,
                              textInputAction: TextInputAction.search,
                              onChanged: cubit.onQueryChanged,
                              style: AppTextStyles.hint.copyWith(color: colors.ink),
                              decoration: InputDecoration(
                                hintText: 'Search people',
                                hintStyle: AppTextStyles.hint.copyWith(color: colors.ink3),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          BlocSelector<SearchCubit, SearchState, bool>(
                            selector: (state) => state.query.isNotEmpty,
                            builder: (context, hasQuery) {
                              if (!hasQuery) return const SizedBox.shrink();
                              return GestureDetector(
                                onTap: () {
                                  _controller.clear();
                                  cubit.onQueryChanged('');
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Icon(Icons.close, size: 18, color: colors.ink3),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: BlocBuilder<SearchCubit, SearchState>(
                builder: (context, state) => switch (state.status) {
                  SearchStatus.idle => _Centered(
                    child: Text(
                      state.query.isEmpty
                          ? 'Search for people by name or @username.'
                          : 'Keep typing — two characters minimum.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySm.copyWith(color: colors.ink2),
                    ),
                  ),
                  SearchStatus.loading => const Padding(
                    padding: EdgeInsets.fromLTRB(14, 0, 14, 0),
                    child: ShimmerListCard(),
                  ),
                  SearchStatus.error => Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                    child: ErrorView(
                      message: state.errorMessage ?? 'Could not run that search.',
                      onRetry: cubit.retry,
                    ),
                  ),
                  SearchStatus.loaded when state.results.isEmpty => _Centered(
                    child: EmptyStateCard(
                      title: 'NO MATCHES',
                      hint: 'Nobody matching "${state.query}". Try a different spelling.',
                    ),
                  ),
                  SearchStatus.loaded => NotificationListener<ScrollNotification>(
                    onNotification: _onScroll,
                    child: ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                      itemCount: state.results.length + 1,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        if (index == state.results.length) {
                          return _Footer(hasMore: state.hasMore, isLoadingMore: state.isLoadingMore);
                        }
                        final user = state.results[index];
                        return _ResultRow(
                          user: user,
                          busy: state.busyIds.contains(user.id),
                          onAdd: () => cubit.sendRequest(user.id),
                        );
                      },
                    ),
                  ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: child),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.hasMore, required this.isLoadingMore});
  final bool hasMore;
  final bool isLoadingMore;

  @override
  Widget build(BuildContext context) {
    if (isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 22),
        child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }
    if (hasMore) return const SizedBox(height: 22);
    return const SizedBox(height: 8);
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.user, required this.busy, required this.onAdd});

  final UserSearchResultEntity user;
  final bool busy;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surf,
        border: Border.all(color: colors.line, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.pushNamed(RouteNames.userProfile, pathParameters: {'userId': user.id}),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              AppAvatar(
                initials: user.displayName.initials,
                seed: avatarSeedForId(user.id),
                imageUrl: user.avatarUrl,
                size: 46,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleMd.copyWith(color: colors.ink),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user.username.withAtSign,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.metaMono.copyWith(color: colors.ink2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _RelationControl(status: user.friendStatus, busy: busy, onAdd: onAdd),
            ],
          ),
        ),
      ),
    );
  }
}

/// The trailing control, driven entirely by the row's own `friendStatus` —
/// the reason the search endpoint returns it per row. Only [FriendRelationStatus.none]
/// gets an actionable button; every other state is a read-only label, since
/// accepting or cancelling belongs on the Circle tab where the full request
/// context lives.
class _RelationControl extends StatelessWidget {
  const _RelationControl({required this.status, required this.busy, required this.onAdd});

  final FriendRelationStatus? status;
  final bool busy;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    if (status == FriendRelationStatus.none) {
      return AppButton(label: 'Add', dense: true, onPressed: busy ? null : onAdd);
    }

    final label = switch (status) {
      FriendRelationStatus.self => 'You',
      FriendRelationStatus.friends => 'Friends',
      FriendRelationStatus.requestSent => 'Requested',
      FriendRelationStatus.requestReceived => 'Wants in',
      // An unrecognized wire value (null) gets no control rather than a
      // wrong one — tapping through to the profile still works.
      _ => null,
    };
    if (label == null) return const SizedBox.shrink();

    return Text(label.toUpperCase(), style: AppTextStyles.metaMono.copyWith(color: colors.ink3));
  }
}
