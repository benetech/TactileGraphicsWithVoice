/* filters.c     Image filters
 */
#include <stdio.h>
#include <strings.h>
#include "filters.h"

/* Native pixel component order on Mac is RGBA, but in iOS video
 * captures it's BGRA.
 */
#if TARGET_MAC
# define R 0
# define G 1
# define B 2
#else
# define R 2
# define G 1
# define B 0
#endif

static int lumi_crude(uint8_t *p)
{
    /* Return a crude luminance, defined as r + g + b.
     *
     * Returned values are in 0..LUMINANCES-1.
     */
    return p[R] + p[G] + p[B];
}

static int __attribute__((unused)) lumi_percept(uint8_t *p)
{
    /* Return a luminance based on human perception of different
     * frequencies. This is the usual definition and is used by ZXing.
     * (We're using the crude definition above for now.)
     *
     *   http://en.wikipedia.org/wiki/Luminance_(relative)
     *
     * Returned values are in 0..LUMINANCES-1.
     */
    return (int)
        (p[R] * (.2126 * 3.0) + p[G] * (.7152 * 3.0) + p[B] * (.0722 * 3.0));
}


void lumi_of_rgba(uint16_t *out, uint8_t *in, int width, int height)
{
    /* Translate an RGBA image to a grayscale image based on luminance.
     * It is permitted for out and in to be the same location.
     */
    uint8_t *p, *end;
    end = in + width * height * BPP;
    for(p = in; p < end; p += BPP)
        *out++ = lumi_crude(p);
}


int lumi_rect_downslopes(uint16_t *in, int inwidth, int inheight,
                    int x, int y, int w, int h, int dsminwid, int dsmindep)
{
    /* Count the number of downslopes in luminosity in a rectangle of
     * pixels (x, y, w, h).  A downslope must be of at least the given
     * width and depth. This is a rough measure of variegation in the
     * rectangle.
     */
# define MINROWSLOPES 2  /* Fewer downslopes in one row is insignificant */
    uint16_t *b, *p;
    uint16_t *bend, *pend, *dsstart;
    int rowslopect, slopect;

    if(x + w > inwidth) w = inwidth - x;
    if(y + h > inheight) h = inheight - y;
    slopect = 0;
    bend = in + (y + h) * inwidth;
    for(b = in + y * inwidth + x; b < bend; b += inwidth) {
        p = b + 1;
        pend = b + w;
        rowslopect = 0;
        while(p < pend) {
            for(; p < pend && *p >= *(p - 1); p++)
                ;
            if(p >= pend)
                break;
            dsstart = p;
            for(; p < pend && *p <= *(p - 1); p++)
                ;
            if(p - dsstart >= dsminwid && *dsstart - *(p - 1) >= dsmindep)
                rowslopect++;
        }
        if(rowslopect >= MINROWSLOPES)
            slopect += rowslopect;
    }
    return slopect;
}


int lumi_rect_mean(uint16_t *in, int inwidth, int inheight,
                    int x, int y, int w, int h)
{
    /* Return the mean luminosity of the rectangle of pixels (x, y, w, h).
     */
    int total, pixelct;
    uint16_t *b, *p;
    uint16_t *bend, *pend;

    if(x + w > inwidth) w = inwidth - x;
    if(y + h > inheight) h = inheight - y;
    total = 0;
    bend = in + (y + h) * inwidth;
    for(b = in + y * inwidth + x; b < bend; b += inwidth) {
        pend = b + w;
        for(p = b; p < pend; p++)
            total += *p;
    }
    pixelct = w * h;
    return (total + pixelct / 2) / pixelct;
}


void lumi_rect_cumu_histogram(int *out, uint16_t *in, int inwidth, int inheight,
                    int x, int y, int w, int h)
{
    /* Cumulative histogram for the rectangle of pixels (x, y, w, h).
     * I.e., it adds to whatever is already in out[].
     */
    uint16_t *b, *p;
    uint16_t *bend, *pend;

    if(x + w > inwidth) w = inwidth - x;
    if(y + h > inheight) h = inheight - y;
    bend = in + (y + h) * inwidth;
    for(b = in + y * inwidth + x; b < bend; b += inwidth) {
        pend = b + w;
        for(p = b; p < pend; p++)
            out[*p]++;
    }
}


void lumi_rect_histogram(int *out, uint16_t *in, int inwidth, int inheight,
                    int x, int y, int w, int h)
{
    memset(out, 0, LUMINANCES * sizeof(int));
    lumi_rect_cumu_histogram(out, in, inwidth, inheight, x, y, w, h);
}


void lumi_dilate(uint16_t *out, uint16_t *in,
                    int width, int height, int radius)
{
    /* Perform dilation of grayscale (luminance) image. in and out must
     * not overlap.
     *
     * Dilation sounds a little fancy:
     *
     *   http://en.wikipedia.org/wiki/Dilation_(morphology)
     *
     * However, for our purposes it just replaces each pixel by the
     * darkest of the surrounding pixels. It makes foreground regions
     * (dark regions) grow at their edges and fills in holes of the
     * given radius or less.
     *
     * Our "structuring element" is a square of side s=2*radius+1.
     * Since min() is commutative and associative, we can break things
     * into a horizontal and vertical pass. So for each pixel we process
     * 2 * s nearby pixels rather than s * s.
     */
    uint16_t *end;
    uint16_t *row, *col, *p, *minp, *a, *b;
    uint16_t scratch[height]; // C99 construct

    /* Horizontal pass.
     */
    end = in + width * height;
    for(row = in; row < end; row += width)
        for(p = row; p < row + width; p++) {
            if((a = p - radius) < row) a = row;
            if((b = p + radius + 1) > row + width) b = row + width;
            minp = p;
            for(; a < b; a ++)
                if(*a < *minp) minp = a;
            out[p - in] = *minp;
        }
    /* Vertical pass.
     */
    end = out + width * height;
    for(col = out; col < out + width; col++) {
        for(p = col; p < end; p += width) {
            if((a = p - radius * width) < out) a = col;
            if((b = p + (radius + 1) * width) > end) b = col + height * width;
            minp = p;
            for(; a < b; a += width)
                if(*a < *minp) minp = a;
            scratch[(p - col) / width] = *minp;
        }
        minp = scratch;
        for(p = col; p < end; p += width)
            *p = *minp++;
    }
}


void lumi_boxblur(uint16_t *out, uint16_t *in,
                    int width, int height, int radius)
{
    /* Perform box blur of grayscale image. in and out must not overlap.
     *
     * Box blur sets each pixel to the average of the surrounding
     * pixels. For equal sized groups, the overall average is the same
     * as the average of the group averages. So we can break things into
     * a horizontal and a vertical pass. Using a moving sum, the blur
     * can be calculated by looking at 2 nearby pixels for each pixel
     * for each direction (independent of the radius). That's 4
     * pixels in all for each pixel (with a little initial setup).
     */
    uint16_t *end;
    uint16_t *row, *col, *p, *a, *b;
    int denom, ct;
    uint16_t scratch[height]; // C99 construct

    denom = radius * 2 + 1;

    /* Horizontal pass.
     */
    end = in + width * height;
    for(row = in; row < end; row += width) {
        ct = (radius + 1) * *row;
        for(p = row; p < row + radius; p++)
            ct += *p;
        for(p = row; p < row + width; p++) {
            if((a = p - radius - 1) < row) a = row;
            if((b = p + radius) > row + width - 1) b = row + width - 1;
            ct = ct - *a + *b;
            out[p - in] = (ct + radius) / denom;
        }
    }
    /* Vertical pass.
     */
    end = out + width * height;
    for(col = out; col < out + width; col++) {
        ct = (radius + 1) * *col;
        for(p = col; p < col + radius * width; p += width)
            ct += *p;
        for(p = col; p < end; p += width) {
            if((a = p - (radius + 1) * width) < out)
                a = col;
            if((b = p + radius * width) > end - width)
                b = col + (height - 1) * width;
            ct = ct - *a + *b;
            scratch[(p - col) / width] = (ct + radius) / denom;
        }
        a = scratch;
        for(p = col; p < end; p += width)
            *p = *a++;
    }
}


#ifdef FORMERLY
void lumi_histogram(int *out, uint16_t *in, int width, int height)
{
    /* Calculate a histogram of the given grayscale (luminance) image.
     */
    uint16_t *end = in + width * height;
    memset(out, 0, LUMINANCES * sizeof(int));
    while(in < end)
        out[*in++]++;
}
#endif /* FORMERLY */


int histo_otsu_thresh(int *histogram, int pixels)
{
    /* Find a good threshold between dark and light pixels using Otsu's
     * method:
     *
     *   http://en.wikipedia.org/wiki/Otsu's_method
     *
     * It's a clustering algorithm that minimizes the variance in
     * luminosity within each group of pixels. It does this by
     * maximizing the difference between the groups.
     */
    double total;     // Total number of pixels
    double pxbelow;   // Number of pixels below current threshold
    double sumbelow;  // sum of luminance * count over all pixels below
    double sumabove;  // sum of luminance * count over all pixels above
    int maxlum;       // luminance with maximum variance so far
    double maxvar;    // maximum variance so far
    double var, md; 
    int i;

    total = pixels;
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


int histo_vvd_thresh(int *histogram, int pixels)
{
    /* Find the threshold between very very dark pixels and the rest.
     */
# define TOTALLY_DARK_F 0.005
    int breakpt05, ct, i;
    
    breakpt05 = pixels * TOTALLY_DARK_F;
    ct = 0;
    for(i = 0; i < LUMINANCES; i++) {
        ct += histogram[i];
        if(ct >= breakpt05)
            break;
    }
    return i;
}
