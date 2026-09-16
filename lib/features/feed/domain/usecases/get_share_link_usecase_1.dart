// Superseded — this file is safe to delete.
//
// It held `GetShareLinkUseCase`, which called `GET /posts/{id}/share-link`.
// That endpoint does not exist on the backend and answered
// `404 RESOURCE_NOT_FOUND` on every share tap.
//
// Nothing needs to be fetched: the API returns a ready-made `shareUrl` on
// every `Post`, `PostModel.fromJson` already reads it, and
// `PostEntity.shareUrl` already stores it. `FeedCubit.getShareLink` and
// `PostDetailCubit.getShareLink` now read that field directly.
//
// The contents were removed rather than the file itself only because this
// session has no way to delete files on your machine — delete it and this
// note goes with it.
