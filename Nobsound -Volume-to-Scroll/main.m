//
//  main.m
//  xxx
//
//  Created by Dirk-Willem van Gulik on 03/06/2021.
//

#import <Foundation/Foundation.h>
#import <IOKit/hid/IOHIDManager.h>
#import <IOKit/hid/IOHIDUsageTables.h>
#import <Carbon/Carbon.h>

#define Debuglog if (0) NSLog

static void Handle_InputCallback(void *inContext, IOReturn inResult, void *inSender, IOHIDValueRef value)
{
    static float speedup = 1;
    static uint64_t last;
    
    CFIndex i = IOHIDValueGetIntegerValue(value);
    if (i == 0)
        return;
    
    IOHIDElementRef elem = IOHIDValueGetElement(value);
    uint32_t u = IOHIDElementGetUsage(elem);
    if (u > 255 || u == 0)
        return;
    
    // IOHIDElementType what = IOHIDElementGetType(elem);
    
#define SNAPTIME (50ULL)
    
    uint64_t now = IOHIDValueGetTimeStamp(value);
    if (now - last < SNAPTIME * 1000 * 1000 && speedup < 900) {
        speedup *= 1.5;
        Debuglog(@"Mega Boost %f",speedup);
    } else
    if (now - last < 2 * SNAPTIME * 1000 * 1000 && speedup < 900) {
        speedup++;
        Debuglog(@"Boost %f", speedup);
    } else
    if (now - last < 5 * SNAPTIME * 1000 * 1000 && speedup > 10) {
        Debuglog(@"Boost rampdown %f", speedup);
        speedup *= 0.5;
    } else
    if (now - last < 10 * SNAPTIME * 1000 * 1000 && speedup > 10) {
        Debuglog(@"Boost stay %f", speedup);
        speedup *= 0.9;
    }
    else {
        if (speedup > 1)
            Debuglog(@"No Boost %f", speedup);
        speedup = 1;
    }
    last = now;
    
    uint16_t scancode = IOHIDElementGetUsage(elem);
    switch(scancode) {
        case 181: {
            CGEventRef e = CGEventCreateKeyboardEvent (NULL, kVK_PageUp, true);
            CGEventPost(kCGSessionEventTap, e);
            CFRelease(e);
        }; break;
        case 182: {
            CGEventRef e = CGEventCreateKeyboardEvent (NULL, kVK_PageDown, true);
            CGEventPost(kCGSessionEventTap, e);
            CFRelease(e);
            
        }; break;
        case 233:
        {
            CGEventRef e = CGEventCreateScrollWheelEvent(NULL, kCGScrollEventUnitLine,
                                                         1, -speedup);
            CGEventPost(kCGSessionEventTap, e);
            CFRelease(e);
        }; break;
        case 234:
        {
            CGEventRef e = CGEventCreateScrollWheelEvent(NULL, kCGScrollEventUnitLine,
                                                         1, speedup);
            CGEventPost(kCGSessionEventTap, e);
            CFRelease(e);
        }; break;
        default: // ignore
            break;
    };
}


static void Handle_DeviceMatchingCallback(void * inContext, IOReturn inResult, void * inSender, IOHIDDeviceRef inIOHIDDeviceRef)
{
    NSLog(@"Control knob Connected");
}

static void Handle_RemovalCallback(void * inContext, IOReturn inResult, void * inSender, IOHIDDeviceRef inIOHIDDeviceRef)
{
    NSLog(@"Control knob Removed");
}


int main(int argc, const char * argv[])
{
    @autoreleasepool {
        IOHIDManagerRef manager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDManagerOptionNone);
        
        if (CFGetTypeID(manager) != IOHIDManagerGetTypeID()) {
            exit(1);
        }
        /*
         {
         "device_id": 4294968441,
         "is_karabiner_virtual_hid_device": false,
         "is_keyboard": false,
         "is_pointing_device": true,
         "location_id": 336658432,
         "product": "Wired KeyBoard",
         "product_id": 514,
         "transport": "USB",
         "vendor_id": 1452
         },
         */
        int vendorId = 1452;
        int productId = 514;
        int usagePage = kHIDPage_GenericDesktop;
        int usage = kHIDUsage_GD_Pointer;
        
#define KEYS 4
        
        CFStringRef keys[KEYS] = {
            CFSTR(kIOHIDVendorIDKey),
            CFSTR(kIOHIDProductIDKey),
            CFSTR(kIOHIDDeviceUsagePageKey),
            CFSTR(kIOHIDDeviceUsageKey),
        };
        
        CFNumberRef values[KEYS] = {
            CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &vendorId),
            CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &productId),
            CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &usagePage),
            CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &usage),
        };
        
        CFDictionaryRef matchingDict = CFDictionaryCreate(kCFAllocatorDefault,
                                                          (const void **) keys, (const void **) values, KEYS,
                                                          &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        
        for (int i=0; i<KEYS; i++) {
            CFRelease(keys[i]);
            CFRelease(values[i]);
        }
        
        IOHIDManagerSetDeviceMatching(manager, matchingDict);
        CFRelease(matchingDict);
        
        IOHIDManagerRegisterDeviceMatchingCallback(manager,
                                                   Handle_DeviceMatchingCallback, NULL);
        IOHIDManagerRegisterDeviceRemovalCallback(manager,
                                                  Handle_RemovalCallback, NULL);
        IOHIDManagerRegisterInputValueCallback(manager,
                                               Handle_InputCallback, NULL);
        
        IOHIDManagerOpen(manager, kIOHIDOptionsTypeSeizeDevice);
        
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        
        [[NSRunLoop mainRunLoop] run];
    }
    return 0;
}
