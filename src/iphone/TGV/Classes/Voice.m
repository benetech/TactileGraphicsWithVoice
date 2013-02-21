//
//  Voice.m
//  TGV
//
//  Created by Jeffrey Scofield on 1/26/13.
//
//

#import "Voice.h"
#define kGoldenPause 1.0 // Pause between guidances (sec)
#define kGiveupPause 2.0 // Pause after starting guidance (sec)

@interface Voice ()
@property (nonatomic, strong) NSString *guidanceNow;
@property (nonatomic) CFAbsoluteTime startedTime;
@property (nonatomic) CFAbsoluteTime finishedTime;
@end

@implementation Voice

@synthesize guidanceNow = _guidanceNow;
@synthesize startedTime = _startedTime;
@synthesize finishedTime = _finishedTime;

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
    if (guidance == nil)
        return NO;
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if(self.guidanceNow == nil && now - self.finishedTime < kGoldenPause)
        return NO; // Too soon since end of last announcement
    if(self.guidanceNow != nil && now - self.startedTime < kGiveupPause)
        return NO; // Too soon since start of last announcement
    self.guidanceNow = guidance;
    self.startedTime = now;
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification,
                                    guidance);
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
