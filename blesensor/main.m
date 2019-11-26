//
//  main.m
//  blesensor
//
//  Created by jige003 on 2019/11/20.
//  Copyright © 2019 jige. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "usb.h"
#import "util.h"


#define VID 0x0451
#define PID 0x16b3


int main(int argc, const char * argv[]) {
    @autoreleasepool {
        int channel = 0;
        int ispipe = 0;
        int v = 0;
        NSString *filename = nil;
        
        {
            int optch;
            extern char *optarg;
            extern int optind;
            extern int opterr;
            while ((optch = getopt(argc, (char **)argv, "c:f:pvh")) != -1) {
                switch (optch) {
                    case 'c':
                        channel = atoi(optarg);
                        if (channel < 0 || channel > 39) {
                            verbose("%s: channel number is out of range\n", argv[0]);
                            exit(1);
                        }
                        break;
                    case 'f':
                        filename = [NSString stringWithUTF8String:optarg];
                        break;
                    case 'p':
                        ispipe = 1;
                        break;
                    case 'v':
                        v = 1;
                        break;
                    case 'h':
                        usage();
                        break;
                    default:
                        exit(1);
                        break;
                }
            }
            argc -= optind;
            argv += optind;
        }
        
        usb *xusb = [[usb alloc] init];
        
        if(![xusb getDevById:VID pid:PID]){
            verbose("cannot get cc2540 usb dongle\n");
            exit(1);
        }
        if (![xusb start: channel]){
            verbose("cannot sniffe on channel:%d\n", channel);
        }
                

        if (!filename) {
            filename = @"/tmp/ble.pcap";
            verbose("use default filename:%s\n", [filename UTF8String]);
        }

        [xusb handle:filename ispipe:ispipe v:v];
        
    }
    return 0;
}
