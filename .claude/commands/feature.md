---
description: Scaffold a new feature (or a new slice of one) following the project's layer checklist
argument-hint: <feature name> — <what it should do>
allowed-tools: Read, Write, Edit, Bash(bash tool/codemap.sh), Bash(flutter analyze), Bash(rg:*), Bash(grep:*)
---

Build out: $ARGUMENTS

Before writing anything, read `docs/ARCHITECTURE.md` and find the closest
existing feature in `docs/CODEMAP.md`. **Copy its shape.** Consistency with
what's already here beats a marginally better structure.

Work outside-in and stop at the first layer that already exists — don't
create a file just to complete the set:

1. `domain/entities/<thing>_entity.dart` — immutable `Equatable`, no JSON
2. `domain/repositories/<feature>_repository.dart` — interface returning
   `Future<Either<Failure, T>>`
3. `domain/usecases/<verb>_<thing>_usecase.dart` — one class per action,
   implementing `UseCase<Result, Params>`
4. `data/models/<thing>_model.dart` — `fromJson`/`toJson`/`toEntity()`
5. `data/datasources/<feature>_remote_datasource.dart` — interface + impl,
   unwrapping via `ApiEnvelope`, paths from `VersionedEndpoints`
6. `data/repositories/<feature>_repository_impl.dart` — exception → `Failure`
7. `presentation/bloc/<screen>_cubit.dart` — Cubit **and** its State, one file
8. `presentation/pages/<screen>_page.dart`
9. Register in `lib/core/di/injection.dart` — and write the one-line comment
   saying *why* it's a singleton or a factory
10. Route in `app_router.dart` + name in `route_names.dart`
11. Cubit test under `test/features/<feature>/`

Then: `bash tool/codemap.sh`, `flutter analyze`, and a `CHANGELOG.md` entry.

While writing:

- Every mutating action gets an in-flight guard — copy
  `FeedCubit._pendingReactions`.
- `const` constructors where the subtree is static; `BlocSelector`/`buildWhen`
  over a page-wide `BlocBuilder`; `ListView.builder` for anything
  variable-length; `cached_network_image` for remote images.
- 120 columns, by hand.
- If the endpoint you need doesn't exist in `docs/BACKEND.md`, **stop and say
  so** rather than inventing a path or faking it locally.

Name the design choice you made for anything non-trivial, in one line, and put
it in `docs/DECISIONS.md` if it will outlive this change.
