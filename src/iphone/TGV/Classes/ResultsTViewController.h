//  ResultsTViewController.h     Controller for table of scanning results
//
// Jeffrey Scofield, Psellos
// http://psellos.com
//

#import <UIKit/UIKit.h>
#import "TGVResults.h"

@interface ResultsTViewController : UIViewController
    <UITableViewDataSource, UITableViewDelegate, TGVResults>
//{
//   BOOL announce;
//}
@property (nonatomic, retain) IBOutlet UITableView *tableView;
@end
