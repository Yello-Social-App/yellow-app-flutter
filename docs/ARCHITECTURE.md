# Architecture

How Yello is put together, and where a new piece of code belongs. Read this
once per session before writing code; use [CODEMAP.md](CODEMAP.md) to find
the specific file.

---

## The stack

| Concern | Choice | Notes |
|---|---|---|
| Platforms | Android + iOS only | No web/desktop. Those folders are deliberately absent — don't re-add them. |
| State | `flutter_bloc`, **Cubits only** | No Bloc, no events. See [DECISIONS.md](DECISIONS.md#adr-002--cubits-only-no-bloc-events). |
| DI | `get_it`, hand-written | `lib/core/di/injection.dart`. No `injectable`, no build_runner. |
| Routing | `go_router` ^17.5.0 | `lib/core/router/`. `StatefulShellRoute` for the 5 tabs. |
| HTTP | `dio` + interceptors | `lib/core/network/`. |
| Errors | `dartz` `Either<Failure, T>` | Domain layer never throws across a boundary. |
| Images | `cached_network_image` | Never bare `Image.network`. |
| Localization | `flutter_localizations` + `lib/l10n/` | `l10n.yaml` at root. |

---

## Layers

Feature-first Clean Architecture. Every feature is
`lib/features/<feature>/{data,domain,presentation}`:

```
presentation/pages      Widgets. Read state, dispatch intent. No business logic.
presentation/widgets    Feature-local reusable widgets.
presentation/bloc       Cubit + its State class, together in one file.
        │  calls
        ▼
domain/usecases         One class per action. `UseCase<Result, Params>`.
        │  calls
        ▼
domain/repositories     Abstract interface. Returns Either<Failure, T>.
        │  implemented by
        ▼
data/repositories       Impl: catches exceptions → Failure, maps Model → Entity.
        │  calls
        ▼
data/datasources        Dio calls / local storage. Throws typed exceptions.
        │
data/models             JSON ⇄ Entity. `fromJson` / `toJson` live here only.
domain/entities         Plain immutable Equatable value types. No JSON.
```

**The two rules that matter most:**

1. **A Cubit calls a usecase, never a repository or a data source.** If you
   catch yourself injecting a repository into a Cubit, the usecase is missing —
   write it.
2. **Dependencies point inward.** `domain/` imports nothing from `data/` or
   `presentation/`. An entity never knows about JSON; that's the model's job.

### Where cross-cutting code goes

```
lib/core/config         AppConfig — one flat static holder, set in bootstrap().
lib/core/constants      Timeouts, header names, asset paths.
lib/core/di             The whole get_it graph.
lib/core/error          Failure types, exceptions, ErrorHandler (envelope → Failure).
lib/core/network        ApiClient, envelope unwrapping, interceptors, versioning.
lib/core/notifications  Firebase push wiring.
lib/core/router         Routes, names, guards.
lib/core/security       JWT, secure storage, session, biometrics, root detection.
lib/core/theme          Colors, text styles, ThemeCubit.
lib/core/usecase        The UseCase base type.
lib/core/utils          Formatters, logger, validators, responsive helpers.
lib/shared/widgets      Cross-feature widgets (AppButton, PagedListView, …).
lib/shared/models       Cross-feature models (PaginatedResponse).
lib/shared/extensions   BuildContext / String extensions.
```

---

## Startup sequence

`lib/main.dart` → `bootstrap(baseUrl: …)` → `lib/bootstrap.dart`:

1. `AppConfig.init(baseUrl:)` — **must** run before DI, because `ApiClient`
   reads `AppConfig.baseUrl` at construction time.
2. `configureDependencies()` — registers the whole `get_it` graph.
3. Session restore / security checks.
4. `runApp(YelloApp())` → `lib/app.dart` builds `MaterialApp.router` off
   `AppRouter.router`.

---

## Request lifecycle

```
Cubit
  → UseCase(params)
    → Repository (interface)
      → RepositoryImpl
        → RemoteDataSource
          → ApiClient (dio)
            → AuthInterceptor    attaches bearer token, refreshes on 401
            → RetryInterceptor   retries idempotent calls (ApiConstants.maxRetries)
            → ErrorInterceptor   maps transport + envelope errors
            → LoggingInterceptor off in release (bodies may carry tokens/PII)
        ← ApiEnvelope.data/.list/.page/.cursorPage unwraps {success, data, timestamp}
        ← Model.fromJson → Entity
      ← Either<Failure, Entity>
```

Never parse `response.data['data']` by hand in a data source — use
`ApiEnvelope`. Never build a `/v1/...` path by hand — use
`VersionedEndpoints`. See [BACKEND.md](BACKEND.md).

---

## Adding a feature — the checklist

Work outside-in, and stop at the first layer that already exists:

1. `domain/entities/<thing>_entity.dart` — the value type.
2. `domain/repositories/<feature>_repository.dart` — the interface, returning
   `Future<Either<Failure, T>>`.
3. `domain/usecases/<verb>_<thing>_usecase.dart` — one per action.
4. `data/models/<thing>_model.dart` — `fromJson`/`toJson` + `toEntity()`.
5. `data/datasources/<feature>_remote_datasource.dart` — interface + impl.
6. `data/repositories/<feature>_repository_impl.dart` — exception → Failure.
7. `presentation/bloc/<screen>_cubit.dart` — Cubit **and** its State.
8. `presentation/pages/<screen>_page.dart`.
9. Register everything in `lib/core/di/injection.dart`
   (singleton vs factory — see [DECISIONS.md](DECISIONS.md#adr-004--registerlazysingleton-vs-registerfactory-is-per-type)).
10. Add the route to `app_router.dart` + `route_names.dart`.
11. Add the endpoint to `VersionedEndpoints` (or the service's own `*Routes`).
12. Test the Cubit under `test/features/<feature>/`.
13. `bash tool/codemap.sh` and add a `CHANGELOG.md` entry.

---

## Conventions that are easy to get wrong

- **120-column formatting**, hand-maintained. `dart format` defaults to 80 and
  will explode the diff. If you must format: `dart format --line-length=120 <file>`
  on the touched files only — never repo-wide.
- **Cubit and State in one file.** Don't split them.
- **`const` constructors** everywhere the subtree is static.
- **`BlocSelector` / `buildWhen`** over a page-wide `BlocBuilder`.
- **`ListView.builder`** for anything variable-length. No `.map().toList()`
  over unbounded data.
- See [GOTCHAS.md](GOTCHAS.md) for the on-device landmines — several of these
  crashed or silently broke the real app.
