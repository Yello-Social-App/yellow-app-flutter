import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/sticker_entity.dart';

/// Stickers on `yello-chat`. A separate interface from `ChatRepository`
/// because a sticker is its own resource with its own routes and its own
/// lifetime: the library outlives any one conversation, and nothing here
/// takes a conversation id except the one route that reads a sticker off a
/// message.
///
/// Sending a sticker is *not* here — that is a message, and it goes out
/// through `ChatRepository.sendMessage(stickerId:)`.
abstract interface class StickerRepository {
  /// The viewer's own library, newest first. A full library (200) is two
  /// pages at the server's clamp of 100.
  Future<Either<Failure, StickerLibraryPage>> getMyStickers({String? cursor});

  /// What the viewer sent most recently, newest first and de-duplicated.
  /// Server-side, so it is the same list on every device — the app keeps no
  /// local Recent. Deleted stickers and withdrawn packs drop out on their own.
  Future<Either<Failure, List<StickerEntity>>> getRecentStickers({int? size});

  /// Every published pack, in display order. Conditional server-side: an
  /// unchanged catalogue costs one `304` and the previously read packs come
  /// back, presigned URLs included.
  Future<Either<Failure, List<StickerPackEntity>>> getStickerPacks();

  /// Step one of making a sticker: upload a picture and get back the square,
  /// 512 px version (plus a cut-out, once removal is switched on).
  ///
  /// PNG, JPEG or WebP — typed from the bytes, not the name — up to 5 MB,
  /// 4096 px a side and 16 MP. 30 drafts per user per hour; the 31st is
  /// `429 RATE_LIMITED`.
  Future<Either<Failure, StickerDraftEntity>> createDraft(File image);

  /// Step two: turn a draft into a library sticker. A draft saves once.
  Future<Either<Failure, StickerEntity>> saveSticker({
    required String draftId,
    required StickerBackground background,
    required String name,
  });

  /// `404` when the sticker is not in the viewer's library — a pack's
  /// stickers included.
  Future<Either<Failure, StickerEntity>> renameSticker({required String stickerId, required String name});

  /// Removes it from the library. Messages that already carry it keep showing
  /// it; only the picker and Recent lose it.
  Future<Either<Failure, Unit>> deleteSticker(String stickerId);

  /// Adds the sticker on a message to the viewer's library — the *same*
  /// image, not a copy. `409 ALREADY_AVAILABLE` for a pack sticker (it is
  /// already in the picker), `404` for a message the viewer cannot see.
  Future<Either<Failure, SavedSticker>> saveStickerFromMessage({
    required String conversationId,
    required String messageId,
  });

  /// Library changes made on **any** of the viewer's devices, including this
  /// one — an HTTP request cannot tell the server which socket made it, so
  /// every session is told and the listener de-duplicates on the sticker's
  /// id.
  ///
  /// Rides the same socket as `ChatRepository.watchEvents`, so subscribing
  /// keeps a connection open: hold a listener only while something on screen
  /// reads the library (see `StickersCubit.watchLibrary`).
  Stream<StickerLibraryEvent> watchLibrary();
}

/// One decoded `sticker.*` frame. Owner-scoped rather than
/// conversation-scoped, which is why these are not [ChatEvent]s — they belong
/// to the library, not to any one screen (the same reasoning as `presence`,
/// ADR-038).
sealed class StickerLibraryEvent {
  const StickerLibraryEvent();
}

/// `sticker.added` — a save, here or on another device.
class StickerAdded extends StickerLibraryEvent {
  const StickerAdded(this.sticker);
  final StickerEntity sticker;
}

/// `sticker.updated` — a rename.
class StickerUpdated extends StickerLibraryEvent {
  const StickerUpdated(this.sticker);
  final StickerEntity sticker;
}

/// `sticker.removed` — a delete. Only the id travels.
class StickerRemoved extends StickerLibraryEvent {
  const StickerRemoved(this.stickerId);
  final String stickerId;
}
