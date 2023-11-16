@import Darwin;
@import Foundation;
@import IOKit;
@import CoreGraphics;

#include "m1ddc.h"
#include "i2c.h"
#include "utils.h"


// -- Generic utility functions

void printUsage() {
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
    " display n               - Chooses which display to control (use number 1, 2 etc.)\n"
    "\n"
    "You can also use 'l', 'v' instead of 'luminance', 'volume' etc.\n");
}


// -- IORegistry related

kern_return_t getIORegistryIterator(io_iterator_t* iter) {
    io_registry_entry_t root = IORegistryGetRootEntry(kIOMainPortDefault);
    kern_return_t ret = IORegistryEntryCreateIterator(root, "IOService", kIORegistryIterateRecursively, iter);
    if (ret != KERN_SUCCESS) {
        IOObjectRelease(*iter);
    }
    return ret;
}

CFTypeRef getCFStringRef(io_service_t service, char* key) {
    CFStringRef cfstring = CFStringCreateWithCString(kCFAllocatorDefault, key, kCFStringEncodingASCII);
    return IORegistryEntrySearchCFProperty(service, kIOServicePlane, cfstring, kCFAllocatorDefault, kIORegistryIterateRecursively);
}


// -- AVService related

DisplayInfos getDisplayInfos(io_service_t service) {
    DisplayInfos display = {};
    
    display.edid = getCFStringRef(service, "EDID UUID");

    CFDictionaryRef displayAttrs = getCFStringRef(service, "DisplayAttributes");
    if (displayAttrs) {
        NSDictionary* displayAttrsNS = (NSDictionary*)displayAttrs;
        NSDictionary* productAttrs = [displayAttrsNS objectForKey:@"ProductAttributes"];
        if (productAttrs) {
            display.serial = [productAttrs objectForKey:@"AlphanumericSerialNumber"];
            display.productName = [productAttrs objectForKey:@"ProductName"];
            display.manufacturerID = [productAttrs objectForKey:@"ManufacturerID"];
        }
    }
    return display;
}

NSString* getDisplayIdentifier(DisplayInfos display) {
    return [NSString stringWithFormat:@"%@:%@", display.serial, display.edid];
}

DisplayInfos* findDisplay(DisplayInfos *displays, char *displayIdentifier) {
    for (int i = 0; i < MAX_DISPLAYS; i++) {
        if (atoi(displayIdentifier) != 0 && atoi(displayIdentifier) == i + 1) {
            // Selecting display based on number
            return displays + i;
        } else if (CFEqual(displayIdentifier, getDisplayIdentifier(displays[i]) )) {
            // Selecting display based on SN:UUID
            return displays + i;
        }
    }
    return NULL;
}


IOAVServiceRef getAVServiceProxy(io_service_t *service, io_iterator_t iter, CFStringRef externalAVServiceLocation ) {
    IOAVServiceRef avService = NULL;
    while ((*service = IOIteratorNext(iter)) != MACH_PORT_NULL) {
        io_name_t name;
        IORegistryEntryGetName(*service, name);
        if (STR_EQ(name, "DCPAVServiceProxy")) {
            avService = IOAVServiceCreateWithService(kCFAllocatorDefault, *service);
            CFStringRef location = getCFStringRef(*service, "Location");
            if (location != NULL && avService && !CFStringCompare(externalAVServiceLocation, location, 0)) {
                return avService;
            }
        }
    }
    return NULL;
}

// -- Input value handling



UInt8 computeAttributeValue(char *command, char *arg, DDCValue displayAttr) {

    int newValue;

    if (STR_EQ(arg, "on") ) { newValue = 1; }
    else if (STR_EQ(arg, "off") ) { newValue = 2; }
    else { newValue = atoi(arg); }

    if (STR_EQ(command, "chg")) {
        newValue = displayAttr.curValue + newValue;
        if (newValue < 0 ) { newValue = 0; }
        if (newValue > displayAttr.maxValue ) { newValue = displayAttr.maxValue; }
    }
    return (UInt8)newValue;
}



// ----------
// -- Main --

// Function to handle the display lister and selection
int getConnectedDisplayInfos(DisplayInfos* displayInfos) {
    int currentDisplay = 0;
    io_service_t service = 0;
    io_iterator_t iter;

    memset(displayInfos, 0, sizeof(displayInfos) * MAX_DISPLAYS);

    // Creating IORegistry iterator
    if (getIORegistryIterator(&iter) != KERN_SUCCESS) {
        return -1;
    }

    CFStringRef externalAVServiceLocation = CFStringCreateWithCString(kCFAllocatorDefault, "External", kCFStringEncodingASCII);

	// Iterating through IORegistry
    while ((service = IOIteratorNext(iter)) != MACH_PORT_NULL && currentDisplay < MAX_DISPLAYS) {
        io_name_t name;
        IORegistryEntryGetName(service, name);
		// Checking for AppleCLCD2 or IOMobileFramebufferShim
        if (STR_EQ(name, "AppleCLCD2") || STR_EQ(name, "IOMobileFramebufferShim")) {
            DisplayInfos display = getDisplayInfos(service);
            display.avService = getAVServiceProxy(&service, iter, externalAVServiceLocation);
            if (display.edid != NULL) {
                displayInfos[currentDisplay] = display;
                currentDisplay++;
            }    
        }
    }

    return currentDisplay;
}

void printDisplayInfos(DisplayInfos *display, int nbDisplays) {
    for (int i = 0; i < nbDisplays; i++) {
        writeToStdOut([NSString stringWithFormat:@"[%i] %@ (%@)\n", i, display[i].productName, getDisplayIdentifier(display[i])]);
    }
}

// Function to handle the reading operation (get, max, chg)
DDCValue readingOperation(DisplayInfos *display, DDCPacket *packet) {
    DDCValue dummyAttr = {-1, -1};

    prepareDDCRead(packet->data);

	// Performing DDC write operation
    IOReturn err = performDDCWrite(display->avService, packet);
    if (err) {
        writeToStdOut([NSString stringWithFormat:@"DDC communication failure: %s\n", mach_error_string(err)]);
        return dummyAttr;
    }

    DDCPacket readPacket = {};
    readPacket.inputAddr = packet->inputAddr;

	// Performing DDC read operation
    err = performDDCRead(display->avService, &readPacket);
    if (err) {
        writeToStdOut([NSString stringWithFormat:@"DDC communication failure: %s\n", mach_error_string(err)]);
        return dummyAttr;
    }

    return convertI2CtoDDC((char *)readPacket.data);
}

// Function to handle the writing operation (set, chg)
int writingOperation(DisplayInfos *display, DDCPacket *packet, UInt8 newValue) {

    // Preparing data buffer for write
    prepareDDCWrite(packet->data, newValue);

    // Performing DDC write operation
    IOReturn err = performDDCWrite(display->avService, packet);
    if (err) {
        writeToStdOut([NSString stringWithFormat:@"DDC communication failure: %s\n", mach_error_string(err)]);
        return 1;
    }
    return 0;
}



int main(int argc, char** argv) {

	if (argc < 3) {
		printUsage();
		return argc > 1 && STR_EQ(argv[1], "help") ? 1 : 0;
	}
    
    DisplayInfos displayInfos[MAX_DISPLAYS];
    DisplayInfos *selectedDisplay = NULL;

    // Display lister and selection
    if (STR_EQ(argv[1], "display")) {

        if (argc == 4) {
            writeToStdOut(@"No command specified. Please use `list` to list displays, or specify a display number to control\n");
            return EXIT_FAILURE;
        }

        int connectedDisplays = getConnectedDisplayInfos(displayInfos);
        if (connectedDisplays == -1) {
            writeToStdOut(@"Could not search for external displays, an error occured while creating IORegistry iterator. Aborting.\n");
            return EXIT_FAILURE;
        } else if (connectedDisplays == 0) {
            writeToStdOut(@"No external display found, aborting");
            return EXIT_FAILURE;
        }

        // Printing out display list
        if (STR_EQ(argv[2], "list") || STR_EQ(argv[2], "l")) {
            printDisplayInfos(displayInfos, connectedDisplays);
            return EXIT_SUCCESS;
        }
        
        // Selecting display
        selectedDisplay = findDisplay(displayInfos, argv[2]);
        if (selectedDisplay == NULL) {
            writeToStdOut(@"The specified display does not exist. Use 'display list' to list displays and use it's number (1, 2...) or its SN:UUID to specify display!\n");
            return EXIT_FAILURE;
        }
		argv += 2;
        argc -= 2;
    }

    // If there is no display selected, we'll use the default display
    if (selectedDisplay == NULL) {
        selectedDisplay = displayInfos;
        selectedDisplay->avService = IOAVServiceCreate(kCFAllocatorDefault);
        if (selectedDisplay->avService == NULL) {
            writeToStdOut(@"Could not find a suitable external display.\n");
            return EXIT_FAILURE;
        }
    }

    // ----------------------------------------
    
    DDCValue displayAttr = {-1, -1};
    DDCPacket packet = createDDCPacket(argv[2]);

    if (!STR_EQ(argv[1], "set")) {
        displayAttr = readingOperation(selectedDisplay, &packet);
        if (displayAttr.curValue == -1) {
            return EXIT_FAILURE;
        }
    }

    if (STR_EQ(argv[1], "get") || STR_EQ(argv[1], "max")) {
        writeToStdOut([NSString stringWithFormat:@"%i\n", (STR_EQ(argv[1], "get") ? displayAttr.curValue : displayAttr.maxValue)]);
        return EXIT_SUCCESS;
    }

    if (STR_EQ(argv[1], "set") || STR_EQ(argv[1], "chg") ) {   
        if (argc < 4) {
            writeToStdOut(@"Missing value! Enter 'm1ddc help' for help!\n");
            return EXIT_FAILURE;
        }

        UInt8 newValue = computeAttributeValue(argv[1], argv[3], displayAttr);

        if (writingOperation(selectedDisplay, &packet, newValue)) {
            return EXIT_FAILURE;
        }
        writeToStdOut([NSString stringWithFormat:@"%i\n", newValue]);
        return EXIT_SUCCESS;
    }
    writeToStdOut(@"Use 'set', 'get', 'max', 'chg' as first parameter! Enter 'm1ddc help' for help!\n");
    return EXIT_FAILURE;
}