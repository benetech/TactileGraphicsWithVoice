//  EventLog.h
//
// Jeffrey Scofield, Psellos
// http://psellos.com
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