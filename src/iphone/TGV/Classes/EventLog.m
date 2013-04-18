//
//  EventLog.m
//  TGV
//
//  Created by Jeffrey Scofield on 3/1/13.
//
//
#import <stdio.h>
#import "EventLog.h"

static NSString *monthNames[] =
    { @"X",
      @"Jan", @"Feb", @"Mar", @"Apr", @"May", @"Jun",
      @"Jul", @"Aug", @"Sep", @"Oct", @"Nov", @"Dec" };

@interface EventLog ()
{
    CFTimeZoneRef timeZone;
}
@property (nonatomic) FILE *logFile;
@end

@implementation EventLog
@synthesize delegate = _delegate;

- (EventLog *) init {
    if((self = [super init]) == nil)
        return nil;
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(didEnterBackground:)
               name:UIApplicationDidEnterBackgroundNotification
             object:nil];
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(willTerminate:)
               name:UIApplicationWillTerminateNotification
            object:nil];
    return self;
}

- (NSURL *)applicationDocumentsDirectory
{
    NSArray *urls =
        [[NSFileManager defaultManager] URLsForDirectory: NSDocumentDirectory
                                                inDomains:NSUserDomainMask];
         return [urls lastObject];
}


- (NSString *) nowString
{
    if(timeZone == NULL) timeZone = CFTimeZoneCopyDefault();
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    CFGregorianDate d = CFAbsoluteTimeGetGregorianDate(now, timeZone);
    return [NSString stringWithFormat: @"%@%02d-%02d%02d", monthNames[d.month], d.day, d.hour, d.minute];
}

- (NSString *) logTimeString
{
    if(timeZone == NULL) timeZone = CFTimeZoneCopyDefault();
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    CFGregorianDate d = CFAbsoluteTimeGetGregorianDate(now, timeZone);
    return [NSString stringWithFormat: @"%02d/%@/%d:%02d:%02d:%06.3f",
                    d.day, monthNames[d.month], (int) d.year, (int) d.hour, d.minute, d.second];
}


- (void) log:(NSString *)message
{
    if (![self.delegate eventLogShouldLogEvent:self])
        return;
    [self open];
    NSString *line = [NSString stringWithFormat: @"%@ %@\n", [self logTimeString], message];
    fputs([line UTF8String], self.logFile);
    fflush(self.logFile);
}


- (void) open
{
    if(self.logFile)
        return;
    NSURL *url = [self applicationDocumentsDirectory];
    NSString *compo = [NSString stringWithFormat: @"%@.txt", [self nowString]];
    NSString *path = [[url URLByAppendingPathComponent: compo] path];
    self.logFile = fopen([path UTF8String], "a");
}

- (void) close
{
    fclose(self.logFile);
    self.logFile = NULL;
}

- (void) didEnterBackground: (NSNotification *) notification
{
    [self close];
}

- (void) willTerminate: (NSNotification *) notification
{
    [self close];
}

@end
