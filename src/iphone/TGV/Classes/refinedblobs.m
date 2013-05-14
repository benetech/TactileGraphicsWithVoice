// refinedblobs.m     Find blobs and refine them a little
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
// Right now we coalesce smallish background blobs with their containing
// foreground blobs. This helps with QR codes because they have many
// light regions inside (especially in close-up).
//
// The basic blob finding (image segmentation) algorithm is taken from
// the work of James Bruce, which goes by the name CMVision:
//
//     Realtime Machine Vision Perception and Prediction
//     Undergraduate Thesis, Carnegie Mellon University, 2000
//     http://www.cs.cmu.edu/~jbruce/cmvision/papers/JBThesis00.pdf
//
#include <stdint.h>
#import "runle.h"
#import "bitmap.h"
#import "Blob.h"
#import "findblobs.h"
#import "refinedblobs.h"


static int __attribute__((unused)) classify(void *ck, int x, int y)
{
    // Classify the given pixel as light (0) or dark (1).
    //
    TGV_BITMAP *b = ck;
    return b->bm_lumi_dil[b->bm_width * y + x] <= b->bm_ldthresh;
}

static void mark_coalescable_blobs(int min_qr_size, NSMutableDictionary *dict)
{
    // Mark background blobs that can safely be coalesced with their
    // containing foreground blobs.
    //

    // First find all the fg blobs that are big enough to be QR codes.
    // The idea is that there won't be very many of them.
    //
    NSMutableArray *qrcands = [[NSMutableArray alloc] init];

    for(NSValue *key in dict) {
        Blob *b = [dict objectForKey: key];
        if(b.bclass == 1 &&
            [b width] >= min_qr_size && [b height] >= min_qr_size)
            [qrcands addObject: b];
    }

    // Now go through all bg blobs and see if they are coalescable. If
    // they're possibly harboring a QR candidate, they're not
    // coalescable.
    //
    for(NSValue *key in dict) {
        Blob *b = [dict objectForKey: key];

        if(b.bclass != 0)
            continue; // Not bg
        b.coalescable = 1; // Assume coalescable
        if([b width] <= min_qr_size || [b height] <= min_qr_size)
            continue; // Small enough to be obviously coalescable
        for(Blob *qrc in qrcands) {
            if(qrc.minx >= b.minx && qrc.minx <= b.maxx &&
               qrc.maxx >= b.minx && qrc.maxx <= b.maxx &&
               qrc.miny >= b.miny && qrc.miny <= b.maxy &&
               qrc.maxy >= b.miny && qrc.maxy <= b.maxy) {
                b.coalescable = 0; // b could contain a qrc, not coalescable
                break;
            }
        }
    }

    [qrcands release];
}

static void darken_bg_blobs(TGV_BITMAP *bitmap, int min_qr_size, RUN **starts,
                        NSMutableDictionary *dict)
{
    // Darken the small background (light) blobs in the dilated image.
    // This will cause them to be coalesced into their containing dark
    // blobs. This should give better metrics when QR codes are close to
    // the camera.
    //
    RUN *r, *comp;
    Blob *b;
    int x, y;
    uint16_t *pxstart, *pxend, *px;

    mark_coalescable_blobs(min_qr_size, dict);
    for(y = 0; y < bitmap->bm_height; y++) {
        x = 0;
        for(r = starts[y]; r < starts[y + 1]; r++) {
            comp = component_find(r);
            b = [dict objectForKey: [NSValue valueWithPointer: comp]];
            if (b.coalescable) {
                pxstart = bitmap->bm_lumi_dil + y * bitmap->bm_width + x;
                pxend = pxstart + r->width;
                for(px = pxstart; px < pxend; px++)
                    *px = 0; // Very very very dark
            }
            x += r->width;
        }
    }
}


NSMutableDictionary *refined_blobs(RUN ***startsp, TGV_BITMAP *bitmap,
                        int min_qr_size)
{
    RUN **starts;
    NSMutableDictionary *dict;

    // The first run of the blob analysis is currently just for finding
    // small background (light) blobs.
    //
    starts = encode_16_thresh(bitmap->bm_lumi_dil, bitmap->bm_width, bitmap->bm_height, bitmap->bm_ldthresh);
    if(starts == NULL) {
        *startsp = NULL;
        return [NSMutableDictionary dictionaryWithCapacity: 0];
    }

    dict = findblobs(bitmap->bm_width, bitmap->bm_height, starts);

    // Coalesce the small background blobs with their containing darker
    // blobs. Darken them in the dilated image, then rerun the blob
    // finding.
    //
    darken_bg_blobs(bitmap, min_qr_size, starts, dict);
    starts = encode_16_thresh(bitmap->bm_lumi_dil, bitmap->bm_width, bitmap->bm_height, bitmap->bm_ldthresh);
    if(starts == NULL) {
        *startsp = NULL;
        return [NSMutableDictionary dictionaryWithCapacity: 0];
    }

    dict = findblobs(bitmap->bm_width, bitmap->bm_height, starts);

    // OK, we have our refined blobs.
    //
    *startsp = starts;
    return dict;
}
