// findblobs.m     Find connected components of an image
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
#import "Blob.h"
#import "findblobs.h"

static void blob_create(NSMutableDictionary *, int, int,
                        int, int, RUN *);
static void blob_union(NSMutableDictionary *, int, int,
                       int, RUN *, int, int, RUN *);


NSMutableDictionary *findblobs(int width, int height, RUN **starts)
{
    // Assemble vertically adjacent runs into blobs, using union-find à
    // la Tarjan to establish a representative run for each region.  Use
    // 4-connected regions for now. Return a dictionary of the blobs.
    // Keys are the representative RUN pointers (wrapped in NSValue).
    // Values are Blob instances.
    //
    NSMutableDictionary *dict =
        [[[NSMutableDictionary alloc] init] autorelease];
    int y, prevx, x;
    RUN *prevr, *r;

    // Make blobs for top row of pixels
    //
    x = 0;
    for(r = starts[0]; r < starts[1]; r++) {
        r->component = NULL;     // Mark as a run with no blob yet
        blob_create(dict, width, height, x, 0, r);
        x += r->width;
    }

    // Aggregate blobs for the rest of the rows
    //
    for(y = 1; y < height; y++) {
        prevx = 0;
        prevr = starts[y - 1];
        x = 0;
        for(r = starts[y]; r < starts[y + 1]; r++) {
            r->component = NULL; // Mark as a run with no blob yet
            while(prevx + prevr->width <= x) {
                prevx += prevr->width;
                prevr++;
            }
            for(;;) {
                if(prevr->pclass == r->pclass)
                    blob_union(dict, width, height, prevx, prevr, x, y, r);
                if(prevx + prevr->width >= x + r->width)
                    break;
                prevx += prevr->width;
                prevr++;
            }
            if(r->component == NULL)
                blob_create(dict, width, height, x, y, r);
            x += r->width;
        }
    }
    return dict;
}


static void blob_create(NSMutableDictionary *dict, int imgwd, int imght,
                        int x, int y, RUN *r)
{
    // Create a new Blob containing just the run r.
    //
    if(r->component != NULL)
        return; // r is already in a blob
    r->component = r;
    Blob *blob = [[Blob alloc] init];
    blob.root = r;
    blob.bclass = r->pclass;
    blob.minx = x;
    blob.maxx = x + r->width - 1;
    blob.miny = y;
    blob.maxy = y;
    // (Currently downslopes are counted later, but it doesn't hurt too
    // much to track them here.)
    //
    blob.slopeCount = r->slopes;
    blob.runCount = 1;
    blob.pixelCount = r->width;
    if (y == 0) blob.topPixels = r->width;
    if (y == imght - 1) blob.botPixels = r->width;
    if (x == 0) blob.leftPixels = 1;
    if (x + r->width == imgwd) blob.rightPixels = 1;
    [dict setObject: blob forKey: [NSValue valueWithPointer: r]];
    [blob release];
}


static void blob_union(NSMutableDictionary *dict, int imgwd, int imght,
                    int oldx, RUN *oldr, int newx, int newy, RUN *newr)
{
    // Make the union of the blobs for oldr and newr.
    //
    RUN *oldrep = component_find(oldr);
    Blob *oldblob = nil;
    if(oldrep)
        oldblob = [dict objectForKey: [NSValue valueWithPointer: oldrep]];
    if(!oldblob) {
        // Caller has erred. Maybe it will work just to make a new blob.
        //
        blob_create(dict, imgwd, imght, newx, newy, newr);
        return;
    }
    RUN *newrep = component_find(newr);
    if(newrep == oldrep)
        // Blobs are already the same. Nothing to do.
        //
        return;
    Blob *newblob = nil;
    NSValue *newkey = nil;
    if(newrep) {
        newkey = [NSValue valueWithPointer: newrep];
        newblob = [dict objectForKey: newkey];
    }
    if(newblob) {
        // New run is already in a blob. Do union of the two blobs.
        //
        newrep->component = oldrep; // Inline component_union()
        if(newblob.minx < oldblob.minx)
            oldblob.minx = newblob.minx;
        if(newblob.maxx > oldblob.maxx)
            oldblob.maxx = newblob.maxx;
        if(newblob.miny < oldblob.miny)
            oldblob.miny = newblob.miny;
        if(newblob.maxy > oldblob.maxy)
            oldblob.maxy = newblob.maxy;
        oldblob.slopeCount = oldblob.slopeCount + newblob.slopeCount;
        oldblob.runCount = oldblob.runCount + newblob.runCount;
        oldblob.pixelCount = oldblob.pixelCount + newblob.pixelCount;
        oldblob.topPixels = oldblob.topPixels + newblob.topPixels;
        oldblob.botPixels = oldblob.botPixels + newblob.botPixels;
        oldblob.leftPixels = oldblob.leftPixels + newblob.leftPixels;
        oldblob.rightPixels = oldblob.rightPixels + newblob.rightPixels;
        [dict removeObjectForKey: newkey];
    } else {
        // New run is not in a blob. Just update the existing blob.
        //
        newr->component = oldrep;
        if(newx < oldblob.minx)
            oldblob.minx = newx;
        if(newx + newr->width - 1 > oldblob.maxx)
            oldblob.maxx = newx + newr->width - 1;
        if(newy < oldblob.miny)
            oldblob.miny = newy;
        if(newy > oldblob.maxy)
            oldblob.maxy = newy;
        oldblob.slopeCount = oldblob.slopeCount + newr->slopes;
        oldblob.runCount = oldblob.runCount + 1;
        oldblob.pixelCount = oldblob.pixelCount + newr->width;
        // (New run can't be on top row. Old blob is always on row above.)
        if (newy == imght - 1) oldblob.botPixels = oldblob.botPixels + newr->width;
        if (newx == 0) oldblob.leftPixels = oldblob.leftPixels + 1;
        if (newx + newr->width == imgwd) oldblob.rightPixels = oldblob.rightPixels + 1;
    }
}
