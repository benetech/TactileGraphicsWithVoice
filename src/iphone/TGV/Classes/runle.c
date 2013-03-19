/* runle.c     Run length encoding
 *
 * (Coding this in straight C for speed.)
 */
#include <stdlib.h>
#include <string.h>
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
