//  TGVAppDelegate.h
//
// Jeffrey Scofield, Psellos
// http://psellos.com
//

#import <UIKit/UIKit.h>

@interface TGVAppDelegate : NSObject <UIApplicationDelegate> {
    
    UIWindow *window;
    UINavigationController *navigationController;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet UINavigationController *navigationController;

@end

