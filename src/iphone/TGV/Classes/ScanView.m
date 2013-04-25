// ScanView.m
//
// Jeffrey Scofield, Psellos
// http://psellos.com
//
// Simple subclass of UIView. The only difference right now is that this
// class can track touches for use in accessibility experiments.
//
// Note: current implementation uses raw events, and hence doesn't work
// when VoiceOver is enabled.
//

#import "ScanView.h"
#import "TGVSettings.h"

@interface ScanView ()
@end

@implementation ScanView
@synthesize delegate = _delegate;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

#if TGV_EXPERIMENTAL
- (void) reportTouches: (NSSet *) touches
{
    if([self.delegate scanViewShouldReportTouches: self]) {
        NSMutableArray *points = [[NSMutableArray alloc] init];
        for(UITouch *touch in touches)
            [points addObject: [NSValue valueWithCGPoint: [touch locationInView: self]]];
        [self.delegate scanView: self didFeelTouchesAtPoints: [[points copy] autorelease]];
        [points release];
    }
}

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan: touches withEvent: event];
    [self reportTouches: touches];
}

- (void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesMoved:touches withEvent:event];
    [self reportTouches: touches];
}

- (void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesEnded: touches withEvent:event];
    [self reportTouches: nil];
}

- (void) touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesCancelled:touches withEvent:event];
    [self reportTouches: nil];
}
#endif // TGV_EXPERIMENTAL

@end
