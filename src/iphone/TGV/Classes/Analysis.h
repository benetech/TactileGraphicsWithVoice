// Analysis.h     Analysis of an image
//
#import <Foundation/Foundation.h>
#import "runle.h"

@interface Analysis : NSObject
@property (readonly, nonatomic, retain) NSArray *sections; // Sections
@property (readonly, nonatomic, retain) NSArray *QRBlobs;  // QR codes as Blobs
@property (readonly, nonatomic) RUN **starts; // (Low level runs of blobs)
@property (readonly, nonatomic) int otsu_thresh;
@property (readonly, nonatomic) int vvd_thresh;
@property (readonly, nonatomic) int fg_thresh;

+ (Analysis *) analysisWithBitmap: (uint8_t *) bitmap
                            width: (size_t) width
                           height: (size_t) height;
@end
