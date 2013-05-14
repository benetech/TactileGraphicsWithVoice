// Analysis.m     Analysis of an image
//
// Jeffrey Scofield, Psellos
// http://psellos.com
//
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
#import "Analysis.h"
#import "Section.h"
#import "runle.h"
#import "filters.h"
#import "bitmap.h"
#import "makesects.h"
#import "refinedblobs.h"
#import "findfinders.h"
#import "dockfinders.h"
#import "findqrcs.h"

@interface Analysis ()
- (void) setSections: (NSArray *) sections;
- (void) setQRBlobs: (NSArray *) QRBlobs;
- (void) setStarts: (RUN **) starts;
@end

@implementation Analysis

+ (Analysis *) analysisWithDevice: (Device *) device
                           bitmap: (uint8_t *) bitmap
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
    TGV_BITMAP bm;
    NSMutableDictionary *blobs;
    NSArray *fpblobs;
    RUN **starts;

    // Make the two luminance bitmaps.
    //
    lumi_orig = (uint16_t *) bitmap;
    lumi_dil = (uint16_t *) bitmap + width * height;

    lumi_of_rgba(lumi_orig, bitmap, width, height);
    if ([device isSlow])
        // On slow devices, use faster but slightly cruder accelerated
        // dilation.
        //
        lumi_dilate_accel(lumi_dil, lumi_orig, width, height, DILATE_RADIUS);
    else
        // On faster devices, use hand coded dilation.
        //
        lumi_dilate(lumi_dil, lumi_orig, width, height, DILATE_RADIUS);

    // Make histogram and compute initial thresholds.
    //
    lumi_rect_histogram(histogram, lumi_orig, width, height,
                        0, 0, width, height);
    otsu_thresh = histo_otsu_thresh(histogram, width * height);
    vvd_thresh = histo_vvd_thresh(histogram, width * height);
    res.otsu_thresh = otsu_thresh;
    res.vvd_thresh = vvd_thresh;

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
    res.fg_thresh = fg_thresh;

    // Find refined blobs.
    //
    bm.bm_lumi_orig = lumi_orig;
    bm.bm_lumi_dil = lumi_dil;
    bm.bm_width = width;
    bm.bm_height = height;
    bm.bm_ldthresh = fg_thresh;
    bm.bm_vvdthresh = vvd_thresh;
    blobs = refined_blobs(&starts, &bm, MIN_QR_SIZE);

    res.starts = starts;

    // Find finder pattern blobs and dock them with harboring blobs.
    // (Note that this modifies the dictionary of blobs.)
    //
    fpblobs = findfinders(MIN_QR_SIZE, MAX_QR_SIZE, &bm, starts, blobs);
    fpblobs = dockfinders(blobs, fpblobs);

    res.FPBlobs = fpblobs;

    // Find QR codes.
    //
    res.QRBlobs = findqrcs(MIN_QR_SIZE, MAX_QR_SIZE, &bm, starts,
                            blobs, fpblobs);

    // OK, finished.
    //
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

- (void) setFPBlobs: (NSArray *) FPBlobs
{
    _FPBlobs = FPBlobs;
    [_FPBlobs retain];
}


- (void) setStarts: (RUN **) starts
{
    _starts = starts;
}


- (void) setOtsu_thresh:(int)otsu_thresh
{
    _otsu_thresh = otsu_thresh;
}


- (void) setVvd_thresh:(int)vvd_thresh
{
    _vvd_thresh = vvd_thresh;
}


- (void) setFg_thresh:(int)fg_thresh
{
    _fg_thresh = fg_thresh;
}
@end
