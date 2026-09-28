import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/security/input_sanitizer.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/sticker_entity.dart';
import '../repositories/sticker_repository.dart';
import 'chat_usecases.dart' show CursorParams, MessageRefParams;

// The service's own limits, mirrored client-side so a pick that cannot
// succeed fails before the bytes leave the phone — the same reasoning as
// `chatAttachmentMaxBytes` in `chat_usecases.dart`.

/// `STICKER_LIBRARY_MAX` — saved-from-message stickers included. The 201st
/// save is `409 CONFLICT` / `STICKER_LIMIT_REACHED`.
const int stickerLibraryMax = 200;

/// A sticker's own name: trimmed, may be empty, and only the owner ever sees
/// it.
const int stickerNameMaxLength = 40;

/// `POST /ws/stickers/drafts` answers `413` above this.
const int stickerUploadMaxBytes = 5 * 1024 * 1024;

/// What `GET /ws/stickers/mine?limit=` is clamped to server-side. Asking for
/// more is not an error, it just returns 100.
const int stickerLibraryPageSize = 100;

/// `GET /ws/stickers/recent?size=` — the default and the ceiling.
const int stickerRecentSize = 24;
const int stickerRecentMaxSize = 50;

/// Extensions the upload route accepts. It types the upload from its bytes,
/// so this is only a courtesy check that saves a round trip — and it is
/// applied only when there *is* an extension, so a picked file without one
/// still goes to the server to be judged there.
const Set<String> _stickerImageExtensions = {'png', 'jpg', 'jpeg', 'webp'};

class GetMyStickersUseCase implements UseCase<StickerLibraryPage, CursorParams> {
  GetMyStickersUseCase(this._repository);
  final StickerRepository _repository;

  @override
  Future<Either<Failure, StickerLibraryPage>> call(CursorParams params) =>
      _repository.getMyStickers(cursor: params.cursor);
}

class GetRecentStickersUseCase implements UseCase<List<StickerEntity>, NoParams> {
  GetRecentStickersUseCase(this._repository);
  final StickerRepository _repository;

  @override
  Future<Either<Failure, List<StickerEntity>>> call(NoParams params) =>
      _repository.getRecentStickers(size: stickerRecentSize);
}

class GetStickerPacksUseCase implements UseCase<List<StickerPackEntity>, NoParams> {
  GetStickerPacksUseCase(this._repository);
  final StickerRepository _repository;

  @override
  Future<Either<Failure, List<StickerPackEntity>>> call(NoParams params) => _repository.getStickerPacks();
}

/// Uploads the picture a sticker will be made from.
///
/// Size is checked here for the same reason `UploadAttachmentUseCase` checks
/// it — learning about a 5 MB limit *after* uploading 12 MB is a slow way to
/// learn — and the wording matches the design's own. Pixel dimensions are
/// left to the server: the phone would have to decode the whole file to
/// measure them, which is most of the cost of just sending it.
class CreateStickerDraftUseCase implements UseCase<StickerDraftEntity, File> {
  CreateStickerDraftUseCase(this._repository);
  final StickerRepository _repository;

  @override
  Future<Either<Failure, StickerDraftEntity>> call(File params) async {
    final name = params.uri.pathSegments.isEmpty ? params.path : params.uri.pathSegments.last;
    final dot = name.lastIndexOf('.');
    if (dot > 0 && !_stickerImageExtensions.contains(name.substring(dot + 1).toLowerCase())) {
      return const Left(ValidationFailure("That file isn't a picture. Try a PNG, JPG or WebP."));
    }
    final size = await params.length();
    if (size > stickerUploadMaxBytes) {
      return const Left(ValidationFailure('That picture is over 5 MB. Try a smaller one, or a screenshot of it.'));
    }
    return _repository.createDraft(params);
  }
}

class SaveStickerParams extends Equatable {
  const SaveStickerParams({required this.draftId, required this.background, this.name = ''});

  final String draftId;

  /// [StickerBackground.removed] is only valid on a draft whose
  /// `cutoutStatus` is `READY` — the creator reads that off the draft, so by
  /// the time this runs the choice has already been constrained.
  final StickerBackground background;

  /// Optional; trimmed and cut to [stickerNameMaxLength] here.
  final String name;

  @override
  List<Object?> get props => [draftId, background, name];
}

class SaveStickerUseCase implements UseCase<StickerEntity, SaveStickerParams> {
  SaveStickerUseCase(this._repository);
  final StickerRepository _repository;

  @override
  Future<Either<Failure, StickerEntity>> call(SaveStickerParams params) => _repository.saveSticker(
    draftId: params.draftId,
    background: params.background,
    name: InputSanitizer.sanitizeText(params.name, maxLength: stickerNameMaxLength),
  );
}

class RenameStickerParams extends Equatable {
  const RenameStickerParams({required this.stickerId, required this.name});
  final String stickerId;
  final String name;

  @override
  List<Object?> get props => [stickerId, name];
}

/// An empty name is a real value — it clears the one that was there — so
/// unlike a group title this does not refuse one.
class RenameStickerUseCase implements UseCase<StickerEntity, RenameStickerParams> {
  RenameStickerUseCase(this._repository);
  final StickerRepository _repository;

  @override
  Future<Either<Failure, StickerEntity>> call(RenameStickerParams params) => _repository.renameSticker(
    stickerId: params.stickerId,
    name: InputSanitizer.sanitizeText(params.name, maxLength: stickerNameMaxLength),
  );
}

class DeleteStickerUseCase implements UseCase<Unit, String> {
  DeleteStickerUseCase(this._repository);
  final StickerRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(String params) => _repository.deleteSticker(params);
}

/// Adds the sticker on a message to the viewer's library. Takes the same
/// `(conversationId, messageId)` pair every other per-message action does.
class SaveStickerFromMessageUseCase implements UseCase<SavedSticker, MessageRefParams> {
  SaveStickerFromMessageUseCase(this._repository);
  final StickerRepository _repository;

  @override
  Future<Either<Failure, SavedSticker>> call(MessageRefParams params) =>
      _repository.saveStickerFromMessage(conversationId: params.conversationId, messageId: params.messageId);
}
