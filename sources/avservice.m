@import Foundation;
@import IOKit;
@import CoreGraphics;

#include "avservice.h"
#include "i2c.h"
#include "utils.h"

// -- EDID parsing (base block only; VESA E-EDID 1.3/1.4 layout)

static Boolean edidIsValid(const UInt8 *edid) {
    static const UInt8 header[8] = {0x00, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x00};
    if (memcmp(edid, header, sizeof(header)) != 0) {
        return false;
    }
    UInt8 sum = 0;
    for (int i = 0; i < EDID_LENGTH; i++) {
        sum += edid[i];
    }
    return sum == 0;
}

// 18-byte display descriptors live at 54, 72, 90, 108. A descriptor whose first three bytes are 0 0 0
// carries a tag at byte 3: 0xFC = product name, 0xFF = serial number (ASCII, LF-terminated, space-padded).
static NSString *edidDescriptorString(const UInt8 *edid, UInt8 tag) {
    for (int d = 54; d <= 108; d += 18) {
        if (edid[d] != 0 || edid[d + 1] != 0 || edid[d + 2] != 0 || edid[d + 3] != tag) {
            continue;
        }
        char text[14] = {0};
        int len = 0;
        for (int k = 5; k < 18 && edid[d + k] != 0x0a; k++) {
            text[len++] = (char)edid[d + k];
        }
        while (len > 0 && text[len - 1] == ' ') {
            text[--len] = '\0';
        }
        return len > 0 ? [NSString stringWithUTF8String:text] : nil;
    }
    return nil;
}

static void parseEDID(AVServiceInfos *infos) {
    const UInt8 *e = infos->edid;
    // Manufacturer id: 3 five-bit letters packed big-endian in bytes 8-9. CoreGraphics reports the same
    // 16-bit value as the vendor number.
    UInt16 mfg = (UInt16)((e[8] << 8) | e[9]);
    char id[4] = {
        (char)('A' - 1 + ((mfg >> 10) & 0x1f)),
        (char)('A' - 1 + ((mfg >> 5) & 0x1f)),
        (char)('A' - 1 + (mfg & 0x1f)),
        '\0',
    };
    infos->manufacturer = [NSString stringWithUTF8String:id];
    infos->vendor = mfg;
    infos->model = (UInt32)(e[10] | (e[11] << 8));
    infos->serial = (UInt32)(e[12] | (e[13] << 8) | (e[14] << 16) | ((UInt32)e[15] << 24));
    infos->productName = edidDescriptorString(e, 0xFC);
    infos->alphNumSerial = edidDescriptorString(e, 0xFF);
}

// -- IORegistry

static Boolean proxyIsExternal(io_service_t proxy) {
    CFTypeRef location = IORegistryEntryCreateCFProperty(proxy, CFSTR("Location"), kCFAllocatorDefault, 0);
    Boolean external = location != NULL &&
        CFGetTypeID(location) == CFStringGetTypeID() &&
        CFStringCompare(CFSTR("External"), location, 0) == kCFCompareEqualTo;
    if (location != NULL) {
        CFRelease(location);
    }
    return external;
}

static IOReturn readEDID(IOAVServiceRef avService, UInt8 *edid) {
    // Standard DDC2B EDID read: set the segment-0 word offset to 0, then read 128 bytes from 0x50.
    UInt8 offset = 0;
    IOReturn err = IOAVServiceWriteI2C(avService, EDID_I2C_ADDRESS, 0x00, &offset, 1);
    if (err) {
        return err;
    }
    usleep(DDC_WAIT);
    err = IOAVServiceReadI2C(avService, EDID_I2C_ADDRESS, 0x00, edid, EDID_LENGTH);
    if (err) {
        return err;
    }
    return edidIsValid(edid) ? kIOReturnSuccess : kIOReturnBadMedia;
}

int getAVServiceInfos(AVServiceInfos *infos, int max) {
    io_iterator_t iter = MACH_PORT_NULL;
    if (IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("DCPAVServiceProxy"), &iter) != KERN_SUCCESS) {
        return 0;
    }

    int count = 0;
    io_service_t proxy;
    while ((proxy = IOIteratorNext(iter)) != MACH_PORT_NULL) {
        if (count >= max || !proxyIsExternal(proxy)) {
            IOObjectRelease(proxy);
            continue;
        }
        AVServiceInfos *curr = infos + count;
        memset(curr, 0, sizeof(*curr));
        curr->proxy = proxy;
        IORegistryEntryGetRegistryEntryID(proxy, &curr->registryID);
        curr->isMCDP29XX = isMCDP29XXProxy(proxy);

        IOAVServiceRef avService = IOAVServiceCreateWithService(kCFAllocatorDefault, proxy);
        if (avService == NULL) {
            curr->edidStatus = kIOReturnNoDevice;
        } else {
            curr->edidStatus = readEDID(avService, curr->edid);
            CFRelease(avService);
        }
        if (curr->edidStatus == kIOReturnSuccess) {
            parseEDID(curr);
        }
        count++;
    }
    IOObjectRelease(iter);
    return count;
}

void releaseAVServiceInfos(AVServiceInfos *infos, int count) {
    for (int i = 0; i < count; i++) {
        if (infos[i].proxy != MACH_PORT_NULL) {
            IOObjectRelease(infos[i].proxy);
            infos[i].proxy = MACH_PORT_NULL;
        }
    }
}

AVServiceInfos *selectAVService(AVServiceInfos *infos, int count, char *identifier) {
    char *stop;
    long number = strtol(identifier, &stop, 10);
    if (*stop == '\0') {
        return (number >= 1 && number <= count) ? infos + (number - 1) : NULL;
    }
    for (int i = 0; i < count; i++) {
        if (infos[i].alphNumSerial != nil && STR_EQ(identifier, infos[i].alphNumSerial.UTF8String)) {
            return infos + i;
        }
    }
    return NULL;
}

static Boolean sameDisplay(AVServiceInfos *infos, DisplayInfos *display) {
    if (infos->alphNumSerial != nil && display->alphNumSerial != nil) {
        return [infos->alphNumSerial isEqualToString:display->alphNumSerial];
    }
    return infos->vendor == display->vendor && infos->model == display->model && infos->serial == display->serial;
}

void matchAVServicesToDisplays(AVServiceInfos *infos, int count, DisplayInfos *displays, int displayCount) {
    for (int i = 0; i < count; i++) {
        infos[i].displayID = 0;
        if (infos[i].edidStatus != kIOReturnSuccess) {
            continue;
        }
        for (int j = 0; j < displayCount; j++) {
            if (sameDisplay(infos + i, displays + j)) {
                infos[i].displayID = displays[j].id;
                break;
            }
        }
    }
}

DDCTransport getAVServiceDDCTransport(AVServiceInfos *infos) {
    DDCTransport transport = {
        .service = NULL,
        .chipAddress = DDC_CHIP_ADDRESS_DEFAULT,
    };
    if (infos == NULL || infos->proxy == MACH_PORT_NULL) {
        return transport;
    }
    transport.service = IOAVServiceCreateWithService(kCFAllocatorDefault, infos->proxy);
    if (transport.service != NULL && infos->isMCDP29XX) {
        transport.chipAddress = DDC_CHIP_ADDRESS_MCDP29XX;
    }
    return transport;
}

void fillDisplayInfosFromAVService(DisplayInfos *display, AVServiceInfos *infos) {
    memset(display, 0, sizeof(*display));
    display->id = infos->displayID;
    display->productName = infos->productName ?: @"Unknown Display";
    display->manufacturer = infos->manufacturer;
    display->alphNumSerial = infos->alphNumSerial;
    display->vendor = infos->vendor;
    display->model = infos->model;
    display->serial = infos->serial;
}
