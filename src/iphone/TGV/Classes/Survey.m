// Survey.m     Ask questions after successful scans
//
// Jeffrey Scofield, Psellos
// http://psellos.com
//

#import <stdio.h>
#import "TGVSettings.h"
#import "Survey.h"

// Right now there's just one question. The idea is that you could
// have some number of them and choose which one to ask each time.
//
static NSString *question = @"Who would win in a fair fight?";
static NSString *answers[] = { @"Pirate", @"Ninja" };
static int answer_ct = sizeof answers / sizeof answers[0];

static NSString *monthNames[] =
{ @"X",
    @"Jan", @"Feb", @"Mar", @"Apr", @"May", @"Jun",
    @"Jul", @"Aug", @"Sep", @"Oct", @"Nov", @"Dec" };


@interface Survey () <UIActionSheetDelegate>
{
    NSUserDefaults *defaults;
    CFTimeZoneRef timeZone;
}
@property (nonatomic, retain) UIActionSheet *actionSheet;
@property (nonatomic) FILE *surveyFile;
@end

@implementation Survey

- (void) askQuestionInView: (UIView *) aView
{
    // Ask the next question, if any.
    //
    if (![defaults boolForKey: kSettingsDoSurvey])
        return;
    self.actionSheet = [[UIActionSheet alloc] init];
    self.actionSheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
    self.actionSheet.title = question;
    for (int i = 0; i < answer_ct; i++)
        [self.actionSheet addButtonWithTitle: answers[i]];
    [self.actionSheet addButtonWithTitle: @"Cancel"];
    self.actionSheet.cancelButtonIndex = answer_ct;
    self.actionSheet.delegate = self;
    [self.actionSheet showInView: aView];
}

- (void) actionSheet: (UIActionSheet *) actionSheet
clickedButtonAtIndex: (NSInteger) buttonIndex
{
    NSString *response =
        buttonIndex < answer_ct ? answers[buttonIndex] : @"Cancel";
    [self recordResponse: response];
    self.actionSheet = nil;
}

- (NSURL *)applicationDocumentsDirectory
{
    NSArray *urls =
    [[NSFileManager defaultManager] URLsForDirectory: NSDocumentDirectory
                                           inDomains:NSUserDomainMask];
    return [urls lastObject];
}

- (NSString *) timeString
{
    if(timeZone == NULL) timeZone = CFTimeZoneCopyDefault();
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    CFGregorianDate d = CFAbsoluteTimeGetGregorianDate(now, timeZone);
    return [NSString stringWithFormat: @"%02d/%@/%d:%02d:%02d:%06.3f",
            d.day, monthNames[d.month], (int) d.year, (int) d.hour, d.minute, d.second];
}

- (void) recordResponse: (NSString *) response
{
    [self open];
    NSString *line = [NSString stringWithFormat: @"%@ %@ | %@\n",
                      [self timeString], question, response];
    fputs([line UTF8String], self.surveyFile);
    fflush(self.surveyFile);
}


- (void) open
{
    if(self.surveyFile != NULL)
        return;
    NSURL *url = [self applicationDocumentsDirectory];
    NSString *path =
        [[url URLByAppendingPathComponent: @"SurveyResults.txt"] path];
    self.surveyFile = fopen([path UTF8String], "a");
}

- (void) close
{
    fclose(self.surveyFile);
    self.surveyFile = NULL;
}

- (id) init
{
    if((self = [super init]) != nil)
        [self setup];
    return self;
}

- (void) awakeFromNib
{
    [super awakeFromNib];
    [self setup];
}

- (void) setup
{
    defaults = [NSUserDefaults standardUserDefaults];
    NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
    [defaultCenter addObserver: self
                      selector: @selector(didBecomeActive:)
                          name: UIApplicationDidBecomeActiveNotification
                        object: nil];
    [defaultCenter addObserver: self
                      selector: @selector(willResignActive:)
                          name: UIApplicationWillResignActiveNotification
                        object: nil];
}

- (void) didBecomeActive: (NSNotification *) notification
{
}

- (void) willResignActive: (NSNotification *) notification
{
    if(self.actionSheet != nil) {
        // Cancel the question when moving to background.
        //
        NSInteger cancelx = self.actionSheet.cancelButtonIndex;
        [self.actionSheet dismissWithClickedButtonIndex: cancelx animated: NO];
        self.actionSheet = nil;
    }
    [self close];
}

@end
