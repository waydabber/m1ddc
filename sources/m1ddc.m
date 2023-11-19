@import Darwin;
@import Foundation;
@import IOKit;
@import CoreGraphics;

#include "ioregistry.h"
#include "i2c.h"
#include "utils.h"


// -- Generic utility functions

static void writeToStdOut(NSString *text) {
    [text writeToFile:@"/dev/stdout" atomically:NO encoding:NSUTF8StringEncoding error:nil];
}

static void printUsage() {
    writeToStdOut(@"Controls volume, luminance (brightness), contrast, color gain, input of an external Display connected via USB-C (DisplayPort Alt Mode) over DDC on an Apple Silicon Mac.\n"
    "Displays attached via the built-in HDMI port of M1 or entry level M2 Macs are not supported.\n"
    "\n"
    "Usage examples:\n"
    "\n"
    " m1ddc set contrast 5          - Sets contrast to 5\n"
    " m1ddc get luminance           - Returns current luminance\n"
    " m1ddc set red 90              - Sets red gain to 90\n"
    " m1ddc chg volume -10          - Decreases volume by 10\n"
    " m1ddc display list            - Lists displays\n"
    " m1ddc display 1 set volume 50 - Sets volume to 50 on Display 1\n"
    "\n"
    "Commands:\n"
    "\n"
    " set luminance n         - Sets luminance (brightness) to n, where n is a number between 0 and the maximum value (usually 100).\n"
    " set contrast n          - Sets contrast to n, where n is a number between 0 and the maximum value (usually 100).\n"
    " set (red,green,blue) n  - Sets selected color channel gain to n, where n is a number between 0 and the maximum value (usually 100).\n"
    " set volume n            - Sets volume to n, where n is a number between 0 and the maximum value (usually 100).\n"
    " set input n             - Sets input source to n, common values include:\n"
    "                           DisplayPort 1: 15, DisplayPort 2: 16, HDMI 1: 17, HDMI 2: 18, USB-C: 27.\n"
    " set input-alt n         - Sets input source to n (using alternate addressing, as used by LG), common values include:\n"
    "                           DisplayPort 1: 208, DisplayPort 2: 209, HDMI 1: 144, HDMI 2: 145, USB-C / DP 3: 210.\n"
    "\n"
    " set mute on             - Sets mute on (you can use 1 instead of 'on')\n"
    " set mute off            - Sets mute off (you can use 2 instead of 'off')\n"
    "\n"
    " set pbp n               - Switches PIP/PBP on certain Dell screens (e.g. U3421W), possible values:\n"
    "                           off: 0, small window: 33, large window: 34, 50/50 split: 36, 26/74 split: 43, 74/26 split: 44.\n"
    " set pbp-input n         - Sets second PIP/PBP input on certain Dell screens, possible values:\n"
    "                           DisplayPort 1: 15, DisplayPort 2: 16, HDMI 1: 17, HDMI 2: 18.\n"
    "\n"
    " get luminance           - Returns current luminance (if supported by the display).\n"
    " get contrast            - Returns current contrast (if supported by the display).\n"
    " get (red,green,blue)    - Returns current color gain (if supported by the display).\n"
    " get volume              - Returns current volume (if supported by the display).\n"
    "\n"
    " max luminance           - Returns maximum luminance (if supported by the display, usually 100).\n"
    " max contrast            - Returns maximum contrast (if supported by the display, usually 100).\n"
    " max (red,green,blue)    - Returns maximum color gain (if supported by the display, usually 100).\n"
    " max volume              - Returns maximum volume (if supported by the display, usually 100).\n"
    "\n"
    " chg luminance n         - Changes luminance by n and returns the current value (requires current and max reading support).\n"
    " chg contrast n          - Changes contrast by n and returns the current value (requires current and max reading support).\n"
    " chg (red,green,blue) n  - Changes color gain by n and returns the current value (requires current and max reading support).\n"
    " chg volume n            - Changes volume by n and returns the current value (requires current and max reading support).\n"
    "\n"
    " display list            - Lists displays.\n"
    " display list detailed   - Lists displays and print display informations (Manufacturer, Serial, UUID, IOPath...)\n"
    " display n               - Chooses which display to control (use number 1, 2 etc.)\n"
    "\n"
    "You can also use 'l', 'v' instead of 'luminance', 'volume' etc.\n");
}


// // ----

// kern_return_t getIORegistryIterator(io_iterator_t* iter) {
//     io_registry_entry_t root = IORegistryGetRootEntry(kIOMainPortDefault);
//     kern_return_t ret = IORegistryEntryCreateIterator(root, "IOService", kIORegistryIterateRecursively, iter);
//     if (ret != KERN_SUCCESS) {
//         IOObjectRelease(*iter);
//     }
//     return ret;
// }

// CFTypeRef getCFStringRef(io_service_t service, char* key) {
//     CFStringRef cfstring = CFStringCreateWithCString(kCFAllocatorDefault, key, kCFStringEncodingASCII);
//     return IORegistryEntrySearchCFProperty(service, kIOServicePlane, cfstring, kCFAllocatorDefault, kIORegistryIterateRecursively);
// }

// // Function to handle the display lister and selection
// int getConnectedDisplayInfos(DisplayInfos* displayInfos) {
//     int currentDisplay = 0;
//     io_service_t service = 0;
//     io_iterator_t iter;

//     memset(displayInfos, 0, sizeof(displayInfos) * MAX_DISPLAYS);

//     // Creating IORegistry iterator
//     if (getIORegistryIterator(&iter) != KERN_SUCCESS) {
//         return -1;
//     }

//     CFStringRef externalAVServiceLocation = CFStringCreateWithCString(kCFAllocatorDefault, "External", kCFStringEncodingASCII);

// 	// Iterating through IORegistry
//     while ((service = IOIteratorNext(iter)) != MACH_PORT_NULL && currentDisplay < MAX_DISPLAYS) {
//         io_name_t name;
//         IORegistryEntryGetName(service, name);
// 		// Checking for AppleCLCD2 or IOMobileFramebufferShim
//         if (STR_EQ(name, "AppleCLCD2") || STR_EQ(name, "IOMobileFramebufferShim")) {
//             DisplayInfos display = {};

//             display.adapter = service;
//             display.avService = getAVServiceProxy(service, iter, externalAVServiceLocation);
//             display.edid = getCFStringRef(service, "EDID UUID");

//             CFDictionaryRef displayAttrs = getCFStringRef(service, "DisplayAttributes");
//             if (displayAttrs) {
//                 NSDictionary* displayAttrsNS = (NSDictionary*)displayAttrs;
//                 NSDictionary* productAttrs = [displayAttrsNS objectForKey:@"ProductAttributes"];
//                 if (productAttrs) {
//                     display.productName = [productAttrs objectForKey:@"ProductName"];
//                     display.manufacturer = [productAttrs objectForKey:@"ManufacturerID"];
//                     display.alphNumSerial = [productAttrs objectForKey:@"AlphanumericSerialNumber"];
//                 }
//             }

//             if (display.edid != NULL) {
//                 displayInfos[currentDisplay] = display;
//                 currentDisplay++;
//             }    
//         }
//     }

//     return currentDisplay;
// }

// // ----


static void printDisplayInfos(DisplayInfos *display, int nbDisplays, bool detailed) {
    for (int i = 0; i < nbDisplays; i++) {
        writeToStdOut([NSString stringWithFormat:@"[%i] %@ (%@)\n", (i + 1), (display + i)->productName, (display + i)->uuid]);
        if (detailed) {
            writeToStdOut([NSString stringWithFormat:@" - Product name:  %@\n", (display + i)->productName]);
            writeToStdOut([NSString stringWithFormat:@" - Manufacturer:  %@\n", (display + i)->manufacturer]);
            writeToStdOut([NSString stringWithFormat:@" - AN Serial:     %@\n", (display + i)->alphNumSerial]);
            writeToStdOut([NSString stringWithFormat:@" - Serial:        0x%04x\n", (display + i)->serial]);
            writeToStdOut([NSString stringWithFormat:@" - Model:         0x%04x\n", (display + i)->model]);
            writeToStdOut([NSString stringWithFormat:@" - Vendor:        0x%04x\n", (display + i)->vendor]);
            writeToStdOut([NSString stringWithFormat:@" - Display ID:    %i\n", (display + i)->id]);
            writeToStdOut([NSString stringWithFormat:@" - UUID:          %@\n", (display + i)->uuid]);
            writeToStdOut([NSString stringWithFormat:@" - EDID:          %@\n", (display + i)->edid]);
            writeToStdOut([NSString stringWithFormat:@" - IO Path:       %@\n", (display + i)->ioLocation]);
            writeToStdOut([NSString stringWithFormat:@" - Adapter:       %u\n", (display + i)->adapter]);
        }
    }
}

// Function to handle the reading operation (get, max, chg)
static DDCValue readingOperation(IOAVServiceRef avService, DDCPacket *packet) {
    DDCValue dummyAttr = {-1, -1};

    prepareDDCRead(packet->data);

	// Performing DDC write operation
    IOReturn err = performDDCWrite(avService, packet);
    if (err) {
        writeToStdOut([NSString stringWithFormat:@"DDC communication failure: %s\n", mach_error_string(err)]);
        return dummyAttr;
    }

    DDCPacket readPacket = {};
    readPacket.inputAddr = packet->inputAddr;

	// Performing DDC read operation
    err = performDDCRead(avService, &readPacket);
    if (err) {
        writeToStdOut([NSString stringWithFormat:@"DDC communication failure: %s\n", mach_error_string(err)]);
        return dummyAttr;
    }

    return convertI2CtoDDC((char *)readPacket.data);
}

// Function to handle the writing operation (set, chg)
static int writingOperation(IOAVServiceRef avService, DDCPacket *packet, UInt8 newValue) {

    // Preparing data buffer for write
    prepareDDCWrite(packet->data, newValue);

    // Performing DDC write operation
    IOReturn err = performDDCWrite(avService, packet);
    if (err) {
        writeToStdOut([NSString stringWithFormat:@"DDC communication failure: %s\n", mach_error_string(err)]);
        return 1;
    }
    return 0;
}



int main(int argc, char** argv) {

    argv += 1;
    argc -= 1;

	if (argc < 2) {
		printUsage();
		return argc && STR_EQ(argv[0], "help") ? 1 : 0;
	}
    
    DisplayInfos displayInfos[MAX_DISPLAYS];
    // DisplayInfos displayInfos2[MAX_DISPLAYS];
    DisplayInfos *selectedDisplay = NULL;

    // Display lister and selection
    if (STR_EQ(argv[0], "display")) {

        int connectedDisplays = getOnlineDisplayInfos(displayInfos);
        // int connectedDisplays2 = getConnectedDisplayInfos(displayInfos2);
        if (connectedDisplays == 0) {
            writeToStdOut(@"No external display found, aborting");
            return EXIT_FAILURE;
        }

        // Printing out display list
        if (STR_EQ(argv[1], "list") || STR_EQ(argv[1], "l")) {
            printDisplayInfos(displayInfos, connectedDisplays, (argc >= 4 && (STR_EQ(argv[2], "detailed") || STR_EQ(argv[2], "d"))));
            // printDisplayInfos(displayInfos2, connectedDisplays2, (argc >= 4 && (STR_EQ(argv[3], "detailed") || STR_EQ(argv[3], "d"))));
            return EXIT_SUCCESS;
        }
        
        // Selecting display
        selectedDisplay = selectDisplay(displayInfos, connectedDisplays, argv[1]);
        if (selectedDisplay == NULL) {
            writeToStdOut(@"The specified display does not exist. Use 'display list' to list displays and use it's number (1, 2...) or its UUID to specify display!\n");
            return EXIT_FAILURE;
        }

		argv += 2;
        argc -= 2;
    }
    
    IOAVServiceRef avService;

    // If there is no display selected, we'll use the default display
    if (selectedDisplay == NULL) {
        selectedDisplay = displayInfos;
        avService = IOAVServiceCreate(kCFAllocatorDefault);
    } else {
        CFStringRef externalAVServiceLocation = CFStringCreateWithCString(kCFAllocatorDefault, "External", kCFStringEncodingASCII);
        avService = getAVServiceProxy(selectedDisplay->adapter, 0, externalAVServiceLocation);
    }

    if (avService == NULL) {
        writeToStdOut(@"Could not find a suitable external display.\n");
        return EXIT_FAILURE;
    }

    if (argc < 2) {
        writeToStdOut(@"Missing parameter! Enter 'm1ddc help' for help!\n");
        return EXIT_FAILURE;
    }

    DDCValue displayAttr = {-1, -1};
    DDCPacket packet = createDDCPacket(argv[1]);

    // Checking that packet.data[2] is not 0 (invalid command)
    if (packet.data[2] == 0) {
        writeToStdOut(@"Invalid command! Enter 'm1ddc help' for help!\n");
        return EXIT_FAILURE;
    }

    // Reading current
    if (!STR_EQ(argv[0], "set")) {
        displayAttr = readingOperation(avService, &packet);
        if (displayAttr.curValue == -1) {
            return EXIT_FAILURE;
        }
    }
    
    if (STR_EQ(argv[0], "get") || STR_EQ(argv[0], "max")) {
        writeToStdOut([NSString stringWithFormat:@"%i\n", (STR_EQ(argv[0], "get") ? displayAttr.curValue : displayAttr.maxValue)]);
        return EXIT_SUCCESS;
    }

    if (STR_EQ(argv[0], "set") || STR_EQ(argv[0], "chg") ) {   
        if (argc < 3) {
            writeToStdOut(@"Missing value! Enter 'm1ddc help' for help!\n");
            return EXIT_FAILURE;
        }

        UInt8 newValue = computeAttributeValue(argv[0], argv[2], displayAttr);

        if (writingOperation(avService, &packet, newValue)) {
            return EXIT_FAILURE;
        }
        writeToStdOut([NSString stringWithFormat:@"%i\n", newValue]);
        return EXIT_SUCCESS;
    }
    writeToStdOut(@"Use 'set', 'get', 'max', 'chg' as first parameter! Enter 'm1ddc help' for help!\n");
    return EXIT_FAILURE;
}