//
//  TGVTabDelegate.m
//  TGV
//
//  Created by Jeffrey Scofield on 12/15/12.
//
//

#import "TGVTabDelegate.h"
#import "ScanViewController.h"

@implementation TGVTabDelegate

- (void) tabBarController: (UITabBarController *) tbc
         didSelectViewController: (UIViewController *) vc
{
    /* User touched a tab. If it's a tab for scanning, start up the scan.
     * If it's not a tab for scanning, turn off the scan.
     */
    //UIViewController *v;
    //for(v in tbc.viewControllers) {
    //    if([v isKindOfClass: [ScanViewController class]]) {
    //        if(v == vc)
    //        [(ScanViewController *) v scanBegin];
    //        else
    //        [(ScanViewController *) v scanEnd];
    //    }
    // }
}

@end
