#ifndef _I2C_H_
#define _I2C_H_

#define DEFAULT_INPUT_ADDRESS	0x51
#define ALTERNATE_INPUT_ADDRESS	0x50

#define LUMINANCE	0x10
#define CONTRAST	0x12
#define VOLUME		0x62
#define MUTE		0x8D
#define INPUT		0x60
#define INPUT_ALT	0xF4		// Alternate address, used for LG exclusively?
#define STANDBY		0xD6
#define RED			0x16		// VCP Code - Video Gain (Drive): Red
#define GREEN		0x18		// VCP Code - Video Gain (Drive): Green
#define BLUE		0x1A		// VCP Code - Video Gain (Drive): Blue
#define PBP_INPUT	0xE8
#define PBP			0xE9

#define DDC_WAIT		10000	// Depending on display this must be set to as high as 50000
#define DDC_ITERATIONS	2		// Depending on display this must be set higher

#define MAX_DISPLAYS	4		// Set this to 2 or 4 depending on the Apple Silicon Mac you're using

typedef CFTypeRef IOAVServiceRef;

typedef struct {
	UInt8 data[256];
	UInt8 inputAddr;
} DDCPacket;

typedef struct {
	signed char curValue;
	signed char maxValue;
} DDCValue;

typedef struct {
	IOAVServiceRef avService;
	NSString *edid;
	NSString *productName;
	NSString *serial;
	NSString *manufacturerID;
	// NSString *manufacturer;
	// NSString *manufacturerDate;
	// NSString *uuid; // -> Get from CGDirectDisplayID in CGDisplayCreateUUIDFromDisplayID(id) then CFUUIDCreateString(kCFAllocatorDefault, uuidValue)
	// NSString *input;
	// NSString *inputAlt;
	// NSString *standby;
	// NSString *luminance;
	// NSString *contrast;
	// NSString *volume;
	// NSString *mute;
	// NSString *red;
	// NSString *green;
	// NSString *blue;
	// NSString *pbpInput;
	// NSString *pbp;
} DisplayInfos;


DDCPacket createDDCPacket(char *command);
void prepareDDCRead(UInt8 *data);
void prepareDDCWrite(UInt8 *data, UInt8 setValue);
IOReturn performDDCWrite(IOAVServiceRef avService, DDCPacket *packet);
IOReturn performDDCRead(IOAVServiceRef avService, DDCPacket *packet);
DDCValue convertI2CtoDDC(char *i2cBytes);


extern IOAVServiceRef IOAVServiceCreate(CFAllocatorRef allocator);
extern IOAVServiceRef IOAVServiceCreateWithService(CFAllocatorRef allocator, io_service_t service);
extern IOReturn IOAVServiceReadI2C(IOAVServiceRef service, uint32_t chipAddress, uint32_t offset, void *outputBuffer, uint32_t outputBufferSize);
extern IOReturn IOAVServiceWriteI2C(IOAVServiceRef service, uint32_t chipAddress, uint32_t dataAddress, void *inputBuffer, uint32_t inputBufferSize);

#endif