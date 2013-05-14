// findqrcs.m     Find QR codes in an image
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
#import "runle.h"
#import "filters.h"
#import "bitmap.h"
#import "findqrcs.h"
#import "Blob.h"
#import "findblobs.h"


static void set_downslope_minwidths(NSMutableDictionary *blobs)
{
    // When looking for luminance changes (downslopes), adjust the
    // minimum width to the size of the containing blob. Larger blobs
    // should have wider downslopes. This is a sensitive adjustment, so
    // we don't change the value too much.
    //
    for(NSValue *key in blobs) {
        Blob *b = [blobs objectForKey: key];
        int width = [b width], height = [b height];
        int maxdim = width > height ? width : height;
        if(maxdim < 80) b.minSlopeWidth = 4;
        else if(maxdim < 160) b.minSlopeWidth = 5;
        else if(maxdim < 320) b.minSlopeWidth = 6;
        else b.minSlopeWidth = 7;
    }
}


static void count_fg_downslopes(TGV_BITMAP *bm, RUN **starts,
                        NSMutableDictionary *blobs)
{
    // Count the downslopes of luminance in the foreground (dark) blobs.
    // Changes in luminance are a good discriminator for QR codes.
    //
    int x, y;
    RUN *r, *comp;
    Blob *b;
    // Value of 5/12 comes from a few experiments.
    int mindepth = 5 * (bm->bm_ldthresh - bm->bm_vvdthresh) / 12;

    set_downslope_minwidths(blobs);
    for(y = 0; y < bm->bm_height; y++) {
        x = 0;
        for(r = starts[y]; r < starts[y + 1]; r++) {
            comp = component_find(r);
            b = [blobs objectForKey: [NSValue valueWithPointer: comp]];
            if(b.bclass == 1)
                b.slopeCount +=
                    lumi_rect_downslopes(bm->bm_lumi_orig,
                                            bm->bm_width, bm->bm_height,
                                            x, y, r->width, 1,
                                            b.minSlopeWidth, mindepth);
            x += r->width;
        }
    }
}


static int qr_candidate(int min_qr_size, int max_qr_size, Blob *blob)
{
    // Determine whether the blob is a potential QR code.
    //
    // Variegation metric: First, we track the number of luminance
    // downslopes in the rows of the blob (count_fg_downslopes, above).
    // Then we normalize according to the size of the blob. There are two
    // reasons for different sized blobs: (A) distance from camera--in
    // this case, the count of the downslopes scales according to the
    // number of rows (the height). The number of downslopes doesn't
    // change much (they just get wider), but the number of rows
    // increases. (B) how much of the QRC is inside the frame--in this
    // case, the count of downslopes scales with the area (total number
    // of pixels). To compromise, we normalize by the geometric mean of
    // the height and the area.
    //
# define VARIEGATION_THRESH 0.100 // Set by trial, error, and measurement
# define QRSIZE(x) ((x) >= min_qr_size && (x) <= max_qr_size)
    if(blob == nil)
        return 0;
    int width = blob.maxx - blob.minx + 1;
    int height = blob.maxy - blob.miny + 1;

#ifdef WRITE_PROPS
    printf("class %d w %d h %d pxct %d runct %d slopect %d minwd %d nvar %f\n",
        blob.bclass, width, height, blob.pixelCount, blob.runCount,
           blob.slopeCount, blob.minSlopeWidth,
           blob.slopeCount / sqrt(height * blob.pixelCount));
#endif // WRITE_PROPS
    return
        blob.bclass == 1 && QRSIZE(width) && QRSIZE(height) &&
        blob.slopeCount / sqrt(height * blob.pixelCount) >= VARIEGATION_THRESH;
}


void filter_candidates_by_size(NSMutableArray *qrcs)
{
    // The given blobs are very good QRC candidates. However, if they
    // differ a lot in size, the smaller ones probably are parts of a
    // QRC code rather than whole codes. (This is particularly common to
    // see with the square finder patterns.) So if the candidates differ
    // in size more than a little, filter out the small ones.
    //
    // (Caller gives us permission to reorder the Blobs in the array.)
    //
    // Right now we're using the number of pixels as our measure of
    // size.
    //
#define BIG_SMALL_RATIO 4.0
    NSComparator cmp =
        ^(Blob *a, Blob *b) {
            if(a.pixelCount < b.pixelCount) return NSOrderedAscending;
            if(a.pixelCount > b.pixelCount) return NSOrderedDescending;
            return NSOrderedSame;
        };
    int count = [qrcs count];

    if(count < 2)
        return;

    [qrcs sortUsingComparator: cmp];
    double px0 = ((Blob *) qrcs[0]).pixelCount;
    double pxN = ((Blob *) qrcs[count - 1]).pixelCount;
    if(pxN / px0 < BIG_SMALL_RATIO)
        // All are roughly similar in size.
        return;

    if(count == 2) {
        // There's obviously one big and one small.
        //
        [qrcs removeObjectAtIndex: 0];
        return;
    }

    // Cluster into big and small by minimizing squares of differences
    // from the mean in each group. This has a familiar feel to it.
    //
    // Note: i tracks the number of blobs that should be considered
    // small. mini is the value for which we get the least squares.
    //
    double totbelow = 0.0;
    double totabove;
    int i, j;
    totabove = 0.0;
    for(i = 0; i < count; i++)
        totabove += ((Blob *) qrcs[i]).pixelCount;
    double min = DBL_MAX;
    int mini = 0;
    i = 0;
    do {
        double meanbelow = i == 0 ? 0.0 : (totbelow / i);
        double meanabove = i == count ? 0.0 : (totabove / (count - i));
        double merit = 0.0, delta;
        for(j = 0; j < i; j++) {
            delta = meanbelow - ((Blob *) qrcs[j]).pixelCount;
            merit += delta * delta;
        }
        for(j = i; j < count; j++) {
            delta = meanabove - ((Blob *) qrcs[j]).pixelCount;
            merit += delta * delta;
        }
        if(merit < min) {
            min = merit;
            mini = i;
        }
        if(i < count) {
            totbelow += ((Blob *) qrcs[i]).pixelCount;
            totabove -= ((Blob *) qrcs[i]).pixelCount;
        }
    } while(i++ < count);

    // Remove the small ones.
    //
    for(j = 0; j < mini; j++)
        [qrcs removeObjectAtIndex: 0];
}


NSArray *findqrcs(int min_qr_size, int max_qr_size, TGV_BITMAP *bitmap,
                        RUN **starts, NSMutableDictionary *blobs,
                        NSArray *fpblobs)
{
    // Find QR codes among the blobs in the dictionary.
    //
    NSMutableArray *mres = [[[NSMutableArray alloc] init] autorelease];

    // Count downslopes of luminance in foreground (dark) blobs. QR
    // codes have lots of downslopes.
    //
    count_fg_downslopes(bitmap, starts, blobs);

    // Find the good candidates.
    //
    for(NSValue *key in blobs) {
        Blob *b = [blobs objectForKey: key];
        if([fpblobs containsObject: b] && b.finderConf > 0.99)
            // Eliminate blobs that really look like finder patterns.
            //
            continue;
        if(qr_candidate(min_qr_size, max_qr_size, b))
            [mres addObject: b];
    }

    // If QRCs differ too much in size, filter out the small ones.
    //
    filter_candidates_by_size(mres);

#ifdef WRITE_PROPS
    printf("----- %d QRC -----\n", (int) [mres count]);
    fflush(stdout);
#endif // WRITE_PROPS

    // That is it.
    //
    return [[mres copy] autorelease];
}
