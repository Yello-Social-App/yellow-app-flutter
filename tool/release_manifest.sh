#!/usr/bin/env bash
# Writes the `latest.json` the in-app updater reads (ADR-029).
#
# Yello is sideloaded, so "is there a newer build?" is answered by a manifest
# published beside each release's APK rather than by the API. The app fetches
# it from AppConfig.updateManifestUrl, which is GitHub's permanent
# `releases/latest/download/latest.json` redirect — so this file is an asset
# on the release, next to the APK itself.
#
#   bash tool/release_manifest.sh                       # notes from CHANGELOG
#   bash tool/release_manifest.sh "Faster feed."        # notes given here
#
# Version and build number come from pubspec.yaml, size from the built APK,
# so the manifest cannot disagree with what it is describing.
#
# Then, for a release tagged v<version>:
#   gh release create v<version> <apk> build/latest.json --title "v<version>"
#
# Pure bash on purpose, like tool/codemap.sh: no Dart/Flutter SDK needed.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

REPO="Yello-Social-App/yellow-app-flutter"
APK="build/app/outputs/flutter-apk/app-release.apk"
OUT="build/latest.json"

# `version: 0.3.0+2` -> 0.3.0 and 2.
VERSION_LINE="$(grep -m1 '^version:' pubspec.yaml | sed 's/^version:[[:space:]]*//')"
VERSION="${VERSION_LINE%%+*}"
BUILD="${VERSION_LINE##*+}"

if [[ -z "$VERSION" || -z "$BUILD" || "$VERSION" == "$VERSION_LINE" ]]; then
  echo "error: pubspec.yaml's version must be <semver>+<build>, got '$VERSION_LINE'" >&2
  exit 1
fi

if [[ ! -f "$APK" ]]; then
  echo "error: $APK not found — run 'flutter build apk --release' first." >&2
  exit 1
fi

# The APK the updater downloads is renamed per version, so two releases'
# assets can never be confused for each other.
APK_NAME="yello-$VERSION.apk"
SIZE="$(wc -c < "$APK" | tr -d '[:space:]')"

# Release notes: whatever was passed in, else this version's first
# CHANGELOG bullet, stripped of Markdown and folded onto one line. It is
# body text on a card in the app, not the changelog itself, so it is capped
# rather than pasted whole.
NOTES="${1:-}"
if [[ -z "$NOTES" ]]; then
  NOTES="$(awk -v v="## [$VERSION]" '
    index($0, v) == 1 { inver = 1; next }
    inver && index($0, "## [") == 1 { exit }
    # The first bullet of the section, which wraps over several lines and
    # ends where the next bullet begins.
    inver && /^- / { if (inbullet) exit; inbullet = 1; sub(/^- /, "") }
    inbullet && /^[[:space:]]*$/ { exit }
    inbullet { gsub(/^[[:space:]]+/, ""); gsub(/\*\*/, ""); gsub(/`/, ""); printf "%s%s", sep, $0; sep = " " }
  ' CHANGELOG.md)"
fi

MAX_NOTES=220
if (( ${#NOTES} > MAX_NOTES )); then
  # Cut at the last sentence end that fits, so the card never trails off
  # mid-clause; fall back to a hard cut when there is no full stop.
  SHORT="${NOTES:0:$MAX_NOTES}"
  if [[ "$SHORT" == *". "* ]]; then
    NOTES="${SHORT%". "*}."
  else
    NOTES="${SHORT% *}…"
  fi
fi

# JSON-escape the two characters that can appear in a release note.
NOTES="${NOTES//\\/\\\\}"
NOTES="${NOTES//\"/\\\"}"

mkdir -p "$(dirname "$OUT")"
cat > "$OUT" <<JSON
{
  "version": "$VERSION",
  "buildNumber": $BUILD,
  "notes": "$NOTES",
  "apkUrl": "https://github.com/$REPO/releases/download/v$VERSION/$APK_NAME",
  "sizeBytes": $SIZE
}
JSON

echo "Wrote $OUT for v$VERSION (build $BUILD, $((SIZE / 1024 / 1024)) MB)."
echo "Upload the APK as '$APK_NAME' — the url above is what the app downloads:"
echo "  cp $APK build/$APK_NAME"
echo "  gh release create v$VERSION build/$APK_NAME $OUT --title \"v$VERSION\""
