// Synchronizer.m     Decide when it's a good time to do a periodic action
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

#import "Synchronizer.h"

#define PERIOD 1.25  // Vaguely plausible period (seconds)

@interface Synchronizer ()
{
    CFAbsoluteTime lastGoodTime;
    int goodTimes; // Number of good times so far
}
@end

@implementation Synchronizer

- (void) setGoodTime: (BOOL) goodTime
{
    if (goodTime) {
        lastGoodTime = CFAbsoluteTimeGetCurrent();
        goodTimes++;
    }
    _goodTime = goodTime;
}

- (BOOL) isGoodTimeWithPeriod: (int) period
{
    return _goodTime && goodTimes % period == 0;
}

- (void) step
{
    [self stepNow: CFAbsoluteTimeGetCurrent()];
}

- (void) stepNow: (CFAbsoluteTime) now
{
    if(lastGoodTime + PERIOD <= now) {
        _goodTime = YES;
        lastGoodTime = now;
        goodTimes++;
    } else {
        _goodTime = NO;
    }
}

@end
