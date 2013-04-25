// TGVViewController.m     Top-level view controller for TGV
//
// Jeffrey Scofield, Psellos
// http://psellos.com
//

#import "TGVViewController.h"

@interface TGVViewController ()

@end

@implementation TGVViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Uncomment to start up in scan mode.
    // self.selectedIndex = 1;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
