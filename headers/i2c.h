#ifndef _I2C_H
# define _I2C_H

# include "ioregistry.h"

# define DEFAULT_INPUT_ADDRESS		0x51
# define ALTERNATE_INPUT_ADDRESS	0x50

# define LUMINANCE	0x10
# define CONTRAST	0x12
# define VOLUME		0x62
# define MUTE		0x8D
# define INPUT		0x60
# define INPUT_ALT	0xF4			// Alternate address, used for LG exclusively?
# define STANDBY	0xD6
# define RED		0x16			// VCP Code - Video Gain (Drive): Red
# define GREEN		0x18			// VCP Code - Video Gain (Drive): Green
# define BLUE		0x1A			// VCP Code - Video Gain (Drive): Blue
# define PBP_INPUT	0xE8
# define PBP		0xE9
# define KVM		0xE7
# define ASUS_KVM	0xF3

# define DDC_WAIT			10000	// Depending on display this must be set to as high as 50000
# define DDC_ITERATIONS		2		// Depending on display this must be set higher
# define DDC_READ_WAIT		50000	// Default wait before reading a reply (--read-wait). DDC/CI asks for at least 40 ms;
									// 10 ms returned empty replies, MCDP29xx ones included
# define DDC_MCDP_READ_WAIT	DDC_READ_WAIT	// Previous name used by library callers
# define DDC_READ_WAIT_MAX_MS	1000	// Highest --read-wait accepted, in ms
# define DDC_READ_ATTEMPTS	4		// Times a read is retried until the reply is valid
# define DDC_RETRY_WAIT		50000	// Between read attempts
# define DDC_BUFFER_SIZE	256


typedef struct {
	UInt8 data[DDC_BUFFER_SIZE];
	UInt8 inputAddr;
} DDCPacket;

typedef struct {
	signed int curValue;
	signed int maxValue;
} DDCValue;

typedef enum {
	DDC_REPLY_INVALID,		// Not a reply to the request (empty, echoed, shifted, bad checksum): ask again
	DDC_REPLY_OK,			// A value
	DDC_REPLY_UNSUPPORTED,	// The display says it doesn't support the VCP code (result 0x01)
} DDCReplyStatus;

extern useconds_t	ddcReadWait;	// Wait before reading a reply, in µs; DDC_READ_WAIT unless --read-wait is given


DDCPacket	createDDCPacket(UInt8 attrCode);

void		prepareDDCRead(DDCPacket *packet);
void		prepareDDCWrite(DDCPacket *packet, UInt16 setValue);

IOReturn	performDDCWrite(IOAVServiceRef avService, DDCPacket *packet);
IOReturn	performDDCRead(IOAVServiceRef avService, DDCPacket *packet);
IOReturn	performDDCWriteAtChipAddress(IOAVServiceRef avService, UInt32 chipAddress, DDCPacket *packet);
IOReturn	performDDCReadAtChipAddress(IOAVServiceRef avService, UInt32 chipAddress, DDCPacket *packet);
DDCReplyStatus	checkDDCReply(UInt8 *data, UInt8 attrCode);

DDCValue	convertI2CtoDDC(char *i2cBytes);

// External functions

extern IOReturn	IOAVServiceReadI2C(IOAVServiceRef service, uint32_t chipAddress, uint32_t offset, void *outputBuffer, uint32_t outputBufferSize);
extern IOReturn IOAVServiceWriteI2C(IOAVServiceRef service, uint32_t chipAddress, uint32_t dataAddress, void *inputBuffer, uint32_t inputBufferSize);

#endif
