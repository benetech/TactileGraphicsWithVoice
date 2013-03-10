/* findqrcs.m     Find and classify QR codes in an image
 */
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
    int thresh05;        // Threshold of very very dark (0.5% are darker)
} BITMAP_PARAMS;


static int otsu(int *histogram, int width, int height)
{
    /* Find a good threshold between dark and light pixels using Otsu's
     * method:
     *
     *   http://en.wikipedia.org/wiki/Otsu's_method
     *
     * It's a clustering algorithm that maximizes the variance of the
     * difference between the two groups of pixels.
     */
    double total;     // Total number of pixels
    double pxbelow;   // Number of pixels below current threshold
    double sumbelow;  // sum of luminance * count over all pixels below
    double sumabove;  // sum of luminance * count over all pixels above
    int maxlum;       // luminance with maximum variance so far
    double maxvar;    // maximum variance so far
    double var, md; 
    int i;

    total = width * height;
    sumabove = 0.0;
    for(i = 0; i < LUMINANCES; i++)
        sumabove += i * histogram[i];
    maxlum = 0;
    maxvar = 0.0;
    pxbelow = 0.0;
    sumbelow = 0.0;
    for(i = 0; i < LUMINANCES; i++) {
        if(pxbelow == 0.0 || pxbelow == total)
            md = 0.0;
        else
            md = sumbelow / pxbelow - sumabove / (total - pxbelow);
        var = pxbelow * (total - pxbelow) * md * md;
        if(var > maxvar) {
            maxvar = var;
            maxlum = i;
        }
        pxbelow += histogram[i];
        sumbelow += i * histogram[i];
        sumabove -= i * histogram[i];
    }
    return maxlum;
}


#ifdef FORMER_METHOD
static int lowspot(int *histogram)
{
    /* Find a low spot in the histogram that separates the dark pixels
     * from the light ones.
     * 
     * The typical histogram for this application has a big peak at the
     * right for light pixels, at a luminance around 500. Then there are
     * one or two much lower peaks at the left for dark pixels, at
     * luminances in the 300s and 400s.
     *
     * Depending on lighting conditions and other factors (such as the
     * white point setting of the camera), real histograms can differ
     * from this. We accommodate the differences by scaling distances to
     * the width of the histogram.
     *
     * Current procedure: smooth the data twice, with two different
     * radii. Then look in the histogram for the rightmost low spot
     * that's reasonably far to the left of the peak.  If there's no low
     * spot, return a fixed distance to the left of the peak.  At the
     * very end, add an adjustment that was determined empirically, i.e.,
     * by trying some examples.
     */
# define REFERENCE_WIDTH 450
# define RADIUS1 30
# define RADIUS2 10
# define LEEWAY 80        // Low spot must be at least this far below big peak
# define FLATDELTA 105    // Distance below peak when dark area is flat
# define ADJUSTMENT 10    // Final empirical adjustment (aka fudge)
# define ROUND(x, radius) (((x) + radius) / (2 * radius + 1))
    int left, right;
    double scale;

    int radius1, radius2, leeway, flatdelta, adjustment;

    int ct;
    int lumin;
    int smooth1[LUMINANCES];
    int smooth2[LUMINANCES];
    int topcount, toplumin;
    int lowlumin, descending;

    // Figure out width of histogram. We measure the width from the
    // leftmost nonzero count to the highest count (the big peak).
    //
    left = -1;
    toplumin = 0;
    right = 0;
    topcount = 0;
    for(lumin = 0; lumin < LUMINANCES; lumin++) {
        if(left < 0 && histogram[lumin] > 0)
            left = lumin - 1;
        if(histogram[lumin] > topcount) {
            topcount = histogram[lumin];
            toplumin = lumin;
        }
        if(lumin > 0 && histogram[lumin] == 0 && histogram[lumin - 1] > 0)
            right = lumin;
    }
    scale = (double) (toplumin - left) / REFERENCE_WIDTH;
# define SCALE(x) ((int) ((x) * scale + 0.5))

    // Scale reference values for this histogram.
    //
    radius1 = SCALE(RADIUS1);
    radius2 = SCALE(RADIUS2);
    leeway = SCALE(LEEWAY);
    flatdelta = SCALE(FLATDELTA);
    adjustment = SCALE(ADJUSTMENT);

    // First smoothing, radius1.
    memset(smooth1, 0, LUMINANCES * sizeof(int));
    ct = 0;
    for(lumin = 0; lumin < radius1 * 2 + 1; lumin++)
        ct += histogram[lumin];
    for(lumin = radius1 + 1; lumin < LUMINANCES - radius1; lumin++) {
        ct = ct - histogram[lumin - radius1 - 1] + histogram[lumin + radius1];
        smooth1[lumin] = ROUND(ct, radius1);
    }
    // Second smoothing, radius2.
    memset(smooth2, 0, LUMINANCES * sizeof(int));
    ct = 0;
    for(lumin = 0; lumin < radius2 * 2 + 1; lumin++)
        ct += histogram[lumin];
    for(lumin = radius2 + 1; lumin < LUMINANCES - radius2; lumin++) {
        ct = ct - histogram[lumin - radius2 - 1] + histogram[lumin + radius2];
        smooth2[lumin] = ROUND(ct, radius2);
    }

#ifdef WRITE_SMOOTH2
    printf("left %d toplumin %d leeway %d radii %d %d\n",
        left, toplumin, leeway, radius1, radius2);
    printf("smooth2\n");
    for(int i = radius2 + 1; i < LUMINANCES - radius2; i++)
        printf("%d %d\n", i, smooth2[i]);
#endif
    printf("otsu(histogram) %d\n", otsu(histogram));
    printf("otsu(smooth1) %d\n", otsu(smooth1));
    printf("otsu(smooth2) %d\n", otsu(smooth2));

    // Find the big peak in the smoothed data.
    //
    topcount = 0;
    toplumin = 0;
    for(lumin = left; lumin < right; lumin++)
        if(smooth2[lumin] > topcount) {
            topcount = smooth2[lumin];
            toplumin = lumin;
        }

    // Look for low spots, i.e., spots where smoothed data changes from
    // descending to ascending.
    //
    descending = 0;
    lowlumin = left - 1;
    for(lumin = left + 1; lumin < toplumin - leeway; lumin++) {
        if(descending) {
            if(smooth2[lumin] > smooth2[lumin - 1]) {
// printf("turnaround %d\n", lumin);
                lowlumin = lumin - 1;
                descending = 0;
            }
        } else {
            if(smooth2[lumin] < smooth2[lumin - 1])
                descending = 1;
        }
    }

    // If no low spot found, use default.
    //
    if(lowlumin <= left)
        lowlumin = toplumin - flatdelta;
    return lowlumin + adjustment;
}
#endif // FORMER_METHOD


static void thresholds(BITMAP_PARAMS *bpar,
                    uint16_t *lumimage, int width, int height)
{
    /* Calculate threshold luminances: (a) between foreground (dark) and
     * background (light); (b) between not totally dark and totally
     * dark.
     */
# define TOTALLY_DARK_F 0.005
    int histogram[LUMINANCES], ct, thresh;
    int breakpt05;
    
    lumi_histogram(histogram, lumimage, width, height);

#ifdef WRITE_HISTOGRAM
    for(int i = 0; i < LUMINANCES; i++)
        printf("%d\n", histogram[i]);
#endif

    ct = 0;
    bpar->thresh = otsu(histogram, width, height);
    breakpt05 = width * height * TOTALLY_DARK_F;
    for(thresh = 0; thresh < LUMINANCES; thresh++) {
        ct += histogram[thresh];
        if(ct >= breakpt05) {
            bpar->thresh05 = thresh;
            break;
        }
    }
}


static int classify(void *ck, int x, int y)
{
    // Classify the given pixel as light (0) or dark (1).
    //
    BITMAP_PARAMS *p = ck;
    return p->lumi_dil[p->width * y + x] <= p->thresh;
}


static int slopect(void *ck, int x, int y, int wd)
{
    // Count the number of significant downslopes of luminance in the
    // original (undilated) image. This is an attempt to measure the
    // amount of variegation in a blob. QR codes are noticeably
    // variegated even when out of focus. The dilation operation can
    // hide the variegations, which is why we look at the original.
    //
    // The slope count for the run must be at least MINCOUNT to be
    // included in the overall total. Counts smaller than this don't
    // really characterize variegation. It's more like a simple
    // gradation.
    //
# define MINWIDTH 3
# define MINCOUNT 2
    BITMAP_PARAMS *p = ck;
    // int mindepth = (p->thresh - p->thresh05) / 4;
    int mindepth = (p->thresh - p->thresh05) / 3;
    uint16_t *base = p->lumi_orig + p->width * y + x;
    int sct, start, i;

    sct = 0;
    i = 1;
    while(i < wd) {
        for(; i < wd && base[i] >= base[i - 1]; i += BPP)
            ;
        if(i >= wd)
            break;
        start = i;
        for(; i < wd && base[i] <= base[i - 1]; i += BPP)
            ;
        if(i - start >= MINWIDTH && base[start] - base[i - 1] >= mindepth)
            sct++;
    }
    return sct < MINCOUNT ? 0 : sct;
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
     */
# define OLD_VARIEGATION_THRESH 0.78            /* Set by eye */
# define NEW_VARIEGATION_THRESH 0.078           /* Set by experiment */
# define QRSIZE(x) ((x) >= 50 && (x) < 300)     /* Set by experiment */
    if(blob == nil)
        return 0;
    int width = blob.maxx - blob.minx + 1;
    int height = blob.maxy - blob.miny + 1;
#ifdef WRITE_PROPS
    printf("class %d w %d h %d pxct %d runct %d slopect %d ovar %f nvar %f\n",
        blob.bclass, width, height, blob.pixelCount, blob.runCount,
           blob.slopeCount,
           blob.slopeCount / (double) blob.runCount,
           blob.slopeCount / sqrt(height * blob.pixelCount));
#endif // WRITE_PROPS
    return
        blob.bclass == 1 && QRSIZE(width) && QRSIZE(height) &&
            // blob.runCount < height + height && /* TRY AFTER COALESCE */
            // blob.slopeCount / (double) blob.runCount >= VARIEGATION_THRESH;
            blob.slopeCount / sqrt(height * blob.pixelCount) >= NEW_VARIEGATION_THRESH;
}


NSArray *findqrcs_x(RUN ***startsp, uint8_t *bitmap,
                        size_t width, size_t height)
{
    // (This internal function returns the calculated runs through
    // *startsp, which is useful during development.)
    //
    // Plan: overwrite incoming bitmap with two smaller grayscale
    // (luminance) bitmaps. First is just a grayscale representation of
    // incoming image. Second is dilated, which makes QR codes easier to
    // recognize. Use original image to determine light/dark thresholds.
    // Use dilated image for recognizing QR codes as blobs.
    //
# define BLUR_RADIUS 3   // (Formerly used blurring instead of dilation)
# define DILATE_RADIUS 3
    BITMAP_PARAMS p;
    RUN **starts;
    NSMutableArray *mres = [[[NSMutableArray alloc] init] autorelease];
    uint16_t *lumi_orig;  // Original image in grayscale (luminance)
    uint16_t *lumi_dil;   // Dilated image in grayscale (luminance)

    lumi_orig = (uint16_t *) bitmap;
    lumi_dil = (uint16_t *) (bitmap + width * height * sizeof(uint16_t));

    lumi_of_rgba(lumi_orig, bitmap, width, height);
    lumi_dilate(lumi_dil, lumi_orig, width, height, DILATE_RADIUS);

    thresholds(&p, lumi_orig, width, height);
    
    p.lumi_orig = lumi_orig;
    p.lumi_dil = lumi_dil;
    p.width = width;
    p.height = height;
    
    starts = encode(classify, slopect, &p, width, height);
    if(starts == NULL) {
        *startsp = NULL;
        return [mres copy]; // Empty array
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
    return [mres copy];
}


NSArray *findqrcs(uint8_t *bitmap, size_t width, size_t height)
{
    RUN **starts;
    return findqrcs_x(&starts, bitmap, width, height);
}
