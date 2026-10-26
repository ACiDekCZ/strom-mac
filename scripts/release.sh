#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (C) 2026 Milan Víšek
#
# Builds the release of the version in VERSION on the maintainer's Mac, signed with the
# "Apple Development" certificate of team TKYS4BYH6B from the login keychain (the certificate
# never leaves it), and packages Strom-Widget-X.Y.Z.zip with SHA256SUMS (see RELEASING.md).
#
#   scripts/release.sh [output-dir]       default: build/release (ignored by git)
#
# Refuses to run unless the working tree is clean, HEAD carries the tag vX.Y.Z of VERSION and all
# three changelogs have notes for the version. The built products are unregistered from Launch
# Services afterwards, so the release build never shows up in the widget gallery of this Mac.
set -euo pipefail

TEAM=TKYS4BYH6B
IDENTITY="Apple Development"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
TAG="v$VERSION"
OUT="${1:-$ROOT/build/release}"
ARTIFACT="Strom-Widget-$VERSION.zip"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

fail() { echo "error: $*" >&2; exit 1; }

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "VERSION ($VERSION) is not X.Y.Z"
for f in CHANGELOG.md CHANGELOG.cs.md CHANGELOG.de.md; do
  grep -qx "## $VERSION" "$ROOT/$f" || fail "$f has no notes for $VERSION"
done
[ -z "$(git -C "$ROOT" status --porcelain)" ] || fail "the working tree is not clean"
TAGGED="$(git -C "$ROOT" rev-parse -q --verify "refs/tags/$TAG^{commit}")" || fail "no tag $TAG"
[ "$TAGGED" = "$(git -C "$ROOT" rev-parse HEAD)" ] || fail "HEAD is not the commit of $TAG"
security find-identity -v -p codesigning | grep -q "\"$IDENTITY: " \
  || fail "no \"$IDENTITY\" certificate in the keychain"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/strom-widget-release.XXXXXX")"
ARCHIVE="$WORK/StromWidget.xcarchive"
APP="$ARCHIVE/Products/Applications/Strom Widget.app"

# Xcode registers every built app with Launch Services; take the products back out, whatever happens.
unregister() {
  local p
  for p in "$WORK"/DerivedData/Build/Products/*/*.app "$WORK"/DerivedData/Build/Intermediates.noindex/ArchiveIntermediates/*/*/*.app \
           "$APP" "$APP/Contents/Library/LoginItems/"*.app "$APP/Contents/PlugIns/"*.appex; do
    [ -e "$p" ] && "$LSREGISTER" -u "$p" 2>/dev/null || true
  done
  rm -rf "$WORK"
}
trap unregister EXIT

echo "== Archive $VERSION ($TAG, $(git -C "$ROOT" rev-parse --short HEAD))"
set -o pipefail
xcodebuild -project "$ROOT/StromWidget.xcodeproj" -scheme StromWidget -configuration Release \
  -derivedDataPath "$WORK/DerivedData" -archivePath "$ARCHIVE" \
  DEVELOPMENT_TEAM="$TEAM" CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$IDENTITY" \
  MARKETING_VERSION="$VERSION" \
  archive 2>&1 | tee "$WORK/build.log" | grep -E '^(\*\*|.*(error|warning):)' || true
grep -q '\*\* ARCHIVE SUCCEEDED \*\*' "$WORK/build.log" || { tail -n 80 "$WORK/build.log"; fail "archive failed"; }

echo "== Verify signature"
codesign --verify --deep --strict --verbose=2 "$APP"
INFO="$(codesign -dv --verbose=4 "$APP" 2>&1)"
grep -q "^TeamIdentifier=$TEAM$" <<<"$INFO" || fail "not signed by team $TEAM"
grep -q "^Authority=$IDENTITY: " <<<"$INFO" || fail "not signed with $IDENTITY"
for part in "$APP/Contents/PlugIns/StromWidgetExtension.appex" "$APP/Contents/Library/LoginItems/StromWidgetHelper.app"; do
  [ -d "$part" ] || fail "missing $(basename "$part")"
  codesign -d --entitlements - "$part" 2>/dev/null | grep -q "$TEAM.info.stromapp.widget" \
    || fail "$(basename "$part") lacks the App Group"
done
PLIST_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
[ "$PLIST_VERSION" = "$VERSION" ] || fail "the app says $PLIST_VERSION, not $VERSION"

echo "== Package"
mkdir -p "$OUT"
rm -f "$OUT/$ARTIFACT" "$OUT/SHA256SUMS"
ditto -c -k --keepParent "$APP" "$OUT/$ARTIFACT"
(cd "$OUT" && shasum -a 256 "$ARTIFACT" > SHA256SUMS)
"$ROOT/scripts/release-notes.sh" "$VERSION" > "$OUT/release-notes.md"

echo "Done: $OUT/$ARTIFACT, SHA256SUMS, release-notes.md"
cat "$OUT/SHA256SUMS"
