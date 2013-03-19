// ScanViewController.mm     Controller for the view that scans QR codes
//
#import <CoreGraphics/CoreGraphics.h>
#import "TGVSettings.h"
#import "ScanViewController.h"
#import "QRCodeReader.h"
#import "filters.h"
#import "EventLog.h"
#import "FrameLog.h"
#import "Synchronizer.h"
#import "Majority.h"
#import "Voice.h"
#import "Signal.h"
#import "Analysis.h"
#import "Section.h"
#import "Blob.h"
#import "findqrcs.h"

#define GUIDE_MAX_QRS 4u     // 4 or more QRs get the same guidance ("many")
#define ANNOT_HEIGHT 30      // Add pixels of annotation to saved images
#define MAX_SAVES 10         // Don't save too many images per scan
#define AUTO_ILLUM_FRAMES 75 // How many failed frames before auto illumination

static NSString *kIllumIsOn = @"illumination is on";

@interface ScanViewController ()
{
  NSUserDefaults *defaults;
  int savedFailScans;      // Count of images saved so far for failed scans
  int savedSuccScans;      // Count of images saved so far for successful scans
  int savedFailCounts;     // Count of images saved so far for failed counts
  uint8_t *bitmapCopy;     // Copy of bitmap for failure analysis
  size_t copyWidth;        // Width of copied bitmap
  size_t copyHeight;       // Height of copied bitmap (includes annotation)
  BOOL copyGoodTime;       // Copy was made at a good time for periodic actions
  CMAcceleration copyGrav; // Gravity at time of copy, for failure analysis
}
@property (nonatomic, strong) EventLog *eventLog;
@property (nonatomic, strong) FrameLog *frameLog;
@property (nonatomic, strong) CMMotionManager *motionManager;
@property (nonatomic, strong) Synchronizer *synchronizer;
@property (nonatomic, strong) Majority *majority;
@property (nonatomic, strong) Voice *voice;
@property (nonatomic, strong) Signal *signal;
@property (nonatomic, retain) NSString *specialMessage;
- (void) setup;
- (void) didBecomeActive: (NSNotification *) notification;
@end


@implementation ScanViewController

- (EventLog *) eventLog
{
  if (!_eventLog) {
    _eventLog = [[EventLog alloc] init];
    _eventLog.delegate = self;
  }
  return _eventLog;
}

- (FrameLog *) frameLog
{
  if (!_frameLog)
    _frameLog = [[FrameLog alloc] init];
  return _frameLog;
}


- (CMMotionManager *) motionManager
{
  if (!_motionManager) {
    _motionManager = [[CMMotionManager alloc] init];
    [_motionManager startDeviceMotionUpdates];
  }
  return _motionManager;
}

- (Synchronizer *) synchronizer
{
  if (!_synchronizer)
    _synchronizer = [[Synchronizer alloc] init];
  return _synchronizer;
}

- (Majority *) majority
{
  if(!_majority) {
    _majority = [[Majority alloc] init];
    _majority.quorum = 7;     // Look at last 7 values
    _majority.maxValue = GUIDE_MAX_QRS;
    _majority.keepCount = AUTO_ILLUM_FRAMES;
  }
  return _majority;
}

- (Voice *) voice
{
  if(!_voice) {
    _voice = [[Voice alloc] init];
  }
  return _voice;
}

- (Signal *) signal
{
  if(!_signal) {
    _signal = [[Signal alloc] init];
    NSBundle *mainBundle = [NSBundle mainBundle];
    _signal.signalToIssue =
      [NSURL fileURLWithPath: [mainBundle pathForResource: @"epianodb4" ofType: @"aif"] isDirectory:NO];
  }
  return _signal;
}

- (BOOL) zxingController:(ZXingWidgetController *)controller
        shouldScanBitmap:(uint8_t *)bitmap
                   width:(size_t)width
                  height:(size_t)height
{
  // Tell the ZXing controller whether to scan the given bitmap looking
  // for QR codes. We say yes only if there looks to be one code there.
  // We also offer vocal guidance on getting the camera aimed at just one
  // code.
  //
  // Note: ownership of bitmap is being transferred to us. We need to
  // free it.
  //
  BOOL shouldScan = NO; // Value to be returned by this method
  
  // DEBUG Track the state of the camera
  // DEBUG [self cameraStats: bitmap width: width height: height];
  // DEBUG

  if ([self anyReasonToSave]) {
    // Make copy of original bitmap for failure analysis. Also save the
    // direction of gravity.
    //
    copyWidth = width;
    copyHeight = height + ANNOT_HEIGHT;
    bitmapCopy = (uint8_t *) malloc(copyWidth * copyHeight * BPP);
    memset(bitmapCopy, 0xff, copyWidth * copyHeight * BPP);
    memcpy(bitmapCopy, bitmap, width * height * BPP);
    copyGrav = self.motionManager.deviceMotion.gravity;
  }
  
  Analysis *analysis =
    [Analysis analysisWithBitmap: bitmap width: width height: height];
  free(bitmap);
  
  // Register the latest count with the majority tracker. Treat anything
  // >= GUIDE_MAX_QRS the same. (Guidance says "many" for this case.)
  //
  [self.majority newValue: MIN([analysis.QRBlobs count], GUIDE_MAX_QRS)];
  
  // TEMP DEBUG
  //printf("votes ");
  //NSArray *mmaa = [self.majority votes];
  //for(NSNumber *nnuu in mmaa) {
  //  printf(" %d", [nnuu intValue]);
  //}
  //printf("\n");
  //fflush(stdout);
  // TEMP DEBUG
  
  // Our result is going to be YES if there's 1 QR code there now, and
  // the majority result is also 1.  The majority result means there have
  // been mostly counts of 1 recently. For now we scan even if the 1 QR
  // code is at the edge or is too small or too large. The risk seems
  // minimal, though it does make the guidance sound overly fussy in some
  // cases.
  //
  shouldScan = [analysis.QRBlobs count] == 1 && [self.majority vote] == 1;
  
  // See whether turning on illumination might help the scan.
  //
  [self autoIlluminateForAnalysis: analysis];
  
  // Offer some audible guidance.
  //
  if ([defaults boolForKey:kSettingsGuideWithBeeps])
    [self guideByBeep: analysis.QRBlobs width: width height: height];
  else
    [self guideByVoice: analysis.QRBlobs width: width height: height];
  
  // The "save failed counts" setting asks to save images whose count
  // isn't 1. If guiding by voice, only save images whose count was
  // announced. If guiding by beeps, save every so often.
  //
  // The way to test is to aim the camera at exactly one QRC. For now,
  // have to change this line of code to test with other numbers of QRCs.
  //
  if (self.synchronizer.isGoodTime && bitmapCopy &&
      [defaults boolForKey: kSettingsSaveFailedCounts] &&
      [analysis.QRBlobs count] != 1 &&
      savedFailCounts < MAX_SAVES) {
    NSString *anno =
      [NSString stringWithFormat: @"Counted %d QR codes",
        [analysis.QRBlobs count]];
    [self saveFrame: bitmapCopy width: copyWidth height: copyHeight annotation: anno];
    savedFailCounts++;
  }

  // If we're not going to scan, no further use for the bitmap copy.
  // Otherwise, bitmap copy will be freed in succeed/fail methods below.
  //
  if (!shouldScan && bitmapCopy) {
    free(bitmapCopy);
    bitmapCopy = NULL;
  }
  if (bitmapCopy)
    copyGoodTime = self.synchronizer.isGoodTime;

#ifdef WANT_TO_SET_FOCUS_POINT
  // If there's just one QR code, set the focus on it every now and then.
  // Note: this didn't seem to help, disabled for now.
  //
  if ([self.majority vote] == 1 &&
      [analysis QRBlobs count] == 1 &&
      [self.synchronizer isGoodTimeWithPeriod: 2]) {
    Blob *b = analysis.QRBlobs[0];
    CGFloat x = (b.maxx + b.minx) / 2.0 / width;
    CGFloat y = (b.maxy + b.miny) / 2.0 / height;
    CGPoint focusPoint = CGPointMake(x, y);
    [controller setFocusPointOfInterest: focusPoint];
  }
#endif // WANT_TO_SET_FOCUS_POINT

  // The autofocus seems to get stuck with QR codes completely out of
  // focus. Perhaps it's not designed to focus on things like QR codes.
  // At any rate, things seem to go far better if you ask for a refocus
  // now and then.
  //
  if ([self.synchronizer isGoodTimeWithPeriod: 2])
    [controller setFocusMode: AVCaptureFocusModeAutoFocus];

#if TGV_EXPERIMENTAL
  // In experimental version, if good time for periodic actions, and
  // don't see 0 QRCs, log some events.
  //
  int qrcsCount = [self.majority vote];
  if (self.synchronizer.isGoodTime && qrcsCount > 0 &&
      [defaults boolForKey: kSettingsLogEvents]) {
    NSString *grav = [self gravityDescription: @"" gravity: self.motionManager.deviceMotion.gravity];
    NSString *line = [NSString stringWithFormat:@"Saw %d code%@, %@", qrcsCount, qrcsCount == 1 ? @"" : @"s", grav];
    [self.eventLog log: line];
  }
#endif

#ifdef NEVERSCAN
  // (This code is useful for testing blob finding. Don't need to keep
  // restarting the scan, because it never succeeds.)
  //
  if(bitmapCopy) {
    free(bitmapCopy);
    bitmapCopy = NULL;
  }
  return NO;
#else
  return shouldScan;
#endif
}

- (BOOL) anyReasonToSave
{
  // Determine if there would be any reason to save the current image for
  // later off-line failure analysis.
  //
  if([defaults boolForKey: kSettingsSaveFailedScans] && savedFailScans < MAX_SAVES)
    return YES;
  if([defaults boolForKey: kSettingsSaveSucceededScans] && savedSuccScans < MAX_SAVES)
    return YES;
  if([defaults boolForKey: kSettingsSaveFailedCounts] && savedFailCounts < MAX_SAVES)
    return YES;
  return NO;
}


- (void) autoIlluminateForAnalysis: (Analysis *) analysis
{
  // If we've seen no QR codes for a while and the image looks shadowy,
  // turn on the torch.
  //
  // Note: voting errors mean it's too early to act (no quorum) or that
  // different numbers of QR codes have been seen (no majority). In either
  // case we don't want to autoilluminate (yet).
  //
  if ([self torchIsOn])
    return; // Nothing to do if torch is already on
  if ([self.majority vote] != 0)
    return; // We see a QR code (or error)
  NSArray *votes = [self.majority votes];
  if ([votes count] < AUTO_ILLUM_FRAMES)
    return; // Haven't seen enough frames to decide.
  for(NSNumber *n in votes)
    if ([n intValue] != 0)
      return; // We saw a QR code (or error) recently
  
  // An image with fg_thresh really close to otsu_thresh doesn't have
  // much in the way of foreground. Treat it as a blank image.
  //
  if (ABS((float) analysis.fg_thresh - analysis.otsu_thresh) / analysis.otsu_thresh < 0.01)
    return;
  
  // We'll consider the image to be shadowy if there are some number of
  // plain dark sections and some number of variegated dark sections.
  // There should be more plain than variegated.
  //
  // A more stringent test might be to verify that the plain sections are
  // next to the variegated ones.
  //
  int darkvaried = 0, darkplain = 0;
  for(Section *s in analysis.sections)
    if (s.meanLuminance <= analysis.fg_thresh) {
      if (s.variegation < 0.015) // XXX, use a name
        darkplain++;
      else
        darkvaried++;
    }

  if(darkvaried > 3 && darkplain > darkvaried && darkplain > 5) {
    // Autoillumination seems warranted.
    //
    [self setTorch: YES];
    self.specialMessage = kIllumIsOn;
  }
}


- (void) guideByVoice: (NSArray *) qrcs width: (size_t) width height: (size_t) height
{
  // For now, pretty simple guidance. If number of QR codes != 1, then
  // say the number seen. If there is 1 code at edge, name the edge.
  // If there's 1 code that seems too small, say "too far". If there's 1
  // code that seems too large, say "too close". If the camera is in the
  // middle focusing, say "focusing". Otherwise just say "one".
  //
  // Note: images are presented in landscape mode with home button to
  // the right. We're translating here between this orientation and the
  // expected portrait orientation of the phone while scanning. (This is
  // something to figure out, however.)
  //
# define LARGEST_QRC_PX 32400 // WAS 48400
# define SMALLEST_QRC 60
  BOOL guided;
  Blob *qrc1;
  int qrcsCount = [self.majority vote];
  self.signal.period = SIGNAL_INF_PERIOD; // Make sure no beeps
  if(qrcsCount < 0) {
    // Not enough activity to get a good count, or no clear count.
    // Remain silent for now.
    //
    self.synchronizer.goodTime = NO;
    return;
  }
  switch(qrcsCount) {
    case 0: guided = [self guide: @"zero"]; break;
    case 1:
      qrc1 = [qrcs count] == 1 ? qrcs[0] : nil;
      if (qrc1 == nil)
        // There has been one QRC a lot recently, but not right now.
        // Just keep quiet for now, I guess.
        //
        guided = NO;
      else if ([qrc1 touchesTop])
        guided = [self guide: @"right"];
      else if ([qrc1 touchesBottom])
        guided = [self guide: @"left"];
      else if ([qrc1 touchesLeft])
        guided = [self guide: @"top"];
      else if ([qrc1 touchesRight])
        guided = [self guide: @"bottom"];
      else if ([qrc1 width] < SMALLEST_QRC && [qrc1 height] < SMALLEST_QRC)
        guided = [self guide: @"too far"];
      else if (qrc1.pixelCount > LARGEST_QRC_PX)
        guided = [self guide: @"too close"];
      else if([self isAdjustingFocus])
        guided = [self guide: @"focusing"];
      else
        guided = [self guide: @"one"];
      break;
    case 2: guided = [self guide: @"two"]; break;
    case 3: guided = [self guide: @"three"]; break;
    default: guided = [self guide: @"many"]; break;
  }
  self.synchronizer.goodTime = guided;
}

- (void) guideByBeep: (NSArray *) qrcs width: (int) width height: (int) height
{
  // For now, issue beeps when there is just one QRC. Beep faster
  // when it's near the center of the display.
  //
  CFTimeInterval period;
  Blob *qrc1;
  int dist;
# define SMALL_DIST 90
# define LARGE_DIST 240

  if ([self.majority vote] == 1 && [qrcs count] == 1) {
    qrc1 = qrcs[0];
    dist = abs(qrc1.minx - width / 2);
    dist = MAX(dist, abs(qrc1.maxx - width / 2));
    dist = MAX(dist, abs(qrc1.miny - height / 2));
    dist = MAX(dist, abs(qrc1.maxy - height / 2));
    dist = MAX(SMALL_DIST, dist);
    dist = MIN(LARGE_DIST, dist);
    period = 0.4 + 1.1 * ((double) (dist - SMALL_DIST) / (double) (LARGE_DIST - SMALL_DIST));
  } else {
    period = SIGNAL_INF_PERIOD;
  }
  self.signal.period = period;
  [self.synchronizer step];
}

- (BOOL) guide: (NSString *) guidance
{
  // Offer the given guidance. There might be a special message we'd
  // rather say first, in which case we offer that instead.
  //
  NSString *g = self.specialMessage ? self.specialMessage : guidance;
  BOOL res = [self.voice offerGuidance: g];
  if (res) self.specialMessage = nil;
  return res;
}

- (void) zxingController: (ZXingWidgetController *) controller
           didScanResult: (NSString *) scanres
{
  if ([defaults boolForKey: kSettingsSaveSucceededScans] && bitmapCopy && savedSuccScans++ < MAX_SAVES) {
    NSString *anno = [self gravityDescription: @"Y " gravity: copyGrav];
    [self saveFrame: bitmapCopy width:copyWidth height:copyHeight annotation: anno];
  }
#if TGV_EXPERIMENTAL
  NSString *line = [NSString stringWithFormat: @"Scan succeeded, text %@", scanres];
  [self.eventLog log: line];
#endif
  [self.resultsController addResult: scanres];
  self.tabController.selectedViewController = self.resultsController;
  if (bitmapCopy) free(bitmapCopy);
  bitmapCopy = NULL;
}

- (void) zxingController:(ZXingWidgetController *) controller didNotScanReason:(NSString *)reason
{
  // To avoid saving too many similar images, only save failed images when
  // it's a good time (around once a second).
  //
  if ([defaults boolForKey: kSettingsSaveFailedScans] && bitmapCopy &&
      copyGoodTime && savedFailScans++ < MAX_SAVES) {
    NSString *anno = [self gravityDescription: @"N " gravity: copyGrav];
    [self saveFrame: bitmapCopy width:copyWidth height:copyHeight annotation: anno];
  }
  if (bitmapCopy) free(bitmapCopy);
  bitmapCopy = NULL;
}

- (void) zxingControllerDidCancel: (ZXingWidgetController *) controller
{
#if TGV_EXPERIMENTAL
  [self.eventLog log: @"Scan cancelled"];
#endif
  self.tabController.selectedViewController = self.resultsController;
  if (bitmapCopy) free(bitmapCopy);
  bitmapCopy = NULL;
}

- (void) cameraStats: (uint8_t *) bitmap width: (int) width height: (int) height
{
  // DEBUG Save frames and camera status for later analysis.
  //
  static int previsits;
  static int visits;

  if(previsits < 60) {
    previsits++;
    return;
  }
  
  if(visits >= 70) return;

  NSString *f = [self isAdjustingFocus] ? @"f" : @"-";
  NSString *x = [self isAdjustingExposure] ? @"x" : @"-";
  NSString *w = [self isAdjustingWhiteBalance] ? @"w" : @"-";
  NSString *anno = [@[f, x, w] componentsJoinedByString: @""];
  [self.frameLog logFrame:bitmap withWidth:width height:height annotation:anno];
  visits++;
  if(visits == 70)
    [self.frameLog save];
}


- (id) init
{
  if(!(self = [super initWithDelegate: self showCancel: NO OneDMode:NO showLicense:NO]))
    return nil;
  [self setup];
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
  [self setup];
  return self;
}

- (void) setup
{
  // Shared initialization code.
  //
  defaults = [NSUserDefaults standardUserDefaults];

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
    [NSURL fileURLWithPath:[mainBundle pathForResource:@"epianodbmaj" ofType:@"aif"] isDirectory:NO];
}


- (void) viewDidAppear:(BOOL)animated
{
#if TGV_EXPERIMENTAL
  [self.eventLog log: @"Scanning started"];
#endif
  [super viewDidAppear:animated];
  [self.voice initializeGuidance];
  self.specialMessage = nil;
  if ([defaults boolForKey: kSettingsIlluminateScans]) {
    [self setTorch: YES];
    self.specialMessage = kIllumIsOn;
  }
  savedFailScans = 0;
  savedSuccScans = 0;
  savedFailCounts = 0;
}

- (void) viewDidDisappear: (BOOL) animated
{
  [super viewDidDisappear: animated];
  if(self.motionManager) {
    [self.motionManager stopDeviceMotionUpdates];
    self.motionManager = nil;
  }
  if ([self torchIsOn])
    [self setTorch: NO];
}

- (void) didBecomeActive: (NSNotification *) notification
{
  if ([self.tabBarController selectedViewController] != self)
    return;
#if TGV_EXPERIMENTAL
  [self.eventLog log: @"Scanning restarted from background"];
#endif
  [self.voice initializeGuidance];
  self.specialMessage = nil;
  if ([defaults boolForKey: kSettingsIlluminateScans]) {
    [self setTorch: YES];
    self.specialMessage = kIllumIsOn;
  }
  savedFailScans = 0;
  savedSuccScans = 0;
  savedFailCounts = 0;
}


- (BOOL) scanViewShouldReportTouches:(ScanView *)scanView
{
#if TGV_EXPERIMENTAL
  return [defaults boolForKey: kSettingsTrackTouches];
#else
  return NO;
#endif
}


- (void) scanView: scanView didFeelTouchesAtPoints: (NSArray *) points
{
  self.trackedPoints = points;
}


- (BOOL) eventLogShouldLogEvent:(EventLog *)eventLog
{
  return [defaults boolForKey: kSettingsLogEvents];
}

- (void) saveFrame: (uint8_t *) bitmap
             width: (size_t) width
            height: (size_t) height
        annotation: (NSString *) annotation
{
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  CGContextRef ctx =
    CGBitmapContextCreate(bitmap, width, height, 8, width * BPP, colorSpace,
                        kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst);
  CGContextSelectFont(ctx, "Helvetica", ANNOT_HEIGHT - 6, kCGEncodingMacRoman);
  const char *text = [annotation UTF8String];
  CGContextShowTextAtPoint(ctx, 5, 5, text, strlen(text));
  CGImageRef image = CGBitmapContextCreateImage(ctx);
  CGContextRelease(ctx);
  CGColorSpaceRelease(colorSpace);
  UIImageWriteToSavedPhotosAlbum([UIImage imageWithCGImage: image], nil, nil, nil);
  CGImageRelease(image);
}

- (NSString *) gravityDescription: (NSString *) prefix gravity: (CMAcceleration) accel
{
# define DOT(x0,y0,z0,x1,y1,z1) (x0*x1 + y0*y1 + z0*z1)
# define MAG(x,y,z) sqrt(x*x + y*y + z*z)
# define BETWEEN(x0,y0,z0,x1,y1,z1) \
   acos(DOT(x0,y0,z0,x1,y1,z1)/(MAG(x0,y0,z0)*MAG(x1,y1,z1)))
# define DEGREES(theta) ((int) (theta * 57.29577951308232 + 0.5))
  
  // Gravity reports as (0.0, 0.0, 0.0) when not warmed up. Otherwise
  // it's a unit vector.
  //
  if(MAG(accel.x, accel.y, accel.z) < 0.5)
    return [NSString stringWithFormat:@"%@(No gravity data)", prefix];
  
  // Our expected down direction is (0.0, 0.0, -1.0) in device coordinates
  double slant = BETWEEN(accel.x, accel.y, accel.z, 0.0, 0.0, -1.0);
  // Projected (x, y) of gravity gives the low spot, so (-x, -y) is
  // high spot.
  double high = atan2(-accel.y, -accel.x);

  high += M_PI / 8.0; // Round to octant
  if (high < 0.0) high += 2.0 * M_PI;
  int hidir = (int) (high / M_PI * 4.0);
  NSString *dirs[] = { @"E", @"NE", @"N", @"NW", @"W", @"SW", @"S", @"SE" };
  
  return [NSString stringWithFormat: @"%@tilt %d, hi pt %@ (%6.3f, %6.3f, %6.3f)",
           prefix, DEGREES(slant), dirs[hidir], accel.x, accel.y, accel.z];
}

- (void) dealloc
{
  self.eventLog = nil;
  if (self.motionManager) {
    [self.motionManager stopDeviceMotionUpdates];
    self.motionManager = nil;
  }
  self.synchronizer = nil;
  self.majority = nil;
  self.voice = nil;
  self.signal = nil;
  [super dealloc];
}
@end
