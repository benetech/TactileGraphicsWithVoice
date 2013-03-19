// findqrcs.m     Find and classify QR codes in an image
//
#import <math.h>
#import "runle.h"
#import "filters.h"
#import "findqrcs.h"
#import "Blob.h"
#import "findblobs.h"

// These values control what we consider to be a QR code in the first
// place.  Later processing in ScanViewController decides whether a code
// is too close or too far from the camera. This counting code is
// specifically designed to be able to count QR codes that can't be
// scanned properly, so we can give advice on how to get a good scan.  So
// we want to use values as liberal as possible here, without allowing
// too many false positives.
//
// Max for QRSIZE was 240 for a while. Recent tests suggest it's OK to
// make it bigger. But keep an eye on it.
//
// Min for QRSIZE was 30 for a long time, then I raised it to 50.  Now
// that seems too big to me. Trying it at 40.
//
#define MIN_QR_SIZE 40
#define MAX_QR_SIZE 300

typedef struct {
    uint16_t *lumi_orig; // Original grayscale (luminance) bitmap image
    uint16_t *lumi_dil;  // Dilated grayscale (luminance) bitmap image
    int width, height;
    int thresh;          // Threshold between dark and light
    int vvdthresh;       // Threshold of very very dark (0.5% are darker)
} BITMAP_PARAMS;


static int classify(void *ck, int x, int y)
{
    // Classify the given pixel as light (0) or dark (1).
    //
    BITMAP_PARAMS *p = ck;
    return p->lumi_dil[p->width * y + x] <= p->thresh;
}

#ifdef FORMERLY
static int slopect(void *ck, int x, int y, int wd)
{
    // Count the number of luminosity downslopes in the given row of
    // pixels. This is a rough measure of variegation.
    //
# define MINWIDTH 5  // Carefully chosen number used previously
    BITMAP_PARAMS *p = ck;
    int minwidth;
    int mindepth = (p->thresh - p->vvdthresh) / 3;
    if(wd < 80) minwidth = 4;
    else if(wd < 160) minwidth = 5;
    else if(wd < 320) minwidth = 6;
    else minwidth = 7;
    int res = lumi_rect_downslopes(p->lumi_orig, p->width, p->height,
                            x, y, wd, 1, minwidth, mindepth);
    return res;
}
#endif // FORMERLY


static void mark_coalescable_blobs(NSMutableDictionary *dict)
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
            [b width] >= MIN_QR_SIZE && [b height] >= MIN_QR_SIZE)
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
        if([b width] <= MIN_QR_SIZE || [b height] <= MIN_QR_SIZE)
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


static void darken_bg_blobs(uint16_t *dil, int width, int height,
                    RUN **starts, NSMutableDictionary *dict)
{
    // Darken the small background (light) blobs in the given dilated
    // image.  This will cause them to be coalesced into their
    // containing dark blobs. This should give better metrics when QR
    // codes are close to the camera.
    //
    RUN *r, *comp;
    Blob *b;
    int x, y;
    uint16_t *pxstart, *pxend, *px;

    mark_coalescable_blobs(dict);
    for(y = 0; y < height; y++) {
        x = 0;
        for(r = starts[y]; r < starts[y + 1]; r++) {
            comp = component_find(r);
            b = [dict objectForKey: [NSValue valueWithPointer: comp]];
            if (b.coalescable) {
                pxstart = dil + y * width + x;
                pxend = pxstart + r->width;
                for(px = pxstart; px < pxend; px++)
                    *px = 0; // Very very very dark
            }
            x += r->width;
        }
    }
}


static void set_downslope_minwidths(NSMutableDictionary *dict)
{
    // When looking for luminance changes (downslopes), adjust the
    // minimum width to the size of the containing blob. Larger blobs
    // should have wider downslopes. This is a sensitive adjustment,
    // so we don't change the value too much.
    //
    for(NSValue *key in dict) {
        Blob *b = [dict objectForKey: key];
        int width = [b width], height = [b height];
        int maxdim = width > height ? width : height;
        if(maxdim < 80) b.minSlopeWidth = 4;
        else if(maxdim < 160) b.minSlopeWidth = 5;
        else if(maxdim < 320) b.minSlopeWidth = 6;
        else b.minSlopeWidth = 7;
    }
}


static void count_fg_downslopes(BITMAP_PARAMS *p,
                    RUN **starts, NSMutableDictionary *dict)
{
    // Count the downslopes of luminance in the foreground (dark) blobs.
    // Changes in luminance are a good discriminator for QR codes.
    //
    int x, y;
    RUN *r, *comp;
    Blob *b;
    int mindepth = 5 * (p->thresh - p->vvdthresh) / 12; // From trial and error

    set_downslope_minwidths(dict);
    for(y = 0; y < p->height; y++) {
        x = 0;
        for(r = starts[y]; r < starts[y + 1]; r++) {
            comp = component_find(r);
            b = [dict objectForKey: [NSValue valueWithPointer: comp]];
            if(b.bclass == 1)
                b.slopeCount +=
                    lumi_rect_downslopes(p->lumi_orig, p->width, p->height,
                                            x, y, r->width, 1,
                                            b.minSlopeWidth, mindepth);
            x += r->width;
        }
    }
}


static int qr_candidate(Blob *blob)
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
# define QRSIZE(x) ((x) >= MIN_QR_SIZE && (x) <= MAX_QR_SIZE)
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


NSArray *findqrcs_x(RUN ***startsp, uint16_t *lumi, uint16_t *dil,
                        size_t width, size_t height,
                        int ld_thresh, int vvd_thresh)
{
    // (This internal function returns the calculated runs through
    // *startsp, which is useful during development.)
    //
    BITMAP_PARAMS p;
    RUN **starts;
    NSMutableArray *mres =
        [[[NSMutableArray alloc] init] autorelease];
    NSArray *res;
    NSMutableDictionary *dict;

    p.lumi_orig = lumi;
    p.lumi_dil = dil;
    p.width = width;
    p.height = height;
    p.thresh = ld_thresh;
    p.vvdthresh = vvd_thresh;

    // The first run of the blob analysis is currently just for finding
    // small background (light) blobs.
    //
    starts = encode(classify, &p, width, height);
    if(starts == NULL) {
        *startsp = NULL;
        return [NSArray array];
    }

    dict = findblobs(width, height, starts);

    // Coalesce the small background blobs with their containing darker
    // blobs. Darken them in the dilated image, then rerun the blob
    // finding.
    //
    darken_bg_blobs(dil, width, height, starts, dict);

    starts = encode(classify, &p, width, height);
    if(starts == NULL) {
        *startsp = NULL;
        return [NSArray array];
    }

    dict = findblobs(width, height, starts);

    // Count downslopes of luminance in foreground (dark) blobs. QR
    // codes have lots of downslopes.
    //
    count_fg_downslopes(&p, starts, dict);

    for(NSValue *key in dict) {
        Blob *b = [dict objectForKey: key];
        if(qr_candidate(b))
            [mres addObject: b];
    }

    // If QRCs differ too much in size, filter out the small ones.
    //
    filter_candidates_by_size(mres);

#ifdef WRITE_PROPS
    printf("----- %d QRC -----\n", (int) [mres count]);
    fflush(stdout);
#endif // WRITE_PROPS

    *startsp = starts;
    res = [[mres copy] autorelease];
    return res;
}


NSArray *findqrcs(uint16_t *lumi, uint16_t *dil, size_t width, size_t height,
                    int ld_thresh, int vvd_thresh)
{
    RUN **starts;
    return findqrcs_x(&starts, lumi, dil, width, height, ld_thresh, vvd_thresh);
}
