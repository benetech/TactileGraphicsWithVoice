// Blob.m    Connected component
//
// Jeffrey Scofield, Psellos
// http://psellos.com
//

#import "Blob.h"

#define kTouchThresh  10 // Number of pixels to count as touching an edge

@implementation Blob

- (int) width
{
    return self.maxx - self.minx + 1;
}

- (int) height
{
    return self.maxy - self.miny + 1;
}

- (BOOL) touchesTop
{
    return self.topPixels > kTouchThresh;
}

- (BOOL) touchesBottom
{
    return self.botPixels > kTouchThresh;
}

- (BOOL) touchesLeft
{
    return self.leftPixels > kTouchThresh;
}

- (BOOL) touchesRight
{
    return self.rightPixels > kTouchThresh;
}
@end
