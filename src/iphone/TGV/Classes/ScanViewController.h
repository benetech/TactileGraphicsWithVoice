//
//  ScanViewController.h

#import <UIKit/UIKit.h>
#import <CoreMotion/CoreMotion.h>
#import "ScanView.h"
#import "EventLog.h"
#import "ZXingWidgetController.h"
#import "ResultsTViewController.h"

@interface ScanViewController : ZXingWidgetController <ZXingDelegate, ScanViewDelegate, EventLogDelegate> {
}
@property (nonatomic, retain) IBOutlet UITabBarController *tabController;
@property (nonatomic, retain) IBOutlet UIViewController <TGVResults> *resultsController;
@end
