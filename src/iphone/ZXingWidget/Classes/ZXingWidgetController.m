// -*- mode:objc; c-basic-offset:2; indent-tabs-mode:nil -*-
/**
 * Copyright 2009-2012 ZXing authors All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "ZXingWidgetController.h"
#import "Decoder.h"
#import "NSString+HTML.h"
#import "ResultParser.h"
#import "ParsedResult.h"
#import "ResultAction.h"
#import "TwoDDecoderResult.h"
#include <sys/types.h>
#include <sys/sysctl.h>

#import <AVFoundation/AVFoundation.h>

#define CAMERA_SCALAR 1.12412 // scalar = (480 / (2048 / 480))
#define FIRST_TAKE_DELAY 1.0
#define ONE_D_BAND_HEIGHT 10.0
#define CAPTURE_FRAME_RATE 15

@interface ZXingWidgetController ()

@property BOOL isStatusBarHidden;
@property (nonatomic, retain) OverlayView *overlayView;

- (void)initCapture;
- (void)stopCapture;

@end

@implementation ZXingWidgetController

@synthesize delegate, showCancel, oneDMode, showLicense;
#if HAS_AVFF
@synthesize captureSession;
@synthesize prevLayer;
#endif
@synthesize result, soundToPlay;
@synthesize overlayView = _overlayView;
@synthesize isStatusBarHidden;
@synthesize readers;


- (id)initWithDelegate:(id<ZXingDelegate>)scanDelegate showCancel:(BOOL)shouldShowCancel OneDMode:(BOOL)shouldUseoOneDMode {
  
  return [self initWithDelegate:scanDelegate showCancel:shouldShowCancel OneDMode:shouldUseoOneDMode showLicense:YES];
}

- (id)initWithDelegate:(id<ZXingDelegate>)scanDelegate showCancel:(BOOL)shouldShowCancel OneDMode:(BOOL)shouldUseoOneDMode showLicense:(BOOL)shouldShowLicense {
  self = [super init];
  if (self) {
    self.delegate = scanDelegate;
    self.oneDMode = shouldUseoOneDMode;
    self.showCancel = shouldShowCancel;
    self.showLicense = shouldShowLicense;
    self.wantsFullScreenLayout = YES;
    beepSound = -1;
    decoding = NO;
    // [self initOverlayView];
  }
  
  return self;
}

- (id) initWithCoder: (NSCoder *) aDecoder {
  if (!(self = [super initWithCoder: aDecoder]))
    return nil;
  self.wantsFullScreenLayout = YES;
  beepSound = -1;
  decoding = NO;
  // [self initOverlayView];
  return self;
}

- (void) initOverlayView {
  OverlayView *theOverLayView =
    [[OverlayView alloc] initWithFrame: [UIScreen mainScreen].bounds
                         cancelEnabled: self.showCancel
                              oneDMode: self.oneDMode
                           showLicense: self.showLicense];
  [theOverLayView setDelegate:self];
  self.overlayView = theOverLayView;
  [theOverLayView release];
}

- (void)dealloc {
  if (beepSound != (SystemSoundID)-1) {
    AudioServicesDisposeSystemSoundID(beepSound);
  }
  
  [self stopCapture];

  [result release];
  [soundToPlay release];
  [_overlayView release];
  [readers release];
  [super dealloc];
}

- (NSArray *) trackedPoints
{
  return self.overlayView.trackedPoints;
}

- (void) setTrackedPoints: (NSArray *) points
{
  self.overlayView.trackedPoints = points;
}

- (void)cancelled {
  [self stopCapture];
  //if (!self.isStatusBarHidden) {
  //  [[UIApplication sharedApplication] setStatusBarHidden:NO];
  //}

  wasCancelled = YES;
  if (delegate != nil) {
    [delegate zxingControllerDidCancel:self];
  }
}

- (NSString *)getPlatform {
  size_t size;
  sysctlbyname("hw.machine", NULL, &size, NULL, 0);
  char *machine = malloc(size);
  sysctlbyname("hw.machine", machine, &size, NULL, 0);
  NSString *platform = [NSString stringWithCString:machine encoding:NSASCIIStringEncoding];
  free(machine);
  return platform;
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  self.wantsFullScreenLayout = YES;
  if ([self soundToPlay] != nil) {
    OSStatus error = AudioServicesCreateSystemSoundID((CFURLRef)[self soundToPlay], &beepSound);
    if (error != kAudioServicesNoError) {
      NSLog(@"Problem loading nearSound.caf");
    }
  }
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  //self.isStatusBarHidden = [[UIApplication sharedApplication] isStatusBarHidden];
  //if (!isStatusBarHidden)
  //  [[UIApplication sharedApplication] setStatusBarHidden:YES];
  
  // Initialize the overlay view lazily, i.e., the first time
  // it is needed. Currently its properties are fixed after that.
  //
  if(!self.overlayView)
    [self initOverlayView];

  decoding = YES;

  [self initCapture];
  [self.view addSubview: self.overlayView];
  
  [self.overlayView setPoints:nil];
  self.overlayView.trackedPoints = nil;
  wasCancelled = NO;
}

- (void)viewDidDisappear:(BOOL)animated {
  [super viewDidDisappear:animated];
  // if (!isStatusBarHidden)
  //  [[UIApplication sharedApplication] setStatusBarHidden: NO withAnimation: UIStatusBarAnimationNone];
  [self.overlayView removeFromSuperview];
  [self stopCapture];
}

- (CGImageRef)CGImageRotated90:(CGImageRef)imgRef
{
  CGFloat angleInRadians = -90 * (M_PI / 180);
  CGFloat width = CGImageGetWidth(imgRef);
  CGFloat height = CGImageGetHeight(imgRef);
  
  CGRect imgRect = CGRectMake(0, 0, width, height);
  CGAffineTransform transform = CGAffineTransformMakeRotation(angleInRadians);
  CGRect rotatedRect = CGRectApplyAffineTransform(imgRect, transform);
  
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  CGContextRef bmContext = CGBitmapContextCreate(NULL,
                                                 rotatedRect.size.width,
                                                 rotatedRect.size.height,
                                                 8,
                                                 0,
                                                 colorSpace,
                                                 kCGImageAlphaPremultipliedFirst);
  CGContextSetAllowsAntialiasing(bmContext, FALSE);
  CGContextSetInterpolationQuality(bmContext, kCGInterpolationNone);
  CGColorSpaceRelease(colorSpace);
  //      CGContextTranslateCTM(bmContext,
  //                                                +(rotatedRect.size.width/2),
  //                                                +(rotatedRect.size.height/2));
  CGContextScaleCTM(bmContext, rotatedRect.size.width/rotatedRect.size.height, 1.0);
  CGContextTranslateCTM(bmContext, 0.0, rotatedRect.size.height);
  CGContextRotateCTM(bmContext, angleInRadians);
  //      CGContextTranslateCTM(bmContext,
  //                                                -(rotatedRect.size.width/2),
  //                                                -(rotatedRect.size.height/2));
  CGContextDrawImage(bmContext, CGRectMake(0, 0,
                                           rotatedRect.size.width,
                                           rotatedRect.size.height),
                     imgRef);
  
  CGImageRef rotatedImage = CGBitmapContextCreateImage(bmContext);
  CFRelease(bmContext);
  [(id)rotatedImage autorelease];
  
  return rotatedImage;
}

- (CGImageRef)CGImageRotated180:(CGImageRef)imgRef
{
  CGFloat angleInRadians = M_PI;
  CGFloat width = CGImageGetWidth(imgRef);
  CGFloat height = CGImageGetHeight(imgRef);
  
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  CGContextRef bmContext = CGBitmapContextCreate(NULL,
                                                 width,
                                                 height,
                                                 8,
                                                 0,
                                                 colorSpace,
                                                 kCGImageAlphaPremultipliedFirst);
  CGContextSetAllowsAntialiasing(bmContext, FALSE);
  CGContextSetInterpolationQuality(bmContext, kCGInterpolationNone);
  CGColorSpaceRelease(colorSpace);
  CGContextTranslateCTM(bmContext,
                        +(width/2),
                        +(height/2));
  CGContextRotateCTM(bmContext, angleInRadians);
  CGContextTranslateCTM(bmContext,
                        -(width/2),
                        -(height/2));
  CGContextDrawImage(bmContext, CGRectMake(0, 0, width, height), imgRef);
  
  CGImageRef rotatedImage = CGBitmapContextCreateImage(bmContext);
  CFRelease(bmContext);
  [(id)rotatedImage autorelease];
  
  return rotatedImage;
}

// DecoderDelegate methods

- (void)decoder:(Decoder *)decoder willDecodeImage:(UIImage *)image usingSubset:(UIImage *)subset{
#ifdef DEBUG
  NSLog(@"DecoderViewController MessageWhileDecodingWithDimensions: Decoding image (%.0fx%.0f) ...", image.size.width, image.size.height);
#endif
}

- (void)decoder:(Decoder *)decoder
  decodingImage:(UIImage *)image
    usingSubset:(UIImage *)subset {
}

- (void)presentResultForString:(NSString *)resultString {
  self.result = [ResultParser parsedResultForString:resultString];
  if (beepSound != (SystemSoundID)-1) {
    AudioServicesPlaySystemSound(beepSound);
  }
#ifdef DEBUG
  NSLog(@"result string = %@", resultString);
#endif
}

- (void)presentResultPoints:(NSArray *)resultPoints
                   forImage:(UIImage *)image
                usingSubset:(UIImage *)subset {
  // simply add the points to the image view
  NSMutableArray *mutableArray = [[NSMutableArray alloc] initWithArray:resultPoints];
  [self.overlayView setPoints:mutableArray];
  [mutableArray release];
}

- (void)decoder:(Decoder *)decoder didDecodeImage:(UIImage *)image usingSubset:(UIImage *)subset withResult:(TwoDDecoderResult *)twoDResult {
  [self presentResultForString:[twoDResult text]];
  [self presentResultPoints:[twoDResult points] forImage:image usingSubset:subset];
  // now, in a selector, call the delegate to give this overlay time to show the points
  [self performSelector:@selector(notifyDelegateOfSuccess:) withObject:[[twoDResult text] copy] afterDelay:0.0];
  decoder.delegate = nil;
}

- (void)decoder:(Decoder *)decoder failedToDecodeImage:(UIImage *)image usingSubset:(UIImage *)subset reason:(NSString *)reason {
  [self.overlayView setPoints:nil];
  [self performSelector:@selector(notifyDelegateOfFailure:) withObject:reason afterDelay:0.0];
  decoder.delegate = nil;
}

- (void)notifyDelegateOfSuccess:(NSString *)text {
    [delegate zxingController:self didScanResult:text];
    [text release];
}

- (void)notifyDelegateOfFailure:(NSString *)reason {
  [delegate zxingController:self didNotScanReason: reason];
}

- (void)decoder:(Decoder *)decoder foundPossibleResultPoint:(CGPoint)point {
  [self.overlayView setPoint:point];
}

/*
  - (void)stopPreview:(NSNotification*)notification {
  // NSLog(@"stop preview");
  }

  - (void)notification:(NSNotification*)notification {
  // NSLog(@"notification %@", notification.name);
  }
*/

#pragma mark - 
#pragma mark AVFoundation

#include <sys/types.h>
#include <sys/sysctl.h>

// Gross, I know. But you can't use the device idiom because it's not iPad when running
// in zoomed iphone mode but the camera still acts like an ipad.
#if HAS_AVFF
static bool isIPad() {
  static int is_ipad = -1;
  if (is_ipad < 0) {
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0); // Get size of data to be returned.
    char *name = malloc(size);
    sysctlbyname("hw.machine", name, &size, NULL, 0);
    NSString *machine = [NSString stringWithCString:name encoding:NSASCIIStringEncoding];
    free(name);
    is_ipad = [machine hasPrefix:@"iPad"];
  }
  return !!is_ipad;
}
#endif
    
- (void)initCapture {
#if HAS_AVFF
  AVCaptureDevice* inputDevice =
    [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
  AVCaptureDeviceInput *captureInput =
    [AVCaptureDeviceInput deviceInputWithDevice:inputDevice error:nil];
  AVCaptureVideoDataOutput *captureOutput = [[AVCaptureVideoDataOutput alloc] init]; 
  captureOutput.alwaysDiscardsLateVideoFrames = YES; 
  [captureOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
  NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey; 
  NSNumber* value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA]; 
  NSDictionary* videoSettings = [NSDictionary dictionaryWithObject:value forKey:key]; 
  [captureOutput setVideoSettings:videoSettings]; 
  self.captureSession = [[[AVCaptureSession alloc] init] autorelease];

  NSString* preset = 0;
  if (NSClassFromString(@"NSOrderedSet") && // Proxy for "is this iOS 5" ...
      [UIScreen mainScreen].scale > 1 &&
      isIPad() && 
      [inputDevice
        supportsAVCaptureSessionPreset:AVCaptureSessionPresetiFrame960x540]) {
    // NSLog(@"960");
    preset = AVCaptureSessionPresetiFrame960x540;
  }
  if (!preset) {
    // NSLog(@"MED");
    preset = AVCaptureSessionPresetMedium;
  }
  self.captureSession.sessionPreset = preset;

  [self.captureSession addInput:captureInput];
  [self.captureSession addOutput:captureOutput];

  // Set frame rate reasonably low if possible.
  //
  AVCaptureConnection *conn = [captureOutput connectionWithMediaType:AVMediaTypeVideo];
  
  // CMTimeShow(conn.videoMinFrameDuration);
  // CMTimeShow(conn.videoMaxFrameDuration);
  
  if(self.capture_frame_rate <= 0)
    self.capture_frame_rate = CAPTURE_FRAME_RATE;
  if (conn.isVideoMinFrameDurationSupported)
    conn.videoMinFrameDuration = CMTimeMake(1, self.capture_frame_rate);
  if (conn.isVideoMaxFrameDurationSupported)
    conn.videoMaxFrameDuration = CMTimeMake(1, self.capture_frame_rate);
  
  // CMTimeShow(conn.videoMinFrameDuration);
  // CMTimeShow(conn.videoMaxFrameDuration);
  
  [captureOutput release];

/*
  [[NSNotificationCenter defaultCenter]
  addObserver:self
  selector:@selector(stopPreview:)
  name:AVCaptureSessionDidStopRunningNotification
  object:self.captureSession];

  [[NSNotificationCenter defaultCenter]
  addObserver:self
  selector:@selector(notification:)
  name:AVCaptureSessionDidStopRunningNotification
  object:self.captureSession];

  [[NSNotificationCenter defaultCenter]
  addObserver:self
  selector:@selector(notification:)
  name:AVCaptureSessionRuntimeErrorNotification
  object:self.captureSession];

  [[NSNotificationCenter defaultCenter]
  addObserver:self
  selector:@selector(notification:)
  name:AVCaptureSessionDidStartRunningNotification
  object:self.captureSession];

  [[NSNotificationCenter defaultCenter]
  addObserver:self
  selector:@selector(notification:)
  name:AVCaptureSessionWasInterruptedNotification
  object:self.captureSession];

  [[NSNotificationCenter defaultCenter]
  addObserver:self
  selector:@selector(notification:)
  name:AVCaptureSessionInterruptionEndedNotification
  object:self.captureSession];
*/

  if (!self.prevLayer) {
    self.prevLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
  }
  // NSLog(@"prev %p %@", self.prevLayer, self.prevLayer);
  self.prevLayer.frame = self.view.bounds;
  self.prevLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
  [self.view.layer addSublayer: self.prevLayer];

  [self.captureSession startRunning];
#endif
}

#if HAS_AVFF
- (void)captureOutput:(AVCaptureOutput *)captureOutput 
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer 
       fromConnection:(AVCaptureConnection *)connection 
{
  if (!decoding) {
    return;
  }
  CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer); 
  /*Lock the image buffer*/
  CVPixelBufferLockBaseAddress(imageBuffer,0); 
  /*Get information about the image*/
  size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer); 
  size_t width = CVPixelBufferGetWidth(imageBuffer); 
  size_t height = CVPixelBufferGetHeight(imageBuffer); 
    
  uint8_t* baseAddress = CVPixelBufferGetBaseAddress(imageBuffer); 
  void* free_me = 0;
  if (false) { // iOS bug?
    uint8_t* tmp = baseAddress;
    int bytes = bytesPerRow*height;
    free_me = baseAddress = (uint8_t*)malloc(bytes);
    baseAddress[0] = 0xdb;
    memcpy(baseAddress,tmp,bytes);
  }
  
  // Make a low-level copy of the bitmap for the delegate to work with.
  //
  uint8_t *copyForDelegate;
  if(delegate != nil) {
    copyForDelegate = malloc(bytesPerRow * height);
    memcpy(copyForDelegate, baseAddress, bytesPerRow * height);
  }
  
  // Make an image for decoding.
  //
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB(); 
  CGContextRef newContext =
    CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace,
                          kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst); 

  CGImageRef capture = CGBitmapContextCreateImage(newContext); 
  CVPixelBufferUnlockBaseAddress(imageBuffer,0);
  free(free_me);
  CGContextRelease(newContext);
  CGColorSpaceRelease(colorSpace);

  // Delegate decides whether to go further in decoding the frame.
  //
  BOOL shouldScan =
    self.delegate != nil &&
    [self.delegate zxingController: self
                  shouldScanBitmap: copyForDelegate
                             width: width
                            height: height];
  if(!shouldScan) {
    CGImageRelease(capture);
    return;
  }

  CGRect cropRect = [self.overlayView cropRect];
  if (oneDMode) {
    // let's just give the decoder a vertical band right above the red line
    cropRect.origin.x = cropRect.origin.x + (cropRect.size.width / 2) - (ONE_D_BAND_HEIGHT + 1);
    cropRect.size.width = ONE_D_BAND_HEIGHT;
    // do a rotate
    CGImageRef croppedImg = CGImageCreateWithImageInRect(capture, cropRect);
    CGImageRelease(capture);
    capture = [self CGImageRotated90:croppedImg];
    capture = [self CGImageRotated180:capture];
    //              UIImageWriteToSavedPhotosAlbum([UIImage imageWithCGImage:capture], nil, nil, nil);
    CGImageRelease(croppedImg);
    CGImageRetain(capture);
    cropRect.origin.x = 0.0;
    cropRect.origin.y = 0.0;
    cropRect.size.width = CGImageGetWidth(capture);
    cropRect.size.height = CGImageGetHeight(capture);
  }

  // N.B.
  // - Won't work if the overlay becomes uncentered ...
  // - iOS always takes videos in landscape
  // - images are always 4x3; device is not
  // - iOS uses virtual pixels for non-image stuff
  
  // Scan the whole image, not just a rectangle.
  // TEMP: make this suaver

  {
    float height = CGImageGetHeight(capture);
    float width = CGImageGetWidth(capture);

    CGRect screen = UIScreen.mainScreen.bounds;
    float tmp = screen.size.width;
    screen.size.width = screen.size.height;;
    screen.size.height = tmp;

    cropRect.origin.x = (width-cropRect.size.width)/2;
    cropRect.origin.y = (height-cropRect.size.height)/2;
    cropRect.origin.x = 0; // TEMP ADDED
    cropRect.origin.y = 0; // TEMP ADDED
    cropRect.size.width = width; // TEMP ADDED
    cropRect.size.height = height; // TEMP ADDED
  }
  // SUAVER XXX look at the whole capture
  // CGImageRef newImage = CGImageCreateWithImageInRect(capture, cropRect);
  UIImage *scrn = [[UIImage alloc] initWithCGImage:capture]; // TEMP ADDED
  CGImageRelease(capture);
  // UIImage *scrn = [[UIImage alloc] initWithCGImage:newImage];
  // CGImageRelease(newImage);
  Decoder *d = [[Decoder alloc] init];
  d.readers = readers;
  d.delegate = self;
  cropRect.origin.x = 0.0;  
  cropRect.origin.y = 0.0;
  decoding = [d decodeImage:scrn cropRect:cropRect] == YES ? NO : YES;
  [d release];
  [scrn release];
} 
#endif

- (void)stopCapture {
  decoding = NO;
#if HAS_AVFF
  [captureSession stopRunning];
  AVCaptureInput* input = [captureSession.inputs objectAtIndex:0];
  [captureSession removeInput:input];
  AVCaptureVideoDataOutput* output = (AVCaptureVideoDataOutput*)[captureSession.outputs objectAtIndex:0];
  [captureSession removeOutput:output];
  [self.prevLayer removeFromSuperlayer];

/*
// heebee jeebees here ... is iOS still writing into the layer?
if (self.prevLayer) {
layer.session = nil;
AVCaptureVideoPreviewLayer* layer = prevLayer;
[self.prevLayer retain];
dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 12000000000), dispatch_get_main_queue(), ^{
[layer release];
});
}
*/

  self.prevLayer = nil;
  self.captureSession = nil;
#endif
}

#pragma mark - Torch

- (BOOL)setTorch:(BOOL)status {
  BOOL didSetTorch = NO;
#if HAS_AVFF
  Class captureDeviceClass = NSClassFromString(@"AVCaptureDevice");
  if (captureDeviceClass != nil) {
    
    AVCaptureDevice *device = [captureDeviceClass defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    [device lockForConfiguration:nil];
    if ([device hasTorch]) {
      if (status) {
        if ([device isTorchModeSupported:AVCaptureTorchModeOn]) {
          [device setTorchModeOnWithLevel: 0.5 error: nil];
          didSetTorch = YES;
        }
      } else {
        if ([device isTorchModeSupported: AVCaptureTorchModeOff]) {
          [device setTorchMode:AVCaptureTorchModeOff];
          didSetTorch = YES;
        }
      }
    }
    [device unlockForConfiguration];
    
  }
#endif
  return didSetTorch;
}

- (BOOL)torchIsOn {
#if HAS_AVFF
  Class captureDeviceClass = NSClassFromString(@"AVCaptureDevice");
  if (captureDeviceClass != nil) {
    
    AVCaptureDevice *device = [captureDeviceClass defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    if ( [device hasTorch] ) {
      return [device torchMode] == AVCaptureTorchModeOn;
    }
    // [device unlockForConfiguration]; LOOKS BUGGY TO ME
  }
#endif
  return NO;
}

#pragma mark - Focus

- (BOOL) fixedFocus
{
  NSString *platform = [self getPlatform];
  if ([platform isEqualToString:@"iPhone1,1"] ||
      [platform isEqualToString:@"iPhone1,2"]) return YES;
  return NO;
}

- (BOOL) isAdjustingFocus
{
  BOOL isIt = NO;
#if HAS_AVFF
  Class captureDeviceClass = NSClassFromString(@"AVCaptureDevice");
  if(captureDeviceClass == nil)
    return NO;
  AVCaptureDevice *device = [captureDeviceClass defaultDeviceWithMediaType: AVMediaTypeVideo];
  isIt = device.isAdjustingFocus;
#endif
  return isIt;
}

- (void) setFocusPointOfInterest: (CGPoint) point
{
#if HAS_AVFF
  Class captureDeviceClass = NSClassFromString(@"AVCaptureDevice");
  if (captureDeviceClass == nil)
    return;
  AVCaptureDevice *device = [captureDeviceClass defaultDeviceWithMediaType:AVMediaTypeVideo];
  if (!device.focusPointOfInterestSupported)
    return;
  if (CGPointEqualToPoint(device.focusPointOfInterest, point))
    return;
  //NSLog(@"Setting focus point of interest");
  [device lockForConfiguration: nil];
  device.focusPointOfInterest = point;
  [device unlockForConfiguration];
#endif
}

- (BOOL) setFocusMode: (AVCaptureFocusMode) focusMode
{
  BOOL didSetFocus = NO;
#if HAS_AVFF
  Class captureDeviceClass = NSClassFromString(@"AVCaptureDevice");
  if (captureDeviceClass == nil)
    return NO;
  AVCaptureDevice *device = [captureDeviceClass defaultDeviceWithMediaType:AVMediaTypeVideo];
  [device lockForConfiguration: nil];
  if ([device isFocusModeSupported: focusMode]) {
    device.focusMode = focusMode;
    didSetFocus = YES;
  }
  [device unlockForConfiguration];
#endif // HAS_AVFF
  return didSetFocus;
}

- (BOOL) isAdjustingExposure
{
  BOOL isIt = NO;
#ifdef HAS_AVFF
  Class captureDeviceClass = NSClassFromString(@"AVCaptureDevice");
  if(captureDeviceClass == nil)
    return NO;
  AVCaptureDevice *device = [captureDeviceClass defaultDeviceWithMediaType: AVMediaTypeVideo];
  isIt = device.isAdjustingExposure;
#endif
  return isIt;
}

- (BOOL) isAdjustingWhiteBalance
{
  BOOL isIt = NO;
#ifdef HAS_AVFF
  Class captureDeviceClass = NSClassFromString(@"AVCaptureDevice");
  if(captureDeviceClass == nil)
    return NO;
  AVCaptureDevice *device = [captureDeviceClass defaultDeviceWithMediaType: AVMediaTypeVideo];
  isIt = device.isAdjustingWhiteBalance;
#endif
  return isIt;
}

@end
