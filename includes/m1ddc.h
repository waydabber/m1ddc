#ifndef _M1DDC_H_
#define _M1DDC_H_


struct I2CWriteData
{
	UInt8 buffer[256];
	UInt8 inputAddr;
};


struct I2CReadData {
	signed char curValue;
	signed char maxValue;
};

#endif