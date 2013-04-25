//  Device.h     Properties of the device
//
// Jeffrey Scofield, Psellos
// http://psellos.com
//

#import <Foundation/Foundation.h>

@interface Device : NSObject
- (BOOL) isSlow;   // Use less CPU intensive solutions if slow
@end
