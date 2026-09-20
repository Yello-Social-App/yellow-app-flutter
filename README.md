# Yello

A Flutter social app for **Android and iOS**. Feed, stories, reactions,
comments, friends, chat, communities, a project showcase, and push
notifications, against a live backend at `https://api.yello.cachewraith.com`.

> The previous README still contained unresolved merge-conflict markers from
> the initial import; this replaces it.

---

## Getting started

```bash
flutter pub get
flutter run          # a connected Android or iOS device
```

There is no web or desktop target, and no dev/staging/prod flavor split — the
base URL is passed once from `lib/main.dart` into `bootstrap(baseUrl:)`.

```bash
flutter analyze                 # must be clean
flutter test                    # unit + widget tests
dart format --line-length=120 <file>   # this repo is 120 cols, NOT the default 80
```

---

## Layout

```
lib/
  core/       config, constants, di, error, network, notifications,
              router, security, theme, usecase, utils
  features/   auth, chat, communities, feed, friends, notification,
              profile, search, shell, showcase
              └─ each: data/ · domain/ · presentation/
  shared/     widgets, models, extensions
  l10n/       localizations
test/         mirrors lib/
tool/         repo scripts (no Dart SDK required)
docs/         the documentation set below
```

---

## Documentation

| File | What it's for |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Layers, request lifecycle, the checklist for adding a feature |
| [docs/CODEMAP.md](docs/CODEMAP.md) | Generated index of every file, route, and DI registration |
| [docs/BACKEND.md](docs/BACKEND.md) | Endpoints, response envelope, error codes, permanent gaps |
| [docs/GOTCHAS.md](docs/GOTCHAS.md) | Things that already broke on a real device |
| [docs/DECISIONS.md](docs/DECISIONS.md) | Decision log (ADRs) |
| [CHANGELOG.md](CHANGELOG.md) | What changed, per release |

`docs/CODEMAP.md` is generated. Regenerate it whenever files, routes, or DI
registrations move:

```bash
bash tool/codemap.sh           # write docs/CODEMAP.md
bash tool/codemap.sh --check   # non-zero exit if the committed map is stale
```

---

## Working with AI assistants

[`AGENTS.md`](AGENTS.md) is the shared contract for any assistant — Claude
Code, Codex, Cursor, Gemini, Copilot — so they all start from the same facts
and reach consistent answers. [`CLAUDE.md`](CLAUDE.md) adds the Claude-specific
workflow on top and defers to `AGENTS.md` for everything shared.

Claude Code also gets, from `.claude/`:

- a session-start brief with the read order and the code map's freshness
- slash commands: `/prime`, `/codemap`, `/changelog`, `/adr`, `/feature`,
  `/review`, `/preflight`
- a read-only `flutter-reviewer` agent for reviews

The one rule that keeps it all working: **when you change the code, keep the
docs true in the same commit.** An index nobody regenerates is worse than no
index.
