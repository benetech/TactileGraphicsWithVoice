// Signal.m     Play a short sound with a controlled periodicity
//
// Created by Jeffrey Scofield on 3/8/13.
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
