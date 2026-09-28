import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/sticker_entity.dart';
import '../../domain/repositories/sticker_repository.dart';
import '../../domain/usecases/sticker_usecases.dart' show stickerLibraryPageSize;
import '../datasources/chat_frame_decoder.dart';
import '../datasources/chat_socket.dart';
import '../datasources/sticker_remote_datasource.dart';

/// Backs stickers with `yello-chat`.
///
/// Thinner than `ChatRepositoryImpl` because a sticker needs neither of the
/// two things that one supplies: the owner is always the token's user (so
/// there is no `fromMe` to derive and no viewer id to prime), and a sticker
/// names nobody (so there is nothing for `UserDirectory` to hydrate). What is
/// left is the network guard and the exception → [Failure] mapping every
/// repository in this app does.
class StickerRepositoryImpl implements StickerRepository {
  StickerRepositoryImpl(this._remote, this._networkInfo, this._socket);

  final StickerRemoteDataSource _remote;
  final NetworkInfo _networkInfo;
  final ChatSocket _socket;

  Future<Either<Failure, T>> _run<T>(Future<T> Function() body) async {
    if (!await _networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      return Right(await body());
    } on AppException catch (e) {
      return Left(ErrorHandler.toFailure(e));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  /// Asks for the server's own clamp explicitly: a full library is then two
  /// pages rather than however many the route's unstated default would make.
  @override
  Future<Either<Failure, StickerLibraryPage>> getMyStickers({String? cursor}) =>
      _run(() => _remote.getMyStickers(cursor: cursor, limit: stickerLibraryPageSize));

  @override
  Future<Either<Failure, List<StickerEntity>>> getRecentStickers({int? size}) =>
      _run(() => _remote.getRecentStickers(size: size));

  @override
  Future<Either<Failure, List<StickerPackEntity>>> getStickerPacks() => _run(_remote.getStickerPacks);

  @override
  Future<Either<Failure, StickerDraftEntity>> createDraft(File image) => _run(() => _remote.createDraft(image));

  @override
  Future<Either<Failure, StickerEntity>> saveSticker({
    required String draftId,
    required StickerBackground background,
    required String name,
  }) => _run(() => _remote.saveSticker(draftId: draftId, background: background, name: name));

  @override
  Future<Either<Failure, StickerEntity>> renameSticker({required String stickerId, required String name}) =>
      _run(() => _remote.renameSticker(stickerId: stickerId, name: name));

  @override
  Future<Either<Failure, Unit>> deleteSticker(String stickerId) => _run(() async {
    await _remote.deleteSticker(stickerId);
    return unit;
  });

  @override
  Future<Either<Failure, SavedSticker>> saveStickerFromMessage({
    required String conversationId,
    required String messageId,
  }) => _run(() => _remote.saveStickerFromMessage(conversationId: conversationId, messageId: messageId));

  /// The shared socket's frames, filtered to the `sticker.*` vocabulary.
  ///
  /// `ChatSocket.frames` is what *opens* the connection (its controller
  /// connects on the first listener and disconnects when the last one goes),
  /// so this stream is a connection lease like every other subscriber's —
  /// which is why `StickersCubit` holds it only while a picker is on screen
  /// rather than for the life of the process.
  @override
  Stream<StickerLibraryEvent> watchLibrary() =>
      _socket.frames.map(ChatFrameDecoder.stickerEvent).where((event) => event != null).cast<StickerLibraryEvent>();
}
