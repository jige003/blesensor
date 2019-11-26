//
//  pcap.h
//  blesensor
//
//  Created by jige003 on 2019/11/22.
//  Copyright © 2019 jige. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <pcap/pcap.h>

NS_ASSUME_NONNULL_BEGIN

@interface pcap : NSObject
@property (assign) pcap_t *handle;
@property (assign) pcap_dumper_t *dumper;
@property (assign) FILE *fp;
@property (assign) int fd;

- (BOOL)openFile:(NSString *)path;

- (BOOL) openPipe;

- (BOOL) fileHandle: (uint8*)buffer length:(NSInteger) length;

- (BOOL) pipeHandle: (uint8*)buffer length:(NSInteger) length;

- (BOOL)close;
@end


NS_ASSUME_NONNULL_END
