@import Foundation;
@import IOKit;
@import ApplicationServices;
@import CoreGraphics;

#include "ioregistry.h"
#include "utils.h"

static CFTypeRef getCFStringRef(io_service_t service, char* key) {
    CFStringRef cfstring = CFStringCreateWithCString(kCFAllocatorDefault, key, kCFStringEncodingASCII);
    return IORegistryEntrySearchCFProperty(service, kIOServicePlane, cfstring, kCFAllocatorDefault, kIORegistryIterateRecursively);
}

CGDisplayCount getOnlineDisplayInfos(DisplayInfos* displayInfos) {
    CGDisplayCount screenCount;
    CGDirectDisplayID screenList[MAX_DISPLAYS];
    CGGetOnlineDisplayList(MAX_DISPLAYS, screenList, &screenCount);

    for (int i = 0; i < (int)screenCount; i++) {
        DisplayInfos *currDisplay = displayInfos + i;
        currDisplay->id = screenList[i];
        CFDictionaryRef displayInfos = CoreDisplay_DisplayCreateInfoDictionary(currDisplay->id);

        currDisplay->serial = CGDisplaySerialNumber(currDisplay->id);
        currDisplay->model = CGDisplayModelNumber(currDisplay->id);
        currDisplay->vendor = CGDisplayVendorNumber(currDisplay->id);
        currDisplay->uuid = CFDictionaryGetValue(displayInfos, CFSTR("kCGDisplayUUID"));
        currDisplay->ioLocation = CFDictionaryGetValue(displayInfos, CFSTR("IODisplayLocation"));
        currDisplay->adapter = IORegistryEntryCopyFromPath(kIOMainPortDefault, (CFStringRef)currDisplay->ioLocation);
        if (currDisplay->adapter == MACH_PORT_NULL) {
            continue;
        }
        currDisplay->edid = getCFStringRef(currDisplay->adapter, "EDID UUID");

        CFDictionaryRef displayAttrs = getCFStringRef(currDisplay->adapter, "DisplayAttributes");
        if (displayAttrs) {
            NSDictionary* displayAttrsNS = (NSDictionary*)displayAttrs;
            NSDictionary* productAttrs = [displayAttrsNS objectForKey:@"ProductAttributes"];
            if (productAttrs) {
                currDisplay->productName = [productAttrs objectForKey:@"ProductName"];
                currDisplay->manufacturer = [productAttrs objectForKey:@"ManufacturerID"];
                currDisplay->alphNumSerial = [productAttrs objectForKey:@"AlphanumericSerialNumber"];
            }
        }
    }
    return screenCount;
}

DisplayInfos* selectDisplay(DisplayInfos *displays, int connectedDisplays, char *displayIdentifier) {
    for (int i = 0; i < connectedDisplays; i++) {
        if (atoi(displayIdentifier) != 0 && atoi(displayIdentifier) == i + 1) {
            // Selecting display based on number
            return &displays[i];
        } else if (STR_EQ(displayIdentifier, displays[i].uuid.UTF8String)) {
            // Selecting display based on UUID
            return &displays[i];
        }
    }
    return NULL;
}

static kern_return_t getIORegistryRootIterator(io_iterator_t* iter) {
    io_registry_entry_t root = IORegistryGetRootEntry(kIOMainPortDefault);
    kern_return_t ret = IORegistryEntryCreateIterator(root, "IOService", kIORegistryIterateRecursively, iter);
    if (ret != KERN_SUCCESS) {
        IOObjectRelease(*iter);
    }
    return ret;
}

IOAVServiceRef getAVServiceProxy(io_service_t service, io_iterator_t iter, CFStringRef externalAVServiceLocation) {
    IOAVServiceRef avService = NULL;
    if (service == MACH_PORT_NULL) return NULL;
    if (iter == 0 && getIORegistryRootIterator(&iter) != KERN_SUCCESS) return NULL;
    while ((service = IOIteratorNext(iter)) != MACH_PORT_NULL) {
        io_name_t name;
        IORegistryEntryGetName(service, name);
        if (STR_EQ(name, "DCPAVServiceProxy")) {
            avService = IOAVServiceCreateWithService(kCFAllocatorDefault, service);
            CFStringRef location = getCFStringRef(service, "Location");
            if (location != NULL && avService != NULL && !CFStringCompare(externalAVServiceLocation, location, 0)) {
                return avService;
            }
        }
    }
    return NULL;
}