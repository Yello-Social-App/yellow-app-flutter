/// A stable image-cache key for a presigned link (`yello-chat` attachments
/// and group photos on R2).
///
/// Those URLs are re-signed on every read — the same file comes back with a
/// different `X-Amz-Signature` query each time the conversation or history
/// is fetched. `cached_network_image` keys both its memory and disk caches
/// by URL unless told otherwise, so left alone every poll is a cache miss
/// and a fresh download of a picture that has not changed. The object's own
/// address — scheme, host and path, signature stripped — is what actually
/// identifies the bytes, and a *new* upload gets a new object path, so this
/// key goes stale exactly when the picture really did change.
///
/// Anything that is not a URL is returned unchanged.
String presignedObjectKey(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return url;
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: uri.path,
  ).toString();
}
