//
//  TGVResults.h
//  TGV
//
//  Created by Jeffrey Scofield on 1/5/13.
//
//

#import <Foundation/Foundation.h>

@protocol TGVResults <NSObject>
- (void) addResult: (NSString *) resultstr;
- (IBAction) clearResults: (id) sender;
@end
