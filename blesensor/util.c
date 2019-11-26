//
//  util.c
//  blesensor
//
//  Created by jige003 on 2019/11/26.
//  Copyright © 2019 jige. All rights reserved.
//

#include "util.h"
#include <stdarg.h>

void verbose(const char *format, ...) {
    va_list args;
    va_start(args, format);
    vfprintf(stderr, format, args);
    va_end(args);
    fflush(stderr);
}


void usage(void) {
    verbose("usage: blesensor [ -f /tmp/ble.pcap ] | [ -c 37 ] | [ -p ] | [ -v ] | [ -h ]\n");
    verbose("\t -f pcap filename path\n");
    verbose("\t -c ble sniffe channel number\n");
    verbose("\t -p use fifo pipe mode; default path: /tmp/ble; wireshark command: wireshark -i /tmp/ble \n");
    verbose("\t -v show verbose\n");
    verbose("\t -h help\n");
    exit(1);
}
