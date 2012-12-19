//
//  TGVAppDelegate.h
//  TGV
//
//  Created by David Kavanagh on 5/10/10.
//  Modified for TGV by Jeffrey Scofield 12/14/12 ...
//

#import <UIKit/UIKit.h>

@interface TGVAppDelegate : NSObject <UIApplicationDelegate> {
    
    UIWindow *window;
    UINavigationController *navigationController;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet UINavigationController *navigationController;

@end

