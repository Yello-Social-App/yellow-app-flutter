import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/external_link.dart';
import '../../../../core/utils/link_scanner.dart';
import '../../../../shared/widgets/image_placeholder.dart';
import '../../../../shared/widgets/shimmer_loading.dart';
import '../../domain/entities/link_preview_entity.dart';
import '../bloc/link_preview_cubit.dart';

/// How many cards one body of text gets, however many links it holds. Three
/// is already an unusual post; past that the cards are longer than the text
/// they belong to.
const int kMaxLinkPreviews = 3;

/// The height of a card's picture. Fixed rather than aspect-ratio-driven: an
/// `og:image` is 1.91:1 by convention but nothing enforces it, and a feed of
/// cards that each pick their own height reads as ragged.
const double kLinkPreviewImageHeight = 168;

/// A card under a body of text for each link in it.
///
/// Scans [text] itself rather than taking a list, so a caller only has to
/// pass the same string it already rendered — there is no way for the cards
/// and the tappable links above them to disagree about what the links are.
class LinkPreviewList extends StatelessWidget {
  const LinkPreviewList({super.key, required this.text, this.padding = const EdgeInsets.fromLTRB(14, 0, 14, 12)});

  final String text;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final urls = <String>[];
    for (final link in LinkScanner.scan(text)) {
      // The same link twice in one post is one card.
      if (!urls.contains(link.url)) urls.add(link.url);
      if (urls.length == kMaxLinkPreviews) break;
    }
    if (urls.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final url in urls) ...[
            if (url != urls.first) const SizedBox(height: 8),
            LinkPreviewCard(url: url),
          ],
        ],
      ),
    );
  }
}

/// One link's Open Graph card: picture, page title, and the host it came
/// from. Tapping it opens the link, the same as tapping the link in the text.
///
/// Asks [LinkPreviewCubit] for the card on the way in and reads the answer
/// back through a [BlocSelector] scoped to this one URL, so a card arriving
/// for some other post does not rebuild this one. The cubit is a singleton
/// holding every card the session has seen — asking twice is free.
class LinkPreviewCard extends StatefulWidget {
  const LinkPreviewCard({super.key, required this.url});

  final String url;

  @override
  State<LinkPreviewCard> createState() => _LinkPreviewCardState();
}

class _LinkPreviewCardState extends State<LinkPreviewCard> {
  final LinkPreviewCubit _cubit = sl<LinkPreviewCubit>();

  @override
  void initState() {
    super.initState();
    _cubit.request(widget.url);
  }

  @override
  void didUpdateWidget(LinkPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A recycled card in a scrolling list is the common case here, not an edit.
    if (oldWidget.url != widget.url) _cubit.request(widget.url);
  }

  @override
  Widget build(BuildContext context) {
    return BlocSelector<LinkPreviewCubit, LinkPreviewState, (LinkPreviewStatus, LinkPreviewEntity?)>(
      bloc: _cubit,
      selector: (state) => (state.statusOf(widget.url), state.previewOf(widget.url)),
      builder: (context, slot) {
        final (status, preview) = slot;
        return switch (status) {
          LinkPreviewStatus.loading => const _LoadingCard(),
          // Nothing readable at the other end. The link is still a link in the
          // text above — an error card would only take up room saying so.
          LinkPreviewStatus.unavailable => const SizedBox.shrink(),
          LinkPreviewStatus.ready => _ReadyCard(preview: preview!),
        };
      },
    );
  }
}

class _ReadyCard extends StatelessWidget {
  const _ReadyCard({required this.preview});

  final LinkPreviewEntity preview;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final title = preview.title;
    final description = preview.description;
    return _CardShell(
      onTap: () => ExternalLink.open(preview.url),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (preview.hasImage) _Thumbnail(imageUrl: preview.imageUrl!),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(CupertinoIcons.link, size: 11, color: colors.ink3),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        preview.label.toUpperCase(),
                        style: AppTextStyles.metaMonoSm.copyWith(color: colors.ink3),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (title != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    title,
                    style: AppTextStyles.titleSm.copyWith(color: colors.ink),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: AppTextStyles.bodySm.copyWith(color: colors.ink2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return SizedBox(
      height: kLinkPreviewImageHeight,
      width: double.infinity,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        // Decoded to the box it is drawn in, not to whatever the page
        // published — an `og:image` is routinely 1200px wide.
        memCacheWidth: (MediaQuery.sizeOf(context).width * dpr).round(),
        memCacheHeight: (kLinkPreviewImageHeight * dpr).round(),
        placeholder: (_, _) => const ShimmerBox(height: kLinkPreviewImageHeight, borderRadius: 0),
        errorWidget: (_, _, _) => const ImagePlaceholder(),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const _CardShell(
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 11, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerBox(width: 88, height: 9),
            SizedBox(height: 8),
            ShimmerBox(height: 12),
            SizedBox(height: 6),
            ShimmerBox(width: 160, height: 12),
          ],
        ),
      ),
    );
  }
}

/// The frame both states share: the post card's own surface, one shade in,
/// with a hairline border and no shadow.
///
/// **No `boxShadow`** — this sits inside a widget that rebuilds on every
/// cubit emit, and a blurred shadow there crashed the app on this project's
/// renderer (see `docs/GOTCHAS.md`).
class _CardShell extends StatelessWidget {
  const _CardShell({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: colors.surf2,
      borderRadius: BorderRadius.circular(AppRadii.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: colors.line2, width: 1.5),
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: child,
        ),
      ),
    );
  }
}
