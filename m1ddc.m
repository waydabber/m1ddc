@import Darwin;
@import Foundation;
@import IOKit;
@import CoreGraphics;

typedef CFTypeRef IOAVServiceRef;
extern IOAVServiceRef IOAVServiceCreate(CFAllocatorRef allocator);
extern IOAVServiceRef IOAVServiceCreateWithService(CFAllocatorRef allocator, io_service_t service);
extern IOReturn IOAVServiceReadI2C(IOAVServiceRef service, uint32_t chipAddress, uint32_t offset, void* outputBuffer, uint32_t outputBufferSize);
extern IOReturn IOAVServiceWriteI2C(IOAVServiceRef service, uint32_t chipAddress, uint32_t dataAddress, void* inputBuffer, uint32_t inputBufferSize);

#define LUMINANCE 0x10
#define CONTRAST 0x12
#define VOLUME 0x62
#define MUTE 0x8D
#define INPUT 0x60
#define INPUT_ALT 0xF4 // alternate address, used for LG exclusively?
#define STANDBY 0xD6
#define RED 0x16 // VCP Code - Video Gain (Drive): Red
#define GREEN 0x18 // VCP Code - Video Gain (Drive): Green
#define BLUE 0x1A // VCP Code - Video Gain (Drive): Blue
#define PBP_INPUT 0xE8
#define PBP 0xE9

#define DDC_WAIT 10000 // depending on display this must be set to as high as 50000
#define DDC_ITERATIONS 2 // depending on display this must be set higher


struct MainData {
	IOAVServiceRef avService;
	UInt8 data[256];
	UInt8 inputAddr;
	signed char curValue;
	signed char maxValue;
	int shift;
	int argc;
	char** argv;
}; 

// -- Generic utility functions

void writeToStdOut(NSString *text) {
    [text writeToFile:@"/dev/stdout" atomically:NO encoding:NSUTF8StringEncoding error:nil];
}

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

kern_return_t createIORegistryIterator(io_iterator_t* iter) {
    io_registry_entry_t root = IORegistryGetRootEntry(kIOMainPortDefault);
    kern_return_t kerr = IORegistryEntryCreateIterator(root, "IOService", kIORegistryIterateRecursively, iter);
    if (kerr != KERN_SUCCESS) {
        IOObjectRelease(*iter);
    }
    return kerr;
}

CFTypeRef getCFStringRef(io_service_t service, char* key) {
    CFStringRef cfstring = CFStringCreateWithCString(kCFAllocatorDefault, key, kCFStringEncodingASCII);
    return IORegistryEntrySearchCFProperty(service, kIOServicePlane, cfstring, kCFAllocatorDefault, kIORegistryIterateRecursively);
}


// -- AVService related

NSString* getDisplayIdentifier(io_service_t service, CFStringRef edidUUID) {
    NSString *productIdentifier = (NSString *)edidUUID;
    CFDictionaryRef displayAttrs = getCFStringRef(service, "DisplayAttributes");
    if (displayAttrs) {
        NSDictionary* displayAttrsNS = (NSDictionary*)displayAttrs;
        NSDictionary* productAttrs = [displayAttrsNS objectForKey:@"ProductAttributes"];
        if (productAttrs) {
            productIdentifier = [NSString stringWithFormat:@"%@:%@", [productAttrs objectForKey:@"AlphanumericSerialNumber"], productIdentifier];
        }
    }
    return productIdentifier;
}


void processDisplayAttributes(io_service_t service, CFStringRef edidUUID, int i) {
    NSString *productName = @"";
    CFDictionaryRef displayAttrs = getCFStringRef(service, "DisplayAttributes");
    if (displayAttrs) {
        NSDictionary* displayAttrsNS = (NSDictionary*)displayAttrs;
        NSDictionary* productAttrs = [displayAttrsNS objectForKey:@"ProductAttributes"];
        if (productAttrs) {
            productName = [productAttrs objectForKey:@"ProductName"];
        }
    }
    writeToStdOut([NSString stringWithFormat:@"[%i] %@ (%@)\n", i, productName, getDisplayIdentifier(service, edidUUID)]);
}


bool processAVService(io_service_t *service, io_iterator_t iter, CFStringRef externalAVServiceLocation, IOAVServiceRef *avService) {
    while ((*service = IOIteratorNext(iter)) != MACH_PORT_NULL) {
        io_name_t name;
        IORegistryEntryGetName(*service, name);
        if ( !strcmp(name, "DCPAVServiceProxy") ) {
            *avService = IOAVServiceCreateWithService(kCFAllocatorDefault, *service);
            CFStringRef location = getCFStringRef(*service, "Location");
            if ( !( location == NULL || !(*avService) || CFStringCompare(externalAVServiceLocation, location, 0) ) ) {
                return false;
            }
        }
    }
    return true;
}

// -- Input value handling

UInt8 dataFromInput(struct MainData *d) {
	char *arg = d->argv[d->shift + 2];
    if ( !strcmp(arg, "luminance") || !strcmp(arg, "l") ) { d->data[2] = LUMINANCE; }
    else if ( !strcmp(arg, "contrast") || !strcmp(arg, "c")  ) { d->data[2] = CONTRAST; }
    else if ( !strcmp(arg, "volume") || !strcmp(arg, "v")  ) { d->data[2] = VOLUME; }
    else if ( !strcmp(arg, "mute") || !strcmp(arg, "m")  ) { d->data[2] = MUTE; }
    else if ( !strcmp(arg, "input") || !strcmp(arg, "i")  ) { d->data[2] = INPUT; }
    else if ( !strcmp(arg, "input-alt") || !strcmp(arg, "I")  ) { d->data[2] = INPUT_ALT; d->inputAddr = 0x50; }
    else if ( !strcmp(arg, "standby") || !strcmp(arg, "s")  ) { d->data[2] = STANDBY; }
    else if ( !strcmp(arg, "red") || !strcmp(arg, "r") ) { d->data[2] = RED; }
    else if ( !strcmp(arg, "green") || !strcmp(arg, "g") ) { d->data[2] = GREEN; }
    else if ( !strcmp(arg, "blue") || !strcmp(arg, "b") ) { d->data[2] = BLUE; }
    else if ( !strcmp(arg, "pbp") || !strcmp(arg, "p") ) { d->data[2] = PBP; }
    else if ( !strcmp(arg, "pbp-input") || !strcmp(arg, "pi") ) { d->data[2] = PBP_INPUT; }
    else {
        return 1;
    }
    return 0;
}

int getSetValue(struct MainData* d) {
    if (d->argc != d->shift + 4) {
        return -1;
    }

    int setValue;
	char *command = d->argv[d->shift + 1];
	char *arg = d->argv[d->shift + 3];

    if ( !strcmp(arg, "on") ) { setValue = 1; }
    else if ( !strcmp(arg, "off") ) { setValue = 2; }
    else { setValue = atoi(arg); }

    if ( !strcmp(command, "chg") ) {
        setValue = d->curValue + setValue;
        if (setValue < 0 ) { setValue = 0; }
        if (setValue > d->maxValue ) { setValue = d->maxValue; }
    }

    return setValue;
}

// -- Data preparation and reading

void prepareDataForRead(UInt8* data) {
    data[0] = 0x82;
    data[1] = 0x01;
    data[3] = 0x6e ^ data[0] ^ data[1] ^ data[2] ^ data[3];
}

void prepareDataForWrite(UInt8* data, UInt8 setValue) {
    data[0] = 0x84;
    data[1] = 0x03;
    data[3] = (setValue) >> 8;
    data[4] = setValue & 255;
    data[5] = 0x6E ^ 0x51 ^ data[0] ^ data[1] ^ data[2] ^ data[3] ^ data[4];
}

int getBytesUsed(UInt8* data) {
    int bytes = 0;
    for (int i = 0; i < sizeof(data); ++i) {
        if (data[i] != 0) {
            bytes = i + 1;
        }
    }
    return bytes;
}

NSData* extractValues(struct MainData* d, char *i2cBytes) {
    NSData *readData = [NSData dataWithBytes:(const void *)i2cBytes length:(NSUInteger)11];
    NSRange maxValueRange = {7, 1};
    NSRange currentValueRange = {9, 1};

    [[readData subdataWithRange:maxValueRange] getBytes:&d->maxValue length:sizeof(1)];
    [[readData subdataWithRange:currentValueRange] getBytes:&d->curValue length:sizeof(1)];
    return readData;
}

// -- I2C communication

IOReturn writeToI2C(struct MainData* d) {
    IOReturn err;

    for (int i = 0; i < DDC_ITERATIONS; ++i) {
        usleep(DDC_WAIT);
        err = IOAVServiceWriteI2C(d->avService, 0x37, d->inputAddr, d->data, getBytesUsed(d->data));
        if (err) {
            return err;
        }
    }
    return err;
}

IOReturn readFromI2C(struct MainData* d, char* i2cBytes) {
    usleep(DDC_WAIT);
    return IOAVServiceReadI2C(d->avService, 0x37, d->inputAddr, i2cBytes, 12);
}



// ----------
// -- Main --

// Function to handle the display lister and selection
int displayListerAndSelection(struct MainData *d) {

    if (d->argc == 4) {
        writeToStdOut(@"No command specified. Please use `list` to list displays, or specify a display number to control\n");
        return 1;
    }

    io_iterator_t iter;
    io_service_t service = 0;

    // Creating IORegistry iterator
	kern_return_t kerr = createIORegistryIterator(&iter);
    if (kerr != KERN_SUCCESS) {
        writeToStdOut([NSString stringWithFormat:@"Error on IORegistryEntryCreateIterator: %d", kerr]);
        return 1;
    }

	// Creating AVService
    CFStringRef externalAVServiceLocation = CFStringCreateWithCString(kCFAllocatorDefault, "External", kCFStringEncodingASCII);
    int i = 1;
    bool noMatch = true;
	char *command = d->argv[d->shift + 2];

	// Iterating through IORegistry
    while ((service = IOIteratorNext(iter)) != MACH_PORT_NULL) {
        io_name_t name;
        IORegistryEntryGetName(service, name);
		// Checking for AppleCLCD2 or IOMobileFramebufferShim
        if (!strcmp(name, "AppleCLCD2") || !strcmp(name, "IOMobileFramebufferShim")) {
            CFStringRef edidUUID = getCFStringRef(service, "EDID UUID");
            if ( edidUUID != NULL ) {

				// Printing out display list
                if ( !strcmp(command, "list") || !strcmp(command, "l") ) {
                    processDisplayAttributes(service, edidUUID, i);
                }
				// Selecting display
				CFStringRef targetIdentifier = CFStringCreateWithCString(kCFAllocatorDefault, command, kCFStringEncodingASCII);
                if ( atoi(command) == i || CFEqual(targetIdentifier, getDisplayIdentifier(service, edidUUID)) ) {
                    noMatch = processAVService(&service, iter, externalAVServiceLocation, &d->avService);
                }
            	i++;
            }
        }
    }

    if ( !strcmp(command, "list") || !strcmp(command, "l")) {
		return -1;
	} else if ( noMatch ) {
        writeToStdOut(@"The specified display does not exist. Use 'display list' to list displays and use it's number (1, 2...) or its SN:UUID to specify display!\n");
        return 1;
    }
    return 0;
}

// Function to get ready for DDC operations
int prepareForDDCOperations(struct MainData* d) {
	// Clearing data buffer
	memset(d->data, 0, sizeof(d->data));
	// Copying input arguments to data buffer
    int err = dataFromInput(d);
    if (err) {
        writeToStdOut(@"Use 'luminance', 'contrast', 'volume' or 'mute' as second parameter! Enter 'm1ddc help' for help!\n");
        return 1;
    }
	return 0;
}

// Function to handle the reading operation (get, max, chg)
int readingOperation(struct MainData* d) {

    prepareDataForRead(d->data);

	// Performing I2C write operation
    IOReturn err = writeToI2C(d);
    if (err) {
        writeToStdOut([NSString stringWithFormat:@"I2C communication failure: %s\n", mach_error_string(err)]);
        return 1;
    }

    char i2cBytes[12];
    memset(i2cBytes, 0, sizeof(i2cBytes));

	// Performing I2C read operation
    err = readFromI2C(d, i2cBytes);
    if (err) {
        writeToStdOut([NSString stringWithFormat:@"I2C communication failure: %s\n", mach_error_string(err)]);
        return 1;
    }

	// Extracting values from read data
    NSData *readData = extractValues(d, i2cBytes);
	char *command = d->argv[d->shift + 1];

	// Printing out the result
    if ( !(strcmp(command, "get")) ) {
        writeToStdOut([NSString stringWithFormat:@"%i\n", d->curValue]);
    } else if ( !(strcmp(command, "max")) ) {
        writeToStdOut([NSString stringWithFormat:@"%i\n", d->maxValue]);
    }
    return 0;
}

// Function to handle the writing operation (set, chg)
int writingOperation(struct MainData* d) {
    // Copying input arguments to data buffer
    int setValue = getSetValue(d);
    if (setValue == -1) {
        writeToStdOut([NSString stringWithFormat:@"Missing value! Enter 'm1ddc help' for help!\n"]);
        return 1;
    }

    // Preparing data buffer for write
    prepareDataForWrite(d->data, setValue);

    // Performing I2C write operation
    IOReturn err = writeToI2C(d);
    if (err) {
        writeToStdOut([NSString stringWithFormat:@"I2C communication failure: %s\n", mach_error_string(err)]);
        return 1;
    }

	char *command = d->argv[d->shift + 1];
    if ( !(strcmp(command, "chg")) ) {
        writeToStdOut([NSString stringWithFormat:@"%i\n", setValue]);
    }
    return 0;
}



int main(int argc, char** argv) {


	if (argc < 3) {
		printUsage();
		return argc > 1 && !strcmp(argv[1], "help") ? 1 : 0;
	}

	struct MainData d;

    d.argc = argc;
	d.argv = argv;
	d.inputAddr = 0x51;
	d.curValue = -1;
	d.maxValue = -1;
	d.shift = 0;

    // Display lister and selection

    if ( !(strcmp(argv[d.shift + 1], "display")) ) {
        int ret = displayListerAndSelection(&d);
		if (ret != 0) {
			return ret == 1 ? 1 : 0;
		}
		d.shift = 2;
    }


	d.avService = IOAVServiceCreate(kCFAllocatorDefault);
    if (!d.avService) {
        writeToStdOut(@"Could not find a suitable external display.\n");
        return 1;
    }

	if ( strcmp(argv[d.shift + 1], "get") && strcmp(argv[d.shift + 1], "max") && strcmp(argv[d.shift + 1], "chg") && strcmp(argv[d.shift + 1], "set") && strcmp(argv[d.shift + 1], "chg") ) {
		writeToStdOut(@"Use 'set', 'get', 'max', 'chg' as first parameter! Enter 'm1ddc help' for help!\n");
    	return 1;
    }
		
	int err = prepareForDDCOperations(&d);
    if (err) return err;

    if ( !strcmp(argv[d.shift + 1], "get") || !strcmp(argv[d.shift + 1], "max") || !strcmp(argv[d.shift + 1], "chg") ) {
        err = readingOperation(&d);
    }
	if ( !strcmp(argv[d.shift + 1], "set") || !strcmp(argv[d.shift + 1], "chg") ) {    
		err = writingOperation(&d);
    }
    
}