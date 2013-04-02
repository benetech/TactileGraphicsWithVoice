//  Device.h     Properties of the device
//

#import <Foundation/Foundation.h>

@interface Device : NSObject
- (BOOL) isSlow;   // Use less CPU intensive solutions if slow
@end
