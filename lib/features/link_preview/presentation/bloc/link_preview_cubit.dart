import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/link_preview_entity.dart';
import '../../domain/usecases/get_link_preview_usecase.dart';

/// What the card for one URL should draw. `loading` also covers "never asked
/// about", because a card asks on the way in — it is a skeleton either way.
enum LinkPreviewStatus { loading, ready, unavailable }

class LinkPreviewState extends Equatable {
  const LinkPreviewState({
    this.previews = const {},
    this.pending = const {},
    this.unavailable = const {},
  });

  /// URL → the card its page advertised. Insertion-ordered, which is what
  /// makes the oldest entry the one to evict.
  final Map<String, LinkPreviewEntity> previews;

  /// In-flight, and the de-duplication guard: one fetch per URL no matter how
  /// many cards ask for it.
  final Set<String> pending;

  /// Asked and got nothing usable. Remembered so a dead link is not re-fetched
  /// every time its post scrolls back into view.
  final Set<String> unavailable;

  LinkPreviewStatus statusOf(String url) {
    if (previews.containsKey(url)) return LinkPreviewStatus.ready;
    if (unavailable.contains(url)) return LinkPreviewStatus.unavailable;
    return LinkPreviewStatus.loading;
  }

  LinkPreviewEntity? previewOf(String url) => previews[url];

  LinkPreviewState copyWith({
    Map<String, LinkPreviewEntity>? previews,
    Set<String>? pending,
    Set<String>? unavailable,
  }) => LinkPreviewState(
    previews: previews ?? this.previews,
    pending: pending ?? this.pending,
    unavailable: unavailable ?? this.unavailable,
  );

  @override
  List<Object?> get props => [previews, pending, unavailable];
}

/// One shared cache of link cards for the whole app — registered as a
/// singleton for exactly that reason.
///
/// The same link appears in the feed card, in the post's own screen, and
/// again in a repost's embed. Per-card cubits would fetch that page three
/// times; this one fetches it once and every card reads the answer. It also
/// means scrolling a post off-screen and back does not re-fetch: the result,
/// including a failure, is remembered.
///
/// Memory is bounded — [_maxRemembered] entries, oldest evicted — because a
/// singleton with an infinite feed in front of it otherwise grows for the
/// life of the process.
class LinkPreviewCubit extends Cubit<LinkPreviewState> {
  LinkPreviewCubit({required GetLinkPreviewUseCase getLinkPreview})
    : _getLinkPreview = getLinkPreview,
      super(const LinkPreviewState());

  final GetLinkPreviewUseCase _getLinkPreview;

  static const int _maxRemembered = 120;

  /// Idempotent: safe to call from every card's `initState`, on every rebuild,
  /// for the same URL. A second call while the first is in flight is dropped.
  Future<void> request(String url) async {
    if (state.pending.contains(url) || state.previews.containsKey(url) || state.unavailable.contains(url)) return;

    emit(state.copyWith(pending: {...state.pending, url}));
    final result = await _getLinkPreview(url);
    if (isClosed) return;

    final pending = {...state.pending}..remove(url);
    result.fold(
      (failure) => emit(state.copyWith(pending: pending, unavailable: _capSet({...state.unavailable, url}))),
      (preview) {
        // A page that advertised neither a picture nor a title has nothing to
        // put in a card, and the link is already tappable in the text.
        if (!preview.hasContent) {
          emit(state.copyWith(pending: pending, unavailable: _capSet({...state.unavailable, url})));
          return;
        }
        emit(state.copyWith(pending: pending, previews: _cap({...state.previews, url: preview})));
      },
    );
  }

  static Map<String, T> _cap<T>(Map<String, T> entries) {
    if (entries.length <= _maxRemembered) return entries;
    final trimmed = Map<String, T>.of(entries);
    while (trimmed.length > _maxRemembered) {
      trimmed.remove(trimmed.keys.first);
    }
    return trimmed;
  }

  static Set<String> _capSet(Set<String> entries) {
    if (entries.length <= _maxRemembered) return entries;
    final trimmed = <String>{...entries};
    while (trimmed.length > _maxRemembered) {
      trimmed.remove(trimmed.first);
    }
    return trimmed;
  }
}
