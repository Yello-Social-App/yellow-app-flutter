import 'package:equatable/equatable.dart';

/// How `yello-chat` classified an upload from its bytes (never its name).
/// JPEG, PNG, GIF and WebP are [image] and render inline; everything else is
/// [file], served as `application/octet-stream` behind a link that forces a
/// download.
///
/// [voice] is the odd one out: it never comes back from the general upload
/// route at all, only from `POST /ws/conversations/{id}/attachments/voice`,
/// which transcodes whatever it is given to mono AAC/M4A and measures the
/// duration and waveform itself. So a VOICE attachment always carries
/// [AttachmentEntity.voice].
enum AttachmentKind {
  image,
  file,
  voice;

  static AttachmentKind fromWire(String? value) => switch (value) {
    'IMAGE' => AttachmentKind.image,
    'VOICE' => AttachmentKind.voice,
    // A kind this app has not heard of still has a name, a size and a link,
    // which is everything the file chip needs — so it degrades to one rather
    // than rendering nothing.
    _ => AttachmentKind.file,
  };
}

/// What the server measured from a voice note's audio (`VoiceMeta`).
///
/// Both fields come from the server's own decode of the upload, never from
/// the recorder: the client's idea of how long it recorded stops at whatever
/// the mic delivered, and the file is transcoded on the way in. So a bubble
/// draws these, not what the recorder counted.
class VoiceMetaEntity extends Equatable {
  const VoiceMetaEntity({required this.durationMs, this.waveform = const []});

  /// Always > 0 on the wire.
  final int durationMs;

  /// Up to 64 loudness values, 0–100, left to right; the loudest bar is 100.
  /// One bar per value — the bubble resamples to however many it can draw.
  final List<int> waveform;

  Duration get duration => Duration(milliseconds: durationMs);

  /// `m:ss`, the form the design shows in the bubble and under the recorder.
  String get durationLabel => formatVoiceDuration(duration);

  @override
  List<Object?> get props => [durationMs, waveform];
}

/// `m:ss` — used for a note's length, the recorder's clock and its 5:00 cap,
/// so they cannot drift apart.
String formatVoiceDuration(Duration d) {
  final seconds = d.inSeconds < 0 ? 0 : d.inSeconds;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
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
    this.voice,
    this.url,
    this.urlExpiresAt,
  });

  final String id;
  final AttachmentKind kind;

  /// Cleaned display name — safe to show as-is.
  final String fileName;
  final String mimeType;
  final int sizeBytes;

  /// Set when and only when [kind] is [AttachmentKind.voice].
  final VoiceMetaEntity? voice;

  /// Null when the deployment has attachments disabled (`503 UNAVAILABLE`
  /// on upload) — the row still renders, there is just nothing to open.
  final String? url;
  final DateTime? urlExpiresAt;

  bool get isImage => kind == AttachmentKind.image;

  /// A voice note the bubble can actually draw. The kind alone is not
  /// enough: without [voice] there is no duration and no waveform, so such
  /// an attachment falls back to the file chip rather than a player with
  /// nothing in it.
  bool get isVoice => kind == AttachmentKind.voice && voice != null;

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
  List<Object?> get props => [id, kind, fileName, mimeType, sizeBytes, voice];
}
