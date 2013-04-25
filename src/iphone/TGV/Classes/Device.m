//  Device.m     Properties of the device
//
// Jeffrey Scofield, Psellos
// http://psellos.com
//
#import <sys/sysctl.h>
#import "Device.h"

@implementation Device
{
    int cpuCount;
}

- (BOOL) isSlow
{
    // Determine whether the device is slow enough that we wouldn't want
    // to tax it with too much computation.
    //
    // Eventually all devices will be fast enough, but on the other hand
    // the app might want to do some more computations too. On balance
    // this function is probably too crude, but it's good enough for
    // now.
    //
    // Another point: it appears that Apple doesn't make it easy to tell
    // the rated speed of the underlying CPU. So we determine the device
    // speed based just on the number of cores.
    //
    if(cpuCount > 0)
        return cpuCount == 1;
    size_t size = sizeof(int);
    int res;
    res = sysctlbyname("hw.physicalcpu", &cpuCount, &size, NULL, 0);
    if(res < 0) {
        cpuCount = 0;
        return YES; // Conservative answer I guess
    }
    // NSLog(@"Saw cpu count %d", cpuCount); // TEMP
    return cpuCount == 1;
}

@end
