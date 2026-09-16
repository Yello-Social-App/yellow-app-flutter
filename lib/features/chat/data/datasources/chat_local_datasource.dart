// Superseded — this file is safe to delete.
//
// It held `ChatLocalDataSource`: the demo conversation seed and the
// simulated "they are typing… " reply that stood in for a backend while chat
// had no server. Chat now runs against the real `yello-chat` service
// (`ChatRemoteDataSourceImpl`), so nothing references it any more and its
// registration is gone from `core/di/injection.dart`.
//
// The contents were removed rather than the file itself only because this
// session has no way to delete files on your machine — delete it yourself
// and this note goes with it. Left non-empty and comment-only so
// `flutter analyze` stays clean in the meantime: the old code constructed
// `ConversationEntity`/`MessageEntity` with their pre-API field names
// (`name`, `avatarSeed`, `text`, `sentAt` as constructor arguments) and
// would now fail to compile.
