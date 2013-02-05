// ScanViewController.mm
//
#import "ScanViewController.h"
#import "QRCodeReader.h"
#import "Voice.h"
#import "Blob.h"
#import "findqrcs.h"


@interface ScanViewController ()
@property (nonatomic, strong) Voice *voice;
- (void) initialize;
- (void) didBecomeActive: (NSNotification *) notification;
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

- (BOOL) zxingController:(ZXingWidgetController *)controller
        shouldScanBitmap:(uint8_t *)bitmap
                   width:(size_t)width
                  height:(size_t)height
{
  // Tell the ZXing controller whether to scan the given bitmap looking
  // for QR codes. We say yes only if there looks to be one code there.
  // We also offer vocal guidance on getting the camera to see just one
  // code.
  //
  // Note: ownership of bitmap is being transferred to us. We need to
  // free it.
  //

#ifdef SAVEFRAMES
  // Make copy of original bitmap for failure analysis.
  //
  uint8_t *bitmapCopy = (uint8_t *) malloc(width * height * 4);
  memcpy(bitmapCopy, bitmap, width * height * 4);
#endif

  NSArray *qrcs = findqrcs(bitmap, width, height);
  free(bitmap);

  // For now, pretty simple guidance. If number of QR codes <> 1, then
  // say the number seen. If there is 1 code at edge, name the edge.
  // Otherwise just say "one".
  //
  // Note: images are presented in landscape mode with home button to
  // the right. We're translating here between this orientation and the
  // expected portrait orientation of the phone while scanning. (This is
  // something to figure out, however.)
  //
  BOOL guided;
  switch([qrcs count]) {
    case 0: guided = [self.voice offerGuidance: @"zero"]; break;
    case 1:
      if ([qrcs[0] touchesTop])
        guided = [self.voice offerGuidance: @"right"];
      else if ([qrcs[0] touchesBottom])
        guided = [self.voice offerGuidance: @"left"];
      else if ([qrcs[0] touchesLeft])
        guided = [self.voice offerGuidance: @"top"];
      else if ([qrcs[0] touchesRight])
        guided = [self.voice offerGuidance: @"bottom"];
      else
        guided = [self.voice offerGuidance: @"one"];
      break;
    case 2: guided = [self.voice offerGuidance: @"two"]; break;
    case 3: guided = [self.voice offerGuidance: @"three"]; break;
    default: guided = [self.voice offerGuidance: @"many"]; break;
  }

#ifdef SAVEFRAMES
  // Save failed frames for analysis. Test by scanning
  // exactly one QRC. (Change the count here for other tests.)
  //
  if (guided && [qrcs count] != 1)
    [self saveFrame: bitmapCopy width: width height: height];
  free(bitmapCopy);
#endif
  
  // If there's just one QR code, set the focus on it.
  //
  if ([qrcs count] == 1) {
    Blob *b = qrcs[0];
    CGFloat x = (b.maxx + b.minx) / 2.0 / width;
    CGFloat y = (b.maxy + b.miny) / 2.0 / height;
    CGPoint focusPoint = CGPointMake(x, y);
    [controller setFocusPointOfInterest: focusPoint];
    // NSLog(@"set focus point %@", NSStringFromCGPoint(focusPoint));
  }

  // For now, if we see 1 QR code, it's worth scanning. Even if it's at
  // the edge. (Something else to figure out.)
  //
#ifdef NEVERSCAN
  return NO; // (Useful for testing the blob finding.)
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
  if(!(self = [super initWithDelegate: self showCancel: NO OneDMode:NO showLicense:NO]))
    return nil;
  [self initialize];
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
  [self initialize];
  return self;
}

- (void) initialize
{
  // Shared initialization code.
  //
  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(didBecomeActive:)
             name:UIApplicationDidBecomeActiveNotification
           object:nil];
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

- (void) viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [self.voice initializeGuidance];
}

- (void) didBecomeActive: (NSNotification *) notification
{
  [self.voice initializeGuidance];
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

