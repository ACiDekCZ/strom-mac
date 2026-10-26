# Strom Widget

A macOS desktop widget for [Strom](https://stromapp.info) research: what is being worked on right now and what was found
in the last 24 hours. Data stays on the Mac.

## Parts

- **Strom Widget** (`App/`) – host app: list of research on this Mac, how to add the widget, language, uninstall.
  It also opens Strom app addresses when a widget is clicked.
- **Widget** (`Extension/`) – WidgetKit extension, small to extra large, one research per widget.
- **Helper** (`Helper/`) – login item without a window. Watches `~/Library/Application Support/Strom/widget/`
  (written by the research), copies it into the App Group and reloads widgets.
- **Shared** (`Shared/`) – data contract, state logic, texts (cs/en/de) and widget views.

## Build

Requires Xcode 26 and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
xcodegen generate
xcodebuild -project StromWidget.xcodeproj -scheme StromWidget build test
```

Signing is local (personal team). Set `TEST_RUNNER_STROM_SNAPSHOT_DIR=<dir>` to write PNG previews of all widget
sizes and states during tests. `STROM_WIDGET_DIR` overrides the research folder.

Note: an Xcode build registers the built app with Launch Services, so the widget may appear in the widget gallery.

## Authors

Milan Víšek and Claude (Anthropic)
