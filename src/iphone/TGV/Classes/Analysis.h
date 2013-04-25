// Analysis.h     Analysis of an image
//
// Jeffrey Scofield, Psellos
// http://psellos.com
//
#import <Foundation/Foundation.h>
#import "Device.h"
#import "runle.h"

// These values control what we consider to be a QR code in the first
// place.  Later processing in ScanViewController decides whether a code
// is off the edge, or too close or too far from the camera. This
// analysis code is specifically designed to be able to count QR codes
// that can't be scanned properly, so we can give advice on how to get a
// good scan.  So we want to use values as liberal as possible here,
// without allowing too many false positives. I.e., we want to be quite
// sure they really are QR codes, but we don't care whether the ZXing
// code will be able to scan them.
//
// Max for QRSIZE was 240 for a while. Recent tests suggest it's OK to
// make it bigger. But keep an eye on it.
//
// Min for QRSIZE was 30 for a long time, then I raised it to 50.  Now
// that seems too big to me. Trying it at 40.
//
#define MIN_QR_SIZE 40
#define MAX_QR_SIZE 300

@interface Analysis : NSObject
@property (readonly, nonatomic, retain) NSArray *sections; // Sections
@property (readonly, nonatomic, retain) NSArray *FPBlobs; // Finders as Blobs
@property (readonly, nonatomic, retain) NSArray *QRBlobs;  // QR codes as Blobs
@property (readonly, nonatomic) RUN **starts; // (Low level runs of blobs)
@property (readonly, nonatomic) int otsu_thresh;
@property (readonly, nonatomic) int vvd_thresh;
@property (readonly, nonatomic) int fg_thresh;

+ (Analysis *) analysisWithDevice: (Device *) device
                           bitmap: (uint8_t *) bitmap
                            width: (size_t) width
                           height: (size_t) height;
@end
