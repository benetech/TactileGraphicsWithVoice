// dockfinders.m     Merge finder patterns into larger blobs
//
#import "Blob.h"
#import "dockfinders.h"

#define HARBOR_MARGIN 0.666


BOOL harbors(Blob *a, Blob *b)
{
    // Determine whether blob *a* harbors blob *b*. Currently what this
    // means is that a significant part of *b* lies in the bounding
    // rectangle of *a* in each orthogonal direction. The amount of *b*
    // that must lie inside is given by 1-HARBOR_MARGIN (currently 1/3).
    //
    // It might be better to rotate into some kind of standard frame,
    // but that sounds like a lot of calculation.
    //
    int xmargin = [b width] * HARBOR_MARGIN;
    int ymargin = [b height] * HARBOR_MARGIN;

#ifdef PRINT_HARBOR_CALCS
printf("a (%d-%d, %d-%d, %d, %d) b (%d-%d, %d-%d, %d, %d) -> %d\n",
    a.minx, a.maxx, a.miny, a.maxy, [a width], [a height],
    b.minx, b.maxx, b.miny, b.maxy, [b width], [b height],
    b.minx >= a.minx - xmargin && b.maxx <= a.maxx + xmargin &&
        b.miny >= a.miny - ymargin && b.maxy <= a.maxy + ymargin);
fflush(stdout);
#endif

    return b.minx >= a.minx - xmargin && b.maxx <= a.maxx + xmargin &&
        b.miny >= a.miny - ymargin && b.maxy <= a.maxy + ymargin;
}


NSArray *dockfinders(NSMutableDictionary *blobs, NSArray *fpblobs)
{
    // fpblobs has blobs that look very much like finder patterns. Look
    // through the dictionary of blobs for nearby foreground (dark)
    // blobs that they can be merged with. Return an array of the blobs
    // from fpblobs that couldn't be merged.
    //
    Blob *harbor;
    NSMutableArray *mres = [NSMutableArray array];

    for(Blob *fpblob in fpblobs) {
        harbor = nil;
        for(NSValue *key in blobs) {
            Blob *blob = [blobs objectForKey: key];
            if(blob == fpblob)
                continue; // Blob can't harbor itself!
            if(blob.bclass == 0)
                continue; // A background blob
            if (blob.pixelCount < fpblob.pixelCount * 2)
                continue; // Too small
            if(     harbors(blob, fpblob) &&
                    (!harbor || blob.pixelCount < harbor.pixelCount))
                harbor = blob; // Remember smallest harboring blob
        }
        if (harbor != nil) {
            fpblob.root->component = harbor.root;
            harbor.pixelCount = harbor.pixelCount + fpblob.pixelCount;
            harbor.minx = MIN(harbor.minx, fpblob.minx);
            harbor.maxx = MAX(harbor.maxx, fpblob.maxx);
            harbor.miny = MIN(harbor.miny, fpblob.miny);
            harbor.maxy = MAX(harbor.maxy, fpblob.maxy);
            harbor.runCount = harbor.runCount + fpblob.runCount;
            harbor.topPixels = harbor.topPixels + fpblob.topPixels;
            harbor.botPixels = harbor.botPixels + fpblob.botPixels;
            harbor.leftPixels = harbor.leftPixels + fpblob.leftPixels;
            harbor.rightPixels = harbor.rightPixels + fpblob.rightPixels;
            [blobs removeObjectForKey: [NSValue valueWithPointer: fpblob.root]];
        } else {
            [mres addObject: fpblob];
        }
    }

    return [[mres copy] autorelease];
}
