//
//  ResultsViewController.h
//  TGV
//
//  Created by Jeffrey Scofield on 12/16/12.
//
//

#import <UIKit/UIKit.h>

@interface ResultsViewController : UIViewController {
    BOOL announce;
}
@property (nonatomic, retain) NSString *resultstring;
@property (nonatomic, retain) UITextView *textview;
- (void) addResult: (NSString *) resultstr;
@end
