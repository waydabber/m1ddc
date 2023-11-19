#ifndef _IOREGISTRY_H
# define _IOREGISTRY_H

# import <CoreGraphics/CoreGraphics.h>

# define MAX_DISPLAYS   4 // Set this to 2 or 4 depending on the Apple Silicon Mac you're using
# define UUID_SIZE      37

typedef CFTypeRef IOAVServiceRef;

typedef struct
{
    CGDirectDisplayID id;
    IOAVServiceRef avService;
    io_service_t adapter;
    NSString *ioLocation;    
    NSString *uuid;
    NSString *edid;    
    NSString *productName;
    NSString *manufacturer;
    NSString *alphNumSerial;
    UInt32 serial;
    UInt32 model;
    UInt32 vendor;
} DisplayInfos;

CGDisplayCount  getOnlineDisplayInfos(DisplayInfos* displayInfos);
DisplayInfos*   selectDisplay(DisplayInfos *displays, int connectedDisplays, char *displayIdentifier);
// IOAVServiceRef  getAVServiceProxy(io_service_t service, io_iterator_t iter, CFStringRef externalAVServiceLocation);
IOAVServiceRef  getDisplayAVService(DisplayInfos* displayInfos);

extern IOAVServiceRef   IOAVServiceCreate(CFAllocatorRef allocator);
extern IOAVServiceRef   IOAVServiceCreateWithService(CFAllocatorRef allocator, io_service_t service);
extern CFDictionaryRef  CoreDisplay_DisplayCreateInfoDictionary(CGDirectDisplayID);

#endif