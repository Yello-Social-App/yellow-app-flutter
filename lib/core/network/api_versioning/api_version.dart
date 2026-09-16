/// API generations the backend may expose. The live backend
/// (`api.yello.cachewraith.com`) currently only serves `v1`; the enum
/// stays in place (rather than inlining `'v1'` everywhere) so a future
/// `v2` migration is a matter of adding a case and moving individual
/// [VersionedEndpoints] entries over one at a time.
enum ApiVersion {
  v1('v1');

  const ApiVersion(this.segment);

  /// The literal URL path segment, e.g. the `v1` in `/v1/...`.
  final String segment;

  static const ApiVersion latest = ApiVersion.v1;
}
