// Analysis.m     Analysis of an image
//
#import "Analysis.h"
#import "Section.h"
#import "runle.h"
#import "filters.h"
#import "makesects.h"
#import "findqrcs.h"

@interface Analysis ()
- (void) setSections: (NSArray *) sections;
- (void) setQRBlobs: (NSArray *) QRBlobs;
- (void) setStarts: (RUN **) starts;
@end

@implementation Analysis
@synthesize sections = _sections;
@synthesize QRBlobs = _QRBlobs;
@synthesize starts = _starts;

+ (Analysis *) analysisWithBitmap: (uint8_t *) bitmap
                            width: (size_t) width
                           height: (size_t) height
{
    // Return an analysis of the bitmap image. Caller allows us to
    // overwrite the bitmap.
    //
    // Plan: we overwrite the bitmap with two half-size luminance
    // bitmaps. The first is the original luminance, the second is
    // dilated (to help find the QR codes).
    //
# define DILATE_RADIUS 3
# define SECTION_UNITS 10  // Divide image into 100 sections
    Analysis *res = [[[[self class] alloc] init] autorelease];
    uint16_t *lumi_orig;  // Original image in grayscale (luminance)
    uint16_t *lumi_dil;   // Dilated image in grayscale (luminance)
    int histogram[LUMINANCES];
    int otsu_thresh, vvd_thresh, fg_thresh;
    RUN **starts;

    // Make the two luminance bitmaps.
    //
    lumi_orig = (uint16_t *) bitmap;
    lumi_dil = (uint16_t *) bitmap + width * height;

    lumi_of_rgba(lumi_orig, bitmap, width, height);
    lumi_dilate(lumi_dil, lumi_orig, width, height, DILATE_RADIUS);

    // Make histogram and compute initial thresholds.
    //
    lumi_rect_histogram(histogram, lumi_orig, width, height,
                        0, 0, width, height);
    otsu_thresh = histo_otsu_thresh(histogram, width * height);
    vvd_thresh = histo_vvd_thresh(histogram, width * height);

    // Get properties of sections and calculate foreground threshold.
    //
    res.sections =
        makesects(lumi_orig, width, height, otsu_thresh, vvd_thresh,
                            SECTION_UNITS);
    fg_thresh = [self fgThresholdForBitmap: lumi_orig
                                     width: width
                                    height: height
                                  sections: res.sections
                                 threshold: otsu_thresh];

    // Find QR codes.
    //
    res.QRBlobs =
        findqrcs_x(&starts, lumi_orig, lumi_dil, width, height,
                        fg_thresh, vvd_thresh);
    res.starts = starts; // Info for troubleshooting

    return res;
}


+ (int) fgThresholdForBitmap: (uint16_t *) lumi
                       width: (int) width
                      height: (int) height
                    sections: (NSArray *) sections
                   threshold: (int) threshold
{
    // Determine a threshold based on the foreground parts of the image,
    // ignoring the light, unvariegated parts. This helps find QR codes
    // with shadows nearby.
    //
# define MIN_FG_SECTS 2
# define FG_VARI_THRESH 0.015
    int histogram[LUMINANCES];
    int fgsections, pixels;

    memset(histogram, 0, LUMINANCES * sizeof(int));

    fgsections = 0;
    pixels = 0;
    for(Section *s in sections) {
        if(s.meanLuminance > threshold && s.variegation < FG_VARI_THRESH)
            continue;
        fgsections++;
        pixels += s.w * s.h;
        lumi_rect_cumu_histogram(histogram, lumi, width, height,
                                    s.x, s.y, s.w, s.h);
    }

    if(fgsections < MIN_FG_SECTS)
        // Didn't see enough foreground to determine a threshold.
        //
        return threshold;
    return histo_otsu_thresh(histogram, pixels);
}


- (void) setSections: (NSArray *) sections
{
    _sections = sections;
    [_sections retain];
}


- (void) setQRBlobs: (NSArray *) QRBlobs
{
    _QRBlobs = QRBlobs;
    [_QRBlobs retain];
}

- (void) setStarts: (RUN **) starts
{
    _starts = starts;
}
@end
