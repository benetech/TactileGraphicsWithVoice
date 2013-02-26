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


void lumi_histogram(int *out, uint16_t *in, int width, int height)
{
    /* Calculate a histogram of the given grayscale (luminance) image.
     */
    uint16_t *end = in + width * height;
    memset(out, 0, LUMINANCES * sizeof(int));
    while(in < end)
        out[*in++]++;
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
