//
//  FrameLog.h
//  TGV
//
//  Created by Jeffrey Scofield on 3/16/13.
//
//

#import <Foundation/Foundation.h>

@interface FrameLog : NSObject
- (void) logFrame: (uint8_t *) frame withWidth: (int) width height: (int) height annotation: (NSString *) annotation;
- (void) save;
@end
