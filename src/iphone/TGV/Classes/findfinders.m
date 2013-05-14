// findfinders.m     Find finder patterns as separate blobs
//
// Jeffrey Scofield, Psellos
// http://psellos.com
//
// This code identifies finder patterns by looking for a few orientation-
// independent features that seem like they ought to characterize them.
// There's plenty of room to use more powerful techniques to do a better
// job. Using ZXing's internal code doesn't seem like a good fit, because
// it's based too much on the image being in good focus.
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

#import "runle.h"
#import "filters.h"
#import "bitmap.h"
#import "Blob.h"
#import "findfinders.h"

#define MIN_FINDER_SIZE 18

#define MAX_SEGS 7

typedef struct {
    int prevy;               // Y value for previous run
    int prevct;              // Segment count for previous run
    int prevwidths[MAX_SEGS + 1]; // Widths for previous run
    int fphisto[MAX_SEGS+2]; // Histogram of segment counts 0..MAX_SEGS+1
    int fpsymmetric;         // Nontrivial runs that are symmetric
    int fplikeprev;          // Nontrivial runs that are like previous one
} FPDATA;

#define fpd_smallodd(fpd) \
    (fpd->fphisto[3] + fpd->fphisto[5] + fpd->fphisto[7])
#define fpd_nontriv(fpd) \
    (fpd->fphisto[4] + fpd->fphisto[5] + fpd->fphisto[6] + \
     fpd->fphisto[7] + fpd->fphisto[8])
#define fpd_multipart(fpd) \
    (fpd->fphisto[6] + fpd->fphisto[7])

// Thresholds that characterize finder patterns (scaled to the number of
// runs). A blob with all counts above these values is very likely to be
// a finder pattern (based on test corpus Mar 27 2013).
//
#define SMALLODD_THRESH  0.500 // Fraction of runs with 3,5,7 parts
#define SYMMETRIC_THRESH 0.557 // Fraction of runs that are symmetrical
#define LIKEPREV_THRESH  0.666 // Fraction of runs like previous run
#define MULTIPART_THRESH 0.164 // Fraction of runs with 6,7 parts

// Cumulative distributions and standard deviations among non finder
// patterns for the finder pattern metrics. We use these to give a
// confidence level to categorizing a blob as a finder pattern. (Based
// on test corpus Mar 28 2013.)
//
// To generate these tables on a Unix system (with awk):
//
//     $ cumulate findercorpus
//
// findercorpus is a list of finder pattern and non finder pattern
// metrics as for the thresholds above. cumulate is an awk script that
// processes the corpus to produce these tables. They're found in the
// Resources group (in the top directory of the project).
//
// To make a new corpus, you conceptually want to enable
// WRITE_FINDERPROPS below, and run the app over a set of images. Then
// determine which of the blobs are actually finder patterns. In practice
// this is much easier using a command-line version of the app.
//

static double g_smallodd[] = {
     0.023973, 0.054795, 0.099315, 0.099315, 0.143836,
     0.191781, 0.287671, 0.404110, 0.729452, 0.958904,
     1.000000
};
static double g_smallodd_s = 0.227778;
static double g_symmetric[] = {
     0.006849, 0.037671, 0.246575, 0.246575, 0.349315,
     0.489726, 0.636986, 0.791096, 0.938356, 1.000000,
     1.000000
};
static double g_symmetric_s = 0.223328;
static double g_likeprev[] = {
     0.424658, 0.469178, 0.702055, 0.702055, 0.794521,
     0.914384, 0.969178, 0.989726, 0.996575, 1.000000,
     1.000000
};
static double g_likeprev_s = 0.202091;
static double g_multipart[] = {
     0.458904, 0.623288, 0.886986, 0.886986, 0.996575,
     1.000000, 1.000000, 1.000000, 1.000000, 1.000000,
     1.000000
};
static double g_multipart_s = 0.124358;


double interpolate(double table[], double x)
{
    // Evaluate a function of the given value 0 <= x <= 1, based on
    // interpolating in the table.
    //
    // In our case the table entries are fractions of the corpus of
    // non-finder-patterns (hence probabilities) for measured values:
    // <= 0.0 , < 0.1, < 0.2, ..., < 1.0.
    //
    // So the value of interpolate(table, x) is the probability that a
    // non-finder-pattern will have a measured value *less than* x.
    //
    int tenths;
    double dummy;

    if(x <= 0.0)
        return 0.0;
    if(x > 1.0)
        return 1.0;
    if(x == 1.0)
        return table[10];
    tenths = x * 10.0; // 0 <= tenths <= 9
    double a = table[tenths];
    double b = table[tenths + 1];
    return a + modf(x * 10.0, &dummy) * (b - a);
}


double nearby_prob(double table[], double stddev, double x)
{
    // Return probability that a measured value will have a value near x
    // (based on test corpus).
    //
# define STDDEV_MULT 1.50

    double delta = STDDEV_MULT * stddev;
    return interpolate(table, x + delta) - interpolate(table, x - delta);
}


int close_enough(int a, int b, int multiplier)
{
    int aup = (a * multiplier + 9) / 10;
    int bup = (b * multiplier + 9) / 10;
    return (a <= b && b <= aup) || (b <= a && a <= bup);
}


int symmetric(int ct, int widths[])
{
# define SYMM_MULT 25
    if(ct < 2)
        // Not enough there to be truly symmetric.
        //
        return 0;
    for(int i = 0; i < ct / 2; i++)
        if(!close_enough(widths[i], widths[ct - 1 - i], SYMM_MULT))
            return 0;
    return 1;
}


int likeprev(int py, int pct, int pwds[], int y, int ct, int wds[])
{
#define PREV_MULT 14
    if(ct < 4)
        // Only nontrivial runs can be like previous.
        return 0;
    if(y != py + 1 || ABS(ct - pct) > 2)
        return 0;
    if(ct == pct) {
        for(int i = 0; i < ct; i++)
            if(!close_enough(pwds[i], wds[i], PREV_MULT))
                return 0;
        return 1;
    }
    return 0;
#ifdef DISABLED
    // (This calculation actually seemed to *mask* the difference
    // between finder patterns and other blobs.)
    //
    int hct = MIN(pct, ct) / 2;
    for(int i = 0; i < hct; i++) {
        if(!close_enough(pwds[i], wds[i], PREV_MULT))
            return 0;
        if(!close_enough(pwds[pct - 1 - i], wds[ct - 1 - i], PREV_MULT))
            return 0;
    }
    if(pct > ct) {
        int a = pwds[pct / 2 - 1] + pwds[pct / 2] + pwds[pct / 2 + 1];
        int b = wds[ct / 2];
        return close_enough(a, b, PREV_MULT);
    }
    int a = wds[ct / 2 - 1] + wds[ct / 2] + wds[ct / 2 + 1];
    int b = pwds[pct / 2];
    return close_enough(a, b, PREV_MULT);
#endif // DISABLED
}


int light_dark_segments(int a[], int alen, uint16_t *base, int width,
                        int thresh)
{
    // Calculate widths of alternating light and dark segments based on
    // the given threshold. If the first pixel is dark, the first
    // segment will have 0 width. Other widths are all nonzero. If there
    // are more than alen segments, return just the first alen widths.
    //
    uint16_t *start, *p, *pend;
    int ct;

    if(alen <= 0)
        return 0;
    ct = 0;
    p = base;
    pend = base + width;
    while(p < pend) {
        start = p;
        while(*p > thresh && p < pend) p++;
        a[ct++] = p - start;
        if(ct >= alen || p >= base + width)
            break;
        start = p;
        while(*p <= thresh && p < pend) p++;
        a[ct++] = p - start;
        if(ct >= alen)
            break;
    }
    return ct;
}


static void rate_fp_run(int ldthresh, FPDATA *fpd, int y,
                        uint16_t *base, int width)
{
    int widths[MAX_SEGS + 1];
    int ct;

    ct = light_dark_segments(widths, MAX_SEGS + 1, base, width, ldthresh);
    if(symmetric(ct, widths))
        fpd->fpsymmetric++;
    if(likeprev(fpd->prevy, fpd->prevct, fpd->prevwidths, y, ct, widths))
        fpd->fplikeprev++;
    fpd->fphisto[MIN(ct, MAX_SEGS + 1)]++;
    fpd->prevy = y;
    fpd->prevct = ct;
    memcpy(fpd->prevwidths, widths, (MAX_SEGS + 1) * sizeof(int));
}


static BOOL is_finder_pattern(int runct, FPDATA *fpd)
{
    float frunct = runct;
    int nontrivct = fpd_nontriv(fpd);
    float likeprev = fpd->fplikeprev / (float) MAX(nontrivct, 1);
    return
        fpd_smallodd(fpd) / frunct > SMALLODD_THRESH &&
        fpd->fpsymmetric / frunct > SYMMETRIC_THRESH &&
        likeprev > LIKEPREV_THRESH &&
        fpd_multipart(fpd) / frunct > MULTIPART_THRESH;
}


static float finder_confidence(int runct, FPDATA *fpd)
{
    // Calculate a probability that the blob with the given metrics
    // is a finder pattern. This uses the same metrics but is somewhat
    // independent of the threshold calculation in is_finder_pattern().
    // It's based just on the probability that a non-finder-pattern
    // would have the given measurements.
    //
    float frunct = runct;
    int nontrivct = fpd_nontriv(fpd);
    float likeprev = fpd->fplikeprev / (float) MAX(nontrivct, 1);
    float non_finder_prob =
        nearby_prob(g_smallodd, g_smallodd_s, fpd_smallodd(fpd) / frunct) *
        nearby_prob(g_symmetric, g_symmetric_s, fpd->fpsymmetric / frunct) *
        nearby_prob(g_likeprev, g_likeprev_s, likeprev) *
        nearby_prob(g_multipart, g_multipart_s, fpd_multipart(fpd) / frunct);
    return 1.0 - non_finder_prob;
}


NSArray *findfinders(int min_qr_size, int max_qr_size, TGV_BITMAP *bitmap,
                        RUN **starts, NSMutableDictionary *blobs)
{
# define NARROWEST_ASPECT 0.48
    int minpx, maxpx;
    NSMutableArray *fpcands = [NSMutableArray array];
    NSMutableArray *mres = [NSMutableArray array];
    int x, y;
    RUN *r, *comp;
    FPDATA *fpdata;
    uint16_t *base;

    minpx = MAX(min_qr_size / 3, MIN_FINDER_SIZE);
    minpx *= minpx;
    maxpx = max_qr_size / 3;
    maxpx *= maxpx;

    // Find all the finder pattern candidates. Hoping there won't be too
    // many of them.
    //
    for(NSValue *key in blobs) {
        Blob *b = [blobs objectForKey: key];
        b.data = NULL;
        int px = b.pixelCount;
        float aspect = (float) [b width] / [b height];
        if (px >= minpx && px < maxpx &&
            aspect >= NARROWEST_ASPECT && aspect <= 1.0 / NARROWEST_ASPECT) {
            [fpcands addObject: b];
            b.data = malloc(sizeof(FPDATA));
            memset(b.data, 0, sizeof(FPDATA));
        }
    }

    // Calculate metrics of the blobs used to determine whether they are
    // finder patterns.
    //
    for(y = 0; y < bitmap->bm_height; y++) {
        x = 0;
        for(r = starts[y]; r < starts[y + 1]; r++) {
            comp = component_find(r);
            Blob *b = [blobs objectForKey: [NSValue valueWithPointer: comp]];
            if ((fpdata = b.data) != NULL) {
                base = bitmap->bm_lumi_orig + y * bitmap->bm_width + x;
                rate_fp_run(bitmap->bm_ldthresh, fpdata, y, base, r->width);
            }
            x += r->width;
        }
    }

#ifdef WRITE_FINDERPROPS
    for(Blob *b in fpcands) {
        int runct = b.runCount;
        float frunct = runct;
        FPDATA *fpd = b.data;
        int nontrivct = fpd_nontriv(fpd);
        printf("x %3d y %3d w %3d h %3d | o %5.3f s %5.3f p %5.3f m %5.3f %5.3f r %d C %f%s\n",
            b.minx, b.miny, [b width], [b height],
            fpd_smallodd(fpd) / frunct,
            fpd->fpsymmetric / frunct,
            fpd->fplikeprev / (float) MAX(nontrivct, 1),
            fpd->fphisto[6] / frunct,
            fpd->fphisto[7] / frunct,
            runct,
            finder_confidence(runct, fpd),
            is_finder_pattern(runct, fpd) ? " *" : "");
    }
    fflush(stdout);
#endif // WRITE_FINDERPROPS

#ifdef DUMPBLOB
    {
    // Draw an ASCII art picture of a blob.
    //
    int widths[8];
    Blob *dumpb = nil;
    for(Blob *b in fpcands)
        if([b width] == 70) {
            dumpb = b;
            break;
        }
    if(dumpb != nil) {
        for(y = 0; y < bitmap->bm_height; y++) {
            x = 0;
            for(r = starts[y]; r < starts[y + 1]; r++) {
                comp = component_find(r);
                Blob *b =
                    [blobs objectForKey: [NSValue valueWithPointer: comp]];
                if(b == dumpb) {
                    FPDATA *fpd = b.data;
                    char s[64];
                    base = bitmap->bm_lumi_orig + y * bitmap->bm_width + x;
                    int ct = light_dark_segments(widths, 8, base, r->width,
                                bitmap->bm_ldthresh);
                    s[0] = '\0';
                    for(int i = 0; i < ct; i++)
                        sprintf(s + strlen(s), "%s%d", i > 0 ? "-" : "", widths[i]);
                    strcat(s, "                                ");
                    s[22] = '\0';
                    printf("%1d %s", ct, s);
                    for(int i = 0; i < x - b.minx; i++) putchar(' ');
                    for(int i = 0; i < r->width; i++)
                        putchar(base[i] <= bitmap->bm_ldthresh ? '#' : '_');
                    putchar('\n');
                }
                x += r->width;
            }
        }
    }
    }
#endif // DUMPBLOB

    // Accumulate (probable) finder patterns in mres. Set their
    // finderConf fields to a confidence level. Maybe we only want to do
    // an operation on things that we're extra sure are finder patterns.
    //
    for(Blob *b in fpcands) {
        if(is_finder_pattern(b.runCount, (FPDATA *) b.data)) {
            b.finderConf = finder_confidence(b.runCount, (FPDATA *) b.data);
            [mres addObject: b];
        }
        free(b.data);
        b.data = NULL;
    }

    return [[mres copy] autorelease];
}
