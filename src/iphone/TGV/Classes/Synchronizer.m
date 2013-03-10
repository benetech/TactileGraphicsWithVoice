// Synchronizer.m     Decide when it's a good time to do a periodic action
//

#import "Synchronizer.h"

#define PERIOD 1.25  // Vaguely plausible period (seconds)

@interface Synchronizer ()
{
    CFAbsoluteTime lastGoodTime;
}
@end

@implementation Synchronizer

@synthesize goodTime = _goodTime;

- (void) setGoodTime:(BOOL)goodTime
{
    if (goodTime)
        lastGoodTime = CFAbsoluteTimeGetCurrent();
    _goodTime = goodTime;
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
    } else {
        _goodTime = NO;
    }
}

@end
