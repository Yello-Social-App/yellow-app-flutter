import 'package:equatable/equatable.dart';

/// What a link turned out to be about: the Open Graph card a page advertises
/// for itself.
///
/// Every field but [url] is optional, because every field is someone else's
/// markup. A page with no `og:` tags at all still produces one of these — a
/// card with nothing but the host is still better than a bare URL, and it is
/// the card [hasContent] refuses.
class LinkPreviewEntity extends Equatable {
  const LinkPreviewEntity({
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
    this.siteName,
  });

  /// The link as it will be opened — the address that was fetched, not the
  /// redirect chain's last hop.
  final String url;

  final String? title;
  final String? description;

  /// Absolute, `http(s)`, and on a publicly routable host — resolved and
  /// re-checked in the data layer, because it is loaded straight into an
  /// image widget on the reader's phone.
  final String? imageUrl;

  final String? siteName;

  /// What the card shows under the picture when the page named itself.
  String get host {
    final parsed = Uri.tryParse(url);
    if (parsed == null) return url;
    final host = parsed.host;
    return host.startsWith('www.') ? host.substring(4) : host;
  }

  String get label => siteName?.trim().isNotEmpty == true ? siteName!.trim() : host;

  bool get hasImage => (imageUrl ?? '').isNotEmpty;

  /// False for a page that advertised nothing at all. Those draw no card:
  /// the link itself is already tappable in the text above.
  bool get hasContent => hasImage || (title ?? '').trim().isNotEmpty;

  @override
  List<Object?> get props => [url, title, description, imageUrl, siteName];
}
