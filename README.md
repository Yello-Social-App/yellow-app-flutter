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

## Releasing

Every step, in order, in PowerShell. The example cuts `1.1.0` (build `7`) —
swap in the real numbers. Yello is sideloaded, so a release is only finished
when a GitHub Release carries the APK and its `latest.json`; that file is the
only way an installed app learns there is an update (ADR-029).

**1. Check the work is ready.** Do not tag until both are clean.

```powershell
flutter analyze
flutter test
```

**2. Pick the version.** Look at what changed since the last tag:

```powershell
git log "$(git describe --tags --abbrev=0)..HEAD" --oneline
```

| Bump | When |
|---|---|
| Major (`2.0.0`) | Something users relied on was removed or changed |
| Minor (`1.1.0`) | New features, nothing broken |
| Patch (`1.0.1`) | Fixes only |

**3. Branch and commit the work.** Read the `git status` list for stray files
before committing.

```powershell
git switch -c release/v1.1.0
git add -A
git status
git commit -m "feat: short summary of what this release adds"
```

**4. Bump the version — two files, by hand.**

- `pubspec.yaml`: `version: 1.0.0+6` becomes `version: 1.1.0+7`. The number
  after `+` **must go up every release** — the in-app updater compares that
  number and never the version text.
- `CHANGELOG.md`: keep `## [Unreleased]` at the top and add a new heading
  under it, so the existing entries fall under the new version:

  ```markdown
  ## [Unreleased]

  ---

  ## [1.1.0] — 2026-10-01
  ```

**5. Commit the release, tag it, push.** Never force-push or move a tag that
is already on GitHub; if one is wrong, cut the next version.

```powershell
git commit -am "chore(release): v1.1.0"
git tag -a v1.1.0 -m "v1.1.0"
git push -u origin release/v1.1.0
git push origin v1.1.0
```

**6. Merge.** Open a pull request from `release/v1.1.0` into `main` on GitHub,
merge it, then:

```powershell
git switch main
git pull
```

**7. Publish the update for the app.** `tool/release_manifest.sh` needs bash,
which is not on the PowerShell PATH — call the one that ships with Git for
Windows.

```powershell
flutter build apk --release
& "C:\Program Files\Git\bin\bash.exe" tool/release_manifest.sh
Copy-Item build/app/outputs/flutter-apk/app-release.apk build/yello-1.1.0.apk
gh release create v1.1.0 build/yello-1.1.0.apk build/latest.json --title "v1.1.0" --latest
```

The APK must be uploaded under exactly the name `yello-<version>.apk`; the
manifest's download link points at it. If you create the release on the GitHub
website instead, leave **"Set as a pre-release" unticked** and tick "Set as
the latest release" — the app reads GitHub's *latest* release, which skips
pre-releases, so a pre-release is invisible to it.

**8. Confirm it worked.**

```powershell
gh release list --limit 3
curl.exe -sL https://github.com/Yello-Social-App/yellow-app-flutter/releases/latest/download/latest.json
```

The new version should show `Latest`, and the JSON should carry the new
`version` and `buildNumber`. GitHub can serve the old manifest for a couple of
minutes after a release changes; wait and retry before changing anything. Then
check **Account menu → App version** on a phone.

**9. Tell people (optional).** Once step 8 shows the new manifest, send the
"new version" push from the Firebase console: **Messaging → New campaign →
Notifications**, write the title and text, target the **Android app**, and
under **Additional options → Custom data** add key `type` with value
`APP_UPDATE`. Tapping it opens App version with the download ready. Without
that key the push still arrives, but a tap only opens the app. Details:
[`docs/BACKEND.md`](docs/BACKEND.md), "`APP_UPDATE` is not a backend push".

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
