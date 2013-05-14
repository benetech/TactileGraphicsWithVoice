// FrameLog.m    Log captured video frames for later analysis
//
// Jeffrey Scofield, Psellos
// http://psellos.com
//
// For speed, keep all the frames in memory. The save method writes them to
// the Photo Album and frees the memory. (Hope iOS doesn't get too annoyed.)
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

#import "filters.h"
#import "FrameLog.h"

#define ANNOT_HEIGHT 30

@interface FrameLog ()
@property (nonatomic, retain) NSMutableArray *frames;
@property (nonatomic, retain) NSMutableArray *times;
@property (nonatomic, retain) NSMutableArray *annotations;
@end

@implementation FrameLog
{
    int frameWidth;
    int frameHeight;
    CFAbsoluteTime start;
}

- (NSMutableArray *) frames
{
    if (!_frames)
        _frames = [[NSMutableArray alloc] init];
    return _frames;
}

- (NSMutableArray *) times
{
    if (!_times)
        _times = [[NSMutableArray alloc] init];
    return _times;
}

- (NSMutableArray *) annotations
{
    if (!_annotations)
        _annotations = [[NSMutableArray alloc] init];
    return _annotations;
}


- (void) logFrame: (uint8_t *) frame
        withWidth: (int) width
           height: (int) height
       annotation: (NSString *) annotation
{
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (start == 0.0) start = now;
    if (frameWidth == 0) {
        frameWidth = width;
        frameHeight = height;
    } else {
        // No need to get complex; all the frames will be the same size.
        //
        if (frameWidth != width || frameHeight != height) {
            NSLog(@"Incompatible frame size");
            return;
        }
    }
    [self.times addObject: [NSNumber numberWithDouble: now]];
    NSMutableData *frameData = [NSMutableData dataWithCapacity: width * (height + ANNOT_HEIGHT) * BPP];
    [frameData appendBytes: frame length: width * height * BPP];
    [self.frames addObject:frameData];
    [self.annotations addObject: annotation];
    NSLog(@"Logged frame %d", [self.frames count]); // TEMP TEMP
}


- (void) save
{
    NSNumber *z = [NSNumber numberWithInt: 0];
    NSMutableArray *context =
       [NSMutableArray arrayWithObjects: self.frames, self.times, self.annotations, z, nil];
    [context retain];
    self.frames = nil;
    self.times = nil;
    self.annotations = nil;
    [self saveNextFrame: nil error: nil context: context];
}

- (void) saveNextFrame: (UIImage *) oimage error: (NSError *) oerror context: (NSMutableArray *) context
{
    NSMutableArray *frames = context[0];
    NSMutableArray *times = context[1];
    NSMutableArray *annotations = context[2];
    int index = [(NSNumber *) context[3] intValue];
    if (index >= (int) [frames count]) {
        [context release];
        return;
    }
    context[3] = [NSNumber numberWithInt: index + 1];
    uint8_t *bitmap = [((NSMutableData *) frames[index]) mutableBytes];
    memset(bitmap + frameWidth * frameHeight * BPP, 0xff, frameWidth * ANNOT_HEIGHT * BPP);
    int height = frameHeight + ANNOT_HEIGHT;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx =
        CGBitmapContextCreate(bitmap, frameWidth, height, 8, frameWidth * BPP, colorSpace,
                          kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst);
    CGContextSelectFont(ctx, "Helvetica", ANNOT_HEIGHT - 6, kCGEncodingMacRoman);
    NSString *biganno = [NSString stringWithFormat: @"%d %6.4f %@",
                         index + 1,
                         [(NSNumber *) times[index] doubleValue] - start,
                         annotations[index]];
    const char *text = [biganno UTF8String];
    CGContextShowTextAtPoint(ctx, 5, 5, text, strlen(text));
    CGImageRef image = CGBitmapContextCreateImage(ctx);
    CGContextRelease(ctx);
    CGColorSpaceRelease(colorSpace);
    UIImageWriteToSavedPhotosAlbum([UIImage imageWithCGImage: image], self,
                                   @selector(saveNextFrame:error:context:),
                                   context);
    CGImageRelease(image);
    NSLog(@"Saved frame %d", index + 1); // TEMP TEMP
}

@end
