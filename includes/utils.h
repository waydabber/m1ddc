#ifndef _UTILS_H_
#define _UTILS_H_

#define STR_EQ(s1, s2) (strcmp(s1, s2) == 0)

void writeToStdOut(NSString *text);
int getBytesUsed(UInt8 *data);

#endif