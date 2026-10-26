#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Copyright (C) 2026 Milan Víšek
#
# One-time GitHub settings for the repository (run by the maintainer after the first push, with
# `gh auth login` done). Safe to run again: every call sets the same state. No secrets: releases
# are built and signed on the maintainer's Mac (RELEASING.md).
#
#   scripts/github-setup.sh [owner/repo]
set -euo pipefail
REPO="${1:-ACiDekCZ/strom-mac}"

echo "== Repository settings"
gh repo edit "$REPO" \
  --description "macOS desktop widget for Strom family history research: what the research works on, what it found and what waits. The data stays on the Mac." \
  --homepage "https://stromapp.info" \
  --enable-issues --enable-wiki=false --enable-projects=false \
  --add-topic macos --add-topic widget --add-topic widgetkit --add-topic swiftui --add-topic swift \
  --add-topic desktop-widget --add-topic genealogy --add-topic family-tree --add-topic family-history \
  --add-topic ai-agent --add-topic offline-first

echo "== Private vulnerability reporting (SECURITY.md)"
gh api -X PUT "repos/$REPO/private-vulnerability-reporting" >/dev/null

echo "Done: https://github.com/$REPO"
