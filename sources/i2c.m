@import Foundation;

#include "i2c.h"
#include "utils.h"

static int getBytesUsed(UInt8* data) {
    int bytes = 0;
    for (int i = 0; i < (int)sizeof(data); ++i) {
        if (data[i] != 0) {
            bytes = i + 1;
        }
    }
    return bytes;
}

// Function to get ready for DDC operations for a specific display attribute
DDCPacket createDDCPacket(UInt8 attrCode) {
    DDCPacket packet = {};
    packet.data[2] = attrCode;
    packet.inputAddr = packet.data[2] == INPUT_ALT ? ALTERNATE_INPUT_ADDRESS : DEFAULT_INPUT_ADDRESS;
    return packet;
}

// Prepare DDC packet for read
void prepareDDCRead(UInt8* data) {
    data[0] = 0x82;
    data[1] = 0x01;
    data[3] = 0x6e ^ data[0] ^ data[1] ^ data[2] ^ data[3];
}

// Prepare DDC packet for write
void prepareDDCWrite(DDCPacket *packet, UInt8 newValue) {
    UInt8* data = packet->data;

    data[0] = 0x84;
    data[1] = 0x03;
    data[3] = (newValue) >> 8;
    data[4] = newValue & 255;
    data[5] = 0x6E ^ packet->inputAddr ^ data[0] ^ data[1] ^ data[2] ^ data[3] ^ data[4];
}


IOReturn performDDCRead(IOAVServiceRef avService, DDCPacket *packet) {
    memset(packet->data, 0, sizeof(UInt8) * DDC_BUFFER_SIZE);
    usleep(DDC_WAIT);
    return IOAVServiceReadI2C(avService, 0x37, packet->inputAddr, packet->data, 12);
}

IOReturn performDDCWrite(IOAVServiceRef avService, DDCPacket *packet) {
    IOReturn ret;

    for (int i = 0; i < DDC_ITERATIONS; ++i) {
        usleep(DDC_WAIT);
        if ((ret = IOAVServiceWriteI2C(avService, 0x37, packet->inputAddr, packet->data, getBytesUsed(packet->data)))) {
            return ret;
        }
    }
    return ret;
}


DDCValue convertI2CtoDDC(char *i2cBytes) {
    DDCValue displayAttr = {};
    NSData *i2cData = [NSData dataWithBytes:(const void *)i2cBytes length:(NSUInteger)11];
    NSRange maxValueRange = {7, 1};
    NSRange curValueRange = {9, 1};
    [[i2cData subdataWithRange:maxValueRange] getBytes:&displayAttr.maxValue length:sizeof(1)];
    [[i2cData subdataWithRange:curValueRange] getBytes:&displayAttr.curValue length:sizeof(1)];
    return displayAttr;
}