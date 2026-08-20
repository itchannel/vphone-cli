/*
 * vphoned_hid — HID event injection via IOKit private API.
 *
 * Matches TrollVNC's STHIDEventGenerator approach: create an
 * IOHIDEventSystemClient, fabricate keyboard events, and dispatch.
 */

#pragma once
#import <Foundation/Foundation.h>

/// Load IOKit symbols and create HID event client. Returns NO on failure.
BOOL vp_hid_load(void);

/// Send a full key press (down + 100ms delay + up).
void vp_hid_press(uint32_t page, uint32_t usage);

/// Send a single key down or key up event.
void vp_hid_key(uint32_t page, uint32_t usage, BOOL down);

/// Inject a single-finger digitizer touch event.
/// phase: 0 = down, 1 = move, 3 = up. x/y are normalized 0..1 with the
/// origin at the top-left. Used for iOS 18 bases where the VZ USB touchscreen
/// dext produces no digitizer events on the 26.x kernel.
void vp_hid_touch(int phase, double x, double y);

/// Inject a synthetic accelerometer reading to drive device orientation.
/// The VM has no real motion sensor, so SpringBoard/UIKit never autorotate on
/// their own; feeding a gravity vector through the HID event system is what a
/// physical device's accelerometer does. `orientation` uses UIDeviceOrientation
/// values: 1 = portrait, 2 = portrait upside-down, 3 = landscape-left,
/// 4 = landscape-right.
/// Returns: 0 = dispatched, -1 = accelerometer symbol unavailable,
/// -2 = event creation returned NULL, -3 = unknown orientation value.
int vp_hid_orientation(int orientation);
