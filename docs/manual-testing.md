# Manual acceptance checklist

Run `swift test`, then run the release bundle from a consistent location on a logged-in Mac. These checks require actual desktop interaction; passing the automated checks does not establish them.

## Permission and app lifecycle

- [ ] Finder shows Snapper's custom application icon; the first-launch permission prompt uses it too.
- [ ] **About Snapper** opens the native About panel with the app icon, version/build from the bundle, and a clickable GitHub link. Opening it again reuses the panel and brings it forward.
- [ ] The menu bar icon shows the app icon's three-zone motif clearly on Retina/non-Retina displays and adapts to light/dark menu bars.
- [ ] The permission prompt is concise and **Open Settings** opens Accessibility settings directly, without an additional permission alert requested by Snapper. If Snapper is absent, add the built app using the **+** button.
- [ ] Launch with no Accessibility grant: menu icon appears, there is no Dock icon, onboarding explains permission, and snapping stays disabled.
- [ ] Decline onboarding: configuration and menu controls remain usable.
- [ ] Grant permission: snapping becomes available without relaunching.
- [ ] The Accessibility menu item appears only while permission is missing; after granting access, reopening the menu hides it.
- [ ] Revoke permission during a Shift-drag: overlays clear and no subsequent snap occurs.
- [ ] Pause during a gesture: overlays clear; enabling again allows the next drag.
- [ ] Quit: overlays disappear and no event monitors remain.

## Real window dragging

Repeat with Finder, Safari, and Terminal; include a third-party/Electron app when available.

- [ ] Drag with Shift held from mouse-down: zones appear only after the window moves.
- [ ] Press Shift midway through a drag: zones appear and track pointer selection.
- [ ] Release Shift while continuing to drag: overlays disappear; mouse release does not snap.
- [ ] Release the mouse over a zone with Shift held: the window matches that zone (subject to app constraints).
- [ ] Release outside every zone: no snap occurs.
- [ ] Start another drag immediately after dropping a window, and after pausing/re-enabling: delayed work from the previous gesture must not revive overlays or move a window.
- [ ] Select text, drag a file, drag a scrollbar, and resize from all edges/corners: no zone preview or snap.
- [ ] Minimized, fullscreen, fixed-size, dialog, and inaccessible windows are skipped.
- [ ] Close/terminate a target during dragging: overlays clear without a crash.
- [ ] Click through the translucent overlay: the target app keeps receiving input and focus stays with it.
- [ ] Test an app minimum size larger than a zone: at most two attempts, no loop, and a useful menu issue.
- [ ] Check behavior with macOS edge tiling on/off and record any conflict.

## Display memory and geometry

- [ ] Select Two Columns for home, Three Columns for work; disconnect home, connect work, reconnect home: each remembers its choice.
- [ ] Quit/relaunch between reconnects: choices remain intact.
- [ ] Connect both displays; drag between them with Shift held: each shows its own layout.
- [ ] Select Off for one display, reconnect/relaunch: it remains off while the other still works.
- [ ] Rearrange displays left/right/above/below primary, including negative coordinates: previews and window frames align.
- [ ] Mix Retina/non-Retina displays, then change resolution/scaling/rotation: logical geometry stays aligned.
- [ ] Move/autohide the Dock and menu bar: new gestures respect the current usable desktop.
- [ ] Enable mirroring: only one logical desktop is shown.
- [ ] Disconnect a target display during dragging, change Space, lock the session, or sleep/wake: pending gesture cancels without moving a different window.

## Configuration and idle behavior

- [ ] Give a zone a `name` different from its `id`: the overlay displays its name, and hit testing still selects the same zone.
- [ ] Use a long zone name in a narrow zone: the label stays inside that zone.
- [ ] Zone labels have padded, rounded system-material backgrounds: Liquid Glass on macOS 26+ with a recent SDK, and translucent HUD material on older systems. Check light/dark appearances, bright/busy windows, Reduce Transparency, and Increase Contrast.
- [ ] Remove a zone's `name` and reload: the configuration is rejected and previous layouts remain active.
- [ ] Switch between layouts with different zone positions: only the selected layout's zones appear, with one stronger highlight under the pointer.
- [ ] Edit valid JSON and reload: menu choices and zones update.
- [ ] Reload malformed or invalid JSON: previous layouts still work; an actionable error is shown.
- [ ] Remove the selected layout: default is used; restore the same ID: saved layout returns.
- [ ] Verify a menu selection changes state.json without rewriting config.json.
- [ ] Leave Snapper idle and inspect Activity Monitor/Instruments: no window-frame sampling or overlays; only the permission timer wakes periodically.
- [ ] Rebuild/relaunch the ad hoc app: confirm whether Accessibility needs regranting and document the result.

Record macOS version, app versions, display models, adapter/dock, and any failed case. Do not mark physical reconnect or real Accessibility behavior as validated by mock tests alone.
