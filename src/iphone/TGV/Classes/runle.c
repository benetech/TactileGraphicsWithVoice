/* runle.c     Run length encoding
 *
 * Jeffrey Scofield, Psellos
 * http://psellos.com
 *
 * (Coding this in straight C for speed.)
 */
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "runle.h"


RUN **encode(int classify(void *, int, int), void *ck, int width, int height)
{
    /* Do run length encoding of bitmap data. The classify() function
     * takes the given opaque cookie and classifies a pixel at a given
     * (x, y) position, for 0 <= x < width and 0 <= y < height.  Return
     * an array that points to the start of the runs for each row. The
     * runs all occupy the same array, so runs for one row end at the
     * beginning of the runs of the next.  The last entry in the array
     * points just past the runs of the last row.
     * 
     * This function retains ownership of the returned values, which are
     * potentially freed or overwritten at the next call.
     */
    static int irunsz = 0;
    static RUN *iruns;
    static int istartsz = 0;
    static RUN **istarts;

    int cursz = width * height * sizeof(RUN);
    if(irunsz < cursz) {
        iruns = realloc(iruns, cursz);
        irunsz = cursz;
    }
    cursz = (height + 1) * sizeof(RUN *);
    if(istartsz < cursz) {
        istarts = realloc(istarts, cursz);
        istartsz = cursz;
    }
    int rct, x, y, startx, curcl, cl;

    if(iruns == NULL || istarts == NULL)
        return NULL;
    memset(iruns, 0, cursz * sizeof(RUN));
    rct = 0;
    for(y = 0; y < height; y++) {
        istarts[y] = iruns + rct;
        startx = 0;
        curcl = classify(ck, 0, y);
        for(x = 1; x < width; x++) {
            cl = classify(ck, x, y);
            if(cl != curcl) {
                iruns[rct].pclass = curcl;
                iruns[rct].width = x - startx;
                iruns[rct].component = NULL;
                curcl = cl;
                startx = x;
                rct++;
            }
        }
        iruns[rct].pclass = curcl;
        iruns[rct].width = x - startx;
        iruns[rct].component = NULL;
        rct++;
    }
    istarts[y] = iruns + rct;
    return istarts;
}


RUN **encode_16_thresh(uint16_t *bitmap, int width, int height, int thresh)
{
    /* Do run length encoding of 16-bpp bitmap data with a specified
     * light/dark threshold.  Return an array that points to the start
     * of the runs for each row. The runs all occupy the same array, so
     * runs for one row end at the beginning of the runs of the next.
     * The last entry in the array points just past the runs of the last
     * row.
     * 
     * This function retains ownership of the returned values, which are
     * potentially freed or overwritten at the next call.
     */
    static int irunsz = 0;
    static RUN *iruns;
    static int istartsz = 0;
    static RUN **istarts;

    int cursz = width * height * sizeof(RUN);
    if(irunsz < cursz) {
        iruns = realloc(iruns, cursz);
        irunsz = cursz;
    }
    cursz = (height + 1) * sizeof(RUN *);
    if(istartsz < cursz) {
        istarts = realloc(istarts, cursz);
        istartsz = cursz;
    }
    int curcl, cl;
    RUN *runp;
    RUN **startp;
    uint16_t *bitmapend;
    uint16_t *row;
    uint16_t *rowend;
    uint16_t *startpx;
    uint16_t *pixel;

    if(iruns == NULL || istarts == NULL)
        return NULL;
    memset(iruns, 0, cursz * sizeof(RUN));
    startp = istarts;
    runp = iruns;
    bitmapend = bitmap + (width * height);
    for(row = bitmap; row < bitmapend; row += width) {
        *startp++ = runp;
        startpx = row;
        curcl = *startpx <= thresh;
        rowend = row + width;
        for(pixel = row + 1; pixel < rowend; pixel++) {
            cl = *pixel <= thresh;
            if(cl != curcl) {
                runp->pclass = curcl;
                runp->width = pixel - startpx;
                runp->component = NULL;
                curcl = cl;
                startpx = pixel;
                runp++;
            }
        }
        runp->pclass = curcl;
        runp->width = pixel - startpx;
        runp->component = NULL;
        runp++;
    }
    *startp = runp;
    return istarts;
}

/* This is the Tarjan union-find algorithm for runs. (Actually I'm not
 * bothering to keep track of the tree sizes.)
 *
 * http://en.wikipedia.org/wiki/Disjoint-set_data_structure
 */

void component_union(RUN *ra, RUN *rb)
{
    /* Union the components of the two runs.
     */
    RUN *arep = component_find(ra);
    RUN *brep = component_find(rb);
    arep->component = brep;
}


RUN *component_find(RUN *r)
{
    /* Find the representative run for r.
     */
    if(r == NULL || r->component == NULL)
        return NULL;
    if(r->component == r)
        return r; // r is representative
    r->component = component_find(r->component); // Path compression
    return r->component;
}
