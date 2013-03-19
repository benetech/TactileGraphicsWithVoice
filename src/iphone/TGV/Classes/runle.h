/* runle.h     Run length encoding
 */

/* A horizontal row of adjacent pixels of the same class. Right now we
 * just have two classes, background (light) and foreground (dark).
 */
typedef struct run {
    short pclass;           /* Pixel class (currently 0 = bg, 1 = fg) */
    short slopes;           /* Number of luminosity gradations (fg only) */
    int width;
    struct run *component;  /* Containing component, for union-find */
} RUN;

RUN **encode(int classify(void *, int, int), void *ck, int width, int height);

void component_union(RUN *, RUN *);
RUN *component_find(RUN *);
