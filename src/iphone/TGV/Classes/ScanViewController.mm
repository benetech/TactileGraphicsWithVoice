// ScanViewController.mm
//
#import "ScanViewController.h"
#import "QRCodeReader.h"
#import "Voice.h"
#import "Blob.h"
#import "findqrcs.h"


@interface ScanViewController ()
@property (nonatomic, strong) Voice *voice;
@end


@implementation ScanViewController

@synthesize tabController = _tabController;
@synthesize resultsController = _resultsController;
@synthesize voice = _voice;

- (Voice *) voice
{
  if(!_voice) {
    _voice = [[Voice alloc] init];
  }
  return _voice;
}


- (void) scanPressed:(id)sender {
    NSMutableSet *readerset = [[NSMutableSet alloc ] init];

    QRCodeReader* qrcodeReader = [[QRCodeReader alloc] init];
    [readerset addObject:qrcodeReader];
    [qrcodeReader release];
    
    self.readers = readerset;
    [readerset release];
    
    NSBundle *mainBundle = [NSBundle mainBundle];
    self.soundToPlay =
        [NSURL fileURLWithPath:[mainBundle pathForResource:@"beep-beep" ofType:@"aiff"] isDirectory:NO];
}

- (BOOL) zxingController:(ZXingWidgetController *)controller
        shouldScanBitmap:(uint8_t *)bitmap
                   width:(size_t)width
                  height:(size_t)height
{
  // Tell the ZXing controller whether to scan the given bitmap looking
  // for QR codes. We say yes only if there looks to be exactly one full
  // code there. If there are more codes, or only a partial code, we offer
  // guidance on getting the camera to see just one code.
  //
  // Note: ownership of bitmap is being transferred to us. We need to
  // free it.
  //

#ifdef SAVEFRAMES
  // Make copy of original bitmap for failure analysis.
  uint8_t *bitmapCopy = (uint8_t *) malloc(width * height * 4);
  memcpy(bitmapCopy, bitmap, width * height * 4);
#endif

  NSArray *qrcs = findqrcs(bitmap, width, height);
  free(bitmap);

  // Just offer very crude guidance for now: the number of QR codes we see.
  //
  BOOL guided;
  switch([qrcs count]) {
    case 0: guided = [self.voice offerGuidance: @"zero"]; break;
    case 1: guided = [self.voice offerGuidance: @"one"]; break;
    case 2: guided = [self.voice offerGuidance: @"two"]; break;
    case 3: guided = [self.voice offerGuidance: @"three"]; break;
    default: guided = [self.voice offerGuidance: @"many"]; break;
  }

#ifdef SAVEFRAMES
  // Save failed frames for analysis. Test by scanning
  // exactly one QRC. (Change the count for later tests.)
  //
  if (guided && [qrcs count] != 1)
    [self saveFrame: bitmapCopy width: width height: height];
  free(bitmapCopy);
#endif
  
  // For now we just look at the number of codes located. Pretty soon
  // we'll look at whether they seem to be off the edge.
  //
#ifdef NEVERSCAN
  return NO;
#else
  return [qrcs count] == 1;
#endif
}


- (void) zxingController: (ZXingWidgetController *) controller
           didScanResult: (NSString *) scanres
{
  [self.resultsController addResult: scanres];
  self.tabController.selectedViewController = self.resultsController;
}


- (void) zxingControllerDidCancel: (ZXingWidgetController *) controller
{
  self.tabController.selectedViewController = self.resultsController;
}


- (id) init
{
  if(!(self = [self initWithDelegate: self showCancel: NO OneDMode: NO]))
    return nil;
  [self scanPressed: nil]; // TEMPORARY: make it suaver when it works
  return self;
}

- (id) initWithCoder: (NSCoder *) aDecoder
{
  if(!(self = [super initWithCoder: aDecoder]))
    return nil;
  self.delegate = self;
  self.showCancel = NO;
  self.oneDMode = NO;
  self.showLicense = NO;
  [self scanPressed: nil]; // TEMPORARY: make it suaver when it works
  return self;
}

- (void) saveFrame: (uint8_t *) bitmap
             width: (size_t) width height: (size_t) height
{
  // Save a frame to the photo album.
# define BPP 4
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  CGContextRef cgctx =
  CGBitmapContextCreate(bitmap, width, height, 8, width * BPP,
                        colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst);
  CGImageRef image = CGBitmapContextCreateImage(cgctx);
  CGContextRelease(cgctx);
  CGColorSpaceRelease(colorSpace);
  UIImageWriteToSavedPhotosAlbum([UIImage imageWithCGImage: image], nil, nil, nil);
  CGImageRelease(image);
}
@end

