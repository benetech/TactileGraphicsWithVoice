//
//  ResultsTViewController.m
//  TGV
//
//  Created by Jeffrey Scofield on 1/5/13.
//
//

#import "ResultsTViewController.h"

@interface ResultsTViewController ()
@property (nonatomic,retain) NSMutableArray *results;
@property (nonatomic, retain) NSString *resultstring;
- (void) initialize;
@end

@implementation ResultsTViewController

- (id) initWithNibName: (NSString *) nibName bundle: (NSBundle *) nibBundle
{
    self = [super initWithNibName: nibName bundle: nibBundle];
    if (self) {
        [self initialize];
    }
    return self;
}

- (id) initWithCoder: (NSCoder *) aDecoder
{
    self = [super initWithCoder: aDecoder];
    if(self) {
        [self initialize];
    }
    return self;
}

- (void) initialize
{
    self.results = [NSMutableArray arrayWithCapacity: 16];
    announce = NO;
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
    }
    announce = NO;
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

#pragma mark - Table view data source

/* REFERENCE *

   UITableViewDataSource protocol

 – tableView:cellForRowAtIndexPath:  required method
 – numberOfSectionsInTableView:
 – tableView:numberOfRowsInSection:  required method
 – sectionIndexTitlesForTableView:
 – tableView:sectionForSectionIndexTitle:atIndex:
 – tableView:titleForHeaderInSection:
 – tableView:titleForFooterInSection:

 – tableView:commitEditingStyle:forRowAtIndexPath:
 – tableView:canEditRowAtIndexPath:

 – tableView:canMoveRowAtIndexPath:
 – tableView:moveRowAtIndexPath:toIndexPath:

 * REFERENCE */

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

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Navigation logic may go here. Create and push another view controller.
    /*
     <#DetailViewController#> *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
     // ...
     // Pass the selected object to the new view controller.
     [self.navigationController pushViewController:detailViewController animated:YES];
     [detailViewController release];
     */
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
