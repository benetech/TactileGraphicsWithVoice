// Synchronizer.h     Decide when it's a good time to do a periodic action
//
// Jeffrey Scofield, Psellos
// http://psellos.com
//
// The basic idea is that there are some things you want to do every now and
// then. If vocal guidance is on, there are some cases where you'd like to
// synchronize with the guidance announcements. If vocal guidance is off, you
// just want to do the things every now and then.
//
// So this class has a manual and automatic mode. In manual mode, the
// good times are controlled externally by setting the goodTime property.
// In automatic mode, each new time is initiated by the step method, and
// its goodness is determined by elapsed time.
//

#import <Foundation/Foundation.h>

@interface Synchronizer : NSObject
@property (nonatomic, getter=isGoodTime) BOOL goodTime;
- (void) step;
- (void) stepNow: (CFAbsoluteTime) now;
- (BOOL) isGoodTimeWithPeriod: (int) period;
@end
