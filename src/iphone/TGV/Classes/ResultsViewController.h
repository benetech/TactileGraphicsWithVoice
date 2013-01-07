//
//  ResultsViewController.h
//  TGV
//
//  Created by Jeffrey Scofield on 12/16/12.
//
//

#import <UIKit/UIKit.h>
#import "TGVResults.h"

@interface ResultsViewController : UIViewController <TGVResults> {
    BOOL announce;
}
@property (nonatomic, retain) NSString *resultstring;
@property (nonatomic, retain) IBOutlet UITextView *textview;
- (void) addResult: (NSString *) resultstr;
- (IBAction) clearResults: (id) sender;
@end
