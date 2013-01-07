//
//  ResultsTViewController.h
//  TGV
//
//  Created by Jeffrey Scofield on 1/5/13.
//
//

#import <UIKit/UIKit.h>
#import "TGVResults.h"

@interface ResultsTViewController : UIViewController
    <UITableViewDataSource, UITableViewDelegate, TGVResults>
{
    BOOL announce;
}
@property (nonatomic, retain) IBOutlet UITableView *tableView;
@end
