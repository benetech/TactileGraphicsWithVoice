// Majority.m     Tracking of changing (small nonnegative int) value
//

#import "Majority.h"

@interface Majority ()
{
    int *histogram; // Count for each 0 <= value <= maxValue
    int *history;   // Recent values, up to quorum
    int *nextin;    // Next history value goes here
    int historyct;  // Number in the history
}
@property (nonatomic, retain) NSMutableArray *voteHistory;
@end

@implementation Majority

- (void) setMaxValue:(int)maxValue
{
    if (maxValue < 0)
        return;
    free(histogram);
    histogram = malloc((maxValue + 1) * sizeof(int));
    memset(histogram, 0, (maxValue + 1) * sizeof(int));
    _maxValue = maxValue;
    // Need to invalidate any previous values.
    //
    historyct = 0;
    nextin = history;
}

- (void) setQuorum:(int)quorum
{
    if(quorum < 0)
        return;
    free(history);
    history = malloc(quorum * sizeof(int));
    nextin = history;
    historyct = 0;
    _quorum = quorum;
    // Need to clear out any previous histogram.
    //
    if(histogram != NULL)
        memset(histogram, 0, (self.maxValue + 1) * sizeof(int));
}

- (void) setKeepCount:(int)keepCount
{
    int count;

    if (self.voteHistory == nil)
        self.voteHistory = [NSMutableArray arrayWithCapacity: keepCount + 1];
    while ((count = [self.voteHistory count]) > 1 && count > keepCount)
        [self.voteHistory removeLastObject];
    _keepCount = keepCount;
}

- (void) newValue: (int) value
{
    if(value < 0 || value > self.maxValue)
        return;
    if(history == NULL)
        return; // Quorum of 0, no memory
    if(historyct >= self.quorum) {
        if(histogram != NULL) histogram[*nextin]--;
        historyct--;
    }
    *nextin++ = value;
    histogram[value]++;
    historyct++;
    if(nextin >= history + self.quorum)
        nextin = history;
    int vote = [self calculateVote];
    if (self.voteHistory == nil)
        self.voteHistory = [NSMutableArray array];
    [self.voteHistory insertObject: [NSNumber numberWithInt: vote]
                           atIndex: 0];
    int count = [self.voteHistory count];
    if (count > 1 && count > self.keepCount)
        [self.voteHistory removeLastObject];
}

- (int) calculateVote
{
    if(historyct < self.quorum)
        return MAJORITY_NOQUORUM;
    // Assert: historyct == self.quorum
    if(histogram == NULL)
        return MAJORITY_NOMAJORITY;
    int max = 0;
    for(int i = 1; i <= self.maxValue; i++) {
        if(histogram[i] > histogram[max])
            max = i;
    }
    if(histogram[max] <= historyct / 2)
        return MAJORITY_NOMAJORITY;
    return max;
}

- (int) vote
{
    if ([self.voteHistory count] == 0)
        return MAJORITY_NOQUORUM;
    return [(NSNumber *) self.voteHistory[0] intValue];
}

- (NSArray *) votes
{
    if (self.voteHistory == nil)
        self.voteHistory = [NSMutableArray array];
    return self.voteHistory;
}

- (void) dealloc
{
    free(history);
    history = NULL;
    free(histogram);
    histogram = NULL;
    self.voteHistory = nil;
    [super dealloc];
}

@end
