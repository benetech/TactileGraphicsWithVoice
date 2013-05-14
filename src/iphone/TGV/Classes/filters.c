/* filters.c     Image filters
 *
 * Jeffrey Scofield, Psellos
 * http://psellos.com
 */
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
#include <stdio.h>
#include <strings.h>
#include <Accelerate/Accelerate.h>
#include "filters.h"

#define Max(a,b) \
   ({ __typeof__ (a) _a = (a); \
       __typeof__ (b) _b = (b); \
     _a > _b ? _a : _b; })

#define Min(a,b) \
   ({ __typeof__ (a) _a = (a); \
       __typeof__ (b) _b = (b); \
     _a < _b ? _a : _b; })

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
            if(     p - dsstart >= dsminwid &&
                    *(dsstart - 1) - *(p - 1) >= dsmindep)
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
     *
     * It's possible that we should just be using lumi_dilate_accel() all
     * the time. It's a lot faster, but not quite as accurate.
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


# define SCALECLAMP(s) ((Min(Max(127, s), 638) - 127) / 2)
# define UNSCALECLAMP(b) (b * 2 + 127)


void lumi_dilate_accel(uint16_t *out, uint16_t *in,
                    int width, int height, int radius)
{
    // Dilate using the vImage library.
    //
    static int tempWidth;
    static int tempHeight;
    static uint8_t *tempA; // Planar8 form of input
    static uint8_t *tempB; // Internal temp buffer for vImage
    static uint8_t *tempC; // Planar8 form of output
    
    // Allocate temporary buffers and keep pointers to them. In practice
    // there is just one allocation for each execution of the app, and
    // little to no reason to deallocate them.
    //
    if(tempWidth != width || tempHeight != height || tempA == NULL) {
        tempA = realloc(tempA, width * height); // One byte per pixel
        tempC = realloc(tempC, width * height);
        free(tempB); // (tempB is allocated below.)
        tempB = NULL;
        if(tempA == NULL | tempC == NULL) {
            // Desperation play. This should never happen; we're not
            // asking for all that much space.
            //
            free(tempA);
            free(tempC);
            tempA = NULL;
            tempC = NULL;
            memcpy(out, in, width * height * sizeof(uint16_t));
            return;
        }
        tempWidth = width;
        tempHeight = height;
    }

    int diam = radius * 2 + 1;
    vImage_Buffer src;
    vImage_Buffer dst;

    // Transform input to Planar8 form.
    //
    uint8_t *scb = tempA;
    uint16_t *send = in + width * height;
    for(uint16_t *s = in; s < send; s++)
        *scb++ = SCALECLAMP(*s);

    // Create data descriptors for vImage.
    //
    src.data = tempA;
    src.height = height;
    src.width = width;
    src.rowBytes = width;
    dst.data = tempC;
    dst.height = height;
    dst.width = width;
    dst.rowBytes = width;
    
    // Allocate vImage temp buffer if necessary. It makes things
    // noticeably faster to reuse the buffer.
    //
    if(tempB == NULL) {
        size_t size = vImageMin_Planar8(&src, &dst, NULL, 0, 0, diam, diam,
                                        kvImageGetTempBufferSize);
        if (size > 0)
            tempB = malloc(size); // If this fails, vImage will allocate
    }
    
    if (vImageMin_Planar8(&src, &dst, tempB, 0, 0, diam, diam, 0) != kvImageNoError) {
        // Same desperation play. Not likely to happen.
        //
        memcpy(out, in, width * height * sizeof(uint16_t));
        return;
    }

    // Translate Planar8 form to output.
    //
    uint16_t *uscs = out;
    uint8_t *bend = tempC + width * height;
    for(uint8_t *b = tempC; b < bend; b++)
        *uscs++ = UNSCALECLAMP(*b);
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
