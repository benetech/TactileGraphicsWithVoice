//  EventLog.m
//
// Jeffrey Scofield, Psellos
// http://psellos.com
//
// Copyright (c) 2012-2013 University of Washington
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// - Redistributions of source code must retain the above copyright notice,
// this list of conditions and the following disclaimer.
// - Redistributions in binary form must reproduce the above copyright
// notice, this list of conditions and the following disclaimer in the
// documentation and/or other materials provided with the distribution.
// - Neither the name of the University of Washington nor the names of its
// contributors may be used to endorse or promote products derived from this
// software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE UNIVERSITY OF WASHINGTON AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
// PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE UNIVERSITY OF WASHINGTON OR
// CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
// WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
// OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
// ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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
