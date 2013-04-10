// Voice.m     Offer periodic vocal guidance
//

#import "Voice.h"
#define kGoldenPause 1.0 // Pause between guidances (sec)
#define kSilentPause 1.3 // Pause after silent guidance (sec)
#define kGiveupPause 2.0 // Pause after starting guidance (sec)

@interface Voice ()
@property (nonatomic, strong) NSString *guidanceNow;
@property (nonatomic) CFAbsoluteTime startedTime;
@property (nonatomic) CFAbsoluteTime finishedTime;
@property (nonatomic) CFAbsoluteTime pauseTime;
@end

@implementation Voice

- (Voice *) init
{
    if ((self = [super init]) == nil)
        return nil;
    [[NSNotificationCenter defaultCenter]
        addObserver: self
           selector: @selector(guidanceDidFinish:)
               name: UIAccessibilityAnnouncementDidFinishNotification
             object: nil];
    return self;
}

- (void) initializeGuidance
{
    self.guidanceNow = nil;
    self.startedTime = 0.0;
    self.finishedTime = 0.0;
    self.pauseTime = 0.0;
}

- (BOOL) offerGuidance: (NSString *) guidance
{
    // Offer guidance, if it has been long enough since the last time. It
    // turns out that the notification for an announcement being finished
    // isn't guaranteed to arrive. If the announcement is preempted by
    // another one (due to user interaction, say), the announcement
    // doesn't finish and the notification doesn't arrive (not even one
    // indicating failure).
    //
    // So, there are two ways to tell if it's time for new guidance. It
    // can be kGoldenPause since the last announcement finished, or it can
    // be kGiveupPause since the last announcement started.
    //
    // There is a special case when guidance == nil. The idea is that this
    // should represent a silent announcement. For this case, wait for
    // slightly longer than kGoldenPause but not as long as kGiveupPause.
    //
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if(self.guidanceNow == nil && now - self.finishedTime < self.pauseTime)
        return NO; // Too soon since end of last announcement
    if(self.guidanceNow != nil && now - self.startedTime < kGiveupPause)
        return NO; // Also too soon since start of last announcement
    self.guidanceNow = guidance;
    self.startedTime = now;
    if(guidance == nil) {
        self.finishedTime = now; // A silent announcement finishes immediately
        self.pauseTime = kSilentPause;
    } else {
        self.finishedTime = 0.0;
        self.pauseTime = kGoldenPause;
        UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification,
                                        guidance);
    }
    return YES;
}

- (void) guidanceDidFinish: (NSNotification *) notification
{
    NSDictionary *dict = [notification userInfo];
    NSString *finished =
        [dict objectForKey: UIAccessibilityAnnouncementKeyStringValue];
    if (![finished isEqualToString: self.guidanceNow])
        return;
    self.guidanceNow = nil;
    self.finishedTime = CFAbsoluteTimeGetCurrent();
}

@end
