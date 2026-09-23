import 'package:equatable/equatable.dart';

/// How `yello-chat` classified an upload from its bytes (never its name).
/// JPEG, PNG, GIF and WebP are [image] and render inline; everything else is
/// [file], served as `application/octet-stream` behind a link that forces a
/// download.
enum AttachmentKind {
  image,
  file;

  static AttachmentKind fromWire(String? value) => value == 'IMAGE' ? AttachmentKind.image : AttachmentKind.file;
}

/// A file or image on a message (`Attachment`).
///
/// [url] is a presigned link that needs no auth header and is valid until
/// [urlExpiresAt] (an hour by default). It is re-signed on every read, so two
/// fetches of the same message carry two different URLs for one file —
/// which is why [props] deliberately exclude it: an attachment's identity is
/// its [id], and anything caching by URL (image caches in particular) must
/// key on [id] instead, or the 5-second history poll would refetch every
/// picture in the transcript on each tick.
class AttachmentEntity extends Equatable {
  const AttachmentEntity({
    required this.id,
    required this.kind,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    this.url,
    this.urlExpiresAt,
  });

  final String id;
  final AttachmentKind kind;

  /// Cleaned display name — safe to show as-is.
  final String fileName;
  final String mimeType;
  final int sizeBytes;

  /// Null when the deployment has attachments disabled (`503 UNAVAILABLE`
  /// on upload) — the row still renders, there is just nothing to open.
  final String? url;
  final DateTime? urlExpiresAt;

  bool get isImage => kind == AttachmentKind.image;

  /// True once the presigned link is past [urlExpiresAt]; callers fetch a
  /// fresh one through `GET /ws/attachments/{id}` rather than retrying it.
  bool get isUrlExpired {
    final expiry = urlExpiresAt;
    return expiry != null && !DateTime.now().isBefore(expiry);
  }

  /// "48 KB", "1.2 MB" — for the file chip.
  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).round()} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  List<Object?> get props => [id, kind, fileName, mimeType, sizeBytes];
}
