//
//  EventLog.h
//  TGV
//
//  Created by Jeffrey Scofield on 3/1/13.
//
//

#import <Foundation/Foundation.h>
@protocol EventLogDelegate;

@interface EventLog : NSObject
@property (nonatomic, assign) id <EventLogDelegate> delegate;
- (void) log: (NSString *) message;
@end

@protocol EventLogDelegate
- (BOOL) eventLogShouldLogEvent: (EventLog *) eventLog;
@end