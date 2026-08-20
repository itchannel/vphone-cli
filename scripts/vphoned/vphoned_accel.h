/*
 * vphoned_accel — Virtual HID accelerometer via IOHIDUserDevice.
 *
 * The VM exposes no motion sensor, so CoreMotion/backboardd never compute a
 * device orientation and injected accelerometer *events* have no consumer
 * (see vphoned_hid's vp_hid_orientation, which dispatches but is ignored).
 *
 * This creates a kernel-backed virtual accelerometer that iOS enumerates like
 * real hardware. Once backboardd subscribes to it, streaming a gravity vector
 * drives normal UIKit autorotation for every app.
 */

#pragma once
#import <Foundation/Foundation.h>

/// Create the virtual HID accelerometer and start streaming its current vector.
/// Call once at startup. Returns YES if the IOHIDUserDevice was created.
BOOL vp_accel_create(void);

/// Whether the virtual accelerometer device was successfully created.
BOOL vp_accel_active(void);

/// Aim the streamed gravity vector at a UIDeviceOrientation: 1 = portrait,
/// 2 = portrait upside-down, 3 = landscape-left, 4 = landscape-right.
/// Returns YES if applied (device active and orientation known). The vector is
/// streamed continuously so backboardd's orientation filter settles on it.
BOOL vp_accel_set_orientation(int orientation);
