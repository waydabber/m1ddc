@import Darwin;
@import Foundation;
@import IOKit;

typedef CFTypeRef IOAVServiceRef;
extern IOAVServiceRef IOAVServiceCreate(CFAllocatorRef allocator);
extern IOReturn IOAVServiceCopyEDID(IOAVServiceRef service, CFDataRef* x2);
extern IOReturn IOAVServiceReadI2C(IOAVServiceRef service, uint32_t chipAddress, uint32_t offset, void* outputBuffer, uint32_t outputBufferSize);
extern IOReturn IOAVServiceWriteI2C(IOAVServiceRef service, uint32_t chipAddress, uint32_t dataAddress, void* inputBuffer, uint32_t inputBufferSize);

#define BRIGHTNESS 0x10
#define CONTRAST 0x12
#define VOLUME 0x62
#define MUTE 0x8D

#define DDC_WAIT 15000
#define DDC_ITERATIONS 3

int main(int argc, char** argv) {
    
    NSString *returnText =@"Controls volume, brightness, contrast of external Display connected via USB-C (DisplayPort Alt Mode) over DDC on an M1 Mac.\n"
    "\n"
    "Example usages:\n"
    "\n"
    " m1ddc set contrast 5 - Sets contrast to 5\n"
    " m1ddc get brightness - Returns current brightness\n"
    " m1ddc chg volume -10 - Decreases volume by 10\n"
    "\n"
    "Paramteres:\n"
    "\n"
    " set brightness n     - Sets brightness to n, where n is a number between 0 and the maximum value (usually 100).\n"
    " set contrast n       - Sets contrast to n, where n is a number between 0 and the maximum value (usually 100).\n"
    " set volume n         - Sets volume to n, where n is a number between 0 and the maximum value (usually 100).\n"
    "\n"
    " set mute on          - Sets mute on (you can use 1 instead of 'on')\n"
    " set mute off         - Sets mute off (you can use 2 instead of 'off')\n"
    "\n"
    " get brightness       - Returns current brightness (if supported by the display).\n"
    " get contrast         - Returns current contrast (if supported by the display).\n"
    " get volume           - Returns current volume (if supported by the display).\n"
    "\n"
    " max brightness       - Returns maximum brightness (if supported by the display, usually 100).\n"
    " max contrast         - Returns maximum contrast (if supported by the display, usually 100).\n"
    " max volume           - Returns maximum volume (if supported by the display, usually 100).\n"
    "\n"
    " chg brightness n     - Change brightness by n and returns the current value (requires current and max reading support).\n"
    " chg contrast n       - Change contrast by n and returns the current value (requires current and max reading support).\n"
    " chg volume n         - Change contrast by n and returns the current value (requires current and max reading support).\n"
    "\n"
    "You can also use 'b', 'v' instead of 'brightness', 'volume' etc.\n"
    ;
    int returnValue = 1;

    if (argc >= 3) {
        
        IOAVServiceRef avService = IOAVServiceCreate(kCFAllocatorDefault);
        
        if (!avService) {
            
            returnText = @"Could not find a suitable external display connected to an M1 Mac. :(!\n";
            goto cya;
            
        }
        
        IOReturn err;
        UInt8 data[256];
        memset(data, 0, sizeof(data));

        if ( !(strcmp(argv[2], "brightness")) || !(strcmp(argv[2], "b")) ) { data[2] = BRIGHTNESS; }
        else if ( !(strcmp(argv[2], "contrast")) || !(strcmp(argv[2], "c"))  ) { data[2] = CONTRAST; }
        else if ( !(strcmp(argv[2], "volume")) || !(strcmp(argv[2], "v"))  ) { data[2] = VOLUME; }
        else if ( !(strcmp(argv[2], "mute")) || !(strcmp(argv[2], "m"))  ) { data[2] = MUTE; }
        else {
            
            returnText = [NSString stringWithFormat:@"Use 'brightness', 'contrast', 'volume' or 'mute' as second parameter! Enter 'm1ddc help' for help!\n"];
            goto cya;
            
        }

        signed char curValue=-1;
        signed char maxValue=-1;
        
        if ( !(strcmp(argv[1], "get")) || !(strcmp(argv[1], "max")) || !(strcmp(argv[1], "chg")) ) {

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

            if ( !(strcmp(argv[1], "get")) ) {

                returnText = [NSString stringWithFormat:@"%i", curValue];
                returnValue = 0;
                goto cya;

            } else if ( !(strcmp(argv[1], "max")) ) {
                
                returnText = [NSString stringWithFormat:@"%i", maxValue];
                returnValue = 0;
                goto cya;

            }
        
        }

        if ( !(strcmp(argv[1], "set")) || !(strcmp(argv[1], "chg")) ) {
            
            if (argc != 4) {
                
                returnText = [NSString stringWithFormat:@"Third parameter should be a number! Enter 'm1ddc help' for help!\n"];
                goto cya;

            }
            
            int setValue;
            
            if ( !(strcmp(argv[3], "on")) ) { setValue=1; }
            else if ( !(strcmp(argv[3], "off")) ) { setValue=2; }
            else { setValue = atoi(argv[3]); }
            
            if ( !(strcmp(argv[1], "chg")) ) {
                
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

            if ( !(strcmp(argv[1], "chg")) ) {

                returnText = [NSString stringWithFormat:@"%i", setValue];
                returnValue = 0;
                goto cya;

            } else {
            
                returnText = @"";
                returnValue = 0;
                goto cya;
                
            }
            
        }
            
        returnText = @"Use 'set', 'get', 'max' or 'chg' as first parameter! Enter 'm1ddc help' for help!\n";
        goto cya;
            
    }
    
    cya:
        
    [returnText writeToFile:@"/dev/stdout" atomically:NO encoding:NSUTF8StringEncoding error:nil];
    return returnValue;

}
