# Duo Demo — design brief

A tiny SwiftUI demo app for the iPhone Duo (Apple's foldable, iOS 27.1). It exists to show
what an app can *know* about where it lives on a foldable, and how two windows of the same
app can talk to each other when placed side by side on the inner display.

## What it must do

- Work on every Duo configuration: cover (outside) display, inner display, portrait and
  landscape, full-width and each half of a split.
- Support running twice (two window scenes) so one copy can sit on the left half and one on
  the right half of the inner display.
- **Position tab**: big words saying where this window is: OUTSIDE / INSIDE, and LEFT / RIGHT
  (or TOP / BOTTOM) when it occupies half the display.
- **Sync tab**: controls kept in sync between the two windows (a segmented picker, a colour
  and a slider), one toggle that is always the *inverse* of the other side, a "ping" that
  flashes the other window, and a way to send the other window to a specific tab.
- A plain tab bar; nothing fancy in it.

## What else the app shows (things Apple doesn't hand you directly, but you can derive)

- **Hinge**: live status (closed / partially open / fully open) and angle from
  `UIHingeInteraction`, drawn as a gauge. When the hinge is partially open and the crease is
  horizontal, the Hinge tab lays itself out "laptop style" around the crease.
- **Crease and cut-outs**: `UIView.reservedRegions(kind: .division)` gives the crease,
  `.occlusion` gives camera cut-outs. The Layout tab can overlay them on the whole window, tells
  you which side of the crease this window sits on, and which side of the crease you tapped.
- **Vertical bar**: the new `verticalBarEdge` trait (iOS 27.1) says whether the system moved the
  tab bar to the leading or trailing edge.
- **Fold counter**: how many times this window transitioned between cover and inner panels.
- **Outside while the inside is open**: a `CameraCaptureAccessory` scene on the cover display
  while the Camera tab has a running capture session. Mirrored preview, countdown, message,
  post-shot review and tap-to-shoot for the subject. Its probe reports the panel as
  `coverWhileOpen` (open hinge but a 466 × 678 screen).

## How position is derived

1. `UIHingeInteraction` tells us whether there is a hinge at all and whether it is closed.
   Closed → OUTSIDE (cover display). Open → INSIDE. No hinge → "single screen" (plain iPhone).
   The screen's point size is used as a cross-check.
2. The window's size against the screen's size says whether it is a half (narrower → horizontal
   split, shorter → vertical split). A scene's window is always at (0, 0) in its own coordinate
   space, so the frame alone cannot say *which* half. For that, in order:
   - the crease: `reservedRegions(kind: .division, options: [.includeInactive])` reports the
     crease on the window edge that faces the hinge (`x = 456` in a 469-wide left window,
     `x = 0` in the right one);
   - the `verticalBarEdge` trait: the system puts the tab bar on the edge away from the crease,
     so `leading` means left and `trailing` means right (in a left-to-right layout);
   - the frame's centre, as a last resort.
3. Safe-area insets, interface orientation and size classes are reported alongside.

## Architecture

- `SharedStore` (one per process, `@Observable`): everything the two windows share, plus a
  registry of every live window's latest `WindowSnapshot`.
- `DuoEnvironment` (one per window, `@Observable`): that window's snapshot and UI toggles.
- `WindowProbe`: a `UIViewRepresentable` sitting behind the root view. Its `UIView` installs the
  hinge interaction, registers for vertical-bar trait changes, and recomputes the snapshot on
  layout, safe-area and trait changes. It is the only UIKit code.
- Tabs are plain SwiftUI views reading the two observables.

Two windows of one iOS app are two `UIWindowScene`s in the same process, so the shared store is
an in-memory singleton; no IPC needed.

## Testing

Built with `xcodegen` + `xcodebuild`, run on the `iPhone Duo` simulator (iOS 27.1) and driven
with `agent-device` (`agent-device fold closed|half-open|open` switches panels).
