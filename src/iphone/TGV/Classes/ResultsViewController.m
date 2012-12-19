//
//  ResultsViewController.m
//  TGV
//
//  Created by Jeffrey Scofield on 12/16/12.
//
//

#import "ResultsViewController.h"

@interface ResultsViewController ()

@end

@implementation ResultsViewController

@synthesize textview;
@synthesize resultstring;

- (id) initWithNibName: (NSString *)nibName bundle: (NSBundle *) nibBundle
{
    self = [super initWithNibName: nibName bundle: nibBundle];
    if (self) {
      [self initialize];
    }
    return self;
}

- (void) initialize
{
  announce = NO;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Do any additional setup after loading the view from its nib.
}

- (void) viewDidAppear: (BOOL) animated
{
  [super viewDidAppear: animated];
  if(announce && [resultstring length] > 0)
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification,
                                    resultstring);
  announce = NO;
}


- (void) addResult: (NSString *) resultstr
{
  self.resultstring = resultstr;
  if (self.isViewLoaded) {
    [self.textview setText: resultstring];
    [self.textview setNeedsDisplay];
    announce = YES;
  }
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
