// ScanViewController.mm
//
#import "ScanViewController.h"
#import "QRCodeReader.h"


@interface ScanViewController ()

@end


@implementation ScanViewController

@synthesize tabcontroller;
@synthesize resultscontroller;


- (IBAction)scanPressed:(id)sender {
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

- (void) zxingController: (ZXingWidgetController *) controller
           didScanResult: (NSString *) scanres
{
  [self.resultscontroller addResult: scanres];
  self.tabcontroller.selectedViewController = self.resultscontroller;
}

- (void) zxingControllerDidCancel: (ZXingWidgetController *) controller
{
  self.tabcontroller.selectedViewController = self.resultscontroller;
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

- (void)dealloc {
  [super dealloc];
}

@end

