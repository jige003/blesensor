//
//  pcap.m
//  blesensor
//
//  Created by jige003 on 2019/11/22.
//  Copyright © 2019 jige. All rights reserved.
//

#import "pcap.h"
#import <sys/stat.h>

// https://wiki.wireshark.org/Development/LibpcapFileFormat
typedef struct pcap_hdr_s
{
    uint32_t magic_number;        /* magic number */
    uint16_t version_major;        /* major version number */
    uint16_t version_minor;        /* minor version number */
    int32_t thiszone;            /* GMT to local correction */
    uint32_t sigfigs;            /* accuracy of timestamps */
    uint32_t snaplen;            /* max length of captured packets, in octets */
    uint32_t network;            /* data link type */
} pcap_hdr_t;

typedef struct pcap_sf_pkthdr
{
    uint32_t ts_sec;            /* timestamp seconds */
    uint32_t ts_usec;            /* timestamp microseconds */
    uint32_t caplen;            /* number of octets of packet saved in file */
    uint32_t len;            /* actual length of packet */
} pcap_sf_pkthdr_t;


static const pcap_hdr_t pcap_hdr = {
    .magic_number = 0xA1B2C3D4,    // native byte ordering
    .version_major = 2,            // current version is 2.4
    .version_minor = 4,
    .thiszone = 0,                // GMT
    .sigfigs = 0,                // zero value for sig figs as standard
    .snaplen = 4096,                // max 802.15.4 packet length
    .network = 256                // IEEE 802.15.4
};

@implementation pcap

- (instancetype)init {
    self = [super init];
    
    if (!self) {
        return nil;
    }
    
   
    _fp = nil;
    _fd = nil;
    
    return self;
}

- (void)dealloc {
    [self close];
    
    _fp = nil;
    _fd = nil;
}

- (BOOL)openFile:(NSString *)path {
    const char * cpath =[path UTF8String];
    FILE *tfp = fopen(cpath, "wb");
    fwrite(&pcap_hdr, sizeof(pcap_hdr), 1, tfp);
    self.fp = tfp;

    return YES;
}

- (BOOL) openPipe{
    char * myfifo = "/tmp/ble";
    mkfifo(myfifo, 0666);
    int tfd = open(myfifo, O_WRONLY | O_NONBLOCK);
    
    write(tfd, &pcap_hdr, sizeof(pcap_hdr));
    
    self.fd = tfd;
    return YES;
}

- (uint8*) parse: (uint8*) buffer length: (NSInteger) length sf_hdr:(pcap_sf_pkthdr_t *)sf_hdr   {
    if (*buffer != 0x00 || length < 10) {
        return nil;
    }
    
    struct pcap_pkthdr header;
          
    uint16 flen;
    memcpy((void*)&flen, (void*)(buffer + 1 ), 2);
          
    uint32 timestamp;
    memcpy((void*)&timestamp, (void*)(buffer + 3 ), 4);
          

    uint8 rssi;
    memcpy((void*)&rssi, (void*)(buffer + length -  2 ), 1);
          
    uint8 flags;
    memcpy((void*)&flags, (void*)(buffer + length -  1 ), 1);
       
    uint32 plen = (uint32)length - 10;
          

    const time_t nanoSeconds = 1000000000;
    const time_t microSeconds = 1000000;
    const time_t nanoToMicro = nanoSeconds / microSeconds;
    struct timeval packetTimestamp;
    packetTimestamp.tv_sec = (time_t)timestamp / nanoSeconds;
    packetTimestamp.tv_usec = (timestamp % nanoSeconds) / nanoToMicro;
       
       
    header.caplen = (uint32)length;
    header.len = (uint32)length;
    header.ts = packetTimestamp;
       
    uint8* body = (uint8*) malloc(length);
       
    memset(body, 0x00, 10);
    body[0] = flags & 0x7f;
    body[1] = rssi;
    body[8] = 0x03;
    body[9] = 0x00;
    memcpy(body + 10, buffer + 8, plen);
       
    sf_hdr->ts_sec  = (bpf_int32)header.ts.tv_sec;
    sf_hdr->ts_usec = (bpf_int32)header.ts.tv_usec;
    sf_hdr->caplen     = header.caplen;
    sf_hdr->len        = header.len;
    
    #ifdef DEBUG
            NSLog(@"length:%ld type:%x  flen:%d plen:%d preamble:%d rssi:%d flags:%d", length, buffer[0], flen, plen,  *(buffer + 7), rssi, flags & 0x7f);
    #endif
    
    return body;
}

- (BOOL) pipeHandle: (uint8*) buffer length:(NSInteger) length {
    pcap_sf_pkthdr_t sf_hdr;
    uint8* body = [self parse:buffer length:length sf_hdr:&sf_hdr];
    
    if (!body) {
        return NO;
    }
    
    write(self.fd, &sf_hdr, sizeof(sf_hdr));
    write(self.fd, body, length);
    
    return YES;

}


- (BOOL)fileHandle: (uint8*) buffer length:(NSInteger)length {
    
    pcap_sf_pkthdr_t sf_hdr;
    uint8* body = [self parse:buffer length:length sf_hdr:&sf_hdr];
    
    if (!body) {
        return NO;
    }
    
    (void)fwrite(&sf_hdr, sizeof(sf_hdr), 1,self.fp);
    (void)fwrite(body, length, 1, self.fp);
    fflush(self.fp);
    
    return YES;
}




- (BOOL)close {
   
    if (self.fp) {
        fclose(self.fp);
    }
    
    if (self.fd){
        close(self.fd);
    }
    
    self.fd = nil;
    self.fp = nil;
   
    
    return YES;
}
@end
