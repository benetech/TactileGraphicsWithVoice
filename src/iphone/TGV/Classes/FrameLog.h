// FrameLog.h
//
// Jeffrey Scofield, Psellos
// http://psellos.com
//

#import <Foundation/Foundation.h>

@interface FrameLog : NSObject
- (void) logFrame: (uint8_t *) frame withWidth: (int) width height: (int) height annotation: (NSString *) annotation;
- (void) save;
@end
