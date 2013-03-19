// Synchronizer.m     Decide when it's a good time to do a periodic action
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
