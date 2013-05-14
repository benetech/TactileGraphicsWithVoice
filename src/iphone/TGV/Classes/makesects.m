// makesects.m     Carve image into sections and analyze
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
#import <math.h>
#import "filters.h"
#import "makesects.h"
#import "Section.h"


NSArray *makesects(uint16_t *lumi, int width, int height,
                        int otsu_thresh, int vvd_thresh, int units)
{
    // Carve the image into (units * units) rectangles and determine
    // their properties. Return NSArray of Section objects.
    //
# define MIN_DS_WID 5
    int x, y;
    int secwidth = (width + units - 1) / units;
    int secheight = (height + units - 1) / units;
    int mindepth = (otsu_thresh - vvd_thresh) / 6;
    int curwidth, curheight;
    NSMutableArray *mres = [[NSMutableArray alloc] init];
    Section *s;

    for(y = 0; y < height; y += secheight) {
        curheight = secheight;
        if(y + secheight > height)
            curheight = height - y;
        for(x = 0; x < width; x += secwidth) {
            curwidth = secwidth;
            if(x + secwidth > width)
                curwidth = width - x;
            s = [[Section alloc] init];
            s.x = x;
            s.y = y;
            s.w = curwidth;
            s.h = curheight;
            s.meanLuminance =
                lumi_rect_mean(lumi, width, height,
                                x, y, curwidth, curheight);
            int dsct =
                lumi_rect_downslopes(lumi, width, height,
                                    x, y, curwidth, curheight,
                                    MIN_DS_WID, mindepth);
            s.variegation =
                (double) dsct / sqrt(curheight * curheight * curwidth);
            [mres addObject: s];
            [s release];
        }
    }
    NSArray *res = [[mres copy] autorelease];
    [mres release];
    return res;
}
