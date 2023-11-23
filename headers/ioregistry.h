#ifndef _IOREGISTRY_H
# define _IOREGISTRY_H

# import <CoreGraphics/CoreGraphics.h>

# ifndef MAX_DISPLAYS
#  define MAX_DISPLAYS   4   // Set this to 2 or 4 depending on the Apple Silicon Mac you're using
# endif

# define UUID_SIZE      37

// IOAVServiceRef is a private class, so we need to define it here
typedef CFTypeRef IOAVServiceRef;

// Base structure for display infos
typedef struct
{
    CGDirectDisplayID id;
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

IOAVServiceRef  getDefaultDisplayAVService();
IOAVServiceRef  getDisplayAVService(DisplayInfos* displayInfos);

// External functions
extern IOAVServiceRef   IOAVServiceCreate(CFAllocatorRef allocator);
extern IOAVServiceRef   IOAVServiceCreateWithService(CFAllocatorRef allocator, io_service_t service);
extern CFDictionaryRef  CoreDisplay_DisplayCreateInfoDictionary(CGDirectDisplayID);

#endif