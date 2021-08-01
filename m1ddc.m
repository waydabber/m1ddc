@import Darwin;
@import Foundation;
@import IOKit;

typedef CFTypeRef IOAVServiceRef;
extern IOAVServiceRef IOAVServiceCreate(CFAllocatorRef allocator);
extern IOAVServiceRef IOAVServiceCreateWithService(CFAllocatorRef allocator, io_service_t service);
extern IOReturn IOAVServiceReadI2C(IOAVServiceRef service, uint32_t chipAddress, uint32_t offset, void* outputBuffer, uint32_t outputBufferSize);
extern IOReturn IOAVServiceWriteI2C(IOAVServiceRef service, uint32_t chipAddress, uint32_t dataAddress, void* inputBuffer, uint32_t inputBufferSize);

#define BRIGHTNESS 0x10
#define CONTRAST 0x12
#define VOLUME 0x62
#define MUTE 0x8D
#define INPUT 0x60
#define STANDBY 0xD6

#define DDC_WAIT 10000 // depending on display this must be set to as high as 50000
#define DDC_ITERATIONS 2 // depending on display this must be set higher

int main(int argc, char** argv) {
    
    IOAVServiceRef avService;
    
    NSString *returnText =@"Controls volume, brightness, contrast, input of a single external Display connected via USB-C (DisplayPort Alt Mode) over DDC on an M1 Mac.\n"
    "Control of displays attached via the HDMI port or by other means is not currently supported.\n"
    "\n"
    "Example usages:\n"
    "\n"
    " m1ddc set contrast 5          - Sets contrast to 5\n"
    " m1ddc get brightness          - Returns current brightness\n"
    " m1ddc chg volume -10          - Decreases volume by 10\n"
    " m1ddc display 1 set volume 50 - Sets volume to 50 on Display 1\n"
    "\n"
    "Commands:\n"
    "\n"
    " set brightness n - Sets brightness to n, where n is a number between 0 and the maximum value (usually 100).\n"
    " set contrast n   - Sets contrast to n, where n is a number between 0 and the maximum value (usually 100).\n"
    " set volume n     - Sets volume to n, where n is a number between 0 and the maximum value (usually 100).\n"
    " set input n      - Sets input source to n, common values include:\n"
    "                    DisplayPort 1: 15, DisplayPort 2: 16, HDMI 1: 17 HDMI 2: 18, USB-C: 27.\n"
    "\n"
    " set mute on      - Sets mute on (you can use 1 instead of 'on')\n"
    " set mute off     - Sets mute off (you can use 2 instead of 'off')\n"
    "\n"
    " get brightness   - Returns current brightness (if supported by the display).\n"
    " get contrast     - Returns current contrast (if supported by the display).\n"
    " get volume       - Returns current volume (if supported by the display).\n"
    "\n"
    " max brightness   - Returns maximum brightness (if supported by the display, usually 100).\n"
    " max contrast     - Returns maximum contrast (if supported by the display, usually 100).\n"
    " max volume       - Returns maximum volume (if supported by the display, usually 100).\n"
    "\n"
    " chg brightness n - Changes brightness by n and returns the current value (requires current and max reading support).\n"
    " chg contrast n   - Changes contrast by n and returns the current value (requires current and max reading support).\n"
    " chg volume n     - Changes volume by n and returns the current value (requires current and max reading support).\n"
    "\n"
    " display list     - Lists displays.\n"
    " display n        - Chooses which display to control (use number 1, 2 etc.)\n"
    "\n"
    "You can also use 'b', 'v' instead of 'brightness', 'volume' etc.\n"
    ;
    int returnValue = 1;
    
    if (argc >= 3) {

        // Display lister and selection
        
        int s=0; // Indicate the presence of display selection (+ messy argument shifter...)

        if ( !(strcmp(argv[s+1], "display")) ) {
            
            io_iterator_t iter;
            io_service_t service = 0;
            io_registry_entry_t root = IORegistryGetRootEntry(kIOMasterPortDefault);
            kern_return_t kerr = IORegistryEntryCreateIterator(root, "IOService", kIORegistryIterateRecursively, &iter);
            
            if (kerr != KERN_SUCCESS) {
                IOObjectRelease(iter);
                returnText = [NSString stringWithFormat:@"Error on IORegistryEntryCreateIterator: %d", kerr];
                goto cya;
            }

            CFStringRef edidUUIDKey = CFStringCreateWithCString(kCFAllocatorDefault, "EDID UUID", kCFStringEncodingASCII);
            CFStringRef locationKey = CFStringCreateWithCString(kCFAllocatorDefault, "Location", kCFStringEncodingASCII);
            CFStringRef displayAttributesKey = CFStringCreateWithCString(kCFAllocatorDefault, "DisplayAttributes", kCFStringEncodingASCII);
            CFStringRef externalAVServiceLocation = CFStringCreateWithCString(kCFAllocatorDefault, "External", kCFStringEncodingASCII);

            returnText = @"";
            
            int i=1;
            bool noMatch = true;
            
            while ((service = IOIteratorNext(iter)) != MACH_PORT_NULL) {
                io_name_t name;
                IORegistryEntryGetName(service, name);
                if ( !strcmp(name, "AppleCLCD2") ) {

                    CFStringRef edidUUID = IORegistryEntrySearchCFProperty(service, kIOServicePlane, edidUUIDKey, kCFAllocatorDefault, kIORegistryIterateRecursively);

                    if ( !(edidUUID == NULL) ) {

                        if ( !(strcmp(argv[s+2], "list")) || !(strcmp(argv[s+2], "l")) ) {
                        
                            CFDictionaryRef displayAttrs = IORegistryEntrySearchCFProperty(service, kIOServicePlane, displayAttributesKey, kCFAllocatorDefault, kIORegistryIterateRecursively);
                                                    
                            if (displayAttrs ) {
                                NSDictionary* displayAttrsNS = (NSDictionary*)displayAttrs;
                                NSDictionary* productAttrs = [displayAttrsNS objectForKey:@"ProductAttributes"];
                                if (productAttrs) {
                                    returnText = [NSString stringWithFormat:@"%@%i - %@", returnText, i, [productAttrs objectForKey:@"ProductName"]];
                                }
                            }
                            returnText = [NSString stringWithFormat:@"%@ (%@)\n", returnText, edidUUID];
    
                        }
                        
                        if ( atoi(argv[s+2]) == i ) {
                            
                            s=2;
                            
                            while ((service = IOIteratorNext(iter)) != MACH_PORT_NULL) {
                                io_name_t name;
                                IORegistryEntryGetName(service, name);
                                if ( !strcmp(name, "DCPAVServiceProxy") ) {
                                
                                    avService = IOAVServiceCreateWithService(kCFAllocatorDefault, service);
                                    CFStringRef location = IORegistryEntrySearchCFProperty(service, kIOServicePlane, locationKey, kCFAllocatorDefault, kIORegistryIterateRecursively);

                                    if ( !( location == NULL || !avService || CFStringCompare(externalAVServiceLocation, location, 0) ) ) {
                                        noMatch = false;
                                        break;
                                    }
                                }
                            }
                        }
                        
                        i++;
                        
                    }
                }
            }

            if ( !(strcmp(argv[s+2], "list")) || !(strcmp(argv[s+2], "l")) ) {
            
                returnValue = 0;
                goto cya;
                
            } else if ( noMatch ) {
                
                returnText = @"The specified display does not exist. Use 'display list' to list displays and use it's number (1, 2...) to specify display!\n";
                returnValue = 0;
                goto cya;

            }
            
        } else {
            
            avService = IOAVServiceCreate(kCFAllocatorDefault);
            
        }
        
        // Get ready for DDC operations
        
        UInt8 data[256];
        memset(data, 0, sizeof(data));

        if ( !(strcmp(argv[s+2], "brightness")) || !(strcmp(argv[s+2], "b")) ) { data[2] = BRIGHTNESS; }
        else if ( !(strcmp(argv[s+2], "contrast")) || !(strcmp(argv[s+2], "c"))  ) { data[2] = CONTRAST; }
        else if ( !(strcmp(argv[s+2], "volume")) || !(strcmp(argv[s+2], "v"))  ) { data[2] = VOLUME; }
        else if ( !(strcmp(argv[s+2], "mute")) || !(strcmp(argv[s+2], "m"))  ) { data[2] = MUTE; }
        else if ( !(strcmp(argv[s+2], "input")) || !(strcmp(argv[s+2], "i"))  ) { data[2] = INPUT; }
        else if ( !(strcmp(argv[s+2], "standby")) || !(strcmp(argv[s+2], "s"))  ) { data[2] = STANDBY; }
        else {
            
            returnText = @"Use 'brightness', 'contrast', 'volume' or 'mute' as second parameter! Enter 'm1ddc help' for help!\n";
            goto cya;
            
        }

        signed char curValue=-1;
        signed char maxValue=-1;
        
        IOReturn err;
        
        if (!avService) {
            
            returnText = @"Could not find a suitable external display.\n";
            goto cya;
            
        }
        
        // Read stuff
        
        if ( !(strcmp(argv[s+1], "get")) || !(strcmp(argv[s+1], "max")) || !(strcmp(argv[s+1], "chg")) ) {

            data[0] = 0x82;
            data[1] = 0x01;
            data[3] = 0x6e ^ data[0] ^ data[1] ^ data[2] ^ data[3];
            
            for (int i = 0; i < DDC_ITERATIONS; ++i) {
                
                usleep(DDC_WAIT);
                err = IOAVServiceWriteI2C(avService, 0x37, 0x51, data, 4);
                
                if (err) {
                    
                    returnText = [NSString stringWithFormat:@"I2C communication failure: %s\n", mach_error_string(err)];
                    goto cya;
                    
                }
                
            }
                
            char i2cBytes[12];
            memset(i2cBytes, 0, sizeof(i2cBytes));

            usleep(DDC_WAIT);
            err = IOAVServiceReadI2C(avService, 0x37, 0x51, i2cBytes, 12);

            if (err) {
                
                returnText = [NSString stringWithFormat:@"I2C communication failure: %s\n", mach_error_string(err)];
                goto cya;
                
            }
            
            NSData *readData = [NSData dataWithBytes:(const void *)i2cBytes length:(NSUInteger)11];
            
            NSRange maxValueRange = {7, 1};
            NSRange currentValueRange = {9, 1};
            
            [[readData subdataWithRange:maxValueRange] getBytes:&maxValue length:sizeof(1)];
            [[readData subdataWithRange:currentValueRange] getBytes:&curValue length:sizeof(1)];

            if ( !(strcmp(argv[s+1], "get")) ) {

                returnText = [NSString stringWithFormat:@"%i\n", curValue];
                returnValue = 0;
                goto cya;

            } else if ( !(strcmp(argv[s+1], "max")) ) {
                
                returnText = [NSString stringWithFormat:@"%i\n", maxValue];
                returnValue = 0;
                goto cya;

            }
        
        }

        // Set stuff
        
        if ( !(strcmp(argv[s+1], "set")) || !(strcmp(argv[s+1], "chg")) ) {
            
            if (argc != s+4) {
                
                returnText = [NSString stringWithFormat:@"Missing value! Enter 'm1ddc help' for help!\n"];
                goto cya;

            }
            
            int setValue;
            
            if ( !(strcmp(argv[s+3], "on")) ) { setValue=1; }
            else if ( !(strcmp(argv[s+3], "off")) ) { setValue=2; }
            else { setValue = atoi(argv[s+3]); }
            
            if ( !(strcmp(argv[s+1], "chg")) ) {
                
                setValue = curValue + setValue;
                if (setValue < 0 ) { setValue=0; }
                if (setValue > maxValue ) { setValue=maxValue; }

            }
            
            data[0] = 0x84;
            data[1] = 0x03;
            data[3] = (setValue) >> 8;
            data[4] = setValue & 255;
            data[5] = 0x6E ^ 0x51 ^ data[0] ^ data[1] ^ data[2] ^ data[3] ^ data[4];
            
            for (int i = 0; i <= DDC_ITERATIONS; i++) {
                
                usleep(DDC_WAIT);
                err = IOAVServiceWriteI2C(avService, 0x37, 0x51, data, 6);
                
                if (err) {
                    
                    returnText = [NSString stringWithFormat:@"I2C communication failure: %s\n", mach_error_string(err)];
                    goto cya;
                    
                }
                
            }

            if ( !(strcmp(argv[s+1], "chg")) ) {

                returnText = [NSString stringWithFormat:@"%i\n", setValue];
                returnValue = 0;
                goto cya;

            } else {
            
                returnText = @"";
                returnValue = 0;
                goto cya;
                
            }
            
        }
            
        returnText = @"Use 'set', 'get', 'max', 'chg' as first parameter! Enter 'm1ddc help' for help!\n";
        goto cya;
            
    }
    
    cya:
        
    [returnText writeToFile:@"/dev/stdout" atomically:NO encoding:NSUTF8StringEncoding error:nil];
    return returnValue;

}
