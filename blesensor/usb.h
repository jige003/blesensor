//
//  usb.h
//  blesensor
//
//  Created by jige003 on 2019/11/20.
//  Copyright © 2019 jige. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/IOCFPlugIn.h>
#import <IOKit/usb/IOUSBLib.h>
#import <IOKit/usb/USB.h>

NS_ASSUME_NONNULL_BEGIN


@interface usb : NSObject

@property (assign) mach_port_t masterPort;
@property (assign) io_service_t service;
@property (assign) IOUSBInterfaceInterface245 **interfaceInterface;
@property (assign) NSInteger control_index;
@property (assign) NSInteger bulk_index;
@property (assign) NSInteger  maxPacketSize;


- (void) listdevs;

- (BOOL) getDevById: (NSInteger) vid pid: (NSInteger) pid;

- (BOOL)controlRequest:(IOUSBDevRequest *)request;

- (BOOL)start: (NSInteger)channel;

- (void) handle: (NSString* )filename  ispipe: (NSInteger) ispipe  v: (NSInteger)v;

@end

NS_ASSUME_NONNULL_END
