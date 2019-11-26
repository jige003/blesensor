//
//  usb.m
//  blesensor
//
//  Created by jige003 on 2019/11/20.
//  Copyright © 2019 jige. All rights reserved.
//

#import "usb.h"
#import "pcap.h"
#import "util.h"

@implementation usb

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    _masterPort = 0;
    
    kern_return_t kr = IOMasterPort(MACH_PORT_NULL, &_masterPort);
    if (kr != KERN_SUCCESS) {
        NSLog (@"Error: Couldn't create a master I/O Kit port(%08x)", kr);
        exit(1);
    }
#ifdef DEBUG
    NSLog(@"masterPort:%x", self.masterPort);
#endif
    return self;
}


- (void) listdevs {
    
    CFMutableDictionaryRef matchingDict;
    matchingDict = IOServiceMatching (kIOUSBDeviceClassName);
    if (!matchingDict)
    {
        NSLog (@"Error: Couldn't create a USB matching dictionary");
        mach_port_deallocate(mach_task_self(), _masterPort);
        exit(1);
    }
    
    io_iterator_t iterator;
    IOServiceGetMatchingServices (kIOMasterPortDefault, matchingDict, &iterator);
    
    io_service_t usbDevice;
    kern_return_t kr;
    
    while ((usbDevice = IOIteratorNext (iterator) != 0))
    {
        IOCFPlugInInterface **plugInInterface = NULL;
        SInt32 theScore;
        
        kr = IOCreatePlugInInterfaceForService(usbDevice, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &plugInInterface, &theScore);
        if ((kIOReturnSuccess != kr) || !plugInInterface){
            NSLog(@"Unable to create a plug-in (%08x)\n", kr);
            continue;
            
        }
            
        IOUSBDeviceInterface182 **dev = NULL;
        HRESULT result = (*plugInInterface)->QueryInterface(plugInInterface, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID), (LPVOID)&dev);

        if (result || !dev)
            NSLog(@"Couldn't create a device interface (%08x)\n", (int) result);

        UInt16 vendorId;
        UInt16 productId;
        UInt16 releaseId;

        (*dev)->GetDeviceVendor(dev, &vendorId);
        (*dev)->GetDeviceProduct(dev, &productId);
        (*dev)->GetDeviceReleaseNumber(dev, &releaseId);

        UInt8 stringIndex;
        (*dev)->USBGetProductStringIndex(dev, &stringIndex);

        IOUSBConfigurationDescriptorPtr descriptor;
        (*dev)->GetConfigurationDescriptorPtr(dev, stringIndex, &descriptor);
    
        io_name_t deviceName;
        kr = IORegistryEntryGetName (usbDevice, deviceName);
        if (kr != KERN_SUCCESS)
        {
            NSLog (@"fail 0x%8x", kr);
            deviceName[0] = '\0';
        }

        NSString * name = [NSString stringWithCString:deviceName encoding:NSASCIIStringEncoding];

        CFTypeRef data = IORegistryEntrySearchCFProperty(usbDevice, kIOServicePlane, CFSTR("BSD Name"), kCFAllocatorDefault, kIORegistryIterateRecursively);

        NSString* bsdName = (__bridge NSString*)data ;

        NSString* attributeString = @"";

        if(bsdName)
            attributeString = [NSString stringWithFormat:@"name: %@, bsdName: %@,vendorId: 0x%x, productId: 0x%x,releaseId: 0x%x", name, bsdName, vendorId, productId, releaseId];
        else
            attributeString = [NSString stringWithFormat:@"name: %@, vendorId: 0x%x, productId: 0x%x,releaseId: 0x%x", name, vendorId, productId, releaseId];
#ifdef DEBUG
        NSLog(@"%@", attributeString);
#endif
        IOObjectRelease(usbDevice);
        (*plugInInterface)->Release(plugInInterface);
        (*dev)->Release(dev);

    }

    //mach_port_deallocate(mach_task_self(), _masterPort);
    //_masterPort = 0;
}




- (BOOL) getDevById: (NSInteger) vid pid: (NSInteger) pid {
    NSMutableDictionary *matching = (__bridge NSMutableDictionary *)IOServiceMatching(kIOUSBDeviceClassName);
    matching[@kUSBVendorID] = @(vid);
    matching[@kUSBProductID] = @(pid);
    
    io_iterator_t iterator = 0;
    #ifdef DEBUG
    NSLog(@"self.masterPort:%x", self.masterPort);
#endif
    IOServiceGetMatchingServices(self.masterPort, (__bridge CFDictionaryRef)matching, &iterator);
    
    
    io_service_t service = 0;
    while ((service = IOIteratorNext(iterator)) != 0) {
#ifdef DEBUG
        NSLog(@"dev service:%x", service);
#endif
        break;
        
    }
    IOObjectRelease(iterator);
    
    IOReturn result;
    IOCFPlugInInterface **pluginInterface = nil;
    SInt32 score = 0;
 #ifdef DEBUG
    NSLog(@"service: %x", service);
#endif
    
    result = IOCreatePlugInInterfaceForService(service, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &pluginInterface, &score);
    if (result != KERN_SUCCESS || pluginInterface == nil) {
        NSLog(@"1");
        return NO;
    }
    
    

    IOUSBDeviceInterface245 **deviceInterface = nil;
    result = (*pluginInterface)->QueryInterface(pluginInterface, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID245), (LPVOID)&deviceInterface);
    IODestroyPlugInInterface(pluginInterface);
    if (result != KERN_SUCCESS || deviceInterface == nil) {
        return NO;
    }

    result = (*deviceInterface)->USBDeviceOpen(deviceInterface);
    if (result != KERN_SUCCESS) {
        (*deviceInterface)->Release(deviceInterface);
        return NO;
    }
    
    if (![self initConfig:deviceInterface]){
        return NO;
    }
    
    if (![self initInterface:deviceInterface]){
        return NO;
    }
    
    if (![self initEndAddr]) {
        return NO;
    }
    
    return YES;
}


- (BOOL)controlRequest:(IOUSBDevRequest *)request {
    if (!self.interfaceInterface) {
        return NO;
    }
    IOUSBInterfaceInterface245 **interfaceInterface = self.interfaceInterface;
    IOReturn result = (*interfaceInterface)->ControlRequest(interfaceInterface, self.control_index, request);
    if (result != KERN_SUCCESS) {
        return NO;
    }
    
    return YES;
}


- (BOOL)clear_bulk {
    if (!self.interfaceInterface) {
        return NO;
    }
    IOUSBInterfaceInterface245 **interfaceInterface = self.interfaceInterface;
    IOReturn result = (*interfaceInterface)->ClearPipeStall(interfaceInterface, self.bulk_index);
    if (result != KERN_SUCCESS) {
        return NO;
    }
    
    return YES;
}

- (NSInteger) read: (void*) buffer length: (NSInteger) length {
    if (!self.interfaceInterface) {
        return NO;
    }
    IOUSBInterfaceInterface245 **interfaceInterface = self.interfaceInterface;
    UInt32 rlen = (UInt32)length;
    IOReturn result = (*interfaceInterface)->ReadPipe(interfaceInterface, self.bulk_index, buffer, &rlen);
    
    if (result != KERN_SUCCESS) {
        return -1;
    }
    return (NSInteger)rlen;
    
}

- (void) handle: (NSString* )filename  ispipe: (NSInteger) ispipe  v: (NSInteger)v {
    
    pcap *pcapt = [[pcap alloc] init];
    if (filename) {
        if (![pcapt openFile:filename]) {
            verbose("cannot open filename:%s\n", [filename UTF8String]);
            exit(1);
        }
    }
    
    if (ispipe) {
        if (![pcapt openPipe]){
            verbose("cannot open fifo pipe:%s\n");
            exit(1);
        }
        verbose("the default fifo pipe: /tmp/ble\n");
    }
    
    
    while(1) {
        NSInteger blen = self.maxPacketSize;
        uint8 buffer[blen];
        NSInteger rlen = [self read:buffer length:blen];
        if (rlen < 0 ){
            continue;
        }
        if (filename){
            [pcapt fileHandle:buffer length:rlen];
        }
        
        if (ispipe){
            [pcapt pipeHandle:buffer length:rlen];
        }
       
    }
    
    [pcapt close];
}


- (BOOL)start: (NSInteger)channel {
    if (channel == 0) {
        channel = 37;
    }

    {
        uint8 data[8] = { 0 };
        IOUSBDevRequest request = {
            .bmRequestType    = USBmakebmRequestType(kUSBIn, kUSBVendor, kUSBDevice),
            .bRequest        = 0xc0,
            .wValue            = 0,
            .wIndex            = 0,
            .wLength        = 8,
            .pData            = data,
            .wLenDone        = 0,
        };
        if (![self controlRequest:&request]) {
            return NO;
        }
    }
    
    if (![self  clear_bulk]) {
        return YES;
    }
   
    {
        IOUSBDevRequest request = {
            .bmRequestType    = USBmakebmRequestType(kUSBOut, kUSBVendor, kUSBDevice),
            .bRequest        = 0xc5,
            .wValue            = 0,
            .wIndex            = 4,
            .wLength        = 0,
            .pData            = nil,
            .wLenDone        = 0,
        };
        if (![self controlRequest:&request]) {
            return NO;
        }
    }
    uint8 requestC6 = 0;
    while (requestC6 != 0x04) {
        uint8 data[1] = { 0 };
        IOUSBDevRequest request = {
            .bmRequestType    = USBmakebmRequestType(kUSBIn, kUSBVendor, kUSBDevice),
            .bRequest        = 0xc6,
            .wValue            = 0,
            .wIndex            = 0,
            .wLength        = 1,
            .pData            = data,
            .wLenDone        = 0,
        };
        if (![self controlRequest:&request]) {
            return NO;
        }
        requestC6 = data[0];
    }
    {
        IOUSBDevRequest request = {
            .bmRequestType    = USBmakebmRequestType(kUSBOut, kUSBVendor, kUSBDevice),
            .bRequest        = 0xc9,
            .wValue            = 0,
            .wIndex            = 0,
            .wLength        = 0,
            .pData            = nil,
            .wLenDone        = 0,
        };
        if (![self controlRequest:&request]) {
            return NO;
        }
    }
    {
        uint8 data[1] = { (uint8)channel };
        IOUSBDevRequest request = {
            .bmRequestType    = USBmakebmRequestType(kUSBOut, kUSBVendor, kUSBDevice),
            .bRequest        = 0xd2,
            .wValue            = 0,
            .wIndex            = 0,
            .wLength        = 1,
            .pData            = data,
            .wLenDone        = 0,
        };
        if (![self controlRequest:&request]) {
            return NO;
        }
    }
    {
        uint8 data[1] = { 0x00 };
        IOUSBDevRequest request = {
            .bmRequestType    = USBmakebmRequestType(kUSBOut, kUSBVendor, kUSBDevice),
            .bRequest        = 0xd2,
            .wValue            = 0,
            .wIndex            = 1,
            .wLength        = 1,
            .pData            = data,
            .wLenDone        = 0,
        };
        if (![self controlRequest:&request]) {
            return NO;
        }
    }
    {
        IOUSBDevRequest request = {
            .bmRequestType    = USBmakebmRequestType(kUSBOut, kUSBVendor, kUSBDevice),
            .bRequest        = 0xd0,
            .wValue            = 0,
            .wIndex            = 0,
            .wLength        = 0,
            .pData            = nil,
            .wLenDone        = 0,
        };
        if (![self controlRequest:&request]) {
            return NO;
        }
    }

    return YES;
}




- (BOOL) initEndAddr {
    if (!self.interfaceInterface) {
        return NO;
    }
    
    IOUSBInterfaceInterface245 **interfaceInterface = self.interfaceInterface;
    UInt8 pipes = 0;
    IOReturn result = (*interfaceInterface)->GetNumEndpoints(interfaceInterface, &pipes);
    if (result != KERN_SUCCESS) {
        return NO;
    }
    #ifdef DEBUG
    NSLog(@"End addr: %x", pipes);
#endif
    
    
    UInt8 direction = 0;
    UInt8 number = 0;
    UInt8 transferType = 0;
    UInt16 maxPacketSize = 0;
    UInt8 interval = 0;
    for (UInt8 index = 0; index <= pipes; index++) {
        result = (*interfaceInterface)->GetPipeProperties(interfaceInterface, index, &direction, &number, &transferType, &maxPacketSize, &interval);
        if (result != KERN_SUCCESS) {
            return NO;
        }
        
        _maxPacketSize = maxPacketSize;
#ifdef DEBUG
        NSLog(@"direction:%x transferType:%x maxPacketSize:%u",direction,  transferType, maxPacketSize);
#endif
        
        switch (transferType) {
            case kUSBControl:
                _control_index = index;
                break;
                
            case kUSBBulk:
                _bulk_index = index;
                break;
                
        }
       
    }

    return YES;
}

- (BOOL) initInterface: (IOUSBDeviceInterface245 **) deviceInterface {
    IOUSBFindInterfaceRequest interfaceRequest = {
        .bInterfaceClass    = kIOUSBFindInterfaceDontCare,
        .bInterfaceSubClass    = kIOUSBFindInterfaceDontCare,
        .bInterfaceProtocol    = kIOUSBFindInterfaceDontCare,
        .bAlternateSetting    = kIOUSBFindInterfaceDontCare,
    };
    io_iterator_t iterator = 0;
    IOReturn result = (*deviceInterface)->CreateInterfaceIterator(deviceInterface, &interfaceRequest, &iterator);
    if (result != KERN_SUCCESS) {
        return NO;
    }
    io_service_t service = 0;
    while ((service = IOIteratorNext(iterator)) != 0) {
        #ifdef DEBUG
        NSLog(@"interface service:%x", service);
#endif
        _service = service;
    }
    
    
    IOCFPlugInInterface **pluginInterface = nil;
    SInt32 score = 0;
    result = IOCreatePlugInInterfaceForService(self.service, kIOUSBInterfaceUserClientTypeID, kIOCFPlugInInterfaceID, &pluginInterface, &score);
    if (result != KERN_SUCCESS || pluginInterface == nil) {
       
        return NO;
    }

    IOUSBInterfaceInterface245 **interfaceInterface = nil;
    result = (*pluginInterface)->QueryInterface(pluginInterface, CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID245), (LPVOID)&interfaceInterface);
    IODestroyPlugInInterface(pluginInterface);
    if (result != KERN_SUCCESS || interfaceInterface == nil) {
        
        return NO;
    }
    
    result = (*interfaceInterface)->USBInterfaceOpen(interfaceInterface);
    if (result != KERN_SUCCESS) {
        
        (*interfaceInterface)->Release(interfaceInterface);
        return NO;
    }
    
    self.interfaceInterface = interfaceInterface;
    
    return YES;
}


 


- (BOOL)initConfig: (IOUSBDeviceInterface245 **) deviceInterface {
    IOReturn result;
    UInt8 configurations = 0;
    
    result = (*deviceInterface)->GetNumberOfConfigurations(deviceInterface, &configurations);
    if (result != KERN_SUCCESS || configurations == 0) {
        return NO;
    }
    IOUSBConfigurationDescriptorPtr    configurationDescriptor = nil;
    result = (*deviceInterface)->GetConfigurationDescriptorPtr(deviceInterface, 0, &configurationDescriptor);
    if (result != KERN_SUCCESS || configurationDescriptor == nil) {
        return NO;
    }
   #ifdef DEBUG
    NSLog(@"configurations: %x",configurations );
#endif
    if (configurations < 1) {
        return NO;
    }
    
    UInt8 configuration = 0;
    
    result = (*deviceInterface)->GetConfiguration(deviceInterface, &configuration);
    if (result != KERN_SUCCESS) {
        return NO;
    }

    #ifdef DEBUG
    NSLog(@"configuration: %x", configuration);
#endif
    

    result = (*deviceInterface)->SetConfiguration(deviceInterface, (UInt8)configuration);
    if (result != KERN_SUCCESS) {
        return NO;
    }
    
    return YES;
}

@end
