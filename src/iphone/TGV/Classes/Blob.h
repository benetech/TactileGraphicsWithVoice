// Blob.h     Connected component
//
// Jeffrey Scofield, Psellos
// http://psellos.com
//
// Copyright (c) 2012-2013 University of Washington
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// - Redistributions of source code must retain the above copyright notice,
// this list of conditions and the following disclaimer.
// - Redistributions in binary form must reproduce the above copyright
// notice, this list of conditions and the following disclaimer in the
// documentation and/or other materials provided with the distribution.
// - Neither the name of the University of Washington nor the names of its
// contributors may be used to endorse or promote products derived from this
// software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE UNIVERSITY OF WASHINGTON AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
// PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE UNIVERSITY OF WASHINGTON OR
// CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
// WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
// OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
// ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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
