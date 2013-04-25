// Voice.h     Offer periodic vocal guidance
//
// Jeffrey Scofield, Psellos
// http://psellos.com
//

#import <Foundation/Foundation.h>

@interface Voice : NSObject
- (void) initializeGuidance;
- (BOOL) offerGuidance: (NSString *) guidance;
@end
