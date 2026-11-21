@import Darwin;
@import Foundation;
@import IOKit;
@import CoreGraphics;

#include "ioregistry.h"
#include "avservice.h"
#include "i2c.h"
#include "utils.h"


// -- Generic utility functions

static void writeToStdOut(NSString *text) {
    [text writeToFile:@"/dev/stdout" atomically:NO encoding:NSUTF8StringEncoding error:nil];
}

static void printUsage() {
    writeToStdOut([NSString stringWithFormat:
    @"Control an external display over DDC/CI on an Apple Silicon Mac using USB-C/DisplayPort\n"
    "Alt Mode or a supported built-in HDMI port.\n"
    "\n"
    "Usage\n"
    "  m1ddc [options] [display <selector>] <command> <control> [value]\n"
    "  m1ddc display list [all] [detailed]\n"
    "  m1ddc help\n"
    "\n"
    "Examples\n"
    "  m1ddc get luminance\n"
    "  m1ddc chg volume -10\n"
    "  m1ddc display 1 set contrast 50\n"
    "  m1ddc --read-wait 80 display serial=SALMQS134621 get input\n"
    "\n"
    "Options (before the command or display selector, in any order)\n"
    "  -v, --verbose     Print which display is used.\n"
    "  --read-wait ms    Wait 1 to %d ms before reading a DDC reply (default %d ms).\n"
    "                    Try a higher value if reads fail with 'no valid reply'.\n"
    "\n"
    "Commands\n"
    "  get <control>          Print the current value, e.g. 'get input'.\n"
    "  max <control>          Print the maximum value reported by the display.\n"
    "  set <control> <value>  Write the value directly and print 'Writing N' on success.\n"
    "  chg <control> <delta>  Add a signed delta to the current value, clamp the result\n"
    "                         to 0 through the reported maximum, then write it and print 'Writing N'.\n"
    "\n"
    "  get and max accept any control the display supports reading. chg needs both the current\n"
    "  and maximum values. Each read gets up to %d attempts. An 'Unsupported VCP code' reply\n"
    "  ends the read immediately. A failed read exits with status 1 and chg skips the write.\n"
    "\n"
    "Controls (aliases in parentheses, case-sensitive)\n"
    "  luminance (l)                Brightness, usually 0 to 100.\n"
    "  contrast (c)                 Contrast, usually 0 to 100.\n"
    "  red (r), green (g), blue (b) Red, green, or blue gain, usually 0 to 100.\n"
    "  volume (v)                   Volume, usually 0 to 100.\n"
    "  mute (m)                     on or 1 to mute, off or 2 to unmute.\n"
    "  standby (s)                  Numeric power mode (VCP 0xD6). Supported modes vary by display.\n"
    "  input (i)                    Input source. Common values are DP 1 = 15, DP 2 = 16,\n"
    "                               HDMI 1 = 17, HDMI 2 = 18, USB-C = 27.\n"
    "  input-alt (I)                Alternate input control on some LG displays. DP 1 = 208,\n"
    "                               DP 2 = 209, HDMI 1 = 144, HDMI 2 = 145, USB-C / DP 3 = 210.\n"
    "  pbp (p)                      PIP/PBP layout on some Dell displays (e.g. U3421W).\n"
    "                               Off = 0, small = 33, large = 34, 50/50 = 36, 26/74 = 43,\n"
    "                               74/26 = 44, 2x2 = 65.\n"
    "  pbp-input (pi)               Secondary Dell PIP/PBP input. DP 1 = 15, DP 2 = 16,\n"
    "                               HDMI 1 = 17, HDMI 2 = 18, HDMI 1 + HDMI 2 + DP 1 = 15953.\n"
    "  kvm (k)                      Dell KVM. USB 1-4 order = 1728, next device = 65280.\n"
    "  asus-kvm                     ASUS USB upstream (e.g. XG27UCDMG, Auto KVM disabled).\n"
    "                               USB-B = 2, USB-C = 3.\n"
    "\n"
    "Display selection\n"
    "  display list [detailed]      List displays from the macOS scan (up to %d online displays).\n"
    "  display N                    Select a number from 'display list', starting at 1.\n"
    "  display [method=]<id>        Select by identifier. Use 'display list detailed' for attributes.\n"
    "    id=<display_id>            uuid=<system_uuid> (default)       edid=<edid_uuid>\n"
    "    seid=<alphanumeric_serial>:<edid_uuid>\n"
    "    basic=<vendor>:<model>:<serial>\n"
    "    ext=<vendor>:<model>:<serial>:<manufacturer>:<alphanumeric_serial>:<product_name>\n"
    "    full=<vendor>:<model>:<serial>:<manufacturer>:<alphanumeric_serial>:<product_name>:<io_location>\n"
    "  display list all [detailed]  Scan up to %d external DDC services, including displays on another\n"
    "                               input. This list has its own numbering. Use 'display list' for N.\n"
    "  display serial=<serial>      Select by alphanumeric EDID serial when 'display list all' shows one.\n"
    "                               Control on an inactive input depends on the display.\n"
    "  List aliases                 l = list, a = all, d = detailed.\n",
    DDC_READ_WAIT_MAX_MS, DDC_READ_WAIT / 1000, DDC_READ_ATTEMPTS, MAX_DISPLAYS, MAX_AVSERVICES]);
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

static void printAVServiceInfos(AVServiceInfos *sinks, int nbSinks, bool detailed) {
    for (int i = 0; i < nbSinks; i++) {
        AVServiceInfos *sink = sinks + i;
        if (sink->edidStatus != kIOReturnSuccess) {
            writeToStdOut([NSString stringWithFormat:@"[%i] (EDID not readable: %s)\n", (i + 1), mach_error_string(sink->edidStatus)]);
            continue;
        }
        writeToStdOut([NSString stringWithFormat:@"[%i] %@ (%@) %@\n", (i + 1), sink->productName ?: @"Unknown Display",
            sink->alphNumSerial ?: @"-", sink->displayID ? @"" : @"- no matching macOS display"]);
        if (detailed) {
            writeToStdOut([NSString stringWithFormat:@" - Product name:  %@\n", sink->productName ?: @"Unknown Display"]);
            writeToStdOut([NSString stringWithFormat:@" - Manufacturer:  %@\n", sink->manufacturer]);
            writeToStdOut([NSString stringWithFormat:@" - AN Serial:     %@\n", sink->alphNumSerial ?: @""]);
            writeToStdOut([NSString stringWithFormat:@" - Vendor:        %u (0x%04x)\n", sink->vendor, sink->vendor]);
            writeToStdOut([NSString stringWithFormat:@" - Model:         %u (0x%04x)\n", sink->model, sink->model]);
            writeToStdOut([NSString stringWithFormat:@" - Serial:        %u (0x%04x)\n", sink->serial, sink->serial]);
            writeToStdOut([NSString stringWithFormat:@" - Display ID:    %@\n", sink->displayID ? [NSString stringWithFormat:@"%u", sink->displayID] : @"none (not driven by macOS)"]);
            writeToStdOut([NSString stringWithFormat:@" - Registry ID:   0x%llx\n", sink->registryID]);
        }
    }
}

// Function to handle the reading operation (get, max, chg)
// Retries until the reply is valid, up to DDC_READ_ATTEMPTS times; an invalid reply is never decoded.
// A display that answers "unsupported VCP code" is taken at its word, without asking again.
static DDCValue readingOperation(DDCTransport *transport, DDCPacket *packet) {
    DDCValue dummyAttr = {-1, -1};
    IOReturn err = kIOReturnSuccess;

    prepareDDCRead(packet);

    for (int attempt = 1; attempt <= DDC_READ_ATTEMPTS; ++attempt) {
        if (attempt > 1) {
            usleep(DDC_RETRY_WAIT);
        }
        err = performDDCWriteAtChipAddress(transport->service, transport->chipAddress, packet);
        if (err) {
            continue;
        }

        DDCPacket readPacket = {};
        readPacket.inputAddr = packet->inputAddr;

        err = performDDCReadAtChipAddress(transport->service, transport->chipAddress, &readPacket);
        if (err) {
            continue;
        }
        DDCReplyStatus reply = checkDDCReply(readPacket.data, packet->data[2]);
        if (reply == DDC_REPLY_OK) {
            return convertI2CtoDDC((char *)readPacket.data);
        }
        if (reply == DDC_REPLY_UNSUPPORTED) {
            writeToStdOut([NSString stringWithFormat:@"Unsupported VCP code 0x%02X: the display does not support this command\n", packet->data[2]]);
            return dummyAttr;
        }
    }

    if (err) {
        writeToStdOut([NSString stringWithFormat:@"DDC communication failure: %s\n", mach_error_string(err)]);
    } else {
        writeToStdOut(@"DDC communication failure: no valid reply\n");
    }
    return dummyAttr;
}

// Function to handle the writing operation (set, chg)
static int writingOperation(DDCTransport *transport, DDCPacket *packet, UInt16 newValue) {

    prepareDDCWrite(packet, newValue);

    IOReturn err = performDDCWriteAtChipAddress(transport->service, transport->chipAddress, packet);
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
    else if (STR_EQ(command, "kvm") || STR_EQ(command, "k")) { return KVM; }
    else if (STR_EQ(command, "asus-kvm")) { return ASUS_KVM; }
    return 0x00;
}

static UInt16 computeAttributeValue(char *command, char *arg, DDCValue displayAttr) {
    int newValue;

    if (STR_EQ(arg, "on") ) { newValue = 1; }
    else if (STR_EQ(arg, "off") ) { newValue = 2; }
    else { newValue = atoi(arg); }

    if (STR_EQ(command, "chg")) {
        newValue = displayAttr.curValue + newValue;
        if (newValue < 0 ) { newValue = 0; }
        if (newValue > displayAttr.maxValue ) { newValue = displayAttr.maxValue; }
    }

    return (UInt16)newValue;
}

int main(int argc, char** argv) {

    bool verbose = false;
    argv += 1;
    argc -= 1;

    // Let the option parser diagnose a missing --read-wait value.
    if (argc == 0 || (argc == 1 && !STR_EQ(argv[0], "--read-wait"))) {
        printUsage();
        return argc && STR_EQ(argv[0], "help") ? EXIT_FAILURE : EXIT_SUCCESS;
    }

    // Options come before the command, in any order. A command never starts with '-', so the first word
    // that doesn't ends the options (a later '-10', as in 'chg volume -10', is never looked at here).
    while (argc > 0 && argv[0][0] == '-') {
        if (STR_EQ(argv[0], "-v") || STR_EQ(argv[0], "--verbose")) {
            verbose = true;
            argv += 1;
            argc -= 1;
        } else if (STR_EQ(argv[0], "--read-wait")) {
            char *end = NULL;
            long ms = argc > 1 ? strtol(argv[1], &end, 10) : 0;
            if (argc < 2 || end == argv[1] || *end != '\0' || ms < 1 || ms > DDC_READ_WAIT_MAX_MS) {
                writeToStdOut([NSString stringWithFormat:@"--read-wait needs a whole number of milliseconds, 1 to %d! Enter 'm1ddc help' for help!\n", DDC_READ_WAIT_MAX_MS]);
                return EXIT_FAILURE;
            }
            ddcReadWait = (useconds_t)(ms * 1000);
            argv += 2;
            argc -= 2;
        } else {
            writeToStdOut([NSString stringWithFormat:@"Unknown option '%s'! Enter 'm1ddc help' for help!\n", argv[0]]);
            return EXIT_FAILURE;
        }
    }

    if (argc < 2) {
        writeToStdOut(@"Missing parameter! Enter 'm1ddc help' for help!\n");
        return EXIT_FAILURE;
    }

    DisplayInfos displayInfos[MAX_DISPLAYS];
    DisplayInfos *selectedDisplay = NULL;
    DisplayInfos directDisplay;

    DDCTransport transport = {
        .service = NULL,
        .chipAddress = DDC_CHIP_ADDRESS_DEFAULT,
    };

    // Display lister and selection
    if (STR_EQ(argv[0], "display")) {

        int connectedDisplays = getOnlineDisplayInfos(displayInfos);
        bool listing = STR_EQ(argv[1], "list") || STR_EQ(argv[1], "l");
        bool wholeSet = (listing && argc >= 3 && (STR_EQ(argv[2], "all") || STR_EQ(argv[2], "a")))
            || strncmp(argv[1], "serial=", 7) == 0;

        // The direct path enumerates every DDC-capable display, whether or not macOS is driving it
        if (wholeSet) {
            AVServiceInfos sinks[MAX_AVSERVICES];
            int nbSinks = getAVServiceInfos(sinks, MAX_AVSERVICES);
            matchAVServicesToDisplays(sinks, nbSinks, displayInfos, connectedDisplays);
            if (listing) {
                printAVServiceInfos(sinks, nbSinks, (argc >= 4 && (STR_EQ(argv[3], "detailed") || STR_EQ(argv[3], "d"))));
                releaseAVServiceInfos(sinks, nbSinks);
                return nbSinks > 0 ? EXIT_SUCCESS : EXIT_FAILURE;
            }
            AVServiceInfos *sink = selectAVService(sinks, nbSinks, argv[1] + 7);
            if (sink != NULL) {
                transport = getAVServiceDDCTransport(sink);
                fillDisplayInfosFromAVService(&directDisplay, sink);
                selectedDisplay = &directDisplay;
            }
            releaseAVServiceInfos(sinks, nbSinks);
            if (selectedDisplay == NULL || transport.service == NULL) {
                writeToStdOut(@"The specified display does not exist. Use 'display list all' to list every DDC-capable display and its serial!\n");
                return EXIT_FAILURE;
            }
        } else {
            if (connectedDisplays == 0) {
                writeToStdOut(@"No external display found, aborting");
                return EXIT_FAILURE;
            }

            // Printing out display list
            if (listing) {
                printDisplayInfos(displayInfos, connectedDisplays, (argc >= 3 && (STR_EQ(argv[2], "detailed") || STR_EQ(argv[2], "d"))));
                return EXIT_SUCCESS;
            }

            // Selecting display
            selectedDisplay = selectDisplay(displayInfos, connectedDisplays, argv[1]);
            if (selectedDisplay == NULL) {
                writeToStdOut(@"The specified display does not exist. Use 'display list' to list displays and use it's number (1, 2...) or its UUID to specify display!\n");
                return EXIT_FAILURE;
            }
        }

		argv += 2;
        argc -= 2;
    }

    // For unqualified commands, use the main display's matched service only
    // when it is positively identified as MCDP29xx. Otherwise preserve the
    // legacy default IOAVServiceCreate()/0x37 behavior.
    if (selectedDisplay == NULL) {
        int connectedDisplays = getOnlineDisplayInfos(displayInfos);
        CGDirectDisplayID mainDisplayID = CGMainDisplayID();

        for (int i = 0; i < connectedDisplays; ++i) {
            if (displayInfos[i].id != mainDisplayID) {
                continue;
            }

            DDCTransport mainTransport = getDisplayDDCTransport(displayInfos + i);
            if (mainTransport.service != NULL && mainTransport.chipAddress == DDC_CHIP_ADDRESS_MCDP29XX) {
                selectedDisplay = displayInfos + i;
                transport = mainTransport;
            } else if (mainTransport.service != NULL) {
                CFRelease(mainTransport.service);
            }
            break;
        }

        if (transport.service == NULL) {
            selectedDisplay = displayInfos;
            transport.service = getDefaultDisplayAVService();
        }
    } else if (transport.service == NULL) {
        transport = getDisplayDDCTransport(selectedDisplay);
    }

    if (transport.service == NULL) {
        writeToStdOut(@"Could not find a suitable external display.\n");
        return EXIT_FAILURE;
    }

    if (argc < 2) {
        writeToStdOut(@"Missing parameter! Enter 'm1ddc help' for help!\n");
        return EXIT_FAILURE;
    }

    if (verbose) {
        writeToStdOut([NSString stringWithFormat:@"Using display: %@ [%@]\n", selectedDisplay->productName, selectedDisplay->uuid ?: selectedDisplay->alphNumSerial ?: @"-"]);
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
        displayAttr = readingOperation(&transport, &packet);
        if (displayAttr.curValue == -1) {
            return EXIT_FAILURE;
        }
    }

    if (STR_EQ(argv[0], "get")) {
        writeToStdOut([NSString stringWithFormat:@"%i\n", displayAttr.curValue]);
        return EXIT_SUCCESS;
    }

    if (STR_EQ(argv[0], "max")) {
        writeToStdOut([NSString stringWithFormat:@"%i\n", displayAttr.maxValue]);
        return EXIT_SUCCESS;
    }

    if (STR_EQ(argv[0], "set") || STR_EQ(argv[0], "chg") ) {
        if (argc < 3) {
            writeToStdOut(@"Missing value! Enter 'm1ddc help' for help!\n");
            return EXIT_FAILURE;
        }

        UInt16 writeValue = computeAttributeValue(argv[0], argv[2], displayAttr);

        if (writingOperation(&transport, &packet, writeValue)) {
            return EXIT_FAILURE;
        }
        writeToStdOut([NSString stringWithFormat:@"Writing %i\n", writeValue]);
        return EXIT_SUCCESS;
    }
    writeToStdOut(@"Use 'set', 'get', 'max', 'chg' as first parameter! Enter 'm1ddc help' for help!\n");
    return EXIT_FAILURE;
}
