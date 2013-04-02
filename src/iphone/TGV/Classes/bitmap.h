/* bitmap.h     TGV bitmap info
 *
 * TGV works with two versions of an image. lumi_orig is the original
 * image, converted to grayscale (luminance values). lumi_dil is a
 * dilated version of the original, which makes the QR codes stand out
 * better. Dilation is explained in filters.c.
 *
 * Each pixel value ranges between 0 and LUMINANCES - 1 (in filters.h).
 */

typedef struct {
    uint16_t *bm_lumi_orig; // Original grayscale (luminance) bitmap image
    uint16_t *bm_lumi_dil;  // Dilated grayscale (luminance) bitmap image
    int bm_width, bm_height;
    int bm_ldthresh;        // Threshold between dark and light
    int bm_vvdthresh;       // Threshold of very very dark (very few are darker)
} TGV_BITMAP;
