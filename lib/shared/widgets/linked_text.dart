import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/external_link.dart';
import '../../core/utils/link_scanner.dart';
import '../../features/link_preview/presentation/widgets/link_preview_card.dart';
import 'app_status_snackbar.dart';

/// Matches a `#hashtag` run — highlighted, but not tappable: there is no
/// tag search to send it to (`/search` is people-only and takes no query),
/// so a tap would have to land somewhere arbitrary. See `CreatePostCubit`
/// for where they come from — the backend has no tags field at all.
final RegExp _hashtagPattern = RegExp(r'#\w+');

/// User-typed text — a post body, a comment, a bio, a chat bubble — with its
/// links drawn as links and tappable, opening in the phone's browser.
///
/// A [StatefulWidget] on purpose: each link needs a [TapGestureRecognizer],
/// recognizers hold resources and must be disposed, and building them inside
/// `build` would leak one per link per frame on a scrolling feed. They are
/// rebuilt only when [text] actually changes.
///
/// Set [tagBackground] to get the feed's yellow highlight behind `#hashtag`
/// words; leave it null (comments, bios, chat) for plain text with links.
/// Hashtags are only looked for *outside* the links, so the `#fragment` on
/// the end of a URL is part of the URL and not a tag.
class LinkedText extends StatefulWidget {
  const LinkedText({
    super.key,
    required this.text,
    required this.style,
    this.tagBackground,
    this.linkColor,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.showLinkPreviews = true,
  });

  final String text;
  final TextStyle style;

  /// Painted behind each `#hashtag`. Null draws them like the rest of the text.
  final Color? tagBackground;

  /// Overrides the link colour. For text on a coloured fill — the yellow
  /// bubble of your own chat message — the palette's link yellow has nothing
  /// to contrast against, so the caller passes the bubble's own ink and the
  /// underline carries the affordance instead.
  final Color? linkColor;

  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  /// Whether a preview card for each link is drawn under the text (ADR-041).
  /// Off where the text is already squeezed into something small — a photo
  /// caption over the image, a repost embed — where the links still open.
  final bool showLinkPreviews;

  @override
  State<LinkedText> createState() => _LinkedTextState();
}

class _LinkedTextState extends State<LinkedText> {
  List<LinkMatch> _links = const [];

  /// Index-aligned with [_links].
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void initState() {
    super.initState();
    _rescan();
  }

  @override
  void didUpdateWidget(LinkedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _rescan();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  void _rescan() {
    _disposeRecognizers();
    _links = LinkScanner.scan(widget.text);
    for (final link in _links) {
      _recognizers.add(TapGestureRecognizer()..onTap = () => _open(link.url));
    }
  }

  /// A tap that opens nothing has to say so. A link drawn as a link and then
  /// silently doing nothing is indistinguishable from one that was never
  /// wired up — which is the bug this widget exists to fix.
  Future<void> _open(String url) async {
    if (await ExternalLink.open(url) || !mounted) return;
    AppStatusSnackbar.showError(
      context,
      title: 'Cannot open',
      message: 'No app on this phone offered to open that link.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final text = Text.rich(
      TextSpan(children: _spans(colors)),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      textAlign: widget.textAlign,
    );
    if (_links.isEmpty || !widget.showLinkPreviews) return text;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        text,
        LinkPreviewList(
          text: widget.text,
          padding: const EdgeInsets.only(top: 8),
        ),
      ],
    );
  }

  List<InlineSpan> _spans(AppColors colors) {
    if (_links.isEmpty) return _plainSpans(widget.text, colors);

    // `yeld` is the palette's readable-on-any-background yellow (olive in the
    // light themes, bright in the dark ones), so a link reads as brand accent
    // in both without a second token.
    final linkColor = widget.linkColor ?? colors.yeld;
    final linkStyle = widget.style.copyWith(
      color: linkColor,
      decoration: TextDecoration.underline,
      decorationColor: linkColor,
    );

    final spans = <InlineSpan>[];
    var last = 0;
    for (var i = 0; i < _links.length; i++) {
      final link = _links[i];
      if (link.start > last) spans.addAll(_plainSpans(widget.text.substring(last, link.start), colors));
      spans.add(
        TextSpan(
          text: widget.text.substring(link.start, link.end),
          style: linkStyle,
          recognizer: _recognizers[i],
        ),
      );
      last = link.end;
    }
    if (last < widget.text.length) spans.addAll(_plainSpans(widget.text.substring(last), colors));
    return spans;
  }

  /// Everything between the links: one span, or one per `#hashtag` run when
  /// [LinkedText.tagBackground] asked for the highlight.
  List<InlineSpan> _plainSpans(String text, AppColors colors) {
    final tagBackground = widget.tagBackground;
    if (tagBackground == null || text.isEmpty) {
      return [TextSpan(text: text, style: widget.style)];
    }

    final spans = <InlineSpan>[];
    var last = 0;
    for (final match in _hashtagPattern.allMatches(text)) {
      if (match.start > last) spans.add(TextSpan(text: text.substring(last, match.start), style: widget.style));
      spans.add(TextSpan(text: match.group(0), style: widget.style.copyWith(backgroundColor: tagBackground)));
      last = match.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last), style: widget.style));
    return spans;
  }
}
