#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (C) 2026 Milan Víšek
#
# Prints the GitHub release notes of a version: the installation steps (.github/release-install.md),
# then the version's notes from CHANGELOG.md, with the Czech and German notes folded below.
#
#   scripts/release-notes.sh X.Y.Z > notes.md
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:?usage: scripts/release-notes.sh X.Y.Z}"

# The lines of "## VERSION" up to the next "## " heading, without the heading.
section() {
  awk -v v="## $VERSION" '$0 == v { on = 1; next } /^## / { on = 0 } on' "$ROOT/$1" \
    | sed -e '/./,$!d' | sed -e ':a' -e '/^\n*$/{$d;N;ba' -e '}'
}

for f in CHANGELOG.md CHANGELOG.cs.md CHANGELOG.de.md; do
  [ -n "$(section "$f")" ] || { echo "error: $f has no notes for $VERSION" >&2; exit 1; }
done

sed -e "s/Strom-Widget-X\.Y\.Z\.zip/Strom-Widget-$VERSION.zip/g" "$ROOT/.github/release-install.md"
printf '\n## What'"'"'s new in %s\n\n' "$VERSION"
section CHANGELOG.md
printf '\n<details>\n<summary>Česky – co je nového</summary>\n\n'
section CHANGELOG.cs.md
printf '\n</details>\n\n<details>\n<summary>Deutsch – was ist neu</summary>\n\n'
section CHANGELOG.de.md
printf '\n</details>\n'
