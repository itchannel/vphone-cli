# Screen Orientation & Rotation — Working Notes / Handoff

Status doc for the `feature/screen-orientation` branch. Captures the goal, what
was tried, what works, and what's left. Written for a fresh session picking this
up on the Mac (where it can actually build/test — the prior session was on
Windows and could not run `make`).

## Goal

User runs iPad apps in the iPhone VM and they render **on their side** (and
partly cut off). They want them shown **upright** and the window **resizable**.
Original framing was "boot an iPad / change rotation" — see the caveat at the
bottom on why a true iPad isn't achievable here.

## Repo / branch state

- Branch: `feature/screen-orientation`.
- Remotes: `origin` = `git@github.com:itchannel/vphone-cli.git` (the user's
  fork), `upstream` = `Lakr233/vphone-cli`.
- Toolchain note: the user's Mac is on **Swift 6.0**, while upstream used some
  Swift 6.1 syntax. Early commits on this branch fix build breakers on 6.0
  (trailing commas in call arg lists; redundant `try`; unused binding).

## What was tried (in order) and the result

### 1. Guest autorotation via HID accelerometer *event* injection — FAILED
`vp_hid_orientation()` in `scripts/vphoned/vphoned_hid.m` dispatches an
`IOHIDEventCreateAccelerometerEvent` through the existing
`IOHIDEventSystemClient`. It dispatches cleanly (`code 0`) but **iOS ignores
it** — nothing consumes it. Kept as a fallback path; not effective.

### 2. Virtual HID accelerometer via `IOHIDUserDevice` — FAILED (dead end)
`scripts/vphoned/vphoned_accel.{h,m}` creates a kernel-backed virtual
accelerometer (HID Sensor page 0x20 / usage 0x73, 3×int16 axes) and streams a
gravity vector at 20 Hz. Entitlements added: `com.apple.developer.hid.virtual.device`
and `IOHIDResourceDeviceUserClient` (in `scripts/vphoned/entitlements.plist`).

- The device **is created** (`virtual accel active: yes`).
- But `CMMotionManager.accelerometerAvailable` stays **no** — iOS's motion
  stack does **not** bind to a fabricated HID-sensor accelerometer, so no device
  orientation is ever computed. Confirmed by the `vp_accel_available()` probe.
- Conclusion: the sensor path can't drive autorotation here. This code is
  **parked** — it could be deleted, but is left as documentation of the attempt.

The `orient` vsock command (host `VPhoneControl.sendOrientation`, guest handler
in `vphoned.m`) reports `method` / `virtual_accel_active` / `accel_available`
back to the host terminal for diagnostics.

### 3. Host-side display rotation — THIS IS THE WORKING APPROACH
Because the iPad app already lays out in landscape and the problem is that the
*host window* shows that landscape framebuffer sideways in a portrait window,
the fix is pure host-side presentation. No guest involvement.

Implemented:
- `VPhoneVirtualMachineView`: `displayRotation` (0/90/180/270) applied via the
  `frameRotation` property (NOT `setFrameCenterRotation` — that isn't bridged
  into Swift). Touches stay correct because AppKit coordinate conversion honors
  `frameRotation`. Origin is computed so the view stays centered after rotation.
- `VPhoneWindowController`: hosts the VM view inside a **container** contentView,
  is the `NSWindowDelegate`, relayouts on resize, resizes the window via
  `setFrame`/`frameRect(forContentRect:)` on rotation, and swaps
  `contentAspectRatio` so resizing keeps the rotated proportions.
- `VPhoneMenuDisplay.swift`: new **Display** menu — Rotate Left / Right / 180 /
  Reset. Wired through `VPhoneMenuController.captureView`.

Confirmed on-device: **rotation works and the Metal content does rotate**
(cleared the main risk). Touches confirmed correct.

## Bugs found & fixed during testing (all on-device)

1. `setContentSize` didn't reliably resize the window → half the content clipped
   when rotated. Fixed by resizing the window frame explicitly with `setFrame`.
2. Wrapping the VM view in a container regressed the **portrait** case: the view
   kept a fixed frame while the window opened at a restored autosave size, so it
   didn't fill the window and was cropped even with no rotation. Fixed by giving
   the VM view `autoresizingMask = [.width, .height]` at rotation 0 (rotation
   turns it off and manages the frame manually). **This was the last fix pushed;
   verify portrait is edge-to-edge complete first thing.**

## Where things stand / next steps

1. **Verify portrait is complete** after the autoresizing fix (commit `20d777d`).
   That must be right before judging rotation.
2. **If a rotated view still clips one edge**: it's the `frameRotation` origin
   math in `layoutRotatedFrame` (VPhoneVirtualMachineView). Find out which edge
   and by how much, nudge the origin. Rotation *direction* (L vs R) is a one-line
   sign flip in `VPhoneMenuDisplay.swift`.
3. **iPad app content cropped (separate issue #2)**: the guest framebuffer is a
   portrait iPhone (`1290×2796`, ~0.46:1). An iPad landscape app expects ~4:3.
   Fix by setting an **iPad-shaped `screenConfig`** in the VM's `config.plist`
   (e.g. iPad Pro 12.9" `2048×2732 @ 264ppi scale 2.0`, or 11" `1668×2388`).
   Takes effect next boot. NOT done yet — needs the user's VM dir.
   Symptom split: if iOS status bar / home indicator are fully visible and only
   the app's inner content is cropped → it's this aspect issue, not rotation.

## Build / test

- Host-only changes (rotation, menus, `VPhoneControl`): `make build`.
- Guest changes (`vphoned*`, entitlements): need the daemon rebuilt+signed;
  `make boot` does both and vphoned auto-updates into the VM on connect.
  Requires `ldid` (`brew install ldid-procursus`), macOS 15+, SIP/AMFI off.
- User is on the **jailbroken** variant.

## Caveat: a true iPad isn't achievable here

The VM's hardware identity is a fixed research **iPhone** model
(`VPhoneHardware.createModel()` — PV=3, boardID 0x90, matches `vresearch101`),
and the firmware pipeline builds iPhone firmware. An iPad-shaped `screenConfig`
fixes canvas proportions so apps stop cropping, but iOS's device *idiom* stays
iPhone. Booting an actual iPad would need different firmware + hardware model
that this project doesn't ship.

## Key files

- `sources/vphone-cli/VPhoneVirtualMachineView.swift` — rotation state + layout.
- `sources/vphone-cli/VPhoneWindowController.swift` — container, resize, delegate.
- `sources/vphone-cli/VPhoneMenuDisplay.swift` — Display menu (rotate actions).
- `sources/vphone-cli/VPhoneMenuController.swift` — menu assembly.
- `sources/vphone-cli/VPhoneControl.swift` — `sendOrientation` (guest path, parked).
- `scripts/vphoned/vphoned_accel.{h,m}` — virtual accelerometer (parked, ineffective).
- `scripts/vphoned/vphoned_hid.{h,m}` — HID event injection + CoreMotion probe.
- `scripts/vphoned/vphoned.m` — `orient` command dispatch.
- `scripts/vphoned/entitlements.plist` — added virtual-HID entitlements.
