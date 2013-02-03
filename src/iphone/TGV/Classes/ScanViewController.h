//
//  ScanViewController.h

#import <UIKit/UIKit.h>
#import "ZXingWidgetController.h"
#import "ResultsViewController.h"

@interface ScanViewController : ZXingWidgetController <ZXingDelegate> {
}
@property (nonatomic, retain) IBOutlet UITabBarController *tabController;
@property (nonatomic, retain) IBOutlet UIViewController <TGVResults> *resultsController;
@end
