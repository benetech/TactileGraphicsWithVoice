// findqrcs.m     Find and classify QR codes in an image
//
#import <math.h>
#import "runle.h"
#import "filters.h"
#import "findqrcs.h"
#import "Blob.h"
#import "findblobs.h"

#define max(a, b) ((a) > (b) ? (a) : (b))
#define min(a, b) ((a) < (b) ? (a) : (b))

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


static int slopect(void *ck, int x, int y, int wd)
{
    // Count the number of luminosity downslopes in the given row of
    // pixels. This is a rough measure of variegation.
    //
# define MINWIDTH 5  // Carefully chosen number, for now
    BITMAP_PARAMS *p = ck;
    int mindepth = (p->thresh - p->vvdthresh) / 3;
    return lumi_rect_downslopes(p->lumi_orig, p->width, p->height,
                            x, y, wd, 1, MINWIDTH, mindepth);
}


static int qr_candidate(Blob *blob)
{
    /* Determine whether the blob is a potential QR code.
     *
     * Variegation metric: First, we track the number of luminance
     * downslopes in the rows of the blob (slopect, above). Then we
     * normalize according to the size of the blob. There are two
     * reasons for different sized blobs: (A) distance from camera--in
     * this case, the count of the downslopes scales according to the
     * number of rows (the height). The number of downslopes doesn't
     * change much, but the number of rows increases. (B) how much of
     * the QRC is inside the frame--in this case, the count of
     * downslopes scales with the area (total number of pixels). To
     * compromise, we normalize by the geometric mean of the height and
     * the area.
     *
     * Max for QRSIZE was 240 for a while. Recent tests suggest it's
     * OK to make it bigger. But keep an eye on it.
     *
     * Min for QRSIZE was 30 for a long time, then I raised it to 50.
     * Now that seems too big to me. Trying it at 40.
     */
# define VARIEGATION_THRESH 0.100            /* Set by experiment */
# define QRSIZE(x) ((x) >= 40 && (x) < 300)  /* Set by experiment */
    if(blob == nil)
        return 0;
    int width = blob.maxx - blob.minx + 1;
    int height = blob.maxy - blob.miny + 1;
#ifdef WRITE_PROPS
    printf("class %d w %d h %d pxct %d runct %d slopect %d nvar %f\n",
        blob.bclass, width, height, blob.pixelCount, blob.runCount,
           blob.slopeCount,
           blob.slopeCount / sqrt(height * blob.pixelCount));
#endif // WRITE_PROPS
    return
        blob.bclass == 1 && QRSIZE(width) && QRSIZE(height) &&
            // blob.runCount < height + height && /* TRY AFTER COALESCE */
            // blob.oSlopeCount / sqrt(height * blob.pixelCount) >= OLD_VARIEGATION_THRESH;
            blob.slopeCount / sqrt(height * blob.pixelCount) >= VARIEGATION_THRESH;
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
    NSMutableArray *mres = [[NSMutableArray alloc] init];
    NSArray *res;

    p.lumi_orig = lumi;
    p.lumi_dil = dil;
    p.width = width;
    p.height = height;
    p.thresh = ld_thresh;
    p.vvdthresh = vvd_thresh;

    starts = encode(classify, slopect, &p, width, height);
    if(starts == NULL) {
        *startsp = NULL;
        res = [[mres copy] autorelease];
        [mres release];
        return res; // Empty array
    }

    NSMutableDictionary *dict = findblobs(width, height, starts);

    for(NSNumber *key in dict) {
        Blob *b = [dict objectForKey: key];
        if(qr_candidate(b))
            [mres addObject: b];
    }
#ifdef WRITE_PROPS
    printf("----- %d QRC -----\n", (int) [mres count]);
    fflush(stdout);
#endif // WRITE_PROPS

    *startsp = starts;
    res = [[mres copy] autorelease];
    [mres release];
    return res;
}


NSArray *findqrcs(uint16_t *lumi, uint16_t *dil, size_t width, size_t height,
                    int ld_thresh, int vvd_thresh)
{
    RUN **starts;
    return findqrcs_x(&starts, lumi, dil, width, height, ld_thresh, vvd_thresh);
}
