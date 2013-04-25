// ResultsTViewController.m     Controller for table of scan results
//
// Jeffrey Scofield, Psellos
// http://psellos.com
//

#import "ResultsTViewController.h"
#import "Survey.h"

# define SURVEY_WAIT1 3.0   // Time for announcement before survey
# define SURVEY_WAIT2 1.5   // Time for return to results page before survey

@interface ResultsTViewController ()
{
    BOOL announce;         // Announce latest result string at next appearance
    BOOL pendingSurvey;    // Show the survey at next appearance
}
@property (nonatomic, retain) NSMutableArray *results;
@property (nonatomic, retain) NSString *resultstring;
@property (nonatomic, retain) Survey *survey;
- (void) setup;
@end

@implementation ResultsTViewController

- (Survey *) survey
{
    if (! _survey)
        _survey = [[Survey alloc] init];
    return _survey;
}

- (id) initWithNibName: (NSString *) nibName bundle: (NSBundle *) nibBundle
{
    self = [super initWithNibName: nibName bundle: nibBundle];
    if (self) {
        [self setup];
    }
    return self;
}

- (id) initWithCoder: (NSCoder *) aDecoder
{
    self = [super initWithCoder: aDecoder];
    if(self) {
        [self setup];
    }
    return self;
}

- (void) setup
{
    NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
    [defaultCenter addObserver: self
                      selector: @selector(didBecomeActive:)
                          name: UIApplicationDidBecomeActiveNotification
                        object: nil];
    [defaultCenter addObserver: self
                      selector: @selector(willResignActive:)
                          name: UIApplicationWillResignActiveNotification
                        object: nil];
    self.results = [NSMutableArray arrayWithCapacity: 16];
    // restore results from save file if any
    announce = NO;
    pendingSurvey = NO;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void) viewDidAppear: (BOOL) animated
{
    [super viewDidAppear: animated];
    if(announce && [self.resultstring length] > 0) {
        UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification,
                                        self.resultstring);
        [self surveyAfterDelay: SURVEY_WAIT1];
    }
    if (pendingSurvey)
        // This is for the case when the survey couldn't be issued immediately.
        //
        [self surveyAfterDelay: SURVEY_WAIT2];
    announce = NO;
}

- (void) surveyAfterDelay: (NSTimeInterval) delay
{
    // Wait a while for the announcement to finish, then issue a survey
    // question if there is one. Currently we just wait a fixed amount of
    // time. In practice, the end-of-announcement notification is not
    // reliable.
    //
    pendingSurvey = NO;
    [self performSelector: @selector(surveyNow:)
               withObject: nil
               afterDelay: delay];
}

- (void) surveyNow: (NSObject *) dummy
{
    // If our view is still being displayed, perform the survey.
    // Otherwise mark it as pending, to be performed the next time our
    // view is displayed.
    //
    if ([self.tabBarController selectedViewController] == self)
        [self.survey askQuestionInView: self.view.window];
    else
        pendingSurvey = YES;
}

- (void) didBecomeActive: (NSNotification *) notification
{
    // Delete any save file
}

- (void) willResignActive: (NSNotification *) notification
{
    // Save results to file.
}

- (void) addResult: (NSString *) str
{
    self.resultstring = str;
    [self.results insertObject: str atIndex: 0];
    [self.tableView reloadData];
    announce = YES;
}

- (IBAction) clearResults: (id) sender
{
    self.resultstring = nil;
    [self.results removeAllObjects];
    [self.tableView reloadData];
    announce = NO;
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if(section > 0)
        return 0;
    return [self.results count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"ResultCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier] autorelease];
    }
    cell.textLabel.text = [self.results objectAtIndex: indexPath.row];
    return cell;
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
