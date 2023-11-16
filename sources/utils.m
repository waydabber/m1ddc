@import Foundation;

void writeToStdOut(NSString *text) {
    [text writeToFile:@"/dev/stdout" atomically:NO encoding:NSUTF8StringEncoding error:nil];
}

int getBytesUsed(UInt8* data) {
    int bytes = 0;
    for (int i = 0; i < (int)sizeof(data); ++i) {
        if (data[i] != 0) {
            bytes = i + 1;
        }
    }
    return bytes;
}