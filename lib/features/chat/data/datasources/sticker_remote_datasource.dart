import 'dart:io';

import 'package:dio/dio.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/sticker_entity.dart';
import '../models/sticker_model.dart';
import 'chat_remote_datasource.dart' show ChatRoutes;

abstract interface class StickerRemoteDataSource {
  Future<StickerLibraryPage> getMyStickers({String? cursor, int? limit});
  Future<List<StickerEntity>> getRecentStickers({int? size});
  Future<List<StickerPackEntity>> getStickerPacks();
  Future<StickerDraftEntity> createDraft(File image);
  Future<StickerEntity> saveSticker({
    required String draftId,
    required StickerBackground background,
    required String name,
  });
  Future<StickerEntity> renameSticker({required String stickerId, required String name});
  Future<void> deleteSticker(String stickerId);
  Future<SavedSticker> saveStickerFromMessage({required String conversationId, required String messageId});
}

class StickerRemoteDataSourceImpl implements StickerRemoteDataSource {
  StickerRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;
  Dio get _dio => _apiClient.dio;

  /// The `ETag` the last `GET /ws/sticker-packs` answered with, and the packs
  /// it answered with, so an unchanged catalogue costs one `304` and no
  /// parsing.
  ///
  /// Cached here rather than in a cubit because it is a property of the
  /// *response*, not of any screen: the route sends `Cache-Control: private,
  /// no-cache`, keeps one URL for a whole hour-long window, and promises each
  /// URL stays valid for at least an hour after it is handed out — so a `304`
  /// means the cached links are still loadable, not merely that the list is
  /// unchanged. Process-lifetime only; nothing is written to disk.
  String? _packsEtag;
  List<StickerPackEntity>? _packs;

  @override
  Future<StickerLibraryPage> getMyStickers({String? cursor, int? limit}) => _guard(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      ChatRoutes.myStickers,
      queryParameters: {'limit': ?limit, 'cursor': ?cursor},
    );
    return StickerMapper.pageFromJson(_body(res));
  });

  /// Answers a bare array, not a page.
  @override
  Future<List<StickerEntity>> getRecentStickers({int? size}) => _guard(() async {
    final res = await _dio.get<List<dynamic>>(ChatRoutes.recentStickers, queryParameters: {'size': ?size});
    return StickerMapper.fromJsonList(res.data);
  });

  /// Conditional: the previous `ETag` goes back as `If-None-Match`, and a
  /// `304` — which carries no body — resolves to the packs already held.
  /// `validateStatus` has to be widened for that, since Dio treats anything
  /// outside 2xx as an error by default.
  @override
  Future<List<StickerPackEntity>> getStickerPacks() => _guard(() async {
    final etag = _packsEtag;
    final cached = _packs;
    final res = await _dio.get<List<dynamic>>(
      ChatRoutes.stickerPacks,
      options: Options(
        headers: {if (etag != null && cached != null) 'If-None-Match': etag},
        validateStatus: (status) => status != null && (status == 304 || (status >= 200 && status < 300)),
      ),
    );
    if (res.statusCode == 304 && cached != null) return cached;
    final packs = StickerPackMapper.fromJsonList(res.data);
    _packsEtag = res.headers.value('etag');
    _packs = packs;
    return packs;
  });

  /// `multipart/form-data`, one field **`image`** — not `file`, as the
  /// attachment routes use. The server types it from the bytes, so the
  /// filename only decides what it is called in a validation message.
  @override
  Future<StickerDraftEntity> createDraft(File image) => _guard(() async {
    final form = FormData.fromMap({
      'image': await MultipartFile.fromFile(image.path, filename: image.uri.pathSegments.last),
    });
    final res = await _dio.post<Map<String, dynamic>>(ChatRoutes.stickerDrafts, data: form);
    return StickerDraftMapper.fromJson(_body(res));
  });

  /// `name` goes out even when empty — that is the documented default, and
  /// omitting it would leave the server to decide.
  @override
  Future<StickerEntity> saveSticker({
    required String draftId,
    required StickerBackground background,
    required String name,
  }) => _guard(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      ChatRoutes.stickers,
      data: {'draftId': draftId, 'background': background.wire, 'name': name},
    );
    return StickerMapper.fromJson(_body(res));
  });

  @override
  Future<StickerEntity> renameSticker({required String stickerId, required String name}) => _guard(() async {
    final res = await _dio.patch<Map<String, dynamic>>(ChatRoutes.sticker(stickerId), data: {'name': name});
    return StickerMapper.fromJson(_body(res));
  });

  /// 204, no body.
  @override
  Future<void> deleteSticker(String stickerId) => _guard(() => _dio.delete<void>(ChatRoutes.sticker(stickerId)));

  /// `201` for a new library entry, `200` for one that was already there —
  /// the caller says something different for each, so the status travels with
  /// the sticker.
  @override
  Future<SavedSticker> saveStickerFromMessage({required String conversationId, required String messageId}) =>
      _guard(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          ChatRoutes.saveMessageSticker(conversationId, messageId),
        );
        return (sticker: StickerMapper.fromJson(_body(res)), alreadyMine: res.statusCode == 200);
      });

  Map<String, dynamic> _body(Response<Map<String, dynamic>> res) => res.data ?? const <String, dynamic>{};

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on DioException catch (e) {
      throw e.error is AppException ? e.error as AppException : ErrorHandler.fromDioException(e);
    }
  }
}
