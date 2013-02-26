// Blob.m    Connected component
//

#import "Blob.h"

#define kTouchThresh  10 // Number of pixels to count as touching an edge

@implementation Blob
@synthesize root = _root;
@synthesize bclass = _bclass;
@synthesize minx = _minx;
@synthesize maxx = _maxx;
@synthesize miny = _miny;
@synthesize maxy = _maxy;
@synthesize slopeCount = _slopeCount;
@synthesize runCount = _runCount;
@synthesize topPixels = _topPixels;
@synthesize botPixels = _botPixels;
@synthesize leftPixels = _leftPixels;
@synthesize rightPixels = _rightPixels;

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
