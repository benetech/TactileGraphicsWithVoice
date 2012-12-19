#import "TGVAppDelegate.h"
#import "ScanViewController.h"

@implementation TGVAppDelegate

@synthesize window;
@synthesize navigationController;


#pragma mark -
#pragma mark Application lifecycle

- (BOOL) application: (UIApplication *) application
         didFinishLaunchingWithOptions: (NSDictionary *) launchOptions
{
  return YES;
}


- (void) applicationWillTerminate: (UIApplication *) application
{
}


#pragma mark -
#pragma mark Memory management

- (void)dealloc {
	[navigationController release];
	[window release];
	[super dealloc];
}

@end
