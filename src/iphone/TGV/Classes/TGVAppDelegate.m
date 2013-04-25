// TGVAppDelegate.m
//
// Jeffrey Scofield, Psellos
// http://psellos.com
//
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


- (void) applicationDidReceiveMemoryWarning:(UIApplication *)application
{
    NSLog(@"Received memory warning");
}


- (void)dealloc {
	[navigationController release];
	[window release];
	[super dealloc];
}

@end
