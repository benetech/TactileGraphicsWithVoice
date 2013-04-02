/* filters.h     Image filters
 */
#include <stdint.h>
#include <CoreGraphics/CGImage.h>
#include <QuartzCore/QuartzCore.h>

#define BPP 4                    /* Bytes per pixel for RGBA */
#define LUMINANCES (255 * 3 + 1) /* Number of different luminance values */

void lumi_of_rgba(uint16_t *out, uint8_t *in, int width, int height);
int lumi_rect_downslopes(uint16_t *in, int inwidth, int inheight,
                    int x, int y, int w, int h, int dsminwid, int dsmindep);
int lumi_rect_mean(uint16_t *in, int inwidth, int inheight,
                    int x, int y, int w, int h);
void lumi_rect_cumu_histogram(int *out, uint16_t *in, int inwidth, int inheight,
                    int x, int y, int w, int h);
void lumi_rect_histogram(int *out, uint16_t *in, int inwidth, int inheight,
                    int x, int y, int w, int h);
void lumi_dilate(uint16_t *out, uint16_t *in,
                    int width, int height, int radius);
void lumi_dilate_accel(uint16_t *out, uint16_t *in,
                 int width, int height, int radius);
void lumi_boxblur(uint16_t *out, uint16_t *in,
                    int width, int height, int radius);
int histo_otsu_thresh(int *histogram, int pixels);
int histo_vvd_thresh(int *histogram, int pixels);
