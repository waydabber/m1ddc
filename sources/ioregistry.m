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
    // Getting online display list and count
    CGDisplayCount screenCount;
    CGDirectDisplayID screenList[MAX_DISPLAYS];
    CGGetOnlineDisplayList(MAX_DISPLAYS, screenList, &screenCount);

    // Fetching each display infos from IOKit
    for (int i = 0; i < (int)screenCount; i++) {
        DisplayInfos *currDisplay = displayInfos + i;
        currDisplay->id = screenList[i];

        // This is a private API, but it's a shortcut to get the system UUID
        CFDictionaryRef displayInfos = CoreDisplay_DisplayCreateInfoDictionary(currDisplay->id);

        currDisplay->serial = CGDisplaySerialNumber(currDisplay->id);
        currDisplay->model = CGDisplayModelNumber(currDisplay->id);
        currDisplay->vendor = CGDisplayVendorNumber(currDisplay->id);

        currDisplay->uuid = CFDictionaryGetValue(displayInfos, CFSTR("kCGDisplayUUID"));
        currDisplay->ioLocation = CFDictionaryGetValue(displayInfos, CFSTR("IODisplayLocation"));
        
        // Retrieving IORegistry entry for display
        currDisplay->adapter = IORegistryEntryCopyFromPath(kIOMainPortDefault, (CFStringRef)currDisplay->ioLocation);
        if (currDisplay->adapter == MACH_PORT_NULL) {
            continue;
        }

        // If successful, we can retrieve the EDID UUID, and other display attributes
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

/* 
 *  Returns display identifier based on identification method
 *  Allowed methods are:
 *  - id    Display ID                          "<id>"
 *  - uuid  Display UUID                        "<uuid>"
 *  - edid  Display EDID UUID                   "<edid>"
 *  - seid  Display Alphnum SN + EDID UUID      "<an_serial>:<edid>"
 *  - basic Match basic identifiers             "<vendor>:<model>:<serial>"
 *  - ext   Match basic + extended identifiers  "<vendor>:<model>:<serial>:<manufacturer>:<an_serial>:<name>"
 *  - full  Match basic + extended + location   "<vendor>:<model>:<serial>:<manufacturer>:<an_serial>:<name>:<location>"
 */
NSString *getDisplayIdentifier(DisplayInfos *display, char *identificationMethod) {
    if (STR_EQ(identificationMethod, "id")) {
        return [NSString stringWithFormat:@"%u", display->id];
    } else if (STR_EQ(identificationMethod, "uuid")) {
        return display->uuid;
    } else if (STR_EQ(identificationMethod, "edid")) {
        return display->edid;
    } else if (STR_EQ(identificationMethod, "seid")) {
        return [NSString stringWithFormat:@"%@:%@",
            display->alphNumSerial,
            display->edid];
    } else if (STR_EQ(identificationMethod, "basic")) {
        return [NSString stringWithFormat:@"%u:%u:%u",
            display->vendor,
            display->model,
            display->serial];
    } else if (STR_EQ(identificationMethod, "ext")) {
        return [NSString stringWithFormat:@"%d:%d:%d:%@:%@:%@",
            display->vendor,
            display->model,
            display->serial,
            display->manufacturer,
            display->alphNumSerial,
            display->productName];
    } else if (STR_EQ(identificationMethod, "full")) {
        return [NSString stringWithFormat:@"%d:%d:%d:%@:%@:%@:%@",
            display->vendor,
            display->model,
            display->serial,
            display->manufacturer,
            display->alphNumSerial,
            display->productName,
            display->ioLocation];
    }
    return NULL;
}

DisplayInfos* selectDisplay(DisplayInfos *displays, int connectedDisplays, char *displayIdentifier) {

    // Checking if display identifier is a display index from the "list" command
    char *stop;
    long displayNumber = strtol(displayIdentifier, &stop, 10);
    if (*stop == '\0') {
        return displayNumber <= connectedDisplays ? displays + (displayNumber - 1) : NULL;
    }

    // Checking if an identification method is specified, otherwise defaulting to UUID
    char *identificationMethod = "uuid";
    char *delimiter = strstr(displayIdentifier, "=");
    if (delimiter != NULL) {
        // Delimiter should not be at the beginning or end of the string
        if (delimiter == displayIdentifier || delimiter == displayIdentifier + strlen(displayIdentifier) - 1) return NULL;
        // Splitting display identifier into identification method and value
        *delimiter = '\0';
        identificationMethod = displayIdentifier;
        displayIdentifier = delimiter + 1;
    }

    // Searching for display that matchs the identifier for the given identification method
    for (int i = 0; i < connectedDisplays; i++) {
        const char *displayValue = getDisplayIdentifier(displays + i, identificationMethod).UTF8String;
        if (displayValue != NULL && STR_EQ(displayIdentifier, displayValue)) {
            return displays + i;
        }
    }
    return NULL;
}

static kern_return_t getIORegistryRootIterator(io_iterator_t* iter) {
    io_registry_entry_t root = IORegistryGetRootEntry(kIOMainPortDefault);
    kern_return_t ret = IORegistryEntryCreateIterator(root, kIOServicePlane, kIORegistryIterateRecursively, iter);
    if (ret != KERN_SUCCESS) {
        IOObjectRelease(*iter);
    }
    return ret;
}

IOAVServiceRef getDefaultDisplayAVService() {
    return IOAVServiceCreate(kCFAllocatorDefault);
}

IOAVServiceRef getDisplayAVService(DisplayInfos* displayInfos) {

    IOAVServiceRef avService = NULL;
    io_service_t service = 0;
    io_iterator_t iter;

    // Creating IORegistry iterator
    if (getIORegistryRootIterator(&iter) != KERN_SUCCESS) {
        return NULL;
    }

    CFStringRef externalAVServiceLocation = CFStringCreateWithCString(kCFAllocatorDefault, "External", kCFStringEncodingASCII);

	// Iterating through IORegistry
    while ((service = IOIteratorNext(iter)) != MACH_PORT_NULL) {
        io_string_t servicePath;
        IORegistryEntryGetPath(service, kIOServicePlane, servicePath);
        // Searching for DCPAVServiceProxy with the same location as the display
        if (displayInfos->ioLocation != NULL && STR_EQ(servicePath, displayInfos->ioLocation.UTF8String)) {
            while ((service = IOIteratorNext(iter)) != MACH_PORT_NULL) {
                io_name_t name;
                IORegistryEntryGetName(service, name);
                if (STR_EQ(name, "DCPAVServiceProxy")) {
                    // Creating IOAVServiceRef from DCPAVServiceProxy
                    avService = IOAVServiceCreateWithService(kCFAllocatorDefault, service);
                    CFStringRef location = getCFStringRef(service, "Location");
                    if (location != NULL && avService != NULL && !CFStringCompare(externalAVServiceLocation, location, 0)) {
                        return avService;
                    }
                }
            }
        }
    }
    return NULL;
}