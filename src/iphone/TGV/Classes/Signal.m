// Signal.m     Play a short sound with a controlled periodicity
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

#import "Signal.h"
#define SIGNAL_MIN_PERIOD 0.40
#define SIGNAL_NO_SOUND ((SystemSoundID) -1)

@interface Signal ()
{
    CFTimeInterval _period;
    CFAbsoluteTime _lastSignal;
    SystemSoundID _signalSound;
}
@end

@implementation Signal
@synthesize signalToIssue = _signalToIssue;

- (Signal *) init
{
    if ((self = [super init]) == nil)
        return nil;
    [self setup];
    return self;
}

- (void) awakeFromNib
{
    [self setup];
}

- (void) setup
{
    _period = SIGNAL_INF_PERIOD;
    _signalSound = SIGNAL_NO_SOUND;
}


- (void) setSignalToIssue: (NSURL *) signalToIssue
{
    if (_signalSound != SIGNAL_NO_SOUND) {
        AudioServicesDisposeSystemSoundID(_signalSound);
        _signalSound = SIGNAL_NO_SOUND;
    }
    _signalToIssue = signalToIssue;
    [_signalToIssue retain];
}


- (CFTimeInterval) period
{
    return _period;
}


- (void) setPeriod: (CFTimeInterval) period
{
    // We depend on this method being called very frequently, so we don't
    // need to establish our own timers. Under the current design this is
    // pretty straightforward.
    //
    if(period < SIGNAL_MIN_PERIOD)
        period = SIGNAL_MIN_PERIOD;
   _period = period;
    if(period >= SIGNAL_INF_PERIOD)
        return;
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (now - _lastSignal >= period)
        [self issueSignalNow: now];
}

- (void) issueSignalNow: (CFAbsoluteTime) now
{
    if (self.signalToIssue == nil)
        return;
    if(_signalSound == SIGNAL_NO_SOUND) {
        OSStatus error =
            AudioServicesCreateSystemSoundID((CFURLRef) self.signalToIssue,
                                             &_signalSound);
        if (error != kAudioServicesNoError) {
            NSLog(@"Problem loading %@", self.signalToIssue);
            return;
        }
        
    }
    AudioServicesPlaySystemSound(_signalSound);
    _lastSignal = now;
}
@end
