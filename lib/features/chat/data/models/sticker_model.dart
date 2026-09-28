import '../../domain/entities/sticker_entity.dart';

/// Wire → domain mapping for `yello-chat`'s sticker payloads. Bare objects,
/// no `{success, data}` envelope, same as every other `/ws` response.
///
/// Every field but `id` degrades rather than throwing: a sticker with a
/// background this client has not heard of still has a picture to draw, and
/// one added field server-side must not be able to take the picker down.
abstract final class StickerMapper {
  static StickerEntity fromJson(Map<String, dynamic> json) => StickerEntity(
    id: json['id'] as String,
    packId: json['packId'] as String?,
    name: json['name'] as String? ?? '',
    background: StickerBackground.fromWire(json['background'] as String?),
    image: imageFromJson(json['image']) ?? const StickerImage(url: ''),
    isMine: json['isMine'] as bool? ?? false,
    createdAt: _date(json['createdAt']),
  );

  /// `Message.sticker` — null on every message that is not a sticker message,
  /// and on a tombstone.
  static StickerEntity? fromJsonOrNull(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    return raw['id'] is String ? fromJson(raw) : null;
  }

  static List<StickerEntity> fromJsonList(dynamic raw) => raw is List
      ? raw.whereType<Map<String, dynamic>>().where((e) => e['id'] is String).map(fromJson).toList(growable: false)
      : const [];

  /// The `{ url, width, height, urlExpiresAt }` block. Null for a draft's
  /// absent `cutout`; a block without a `url` is also null, since there is
  /// nothing to draw from it.
  static StickerImage? imageFromJson(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final url = raw['url'] as String?;
    if (url == null || url.isEmpty) return null;
    return StickerImage(
      url: url,
      width: (raw['width'] as num?)?.toInt() ?? 512,
      height: (raw['height'] as num?)?.toInt() ?? 512,
      urlExpiresAt: _date(raw['urlExpiresAt']),
    );
  }

  /// `GET /ws/stickers/mine` — `{ items, nextCursor }`, newest first. The
  /// server's order is kept: "newest first" is what the picker draws, and
  /// re-sorting here would fight the keyset cursor.
  static StickerLibraryPage pageFromJson(Map<String, dynamic> json) =>
      StickerLibraryPage(items: fromJsonList(json['items']), nextCursor: json['nextCursor'] as String?);
}

abstract final class StickerPackMapper {
  static StickerPackEntity fromJson(Map<String, dynamic> json) => StickerPackEntity(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    thumbnailUrl: json['thumbnailUrl'] as String?,
    stickers: StickerMapper.fromJsonList(json['stickers']),
  );

  /// `GET /ws/sticker-packs` answers a bare array. A pack with no stickers
  /// left in it is dropped — it would draw an empty tab.
  static List<StickerPackEntity> fromJsonList(dynamic raw) => raw is List
      ? raw
            .whereType<Map<String, dynamic>>()
            .where((e) => e['id'] is String)
            .map(fromJson)
            .where((pack) => pack.stickers.isNotEmpty)
            .toList(growable: false)
      : const [];
}

abstract final class StickerDraftMapper {
  static StickerDraftEntity fromJson(Map<String, dynamic> json) => StickerDraftEntity(
    draftId: json['draftId'] as String,
    original: StickerMapper.imageFromJson(json['original']) ?? const StickerImage(url: ''),
    cutout: StickerMapper.imageFromJson(json['cutout']),
    cutoutStatus: StickerCutoutStatus.fromWire(json['cutoutStatus'] as String?),
    expiresAt: _date(json['expiresAt']),
  );
}

DateTime? _date(dynamic raw) => raw is String ? DateTime.tryParse(raw) : null;
