# duo-demo

A tiny SwiftUI demo for the **iPhone Duo** (iOS 27.1) showing what an app can figure out about
where it is on a foldable, and how two windows of the same app can talk to each other.

## What's in it

| Tab | What it shows |
| --- | --- |
| **Position** | Big words: `OUTSIDE` / `INSIDE`, plus `LEFT` / `RIGHT` (or `TOP` / `BOTTOM`) when the window is one half of a split. Derived from `UIHingeInteraction` + the window's frame in screen space. |
| **Sync** | A segmented picker, colour and slider kept in sync across both windows; a toggle that is always the inverse of the other side; ping the other window; send the other window to a tab. |
| **Hinge** | Live hinge status and angle (`UIHinge`), drawn as a gauge. Partially open + horizontal crease → laptop-style layout split on the crease. |
| **Layout** | Crease and camera cut-outs via `UIView.reservedRegions(kind:)`, overlaid on the window; which side of the crease you're on; which side you tapped; `verticalBarEdge` trait; safe areas; size classes. |
| **About** | Which API backs each trick. |

## Run it

```sh
brew install xcodegen   # once
xcodegen generate
open DuoDemo.xcodeproj  # pick the "iPhone Duo" simulator, run
```

Then open the app a second time (from the Sync tab's "Open another window" button, or the
system multitasking UI) and drop the two copies on the left and right halves of the inner display.

Requires Xcode 27.1 (iOS 27.1 SDK, iPhone Duo simulator).
