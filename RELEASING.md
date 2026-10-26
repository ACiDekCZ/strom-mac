# Releasing a new version

Releases are built and signed on the maintainer's Mac, not in GitHub Actions: the widget, the host app and the
helper share an App Group (`TKYS4BYH6B.info.stromapp.widget`), and macOS lets them use it without asking only when
the signature carries the same team ID. The "Apple Development" certificate of team TKYS4BYH6B stays in the login
keychain; no certificate goes into repository secrets.

## Procedure

1. Raise the version in `VERSION` and `MARKETING_VERSION` (`project.yml`, then `xcodegen generate`), and add the
   notes under `## X.Y.Z` to `CHANGELOG.md`, `CHANGELOG.cs.md` and `CHANGELOG.de.md`.
2. Commit, push `main` and wait for green CI (`gh run watch`).
3. Tag the commit and push the tag:

   ```sh
   git tag -a "v$(cat VERSION)" -m "Strom Widget $(cat VERSION)"
   git push origin "v$(cat VERSION)"
   ```

4. Build, sign and package:

   ```sh
   scripts/release.sh
   ```

   It refuses a dirty working tree, a HEAD without the tag of `VERSION` or a changelog without notes for the
   version. It archives the Release build signed with "Apple Development" (team TKYS4BYH6B), checks the signature
   (`codesign --verify --deep --strict`, team ID, App Group of the widget and the helper, version in `Info.plist`)
   and writes to `build/release/`: `Strom-Widget-X.Y.Z.zip` (`ditto --keepParent`), `SHA256SUMS` and
   `release-notes.md` (installation steps from `.github/release-install.md`, then the notes in English with Czech
   and German folded below, `scripts/release-notes.sh`). The built products are unregistered from Launch Services,
   so the release build does not appear in the widget gallery of the Mac.
   If the keychain asks for access to the signing key, allow it for `codesign`.

5. Publish:

   ```sh
   V=$(cat VERSION)
   gh release create "v$V" "build/release/Strom-Widget-$V.zip" build/release/SHA256SUMS \
     --title "Strom Widget $V" --notes-file build/release/release-notes.md
   ```

6. Check the published files:

   ```sh
   D=$(mktemp -d); gh release download "v$V" --dir "$D"
   (cd "$D" && shasum -a 256 -c SHA256SUMS && ditto -x -k "Strom-Widget-$V.zip" .)
   codesign --verify --deep --strict "$D/Strom Widget.app" && codesign -dv --verbose=4 "$D/Strom Widget.app"
   ```

Versions follow [Semantic Versioning](https://semver.org/): before 1.0, `0.MINOR.PATCH`.

## Signing

- The release is signed with "Apple Development", **not notarized**: on first start macOS blocks it once and it is
  allowed in *System Settings → Privacy & Security → Open Anyway* (steps at the top of every release's notes).
- **The certificate is valid for one year.** Apps signed with it keep working after it expires, but a new release
  needs a renewed certificate (Xcode → Settings → Accounts → Manage Certificates). The team ID stays the same, so the
  App Group and the widget's settings carry over.
- A self-signed certificate would not do: it has no team ID, so macOS 15 and later ask before every start whether
  the app may use the App Group, and the widget extension cannot ask at all.
- With a Developer ID (Apple Developer Program) the same build can be notarized and the "Open Anyway" step goes away.

## One-time GitHub settings

`scripts/github-setup.sh` sets the description, homepage, topics and private vulnerability reporting.
