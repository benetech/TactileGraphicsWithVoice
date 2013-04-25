// Majority.h     Track changing (small nonnegative int) value
//
// Jeffrey Scofield, Psellos
// http://psellos.com
//
// Track a series of small int values, taking a vote after each new value
// shows up. The idea of the vote is to determine what value has shown up
// the majority of the time recently. The newValue: method registers a
// new value. The vote method returns value that was the majority of the
// most recent k values, where k is controlled by the quorum property.
// The votes method returns a history of the recent votes (an NSArray of
// NSNumbers). In both cases, a vote can be given as MAJORITY_NOQUORUM
// (not enough values have shown up yet) or as MAJORITY_NOMAJORITY (there
// are enough values, but no clear majority).
//
// The code depends on the values being nonnegative and really small. The
// maxValue property gives the largest allowed value. (For TGV, the
// largest value is 4. Like I said, really small.)
//

#import <Foundation/Foundation.h>

#define MAJORITY_NOQUORUM   (-1)
#define MAJORITY_NOMAJORITY (-2)

@interface Majority : NSObject
@property (nonatomic) int quorum;     // How many recent values to track
@property (nonatomic) int maxValue;   // Largest value of tracked int
@property (nonatomic) int keepCount;  // Number of previous votes to keep
- (void) clear;                       // Reset all vote counters to 0
- (void) newValue: (int) value;       // Register a new tracked value
- (int) vote;                         // Majority value of most recent quorum
- (NSArray *) votes;                  // History of votes (most recent first)
@end
