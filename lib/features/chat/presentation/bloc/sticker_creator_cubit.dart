import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/sticker_entity.dart';
import '../../domain/usecases/sticker_usecases.dart';

/// Where the creator is. Two visible steps with an upload between them, which
/// is its own step because the upload is where the server crops, scales,
/// strips the metadata and (when it is switched on) cuts the subject out —
/// long enough to need a state of its own rather than a flag.
enum StickerCreatorStep { pick, uploading, edit, saving }

class StickerCreatorState extends Equatable {
  const StickerCreatorState({
    this.step = StickerCreatorStep.pick,
    this.draft,
    this.background = StickerBackground.kept,
    this.name = '',
    this.pickError,
    this.actionError,
  });

  final StickerCreatorStep step;

  /// The uploaded picture, once there is one. Lives an hour and saves once.
  final StickerDraftEntity? draft;

  /// What [save] will ask for. Constrained to [StickerBackground.kept]
  /// whenever the draft has no cut-out — `REMOVED` on such a draft is
  /// `409 CONFLICT`.
  final StickerBackground background;
  final String name;

  /// Why the last pick did not become a draft — too big, not a picture, the
  /// hourly draft cap. Shown inside the picker box, the way the design's
  /// "That file isn't a picture" state does, and cleared by the next pick.
  final String? pickError;

  /// One-shot failure from [save], surfaced as a snackbar. Dropped on the
  /// next emit, the same contract as `ChatState.actionError`.
  final String? actionError;

  bool get isBusy => step == StickerCreatorStep.uploading || step == StickerCreatorStep.saving;

  /// Whether the Remove/Keep choice is offerable at all. False while removal
  /// is switched off server-side, which is what leaves the toggle disabled on
  /// `Keep` — see `StickerCutoutStatus`.
  bool get canRemoveBackground => draft?.hasCutout ?? false;

  /// The picture to preview for the current choice.
  StickerImage? get preview => draft?.previewFor(background);

  static const Object _unset = Object();

  StickerCreatorState copyWith({
    StickerCreatorStep? step,
    Object? draft = _unset,
    StickerBackground? background,
    String? name,
    String? pickError,
    String? actionError,
  }) => StickerCreatorState(
    step: step ?? this.step,
    draft: identical(draft, _unset) ? this.draft : draft as StickerDraftEntity?,
    background: background ?? this.background,
    name: name ?? this.name,
    pickError: pickError,
    actionError: actionError,
  );

  @override
  List<Object?> get props => [step, draft, background, name, pickError, actionError];
}

/// Turns a picked picture into a library sticker — the two-step "Create a
/// sticker" flow.
///
/// Fresh per creator (`registerFactory`): a draft is single-use and expires in
/// an hour, so there is nothing here worth outliving the screen. What comes
/// out is handed to `StickersCubit.applySaved` by the caller, which is what
/// puts it in the picker without a refetch.
class StickerCreatorCubit extends Cubit<StickerCreatorState> {
  StickerCreatorCubit({required CreateStickerDraftUseCase createDraft, required SaveStickerUseCase saveSticker})
    : _createDraft = createDraft,
      _saveSticker = saveSticker,
      super(const StickerCreatorState());

  final CreateStickerDraftUseCase _createDraft;
  final SaveStickerUseCase _saveSticker;

  /// Uploads [image] and moves to the edit step.
  ///
  /// The default choice is whatever the draft can actually offer: the cut-out
  /// when there is one (which is what the design calls the default), and
  /// `Keep` otherwise. Nothing here has to change when removal is switched on
  /// server-side.
  Future<void> usePicture(File image) async {
    if (state.isBusy) return;
    emit(state.copyWith(step: StickerCreatorStep.uploading, draft: null));
    final result = await _createDraft(image);
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(step: StickerCreatorStep.pick, pickError: failure.message)),
      (draft) => emit(
        state.copyWith(
          step: StickerCreatorStep.edit,
          draft: draft,
          background: draft.hasCutout ? StickerBackground.removed : StickerBackground.kept,
        ),
      ),
    );
  }

  /// Back to the picker. The old draft is dropped rather than kept as a
  /// fallback: it saves once, and holding it would let Save land on the
  /// picture the user just replaced.
  void changePicture() {
    if (state.isBusy) return;
    emit(const StickerCreatorState());
  }

  void setBackground(StickerBackground background) {
    if (background == StickerBackground.removed && !state.canRemoveBackground) return;
    emit(state.copyWith(background: background));
  }

  void setName(String name) => emit(state.copyWith(name: name));

  /// Saves the draft. Answers the sticker, or null when the save failed — in
  /// which case the message is already on its way out as
  /// [StickerCreatorState.actionError] and the edit step is still on screen so
  /// the user can try again.
  ///
  /// A draft saves once, so this deliberately does *not* return to the edit
  /// step on success: there is nothing left to save.
  Future<StickerEntity?> save() async {
    final draft = state.draft;
    if (draft == null || state.isBusy) return null;
    emit(state.copyWith(step: StickerCreatorStep.saving));
    final result = await _saveSticker(
      SaveStickerParams(draftId: draft.draftId, background: state.background, name: state.name),
    );
    if (isClosed) return null;
    return result.fold((failure) {
      emit(state.copyWith(step: StickerCreatorStep.edit, actionError: failure.message));
      return null;
    }, (sticker) => sticker);
  }
}
