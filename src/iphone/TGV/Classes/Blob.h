// Blob.h     Connected component
//
#import <Foundation/Foundation.h>
#import "runle.h"

@interface Blob : NSObject
@property (nonatomic) RUN *root;       // Representative run of the blob
@property (nonatomic) int bclass;      // Class of blob: 0 = bg, 1 = fg
@property (nonatomic) int minx, maxx;  // Leftmost, rightmost pixels
@property (nonatomic) int miny, maxy;  // Topmost, bottommost pixels
@property (nonatomic) int slopeCount;  // Number of gradation changes
@property (nonatomic) int runCount;    // Number of runs
@property (nonatomic) int topPixels;   // Number of pixels in top pixel row
@property (nonatomic) int botPixels;   // Number of pixels in bottom pixel row
@property (nonatomic) int leftPixels;  // Number of pixels along left edge
@property (nonatomic) int rightPixels; // Number of pixels along right edge

- (BOOL) touchesTop;
- (BOOL) touchesBottom;
- (BOOL) touchesLeft;
- (BOOL) touchesRight;
@end
