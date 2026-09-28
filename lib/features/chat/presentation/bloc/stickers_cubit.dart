import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/sticker_entity.dart';
import '../../domain/repositories/sticker_repository.dart';
import '../../domain/usecases/chat_usecases.dart' show CursorParams;
import '../../domain/usecases/sticker_usecases.dart';

enum StickerLibraryStatus { initial, loading, loaded, error }

class StickersState extends Equatable {
  const StickersState({
    this.status = StickerLibraryStatus.initial,
    this.recent = const [],
    this.mine = const [],
    this.packs = const [],
    this.mineCursor,
    this.isLoadingMore = false,
    this.errorMessage,
    this.busyStickerIds = const {},
    this.actionError,
  });

  final StickerLibraryStatus status;

  /// What the viewer sent most recently — server-side, so it is the same on
  /// every device. Newest first, no duplicates.
  final List<StickerEntity> recent;

  /// The viewer's own library, newest first. One page at a time; a full
  /// library (200) is two.
  final List<StickerEntity> mine;

  /// Published packs, in display order.
  final List<StickerPackEntity> packs;

  final String? mineCursor;
  final bool isLoadingMore;

  /// Set when the first load failed and there is nothing to draw.
  final String? errorMessage;

  /// Stickers with a rename or delete in flight; their tile is disabled.
  final Set<String> busyStickerIds;

  /// One-shot failure from a rename or delete, surfaced as a snackbar and
  /// dropped on the next emit — the same contract as `ChatState.actionError`.
  final String? actionError;

  bool get hasMoreMine => mineCursor != null;

  /// Nothing saved *and* nothing published: the picker shows the first-run
  /// invitation rather than an empty grid.
  bool get isEmpty => mine.isEmpty && packs.isEmpty && recent.isEmpty;

  /// The library is at the server's ceiling, so the next save would be
  /// `409 STICKER_LIMIT_REACHED`. Only trustworthy once the whole library has
  /// been paged in, which is why the cursor is consulted too.
  bool get isFull => !hasMoreMine && mine.length >= stickerLibraryMax;

  /// Every sticker the viewer can send, library first then packs — what the
  /// picker's search runs over. Pack stickers carry the names the importer
  /// gave them, so they are searchable too.
  Iterable<StickerEntity> get all => [mine, for (final pack in packs) pack.stickers].expand((list) => list);

  /// Name search, case-insensitive substring. Unnamed stickers match nothing,
  /// which is what the creator's "Helps you find it in search" hint is about.
  List<StickerEntity> search(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const [];
    return [
      for (final sticker in all)
        if (sticker.name.toLowerCase().contains(needle)) sticker,
    ];
  }

  static const Object _unset = Object();

  StickersState copyWith({
    StickerLibraryStatus? status,
    List<StickerEntity>? recent,
    List<StickerEntity>? mine,
    List<StickerPackEntity>? packs,
    Object? mineCursor = _unset,
    bool? isLoadingMore,
    String? errorMessage,
    Set<String>? busyStickerIds,
    String? actionError,
  }) => StickersState(
    status: status ?? this.status,
    recent: recent ?? this.recent,
    mine: mine ?? this.mine,
    packs: packs ?? this.packs,
    mineCursor: identical(mineCursor, _unset) ? this.mineCursor : mineCursor as String?,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    errorMessage: errorMessage,
    busyStickerIds: busyStickerIds ?? this.busyStickerIds,
    actionError: actionError,
  );

  @override
  List<Object?> get props => [
    status,
    recent,
    mine,
    packs,
    mineCursor,
    isLoadingMore,
    errorMessage,
    busyStickerIds,
    actionError,
  ];
}

/// The sticker library behind the picker: Recent, My stickers and the packs.
///
/// **Long-lived on purpose** (`registerLazySingleton`) so reopening the picker
/// draws the grid it drew last time instead of a spinner. Per `docs/GOTCHAS.md`
/// that makes staleness this class's problem, so it is answered in two ways
/// and written down here:
///
///  * **the picker calls [load] every time it opens** — the reads are cheap
///    (the packs route is conditional and usually answers `304`), and this is
///    the guarantee the screen relies on;
///  * **`sticker.*` frames** keep it live while a picker is on screen, for
///    changes made on the viewer's *other* devices ([watchLibrary]).
///
/// Everything this app does to the library itself is applied here directly
/// from the response, so neither of those is load-bearing for the device that
/// made the change.
class StickersCubit extends Cubit<StickersState> {
  StickersCubit({
    required GetMyStickersUseCase getMine,
    required GetRecentStickersUseCase getRecent,
    required GetStickerPacksUseCase getPacks,
    required RenameStickerUseCase renameSticker,
    required DeleteStickerUseCase deleteSticker,
    required StickerRepository repository,
  }) : _getMine = getMine,
       _getRecent = getRecent,
       _getPacks = getPacks,
       _renameSticker = renameSticker,
       _deleteSticker = deleteSticker,
       _repository = repository,
       super(const StickersState());

  final GetMyStickersUseCase _getMine;
  final GetRecentStickersUseCase _getRecent;
  final GetStickerPacksUseCase _getPacks;
  final RenameStickerUseCase _renameSticker;
  final DeleteStickerUseCase _deleteSticker;

  /// For [watchLibrary] alone — a socket stream has no result for a `UseCase`
  /// to carry, the same reason `MessagesCubit` holds one for presence.
  final StickerRepository _repository;

  bool _isLoading = false;

  /// In-flight guard for the mutating actions, the `FeedCubit._pendingReactions`
  /// shape.
  final Set<String> _pendingStickerIds = {};

  /// Loads all three lists at once.
  ///
  /// The spinner is only shown when there is nothing to draw yet: a reopen
  /// keeps the previous grid on screen and swaps it when the reads land, so
  /// the picker never flashes empty over a library it already has.
  Future<void> load() async {
    if (_isLoading || isClosed) return;
    _isLoading = true;
    if (state.status == StickerLibraryStatus.initial) {
      emit(state.copyWith(status: StickerLibraryStatus.loading));
    }
    final results = await Future.wait<dynamic>([
      _getRecent(const NoParams()),
      _getMine(const CursorParams()),
      _getPacks(const NoParams()),
    ]);
    _isLoading = false;
    if (isClosed) return;

    final recentResult = results[0] as Either<Failure, List<StickerEntity>>;
    final mineResult = results[1] as Either<Failure, StickerLibraryPage>;
    final packsResult = results[2] as Either<Failure, List<StickerPackEntity>>;

    // A list that failed keeps whatever was already held rather than
    // blanking: two of the three are supporting tabs, and an empty tab reads
    // as "you have none" when the truth is "we could not ask".
    final recent = recentResult.getOrElse(() => state.recent);
    final packs = packsResult.getOrElse(() => state.packs);
    final page = mineResult.fold((_) => null, (p) => p);

    // My stickers is the one list the picker cannot work without — Create
    // lives in it, and the limit is read off it. A failure there is the only
    // one that counts as a failed load, and then only on a first load, since
    // a reopen can still draw the library it already has.
    if (page == null && state.status != StickerLibraryStatus.loaded) {
      emit(
        state.copyWith(
          status: StickerLibraryStatus.error,
          errorMessage: mineResult.fold((failure) => failure.message, (_) => null),
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: StickerLibraryStatus.loaded,
        recent: recent,
        mine: page?.items ?? state.mine,
        mineCursor: page != null ? page.nextCursor : state.mineCursor,
        packs: packs,
      ),
    );
  }

  /// The next page of My stickers. Appended, never prepended — the list is
  /// newest first and the cursor walks backwards through it.
  Future<void> loadMoreMine() async {
    if (!state.hasMoreMine || state.isLoadingMore || isClosed) return;
    emit(state.copyWith(isLoadingMore: true));
    final result = await _getMine(CursorParams(cursor: state.mineCursor));
    if (isClosed) return;
    result.fold(
      (_) => emit(state.copyWith(isLoadingMore: false)),
      (page) => emit(
        state.copyWith(mine: [...state.mine, ...page.items], mineCursor: page.nextCursor, isLoadingMore: false),
      ),
    );
  }

  /// A sticker this device just created or saved. Put at the head of My
  /// stickers so the picker shows it without a refetch; a duplicate id is
  /// replaced rather than added, which is also what makes a `sticker.added`
  /// frame echoing our own save harmless.
  void applySaved(StickerEntity sticker) {
    final next = [sticker, ...state.mine.where((s) => s.id != sticker.id)];
    emit(state.copyWith(mine: next));
  }

  /// A sticker was just sent: hoist it to the front of Recent.
  ///
  /// The server tracks Recent itself, so this only saves the picker from
  /// showing a stale order until the next [load] — which is the difference
  /// between the tab being right and being right *eventually*.
  void markSent(StickerEntity sticker) {
    final next = [sticker, ...state.recent.where((s) => s.id != sticker.id)];
    emit(state.copyWith(recent: next.take(stickerRecentMaxSize).toList(growable: false)));
  }

  Future<void> rename(StickerEntity sticker, String name) async {
    if (!sticker.canManage) return;
    if (!_pendingStickerIds.add(sticker.id)) return;
    emit(state.copyWith(busyStickerIds: {...state.busyStickerIds, sticker.id}));
    try {
      final result = await _renameSticker(RenameStickerParams(stickerId: sticker.id, name: name));
      if (isClosed) return;
      // Cleared *before* the result is folded, so the failure is what the last
      // emit carries: `copyWith` drops `actionError` on every state that does
      // not set it, and clearing the tile afterwards would take the message
      // with it.
      _clearBusy(sticker.id);
      result.fold((failure) => emit(state.copyWith(actionError: failure.message)), _applyUpdated);
    } finally {
      _clearBusy(sticker.id);
    }
  }

  Future<void> remove(StickerEntity sticker) async {
    if (!sticker.canManage) return;
    if (!_pendingStickerIds.add(sticker.id)) return;
    emit(state.copyWith(busyStickerIds: {...state.busyStickerIds, sticker.id}));
    try {
      final result = await _deleteSticker(sticker.id);
      if (isClosed) return;
      _clearBusy(sticker.id);
      result.fold((failure) => emit(state.copyWith(actionError: failure.message)), (_) => _applyRemoved(sticker.id));
    } finally {
      _clearBusy(sticker.id);
    }
  }

  /// Releases the in-flight guard and re-enables the tile. Idempotent, so the
  /// `finally` that backstops a thrown usecase can call it again for nothing.
  void _clearBusy(String stickerId) {
    if (!_pendingStickerIds.remove(stickerId)) return;
    if (!isClosed) emit(state.copyWith(busyStickerIds: {...state.busyStickerIds}..remove(stickerId)));
  }

  // --- live library events ---

  /// How many screens want `sticker.*` frames. Leased rather than started
  /// once, because subscribing is what holds the WebSocket open — the same
  /// bookkeeping presence needs (ADR-038). A picker opened over a chat adds a
  /// second holder to a connection that is already up.
  int _watchers = 0;
  StreamSubscription<StickerLibraryEvent>? _sub;

  void watchLibrary() {
    _watchers++;
    _sub ??= _repository.watchLibrary().listen(_onEvent);
  }

  void releaseLibrary() {
    if (_watchers == 0) return;
    _watchers--;
    if (_watchers > 0) return;
    unawaited(_sub?.cancel());
    _sub = null;
  }

  /// Frames reach **every** session the viewer has, this one included, so each
  /// branch has to be idempotent on the sticker's id rather than assume the
  /// change has not been applied already.
  void _onEvent(StickerLibraryEvent event) {
    if (isClosed) return;
    switch (event) {
      case StickerAdded(:final sticker):
        applySaved(sticker);
      case StickerUpdated(:final sticker):
        _applyUpdated(sticker);
      case StickerRemoved(:final stickerId):
        _applyRemoved(stickerId);
    }
  }

  /// Swaps a sticker in place wherever it is held, and no-ops on an id this
  /// state does not carry — a rename of a sticker on a page not loaded yet
  /// must not resurrect it into the grid out of order.
  void _applyUpdated(StickerEntity sticker) {
    if (!state.mine.any((s) => s.id == sticker.id) && !state.recent.any((s) => s.id == sticker.id)) return;
    emit(
      state.copyWith(
        mine: [
          for (final s in state.mine)
            if (s.id == sticker.id) sticker else s,
        ],
        recent: [
          for (final s in state.recent)
            if (s.id == sticker.id) sticker else s,
        ],
      ),
    );
  }

  /// A deleted sticker leaves the library *and* Recent — the server drops it
  /// from both, and leaving it in Recent would offer a tile whose send is a
  /// `404`. Packs are untouched: a pack sticker cannot be deleted.
  void _applyRemoved(String stickerId) {
    emit(
      state.copyWith(
        mine: state.mine.where((s) => s.id != stickerId).toList(growable: false),
        recent: state.recent.where((s) => s.id != stickerId).toList(growable: false),
      ),
    );
  }

  @override
  Future<void> close() {
    _watchers = 0;
    unawaited(_sub?.cancel());
    return super.close();
  }
}
