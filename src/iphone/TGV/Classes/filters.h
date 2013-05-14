/* filters.h     Image filters
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
