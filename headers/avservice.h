#ifndef _AVSERVICE_H
# define _AVSERVICE_H

# import <IOKit/IOKitLib.h>
# include "ioregistry.h"

// Direct enumeration of DDC-capable sinks.
//
// getOnlineDisplayInfos() starts from CGGetOnlineDisplayList(), so it only sees displays that are
// currently part of the macOS desktop. A display that is powered on but showing another input (a
// KVM-style setup, another computer) keeps its DCPAVServiceProxy in the IORegistry and keeps answering
// DDC/CI on it, yet it never appears in that list. This enumerates every External DCPAVServiceProxy
// instead and identifies each sink by its EDID (read over I2C at 0x50), so a display can be addressed
// whether or not macOS is driving it.

# define EDID_LENGTH            128
# define EDID_I2C_ADDRESS       0x50
# define MAX_AVSERVICES         8

typedef struct
{
    io_service_t proxy;             // DCPAVServiceProxy registry entry (retained; release with IOObjectRelease)
    uint64_t registryID;
    Boolean isMCDP29XX;             // DDC goes through chip address 0xB7 on MCDP29xx bridges
    IOReturn edidStatus;            // kIOReturnSuccess when edid[] is a valid 128-byte base block
    UInt8 edid[EDID_LENGTH];
    NSString *manufacturer;         // 3-letter EISA/PNP id from the EDID, e.g. "AUS"
    NSString *productName;          // EDID display product name descriptor (0xFC), or nil
    NSString *alphNumSerial;        // EDID display serial number descriptor (0xFF), or nil
    UInt32 vendor;                  // EDID manufacturer id, as CGDisplayVendorNumber() reports it
    UInt32 model;                   // EDID product code, as CGDisplayModelNumber() reports it
    UInt32 serial;                  // EDID 32-bit serial, as CGDisplaySerialNumber() reports it
    CGDirectDisplayID displayID;    // the matching CoreGraphics display, or 0 when macOS does not drive it
} AVServiceInfos;

// Fills up to `max` entries; returns the count. Entries whose EDID could not be read are kept
// (edidStatus != kIOReturnSuccess) so the caller can show them as present-but-unreadable.
// Release the registry entries with releaseAVServiceInfos() when done.
int             getAVServiceInfos(AVServiceInfos *infos, int max);
void            releaseAVServiceInfos(AVServiceInfos *infos, int count);

// Picks by list index ("1", "2", ...) or by EDID alphanumeric serial. NULL when nothing matches.
AVServiceInfos* selectAVService(AVServiceInfos *infos, int count, char *identifier);

// Marks entries that are also CoreGraphics displays (by EDID identity against `displays`).
void            matchAVServicesToDisplays(AVServiceInfos *infos, int count, DisplayInfos *displays, int displayCount);

// Transport for a directly enumerated sink. transport.service is NULL on failure.
DDCTransport    getAVServiceDDCTransport(AVServiceInfos *infos);

// Fills a DisplayInfos from a directly enumerated sink so the rest of the tool can treat it like
// any other display (adapter/uuid/edid stay unset; id is the CG display id or 0).
void            fillDisplayInfosFromAVService(DisplayInfos *display, AVServiceInfos *infos);

#endif
