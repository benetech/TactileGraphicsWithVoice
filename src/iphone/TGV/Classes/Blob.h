// Blob.h     Connected component
//
// Jeffrey Scofield, Psellos
// http://psellos.com
//
#import <Foundation/Foundation.h>
#import "runle.h"

@interface Blob : NSObject
@property (nonatomic) RUN *root;           // Representative run of the blob
@property (nonatomic) void *data;          // Temporary associated data
@property (nonatomic) int pixelCount;      // Total number of px in the blob
@property (nonatomic) float finderConf;    // Finder pattern confidence
@property (nonatomic) short bclass;        // Class of blob: 0 = bg, 1 = fg
@property (nonatomic) short minx, maxx;    // Leftmost, rightmost pixels
@property (nonatomic) short miny, maxy;    // Topmost, bottommost pixels
@property (nonatomic) short minSlopeWidth; // Minimum gradation change width
@property (nonatomic) short slopeCount;    // Number of gradation changes
@property (nonatomic) short runCount;      // Number of runs
@property (nonatomic) short topPixels;     // Number of px in top row
@property (nonatomic) short botPixels;     // Number of px in bottom row
@property (nonatomic) short leftPixels;    // Number of px along left edge
@property (nonatomic) short rightPixels;   // Number of px along right edge
@property (nonatomic) short coalescable;   // Bg blob to coalesce with fg

- (int) width;
- (int) height;
- (BOOL) touchesTop;
- (BOOL) touchesBottom;
- (BOOL) touchesLeft;
- (BOOL) touchesRight;
@end
