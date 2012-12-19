//
//  ScanViewController.h

#import <UIKit/UIKit.h>
#import "ZXingWidgetController.h"
#import "ResultsViewController.h"

@interface ScanViewController : ZXingWidgetController <ZXingDelegate> {
}
@property (nonatomic, retain) IBOutlet UITabBarController *tabcontroller;
@property (nonatomic, retain) IBOutlet ResultsViewController *resultscontroller;

- (IBAction)scanPressed:(id)sender;
@end
