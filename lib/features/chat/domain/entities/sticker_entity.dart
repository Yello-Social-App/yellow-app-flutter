import 'package:equatable/equatable.dart';

/// What the server did with the picture behind the subject.
///
/// [removed] is a cut-out with an alpha channel and the white outline baked
/// into the pixels — it is drawn as-is, over whatever is behind it. [kept] is
/// the whole picture cropped square and flattened onto white, and the *app*
/// draws its rounded corners and white frame (the bytes carry neither).
enum StickerBackground {
  removed,
  kept;

  String get wire => this == StickerBackground.removed ? 'REMOVED' : 'KEPT';

  /// Anything this client has not heard of reads as [kept]: a sticker whose
  /// background is an unknown treatment still has a square picture, and
  /// framing it is the safe way to draw one.
  static StickerBackground fromWire(String? value) =>
      value == 'REMOVED' ? StickerBackground.removed : StickerBackground.kept;
}

/// Whether a draft has a cut-out to offer.
///
/// Background removal is built but **switched off server-side** for now (the
/// chat container has 300 MB and a usable model needs more), so every draft
/// currently comes back [noSubject] with no cut-out. The creator handles both
/// branches anyway, which is what lets the server switch it on with no client
/// change — see `docs/BACKEND.md`.
enum StickerCutoutStatus {
  ready,
  noSubject;

  /// [ready] only for an explicit `READY`. Every other word — including one
  /// added later — reads as [noSubject], which keeps the creator on
  /// [StickerBackground.kept]; asking for `REMOVED` on a draft without a
  /// cut-out is `409 CONFLICT`.
  static StickerCutoutStatus fromWire(String? value) =>
      value == 'READY' ? StickerCutoutStatus.ready : StickerCutoutStatus.noSubject;
}

/// One rendered sticker picture. Always 512 × 512 WebP.
///
/// [url] is presigned and needs no auth header. As with
/// `AttachmentEntity.url` it is deliberately **not** in [props]: the server
/// re-signs it on every read, so counting it as a change would make the whole
/// transcript — and the whole picker — look new on every history poll.
/// Anything caching by URL must key on the owning sticker's id instead.
class StickerImage extends Equatable {
  const StickerImage({required this.url, this.width = 512, this.height = 512, this.urlExpiresAt});

  final String url;
  final int width;
  final int height;
  final DateTime? urlExpiresAt;

  bool get isUrlExpired {
    final expiry = urlExpiresAt;
    return expiry != null && !DateTime.now().isBefore(expiry);
  }

  @override
  List<Object?> get props => [width, height];
}

/// A sticker, as `yello-chat` models it.
///
/// The same type covers all three places one arrives from, because the wire
/// shape is the same object in each — only some fields are filled:
///
///  * **the library** (`/ws/stickers/mine`, `/ws/stickers/recent`) — every
///    field, [isMine] true;
///  * **a pack** (`/ws/sticker-packs`) — [packId] set, [isMine] false;
///  * **a message** (`Message.sticker`) — id, [packId], [background] and
///    [image] only. The owner's name is never on a message, so [name] is
///    empty and [isMine] false there regardless of whose library it is in.
///    Whether it is already yours is the server's answer to
///    `…/sticker/save`, not something the message says.
class StickerEntity extends Equatable {
  const StickerEntity({
    required this.id,
    required this.background,
    required this.image,
    this.packId,
    this.name = '',
    this.isMine = false,
    this.createdAt,
  });

  final String id;

  /// A pack slug (`pack_yello_buddy`) for a pack sticker, null for one the
  /// user made or saved. Pack stickers cannot be renamed or deleted.
  final String? packId;

  /// Up to 40 characters, private to the owner, and often empty — a sticker
  /// saved from someone else's message starts with no name at all. Only the
  /// picker's search reads it.
  final String name;

  final StickerBackground background;
  final StickerImage image;

  /// Known to be in the viewer's own library. False on a pack sticker and on
  /// every sticker read off a message — see the class comment.
  final bool isMine;

  /// When it entered the library (for a pack sticker, when the pack was
  /// published). Null on a sticker read off a message.
  final DateTime? createdAt;

  bool get isFromPack => packId != null;

  /// The app draws the rounded corners and the white frame for a [kept]
  /// sticker; a [removed] one is drawn straight, alpha and all.
  bool get needsFrame => background == StickerBackground.kept;

  /// Renaming and deleting are library operations — a pack's stickers answer
  /// `404 STICKER_NOT_FOUND` to both.
  bool get canManage => isMine && !isFromPack;

  StickerEntity copyWith({String? name, StickerImage? image}) => StickerEntity(
    id: id,
    packId: packId,
    name: name ?? this.name,
    background: background,
    image: image ?? this.image,
    isMine: isMine,
    createdAt: createdAt,
  );

  @override
  List<Object?> get props => [id, packId, name, background, image, isMine, createdAt];
}

/// A published sticker pack (`/ws/sticker-packs`). Not paged — the whole
/// catalogue comes in one response, packs in display order and stickers in
/// pack order.
class StickerPackEntity extends Equatable {
  const StickerPackEntity({required this.id, required this.name, required this.stickers, this.thumbnailUrl});

  /// A slug, not a UUID — `pack_yello_buddy`.
  final String id;
  final String name;

  /// Nullable, and excluded from [props] for the same reason
  /// [StickerImage.url] is: it is presigned and re-signed on every read.
  final String? thumbnailUrl;

  final List<StickerEntity> stickers;

  @override
  List<Object?> get props => [id, name, stickers];
}

/// An uploaded picture waiting to become a sticker (`/ws/stickers/drafts`).
///
/// Drafts live an hour and save **once**; a second `POST /ws/stickers` with
/// the same [draftId] is `404 DRAFT_NOT_FOUND`. The uploaded bytes are never
/// stored — what comes back is already cropped square, scaled to 512 and
/// stripped of EXIF, GPS and XMP.
class StickerDraftEntity extends Equatable {
  const StickerDraftEntity({
    required this.draftId,
    required this.original,
    required this.cutoutStatus,
    this.cutout,
    this.expiresAt,
  });

  final String draftId;

  /// The square, scaled picture — what a [StickerBackground.kept] sticker
  /// will be.
  final StickerImage original;

  /// The cut-out, when the server found a subject. Null while removal is
  /// switched off, and whenever [cutoutStatus] is
  /// [StickerCutoutStatus.noSubject].
  final StickerImage? cutout;

  final StickerCutoutStatus cutoutStatus;
  final DateTime? expiresAt;

  /// Whether `REMOVED` is offerable at all. Both halves are checked, not just
  /// the status: without a cut-out picture there is nothing to preview, and
  /// saving `REMOVED` would be `409 CONFLICT`.
  bool get hasCutout => cutoutStatus == StickerCutoutStatus.ready && cutout != null;

  /// What to preview for [background] — the cut-out for `REMOVED`, the whole
  /// square for `KEPT`.
  StickerImage previewFor(StickerBackground background) =>
      background == StickerBackground.removed ? (cutout ?? original) : original;

  @override
  List<Object?> get props => [draftId, original, cutout, cutoutStatus, expiresAt];
}

/// The result of saving a sticker off someone else's message.
///
/// `POST …/sticker/save` answers `201` with a new library entry and `200`
/// with the one that was already there, and the two want different words on
/// screen ("Added to My stickers" / "Already in My stickers") — which is the
/// only reason the status code crosses out of the data layer at all.
typedef SavedSticker = ({StickerEntity sticker, bool alreadyMine});

/// A keyset page of the viewer's own stickers. [nextCursor] is opaque — pass
/// it back verbatim; null means there is nothing older.
class StickerLibraryPage extends Equatable {
  const StickerLibraryPage({required this.items, this.nextCursor});

  final List<StickerEntity> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;

  @override
  List<Object?> get props => [items, nextCursor];
}
