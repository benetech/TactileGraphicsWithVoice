#import "TGVAppDelegate.h"
#import "ScanViewController.h"

@implementation TGVAppDelegate

@synthesize window;
@synthesize navigationController;


- (BOOL) application: (UIApplication *) application
         didFinishLaunchingWithOptions: (NSDictionary *) launchOptions
{
  return YES;
}


- (void) applicationWillTerminate: (UIApplication *) application
{
}


- (void)dealloc {
	[navigationController release];
	[window release];
	[super dealloc];
}

@end
