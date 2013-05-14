//  Device.m     Properties of the device
//
// Jeffrey Scofield, Psellos
// http://psellos.com
//
// Copyright (c) 2012-2013 University of Washington
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// - Redistributions of source code must retain the above copyright notice,
// this list of conditions and the following disclaimer.
// - Redistributions in binary form must reproduce the above copyright
// notice, this list of conditions and the following disclaimer in the
// documentation and/or other materials provided with the distribution.
// - Neither the name of the University of Washington nor the names of its
// contributors may be used to endorse or promote products derived from this
// software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE UNIVERSITY OF WASHINGTON AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
// PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE UNIVERSITY OF WASHINGTON OR
// CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
// WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
// OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
// ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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
