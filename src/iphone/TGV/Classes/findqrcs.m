/* findqrcs.m     Find and classify QR codes in an image
 */
#import "runle.h"
#import "findqrcs.h"
#import "Blob.h"
#import "findblobs.h"

#define max(a, b) ((a) > (b) ? (a) : (b))
#define min(a, b) ((a) < (b) ? (a) : (b))

# define BPP 4 /* Bytes per pixel */

typedef struct {
    unsigned char *bitmap;
    int width, height;
    int thresh;        // Threshold between dark and light
    int thresh05;      // Threshold of very very dark (0.5% are darker)
} BITMAP_PARAMS;

static void blur2d(unsigned char *bitmap, int width, int height, int radius)
{
# define LCOMP(b, x) ((x) >= 0 ? b[x] : b[((x)+stride)%BPP])
# define RCOMP(b, x) ((x) < stride ? b[x] : b[stride-BPP+(x)%BPP])
# define LCOMPV(b, x) ((x) >= 0 ? b[x] : b[(totbytes+(x))%stride])
# define RCOMPV(b, x) ((x) < totbytes ? b[x] : b[totbytes-stride+(x)%stride])
    struct rgb { int b, g, r; } accum;
    int stride = width * BPP;
    int totbytes = width * height * BPP;
    unsigned char *end;
    unsigned char *base;
    int denom = radius * 2 + 1;
    int l, c, r, i;
    int scratchlen = (width > height ? width : height) * BPP;
    unsigned char *scratch = malloc(scratchlen);
    
    end = bitmap + height * stride;
    for(base = bitmap; base < end; base += stride) {
        accum.b = (radius + 1) * base[0];
        accum.g = (radius + 1) * base[1];
        accum.r = (radius + 1) * base[2];
        for(c = 0; c < radius * BPP; c += BPP) {
            accum.b += base[c + 0];
            accum.g += base[c + 1];
            accum.r += base[c + 2];
        }
        for(    l = -BPP * (radius + 1), c = 0, r = BPP * radius;
                c < stride;
                l += BPP, c += BPP, r += BPP) {
            accum.b -= LCOMP(base, l + 0);
            accum.g -= LCOMP(base, l + 1);
            accum.r -= LCOMP(base, l + 2);
            accum.b += RCOMP(base, r + 0);
            accum.g += RCOMP(base, r + 1);
            accum.r += RCOMP(base, r + 2);
            scratch[c + 0] = (accum.b + radius) / denom;
            scratch[c + 1] = (accum.g + radius) / denom;
            scratch[c + 2] = (accum.r + radius) / denom;
            scratch[c + 3] = base[c + 3];
        }
        memcpy(base, scratch, stride);
    }
    
    end = bitmap + stride;
    for(base = bitmap; base < end; base += BPP) {
        accum.b = (radius + 1) * base[0];
        accum.g = (radius + 1) * base[1];
        accum.r = (radius + 1) * base[2];
        for(c = 0; c < radius * stride; c += stride) {
            accum.b += base[c + 0];
            accum.g += base[c + 1];
            accum.r += base[c + 2];
        }
        for(    l = -stride * (radius + 1), i = 0, c = 0, r = stride * radius;
                c < totbytes;
                l += stride, i += BPP, c += stride, r += stride) {
            accum.b -= LCOMPV(base, l + 0);
            accum.g -= LCOMPV(base, l + 1);
            accum.r -= LCOMPV(base, l + 2);
            accum.b += RCOMPV(base, r + 0);
            accum.g += RCOMPV(base, r + 1);
            accum.r += RCOMPV(base, r + 2);
            scratch[i + 0] = (accum.b + radius) / denom;
            scratch[i + 1] = (accum.g + radius) / denom;
            scratch[i + 2] = (accum.r + radius) / denom;
            scratch[i + 3] = base[c + 3];
        }
        for(i = 0, c = 0; c < totbytes; i += BPP, c += stride)
            * (int32_t *) (base + c) = * (int32_t *) (scratch + i);
    }
    
    free(scratch);
}

static int luminance(unsigned char *pixel)
{
    /* Return the luminance of the given pixel, which I'm defining as
     * b + g + r.
     */
    return pixel[0] + pixel[1] + pixel[2];
    // Alternate luminance def based on human perception.
    //return (int)
    //(pixel[0] * (.0722 * 3.0) +
     //pixel[1] * (.7152 * 3.0) +
     //pixel[2] * (.2126 * 3.0));
}

#ifdef COULD_BE_USEFUL
static float saturation(unsigned char *pixel)
{
    /* Return the saturation (density of hue) of the given pixel.
     */
    int low = min(min(pixel[0], pixel[1]), pixel[2]);
    int high = max(max(pixel[0], pixel[1]), pixel[2]);
    return high == 0 ? 0.0 : ((float) (high - low) / high);
}

static BOOL grayish(unsigned char *pixel)
{
    /* Return true if the given pixel (R,G,B,x) is reasonably close to
     * gray. I.e., if the saturation is below a certain level.
     */
    return saturation(pixel) < 0.2;
}
#endif /* COULD_BE_USEFUL */

static void thresholds(BITMAP_PARAMS *bpar,
                    unsigned char *bitmap, int width, int height, float f)
{
    /* Calculate threshold luminances: (a) between foreground (dark) and
     * background (light)--i.e.,the point where the given fraction f of
     * pixels are darker; (b) between not totally dark and totally
     * dark--at the point where almost no (currently, 0.5%) pixels are
     * darker.
     * 
     * Note: this code assumes f > TOTALLY_DARK_F.
     */
# define TOTALLY_DARK_F 0.005
# define LUMINANCES (255 * 3 + 1)
    int histogram[LUMINANCES], ct, thresh;
    int bytes, breakpt05, breakpt, i;
    
    bytes = width * height * BPP;
    breakpt05 = width * height * TOTALLY_DARK_F;
    breakpt = width * height * f;
    memset(histogram, 0, LUMINANCES * sizeof(int));
    for(i = 0; i < bytes; i += BPP)
        histogram[luminance(bitmap + i)]++;
#ifdef WRITE_HISTOGRAM
    for(i = 0; i < LUMINANCES; i++)
        printf("%d\n", histogram[i]);
#endif
    ct = 0;
    bpar->thresh05 = LUMINANCES;
    for(thresh = 0; thresh < LUMINANCES; thresh++) {
        ct += histogram[thresh];
        if(bpar->thresh05 >= LUMINANCES && ct >= breakpt05)
            bpar->thresh05 = thresh;
        if(ct >= breakpt) {
            bpar->thresh = thresh;
            break;
        }
    }
}


static int classify(void *ck, int x, int y)
{
    BITMAP_PARAMS *p = ck;
    return luminance(p->bitmap + (p->width * y + x) * BPP) <= p->thresh;
}


static int slopect(void *ck, int x, int y, int wd)
{
    // Count the number of significant downslopes of luminance. This is
    // an attempt to measure the amount of variegation in a blob. QR
    // codes are noticeably variegated even when out of focus.
    //
    BITMAP_PARAMS *p = ck;
    int minbytes = 3 * BPP;
    int mindepth = (p->thresh - p->thresh05) / 4;
    int bytes = wd * BPP;
    unsigned char *base = p->bitmap + (p->width * y + x) * BPP;
    int sct, start, i;

    sct = 0;
    i = BPP;
    while(i < bytes) {
        for(    ;
                i < bytes && luminance(base + i) >= luminance(base + i - BPP);
                i += BPP)
            ;
        if(i >= bytes)
            break;
        start = i;
        for(    ;
                i < bytes && luminance(base + i) <= luminance(base + i - BPP);
                i += BPP)
            ;
        if(     i - start >= minbytes &&
                luminance(base + start) - luminance(base + i - BPP) >= mindepth)
            sct++;
    }
    return sct;
}


static int qr_candidate(Blob *blob)
{
    /* Determine whether the blob is a potential QR code.
     */
# define VARIEGATION_THRESH 1.0             /* CRUDE FOR NOW */
# define QRSIZE(x) ((x) >= 30 && (x) < 240) /* CRUDE FOR NOW */
    if(blob == nil)
        return 0;
    int width = blob.maxx - blob.minx + 1;
    int height = blob.maxy - blob.miny + 1;
#ifdef DEVELOP
    printf("class %d w %d h %d runCount %d slope %f\n",
        blob.bclass, width, height, blob.runCount, 
        blob.slopeCount / (double) blob.runCount);
#endif /* DEVELOP */
    return
        blob.bclass == 1 && QRSIZE(width) && QRSIZE(height) &&
            // blob.runCount < height + height && /* TRY AFTER COALESCE */
            blob.slopeCount / (double) blob.runCount >= VARIEGATION_THRESH;
}


NSArray *findqrcs_x(RUN ***startsp, uint8_t *bitmap,
                        size_t width, size_t height)
{
    // (This internal function returns the calculated runs through
    // *startsp, which is useful during development.)
    //
# define BLUR_RADIUS 3
    // A fixed value for dark fraction is clearly not such a good idea.
    // There's a lot of variation in the number of dark pixels. Need to
    // calculate it from the histogram, if possible.
    //
    // History:
    //     0.125 initially (while blurring was introducing extra dark pixels)
    //     0.1 after blurring was fixed
    //     0.2 to try to improve behavior when QRC is close to camera
# define DARK_FRACTION 0.20
    BITMAP_PARAMS p;
    RUN **starts;
    NSMutableArray *mres = [[[NSMutableArray alloc] init] autorelease];

    blur2d(bitmap, width, height, BLUR_RADIUS);

    thresholds(&p, bitmap, width, height, DARK_FRACTION);
    
    p.bitmap = bitmap;
    p.width = width;
    p.height = height;

    starts = encode(classify, slopect, &p, width, height);
    if(starts == NULL) {
        *startsp = NULL;
        return [mres copy]; // Empty array
    }
    NSMutableDictionary *dict = findblobs(height, starts);

    for(NSNumber *key in dict) {
        Blob *b = [dict objectForKey: key];
        if(qr_candidate(b))
            [mres addObject: b];
    }

    *startsp = starts;
    return [mres copy];
}


NSArray *findqrcs(uint8_t *bitmap, size_t width, size_t height)
{
    RUN **starts;
    return findqrcs_x(&starts, bitmap, width, height);
}
