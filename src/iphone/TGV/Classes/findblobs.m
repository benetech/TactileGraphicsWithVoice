// findblobs.m     Find connected components of an image
//
#import <Foundation/Foundation.h>
#import "runle.h"
#import "Blob.h"
#import "findblobs.h"

static void blob_create(NSMutableDictionary *, int, int, RUN *);
static void blob_union(NSMutableDictionary *, int, RUN *, int, int, RUN *);


NSMutableDictionary *findblobs(int height, RUN **starts)
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
        blob_create(dict, x, 0, r);
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
            while(prevx + prevr->width < x) {
                prevx += prevr->width;
                prevr++;
            }
            for(;;) {
                if(prevr->pclass == r->pclass)
                    blob_union(dict, prevx, prevr, x, y, r);
                if(prevx + prevr->width >= x + r->width)
                    break;
                prevx += prevr->width;
                prevr++;
            }
            if(r->component == NULL)
                blob_create(dict, x, y, r);
            x += r->width;
        }
    }
    return dict;
}


static void blob_create(NSMutableDictionary *dict, int x, int y, RUN *r)
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
    blob.slopeCount = r->slopes;
    blob.runCount = 1;
    [dict setObject: blob forKey: [NSValue valueWithPointer: r]];
    [blob release];
}


static void blob_union(NSMutableDictionary *dict,
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
        blob_create(dict, newx, newy, newr);
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
    }
}
