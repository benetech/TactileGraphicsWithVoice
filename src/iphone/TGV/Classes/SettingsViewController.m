// SettingsViewController.m     Control the settings tab
//

#import "SettingsViewController.h"

@interface SettingsViewController ()
{
    NSUserDefaults *defaults;
}
@end

@implementation SettingsViewController

- (void) setGuideWithBeeps: (UISwitch *) sender
{
    [defaults setBool: sender.isOn forKey: kSettingsGuideWithBeeps];
    [defaults synchronize];
}

- (void) setIlluminateScans: (UISwitch *) sender
{
    [defaults setBool: sender.isOn forKey: kSettingsIlluminateScans];
    [defaults synchronize];
}

- (void) setScanAllCounts: (UISwitch *) sender
{
    [defaults setBool: sender.isOn forKey: kSettingsScanAllCounts];
    [defaults synchronize];
}

- (void) setAnnounceZero: (UISwitch *) sender
{
    [defaults setBool: sender.isOn forKey: kSettingsAnnounceZero];
    [defaults synchronize];
}

- (void) setDoSurvey: (UISwitch *) sender
{
    [defaults setBool: sender.isOn forKey: kSettingsDoSurvey];
    [defaults synchronize];
}

- (void) setSilentGuidance: (UISwitch *) sender
{
    [defaults setBool: sender.isOn forKey: kSettingsSilentGuidance];
    [defaults synchronize];
}

- (void) setSaveFailedScans: (UISwitch *) sender
{
    [defaults setBool: sender.isOn forKey: kSettingsSaveFailedScans];
    [defaults synchronize];
}

- (void) setSaveSucceededScans: (UISwitch *) sender
{
    [defaults setBool: sender.isOn forKey: kSettingsSaveSucceededScans];
    [defaults synchronize];
}

- (void) setSaveFailedCounts: (UISwitch *) sender
{
    [defaults setBool: sender.isOn forKey: kSettingsSaveFailedCounts];
    [defaults synchronize];
}

- (void) setTrackTouches: (UISwitch *) sender
{
    [defaults setBool: sender.isOn forKey: kSettingsTrackTouches];
    [defaults synchronize];
}

- (void) setLogEvents: (UISwitch *) sender
{
    [defaults setBool: sender.isOn forKey: kSettingsLogEvents];
    [defaults synchronize];
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSString *) tableView: (UITableView *) tableView titleForHeaderInSection:(NSInteger)section
{
    switch (section) {
        case 0: return nil;
        case 1: return @"Testing and Troubleshooting";
        default: return nil;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case 0: return 4;
        case 1:
#if TGV_EXPERIMENTAL
            return 4;
#else
            return 2;
#endif
        default: return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"SettingsCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier: CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier] autorelease];
    }
    NSString *label;
    SEL action;
    BOOL initialValue;
    switch (indexPath.section * 10 + indexPath.row) {
        case 0:
            label = @"Guide With Beeps";
            action = @selector(setGuideWithBeeps:);
            initialValue = [defaults boolForKey: kSettingsGuideWithBeeps];
            break;
        case 1:
            label = @"Illuminate Scans";
            action = @selector(setIlluminateScans:);
            initialValue = [defaults boolForKey: kSettingsIlluminateScans];
            break;
        case 2:
            label = @"Scan All the Time";
            action = @selector(setScanAllCounts:);
            initialValue = [defaults boolForKey: kSettingsScanAllCounts];
            break;
        case 3:
            label = @"Announce Zero Counts";
            action = @selector(setAnnounceZero:);
            initialValue = [defaults boolForKey: kSettingsAnnounceZero];
            break;
        case 10:
            label = @"Issue Survey Questions";
            action = @selector(setDoSurvey:);
            initialValue = [defaults boolForKey: kSettingsDoSurvey];
            break;
        case 11:
            label = @"Silent Guidance";
            action = @selector(setSilentGuidance:);
            initialValue = [defaults boolForKey: kSettingsSilentGuidance];
            break;
#ifdef TROUBLE_WITH_SCANS
        // These are disabled for now. If you want to reenable them, don't
        // forget to remove code in [self setup] that sets them to NO.
        // (A few lines below.)
        //
        case 12:
            label = @"Save Failed Scans";
            action = @selector(setSaveFailedScans:);
            initialValue = [defaults boolForKey: kSettingsSaveFailedScans];
            break;
        case 13:
            label = @"Save Succeeded Scans";
            action = @selector(setSaveSucceededScans:);
            initialValue = [defaults boolForKey: kSettingsSaveSucceededScans];
            break;
        case 14:
            label = @"Save Failed Counts";
            action = @selector(setSaveFailedCounts:);
            initialValue = [defaults boolForKey: kSettingsSaveFailedCounts];
            break;
#endif // TROUBLE_WITH_SCANS
#if TGV_EXPERIMENTAL
        case 12:
            label = @"Highlight scan touch";
            action = @selector(setTrackTouches:);
            initialValue = [defaults boolForKey: kSettingsTrackTouches];
            break;
        case 13:
            label = @"Log Events";
            action = @selector(setLogEvents:);
            initialValue = [defaults boolForKey: kSettingsLogEvents];
            break;
#endif
        default:
            label = nil;
            break;
    }
    if (label == nil) {
        cell.textLabel.text = @"(Undefined)";
    } else {
        UISwitch *switchv = [[UISwitch alloc] init];
        cell.textLabel.text = label;
        cell.accessoryView = switchv;
        switchv.on = initialValue;
        [switchv addTarget: self action: action forControlEvents: UIControlEventValueChanged];
    }
    return cell;
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
    
    // Disable some troubleshooting options for now. Otherwise they might
    // get stuck in the on position.
    //
    [defaults setBool: NO forKey: kSettingsSaveFailedScans];
    [defaults setBool: NO forKey: kSettingsSaveSucceededScans];
    [defaults setBool: NO forKey: kSettingsSaveFailedCounts];
    [defaults synchronize];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
@end
