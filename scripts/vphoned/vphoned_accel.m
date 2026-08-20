#import "vphoned_accel.h"
#include <dlfcn.h>

// IOHIDUserDevice — user-space virtual HID device, resolved lazily from IOKit.
typedef struct __IOHIDUserDevice *IOHIDUserDeviceRef;

static IOHIDUserDeviceRef (*pUDCreate)(CFAllocatorRef, CFDictionaryRef);
static int (*pUDHandleReport)(IOHIDUserDeviceRef, const uint8_t *, CFIndex);
static void (*pUDScheduleQ)(IOHIDUserDeviceRef, dispatch_queue_t);

static IOHIDUserDeviceRef gDevice;
static dispatch_queue_t gQueue;
static dispatch_source_t gTimer;
static int16_t gX, gY, gZ;
static BOOL gActive;

// int16 logical units representing 1g. Half of the ±32767 range for headroom.
#define VP_G_ONE 16384

// HID Sensor accelerometer report descriptor: Report ID 1, three signed 16-bit
// acceleration axes (X/Y/Z). Usage Page 0x20 (Sensor), Usage 0x73
// (Motion: Accelerometer 3D); data-field usages 0x0453/0x0454/0x0455.
static const uint8_t kAccelDescriptor[] = {
    0x05, 0x20,        // Usage Page (Sensor)
    0x09, 0x73,        // Usage (Motion: Accelerometer 3D)
    0xA1, 0x01,        // Collection (Application)
    0x85, 0x01,        //   Report ID (1)
    0x05, 0x20,        //   Usage Page (Sensor)
    0x0A, 0x53, 0x04,  //   Usage (Accel Axis X)
    0x0A, 0x54, 0x04,  //   Usage (Accel Axis Y)
    0x0A, 0x55, 0x04,  //   Usage (Accel Axis Z)
    0x16, 0x01, 0x80,  //   Logical Minimum (-32767)
    0x26, 0xFF, 0x7F,  //   Logical Maximum (32767)
    0x75, 0x10,        //   Report Size (16)
    0x95, 0x03,        //   Report Count (3)
    0x81, 0x02,        //   Input (Data,Var,Abs)
    0xC0,              // End Collection
};

typedef struct __attribute__((packed)) {
    uint8_t reportID;
    int16_t x;
    int16_t y;
    int16_t z;
} VPAccelReport;

static void vp_accel_send(void) {
    if (!gDevice || !pUDHandleReport) return;
    VPAccelReport rep = {.reportID = 1, .x = gX, .y = gY, .z = gZ};
    pUDHandleReport(gDevice, (const uint8_t *)&rep, sizeof(rep));
}

BOOL vp_accel_create(void) {
    void *h = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW);
    if (!h) {
        NSLog(@"vphoned: accel dlopen IOKit failed");
        return NO;
    }

    pUDCreate = dlsym(h, "IOHIDUserDeviceCreate");
    pUDHandleReport = dlsym(h, "IOHIDUserDeviceHandleReport");
    pUDScheduleQ = dlsym(h, "IOHIDUserDeviceScheduleWithDispatchQueue");

    if (!pUDCreate || !pUDHandleReport) {
        NSLog(@"vphoned: IOHIDUserDevice symbols missing, virtual accel disabled");
        return NO;
    }

    NSData *desc = [NSData dataWithBytes:kAccelDescriptor length:sizeof(kAccelDescriptor)];
    NSDictionary *props = @{
        @"ReportDescriptor" : desc,   // kIOHIDReportDescriptorKey
        @"VendorID" : @(0x05AC),      // Apple
        @"ProductID" : @(0x7654),
        @"Product" : @"vphone Virtual Accelerometer",
        @"Manufacturer" : @"vphone",
        @"PrimaryUsagePage" : @(0x20),  // Sensor
        @"PrimaryUsage" : @(0x73),      // Accelerometer 3D
        @"Transport" : @"Virtual",
    };

    gDevice = pUDCreate(kCFAllocatorDefault, (__bridge CFDictionaryRef)props);
    if (!gDevice) {
        NSLog(@"vphoned: IOHIDUserDeviceCreate returned NULL (check "
              @"com.apple.developer.hid.virtual.device entitlement)");
        return NO;
    }

    gQueue = dispatch_queue_create("com.vphone.vphoned.accel", DISPATCH_QUEUE_SERIAL);
    if (pUDScheduleQ) pUDScheduleQ(gDevice, gQueue);

    // Default portrait: gravity down along -Y.
    gX = 0;
    gY = -VP_G_ONE;
    gZ = 0;

    // Real accelerometers stream continuously; a one-shot report is averaged
    // away. Publish the current vector at ~20 Hz so backboardd's orientation
    // filter settles on it.
    gTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, gQueue);
    dispatch_source_set_timer(gTimer, dispatch_time(DISPATCH_TIME_NOW, 0),
                              50 * NSEC_PER_MSEC, 10 * NSEC_PER_MSEC);
    dispatch_source_set_event_handler(gTimer, ^{ vp_accel_send(); });
    dispatch_resume(gTimer);

    gActive = YES;
    NSLog(@"vphoned: virtual accelerometer created (streaming at 20 Hz)");
    return YES;
}

BOOL vp_accel_active(void) { return gActive; }

BOOL vp_accel_set_orientation(int orientation) {
    if (!gActive) return NO;

    // Gravity vector per orientation. Signs are the first tuning knob if a
    // rotation lands mirrored or 180 off — change them here only.
    switch (orientation) {
    case 1: gX = 0;         gY = -VP_G_ONE; gZ = 0; break; // portrait
    case 2: gX = 0;         gY =  VP_G_ONE; gZ = 0; break; // upside-down
    case 3: gX =  VP_G_ONE; gY = 0;         gZ = 0; break; // landscape-left
    case 4: gX = -VP_G_ONE; gY = 0;         gZ = 0; break; // landscape-right
    default: return NO;
    }

    dispatch_async(gQueue, ^{ vp_accel_send(); });
    NSLog(@"vphoned: virtual accel orientation %d (g=%d,%d,%d)", orientation, gX, gY, gZ);
    return YES;
}
