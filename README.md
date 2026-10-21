# Snapper

A native macOS menu bar app for snapping windows into custom zones, with a
layout remembered for each display.

- Hold **Shift** while dragging a window to reveal its display's zones. Release
  the mouse over a zone to snap; release Shift to cancel.
- Use the menu bar to choose a layout for each display, turn a display's zones
  off, or pause Snapper.
- Switch between home and work monitors: each restores its selected layout,
  including after restarting the app.

Requires macOS 14 or later. Enable Snapper in **System Settings → Privacy &
Security → Accessibility** so it can move and resize windows.

## Install

```sh
brew install --cask nikhilweee/tap/snapper
```

Then launch Snapper from /Applications. The app is ad-hoc signed (no Apple
Developer account); the cask clears the quarantine flag after install so
Gatekeeper doesn't block the first launch.

## Configuration

Choose **Open Configuration** from the menu to edit
`~/Library/Application Support/Snapper/config.json`, then **Reload
Configuration** to apply changes. A starter configuration is created on first
launch.

Each layout and zone has an `id` and a `name`. Zone coordinates are percentages
of the usable desktop, measured from the top-left, excluding the menu bar and
Dock. For example, this zone occupies the left half:

```json
{ "id": "left", "name": "Editor", "x": 0, "y": 0, "width": 50, "height": 100 }
```

## Build from source

Requires full Xcode with Swift 6 or later. No third-party dependencies.

```sh
./build.sh
open build/Snapper.app
```

Produces an ad hoc signed `build/Snapper.app` and `build/Snapper.zip`. Use
`./build.sh --universal` for both Apple Silicon and Intel, and `swift test` to
run the tests. Quit the running app before rebuilding; if Accessibility access
stops working afterward, remove and re-add the built app in Accessibility
settings.

See the [release checklist](docs/releasing.md) and
[manual checks](docs/manual-testing.md).
