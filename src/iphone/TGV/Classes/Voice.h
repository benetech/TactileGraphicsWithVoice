//
//  Voice.h
//  TGV
//
//  Created by Jeffrey Scofield on 1/26/13.
//
//

#import <Foundation/Foundation.h>

@interface Voice : NSObject
- (void) initializeGuidance;
- (BOOL) offerGuidance: (NSString *) guidance;
@end
