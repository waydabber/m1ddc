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

static void printDisplayInfos(DisplayInfos *display, int nbDisplays, bool detailed) {
    for (int i = 0; i < nbDisplays; i++) {
        writeToStdOut([NSString stringWithFormat:@"[%i] %@ (%@)\n", (i + 1), (display + i)->productName, (display + i)->uuid]);
        if (detailed) {
            writeToStdOut([NSString stringWithFormat:@" - Product name:  %@\n", (display + i)->productName]);
            writeToStdOut([NSString stringWithFormat:@" - Manufacturer:  %@\n", (display + i)->manufacturer]);
            writeToStdOut([NSString stringWithFormat:@" - AN Serial:     %@\n", (display + i)->alphNumSerial]);
            writeToStdOut([NSString stringWithFormat:@" - Vendor:        %u (0x%04x)\n", (display + i)->vendor, (display + i)->vendor]);
            writeToStdOut([NSString stringWithFormat:@" - Model:         %u (0x%04x)\n", (display + i)->model, (display + i)->model]);
            writeToStdOut([NSString stringWithFormat:@" - Serial:        %u (0x%04x)\n", (display + i)->serial, (display + i)->serial]);
            writeToStdOut([NSString stringWithFormat:@" - Display ID:    %i\n", (display + i)->id]);
            writeToStdOut([NSString stringWithFormat:@" - System UUID:   %@\n", (display + i)->uuid]);
            writeToStdOut([NSString stringWithFormat:@" - EDID UUID:     %@\n", (display + i)->edid]);
            writeToStdOut([NSString stringWithFormat:@" - IO Location:   %@\n", (display + i)->ioLocation]);
            writeToStdOut([NSString stringWithFormat:@" - Adapter:       %u\n", (display + i)->adapter]);
        }
    }
}

// Function to handle the reading operation (get, max, chg)
static DDCValue readingOperation(IOAVServiceRef avService, DDCPacket *packet) {
    DDCValue dummyAttr = {-1, -1};

    prepareDDCRead(packet->data);

    IOReturn err = performDDCWrite(avService, packet);
    if (err) {
        writeToStdOut([NSString stringWithFormat:@"DDC communication failure: %s\n", mach_error_string(err)]);
        return dummyAttr;
    }

    DDCPacket readPacket = {};
    readPacket.inputAddr = packet->inputAddr;

    err = performDDCRead(avService, &readPacket);
    if (err) {
        writeToStdOut([NSString stringWithFormat:@"DDC communication failure: %s\n", mach_error_string(err)]);
        return dummyAttr;
    }

    return convertI2CtoDDC((char *)readPacket.data);
}

// Function to handle the writing operation (set, chg)
static int writingOperation(IOAVServiceRef avService, DDCPacket *packet, UInt8 newValue) {

    prepareDDCWrite(packet->data, newValue);

    IOReturn err = performDDCWrite(avService, packet);
    if (err) {
        writeToStdOut([NSString stringWithFormat:@"DDC communication failure: %s\n", mach_error_string(err)]);
        return 1;
    }
    return 0;
}

static UInt8 attrCodeFromCommand(char *command) {
    if (STR_EQ(command, "luminance") || STR_EQ(command, "l")) { return LUMINANCE; }
    else if (STR_EQ(command, "contrast") || STR_EQ(command, "c")) { return CONTRAST; }
    else if (STR_EQ(command, "volume") || STR_EQ(command, "v")) { return VOLUME; }
    else if (STR_EQ(command, "mute") || STR_EQ(command, "m")) { return MUTE; }
    else if (STR_EQ(command, "input") || STR_EQ(command, "i")) { return INPUT; }
    else if (STR_EQ(command, "input-alt") || STR_EQ(command, "I")) { return INPUT_ALT; }
    else if (STR_EQ(command, "standby") || STR_EQ(command, "s")) { return STANDBY; }
    else if (STR_EQ(command, "red") || STR_EQ(command, "r")) { return RED; }
    else if (STR_EQ(command, "green") || STR_EQ(command, "g")) { return GREEN; }
    else if (STR_EQ(command, "blue") || STR_EQ(command, "b")) { return BLUE; }
    else if (STR_EQ(command, "pbp") || STR_EQ(command, "p")) { return PBP; }
    else if (STR_EQ(command, "pbp-input") || STR_EQ(command, "pi")) { return PBP_INPUT; }
    return 0x00;
}

static UInt8 computeAttributeValue(char *command, char *arg, DDCValue displayAttr) {
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

int main(int argc, char** argv) {

    bool verbose = false;
    argv += 1;
    argc -= 1;

	if (argc < 2) {
		printUsage();
		return argc && STR_EQ(argv[0], "help") ? 1 : 0;
	}

    if (STR_EQ(argv[0], "-v") || STR_EQ(argv[0], "--verbose")) {
        argv += 1;
        argc -= 1;
        verbose = true;
    }
    
    DisplayInfos displayInfos[MAX_DISPLAYS];
    DisplayInfos *selectedDisplay = NULL;

    // Display lister and selection
    if (STR_EQ(argv[0], "display")) {

        int connectedDisplays = getOnlineDisplayInfos(displayInfos);
        if (connectedDisplays == 0) {
            writeToStdOut(@"No external display found, aborting");
            return EXIT_FAILURE;
        }

        // Printing out display list
        if (STR_EQ(argv[1], "list") || STR_EQ(argv[1], "l")) {
            printDisplayInfos(displayInfos, connectedDisplays, (argc >= 3 && (STR_EQ(argv[2], "detailed") || STR_EQ(argv[2], "d"))));
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
        avService = getDefaultDisplayAVService();
    } else {
        avService = getDisplayAVService(selectedDisplay);
    }

    if (avService == NULL) {
        writeToStdOut(@"Could not find a suitable external display.\n");
        return EXIT_FAILURE;
    }

    if (argc < 2) {
        writeToStdOut(@"Missing parameter! Enter 'm1ddc help' for help!\n");
        return EXIT_FAILURE;
    }

    if (verbose) {
        writeToStdOut([NSString stringWithFormat:@"Using display: %@ [%@]\n", selectedDisplay->productName, selectedDisplay->uuid]);
    }

    DDCValue displayAttr = {-1, -1};
    UInt8 attrCode = attrCodeFromCommand(argv[1]);
    DDCPacket packet = createDDCPacket(attrCode);

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

        UInt8 writeValue = computeAttributeValue(argv[0], argv[2], displayAttr);

        if (writingOperation(avService, &packet, writeValue)) {
            return EXIT_FAILURE;
        }
        writeToStdOut([NSString stringWithFormat:@"%i\n", writeValue]);
        return EXIT_SUCCESS;
    }
    writeToStdOut(@"Use 'set', 'get', 'max', 'chg' as first parameter! Enter 'm1ddc help' for help!\n");
    return EXIT_FAILURE;
}