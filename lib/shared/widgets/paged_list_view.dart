import 'package:flutter/material.dart';

import 'error_view.dart';
import 'shimmer_loading.dart';

/// The loading / error / empty / paged-list switch that every
/// offset-or-cursor-paged screen in this app needs, in one place.
///
/// Two behaviours worth knowing about, because both are easy to get wrong and
/// silent when you do:
///
///  * **Every branch returns a scrollable**, including the empty and error ones.
///    A non-scrollable child silently disables an enclosing `RefreshIndicator`,
///    which is exactly the state a user most wants to pull-to-retry from.
///  * **[errorMessage] should only be non-null when the list is also empty.** A
///    failed "load more" ought to keep the rows already on screen and just drop
///    the footer spinner — replacing them with an error card throws away
///    content the user was reading.
class PagedListView extends StatelessWidget {
  const PagedListView({
    super.key,
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
    required this.isEmpty,
    required this.emptyTitle,
    required this.emptyHint,
    required this.itemCount,
    required this.isLoadingMore,
    required this.onLoadMore,
    required this.itemBuilder,
    this.header,
    this.skeleton = const [ShimmerListCard(), ShimmerListCard()],
    this.padding = const EdgeInsets.fromLTRB(14, 0, 14, 24),
    this.separatorHeight = 10,
    this.loadMoreThreshold = 400,
  });

  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;
  final bool isEmpty;
  final String emptyTitle;
  final String emptyHint;
  final int itemCount;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// Optional content pinned above the list *inside* the same scrollable, so a
  /// long header scrolls away with the rows instead of eating the viewport.
  final Widget? header;

  /// What the loading state shows in place of rows, laid out with the same
  /// [separatorHeight] the real rows get. Defaults to two generic
  /// [ShimmerListCard]s; a screen whose rows have their own distinctive shape
  /// passes skeletons that mirror that card (`ShimmerCommunityPostCard`,
  /// `ShimmerProjectCard`, ...) so the real rows swap in without the list
  /// visibly re-flowing.
  final List<Widget> skeleton;
  final EdgeInsets padding;
  final double separatorHeight;

  /// How far from the bottom (in pixels) to ask for the next page, so it is
  /// usually already in by the time the user gets there.
  final double loadMoreThreshold;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return ListView(
        padding: padding,
        children: [
          ?header,
          for (var i = 0; i < skeleton.length; i++) ...[
            if (i > 0) SizedBox(height: separatorHeight),
            skeleton[i],
          ],
        ],
      );
    }
    if (errorMessage != null) {
      return ListView(
        padding: padding,
        children: [
          ?header,
          ErrorView(message: errorMessage!, onRetry: onRetry),
        ],
      );
    }
    if (isEmpty) {
      return ListView(
        padding: padding,
        children: [
          ?header,
          EmptyStateCard(title: emptyTitle, hint: emptyHint),
        ],
      );
    }

    final headerCount = header == null ? 0 : 1;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is! ScrollUpdateNotification) return false;
        final metrics = notification.metrics;
        // Ignore horizontal scrollers nested inside rows (filter chips, etc.) —
        // only this list's own vertical scroll should page.
        if (metrics.axis != Axis.vertical) return false;
        if (metrics.pixels >= metrics.maxScrollExtent - loadMoreThreshold) onLoadMore();
        return false;
      },
      child: ListView.separated(
        padding: padding,
        itemCount: headerCount + itemCount + 1,
        separatorBuilder: (context, index) => SizedBox(height: separatorHeight),
        itemBuilder: (context, index) {
          if (headerCount == 1 && index == 0) return header!;
          final itemIndex = index - headerCount;
          if (itemIndex == itemCount) {
            if (isLoadingMore) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              );
            }
            return const SizedBox(height: 12);
          }
          return itemBuilder(context, itemIndex);
        },
      ),
    );
  }
}
