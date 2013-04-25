// TGVResults.h    Protocol for reporting scan results
//
// Jeffrey Scofield, Psellos
// http://psellos.com
//

#import <Foundation/Foundation.h>

@protocol TGVResults <NSObject>
- (void) addResult: (NSString *) resultstr;
- (IBAction) clearResults: (id) sender;
@end
