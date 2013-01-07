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

static NSString *placeholder = @"Scanned text will go here.";

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
  textview.text = placeholder;
  announce = NO;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
}

- (void) viewDidAppear: (BOOL) animated
{
  [super viewDidAppear: animated];
  if(announce && [resultstring length] > 0) {
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification,
                                    resultstring);
  }
  announce = NO;
}


- (void) addResult: (NSString *) resultstr
{
  self.resultstring = resultstr;
  if (self.isViewLoaded) {
    if([textview.text isEqualToString: placeholder])
      textview.text = @"";
    NSArray *newtext = @[resultstr, @"\n", textview.text];
    textview.text = [newtext componentsJoinedByString: @""];
    [textview setNeedsDisplay];
    announce = YES;
  }
}

- (IBAction) clearResults: (id) sender
{
  textview.text = placeholder;
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
