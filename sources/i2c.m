@import Foundation;

#include "ioregistry.h"
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

static UInt8 dataFromCommand(char *command) {
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

// Function to get ready for DDC operations
DDCPacket createDDCPacket(char *command) {
    DDCPacket packet = {};
    packet.data[2] = dataFromCommand(command);
    packet.inputAddr = packet.data[2] == INPUT_ALT ? ALTERNATE_INPUT_ADDRESS : DEFAULT_INPUT_ADDRESS;
    return packet;
}

void prepareDDCRead(UInt8* data) {
    data[0] = 0x82;
    data[1] = 0x01;
    data[3] = 0x6e ^ data[0] ^ data[1] ^ data[2] ^ data[3];
}

void prepareDDCWrite(UInt8* data, UInt8 newValue) {
    data[0] = 0x84;
    data[1] = 0x03;
    data[3] = (newValue) >> 8;
    data[4] = newValue & 255;
    data[5] = 0x6E ^ 0x51 ^ data[0] ^ data[1] ^ data[2] ^ data[3] ^ data[4];
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