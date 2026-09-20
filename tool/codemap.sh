#!/usr/bin/env bash
# Regenerates docs/CODEMAP.md from the source tree.
#
# Why this exists: an AI assistant (or a new teammate) should be able to find
# the right file from an index instead of grepping 200+ Dart files every
# session. The map is generated, never hand-edited, so it cannot drift —
# re-run it after any change that adds/moves/removes a file, a route, or a DI
# registration.
#
#   bash tool/codemap.sh          # writes docs/CODEMAP.md
#   bash tool/codemap.sh --check  # exits 1 if the committed map is stale
#
# Pure bash + awk/grep on purpose: it must run without a Dart/Flutter SDK.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

OUT="docs/CODEMAP.md"
MODE="${1:-write}"

# ---------------------------------------------------------------- helpers ---

# Strips lib/ and the .dart suffix for compact display.
short() { sed 's|^lib/||; s|\.dart$||'; }

# "feed" -> "Feed", "notification" -> "Notification"
title() { printf '%s' "$1" | sed 's/^./\U&/'; }

# Lists dart files under a feature subpath, one per line, sorted, or nothing.
files_in() { find "$1" -name '*.dart' 2>/dev/null | sort || true; }

# Prints a "- `path` — Class1, Class2" line for each file in stdin.
list_with_classes() {
  while read -r f; do
    [ -z "$f" ] && continue
    # Public classes only — private `_Foo` widgets are implementation detail.
    classes=$(grep -oE '^(abstract +)?class +[A-Z][A-Za-z0-9_]*' "$f" 2>/dev/null \
      | sed -E 's/^(abstract )?class +//' | paste -sd',' - | sed 's/,/, /g' || true)
    # Top-level public functions (column-0 anchored, so class members are
    # excluded) — several widgets here expose a `showXxxSheet(...)` and no
    # public class at all.
    fns=$(grep -oE '^[A-Za-z_][A-Za-z0-9_<>, ?]*[ >]+[a-z][A-Za-z0-9_]*\(' "$f" 2>/dev/null \
      | grep -oE '[a-z][A-Za-z0-9_]*\($' | sed 's/($/()/' | sort -u | paste -sd',' - | sed 's/,/, /g' || true)
    api=$(printf '%s' "$classes")
    if [ -n "$fns" ]; then
      api=$([ -n "$api" ] && printf '%s, %s' "$api" "$fns" || printf '%s' "$fns")
    fi
    if [ -n "$api" ]; then
      printf -- '- `%s` — %s\n' "$f" "$api"
    else
      printf -- '- `%s`\n' "$f"
    fi
  done
}

# ----------------------------------------------------------------- render ---

render() {
  local sha count_dart count_test
  sha=$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')
  count_dart=$(find lib -name '*.dart' | wc -l | tr -d ' ')
  count_test=$(find test -name '*_test.dart' 2>/dev/null | wc -l | tr -d ' ')

  cat <<HEADER
<!-- GENERATED FILE — do not edit by hand. Run: bash tool/codemap.sh -->

# Code map

Index of every meaningful file in \`lib/\`, so you can jump straight to the
right one instead of searching. **Read this before opening source files.**

- Generated from commit \`$sha\`
- \`lib/\`: $count_dart Dart files · \`test/\`: $count_test test files
- Regenerate: \`bash tool/codemap.sh\` · Staleness check: \`bash tool/codemap.sh --check\`

Layer rule (see [ARCHITECTURE.md](ARCHITECTURE.md)): \`presentation\` → \`domain/usecases\`
→ \`domain/repositories\` (interface) → \`data/repositories\` (impl) → \`data/datasources\`.
A Cubit never touches a repository or a data source directly.

---

## Entry points

HEADER

  for f in lib/main.dart lib/bootstrap.dart lib/app.dart; do
    [ -f "$f" ] && printf -- '- `%s`\n' "$f"
  done

  # ------------------------------------------------------------- routes ---
  cat <<'ROUTES'

---

## Routes

Declared in `lib/core/router/app_router.dart`; names live in
`lib/core/router/route_names.dart`; the redirect guard is
`lib/core/router/route_guards.dart`.

| Path | Route name | Page widget |
|---|---|---|
ROUTES

  awk -f tool/_routes_extract.awk lib/core/router/app_router.dart

  # ---------------------------------------------------------------- DI ---
  cat <<'DI'

---

## Dependency injection

All wiring is hand-written in `lib/core/di/injection.dart` (no build_runner).
`registerLazySingleton` vs `registerFactory` is a deliberate call per type —
the file's own comments explain each one; read them before changing a lifetime.

### Singletons (`registerLazySingleton`)

DI

  awk -f tool/_di_extract.awk lib/core/di/injection.dart \
    | awk -F'\t' '$1 == "LazySingleton" { print $2 }' | sort -u \
    | sed 's/^/- `/; s/$/`/'

  printf '\n### Factories (`registerFactory`)\n\nA new instance per injection point — screen-scoped state that should reset\non re-entry.\n\n'

  awk -f tool/_di_extract.awk lib/core/di/injection.dart \
    | awk -F'\t' '$1 == "Factory" { print $2 }' | sort -u \
    | sed 's/^/- `/; s/$/`/'

  # ------------------------------------------------------------ features ---
  printf '\n---\n\n## Features\n'

  for dir in $(find lib/features -maxdepth 1 -mindepth 1 -type d | sort); do
    feature=$(basename "$dir")
    printf '\n### %s — `%s`\n' "$(title "$feature")" "$dir"

    for layer in \
      "presentation/bloc:Cubits + States" \
      "presentation/pages:Pages" \
      "presentation/widgets:Widgets" \
      "domain/usecases:Usecases" \
      "domain/entities:Entities" \
      "domain/repositories:Repository interfaces" \
      "data/repositories:Repository implementations" \
      "data/models:Models (JSON ⇄ entity)" \
      "data/datasources:Data sources"
    do
      sub="${layer%%:*}"; label="${layer#*:}"
      found=$(files_in "$dir/$sub" || true)
      [ -z "$found" ] && continue
      printf '\n**%s**\n\n' "$label"
      printf '%s\n' "$found" | list_with_classes
    done
  done

  # ---------------------------------------------------------------- core ---
  cat <<'CORE'

---

## Core (cross-cutting)

CORE

  for dir in $(find lib/core -maxdepth 1 -mindepth 1 -type d | sort); do
    printf '\n**`%s`**\n\n' "$dir"
    files_in "$dir" | list_with_classes
  done

  # -------------------------------------------------------------- shared ---
  printf '\n---\n\n## Shared\n'
  for dir in $(find lib/shared -maxdepth 1 -mindepth 1 -type d | sort); do
    printf '\n**`%s`**\n\n' "$dir"
    files_in "$dir" | list_with_classes
  done

  # --------------------------------------------------------------- tests ---
  printf '\n---\n\n## Tests\n\n'
  find test -name '*.dart' 2>/dev/null | sort | sed 's/^/- `/; s/$/`/'

  printf '\n'
}

# ------------------------------------------------------------------ main ---

if [ "$MODE" = "--check" ]; then
  tmp=$(mktemp)
  render > "$tmp"
  if [ ! -f "$OUT" ] || ! diff -q "$OUT" "$tmp" > /dev/null; then
    echo "STALE: $OUT does not match the source tree. Run: bash tool/codemap.sh" >&2
    rm -f "$tmp"
    exit 1
  fi
  rm -f "$tmp"
  echo "OK: $OUT is current."
else
  render > "$OUT"
  echo "Wrote $OUT ($(wc -l < "$OUT" | tr -d ' ') lines)."
fi
