//
//  Voice.m
//  TGV
//
//  Created by Jeffrey Scofield on 1/26/13.
//
//

#import "Voice.h"
#define kGoldenPause 1.0 // Pause between guidances (sec)

@interface Voice ()
@property (nonatomic, strong) NSString *guidanceNow;
@property (nonatomic) CFAbsoluteTime finishedTime;
@end

@implementation Voice

@synthesize guidanceNow = _guidanceNow;
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
    self.finishedTime = 0.0;
}

- (BOOL) offerGuidance: (NSString *) guidance
{
    if (guidance == nil)
        return NO;
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (self.guidanceNow || now - self.finishedTime < kGoldenPause) {
        // Too soon for new guidance.
        return NO;
    }
    self.guidanceNow = guidance;
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
