// Majority.m     Tracking of changing (small nonnegative int) value
//
// Jeffrey Scofield, Psellos
// http://psellos.com
//
// Copyright (c) 2012-2013 University of Washington
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// - Redistributions of source code must retain the above copyright notice,
// this list of conditions and the following disclaimer.
// - Redistributions in binary form must reproduce the above copyright
// notice, this list of conditions and the following disclaimer in the
// documentation and/or other materials provided with the distribution.
// - Neither the name of the University of Washington nor the names of its
// contributors may be used to endorse or promote products derived from this
// software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE UNIVERSITY OF WASHINGTON AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
// PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE UNIVERSITY OF WASHINGTON OR
// CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
// WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
// OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
// ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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
    [self.voteHistory removeAllObjects];
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
    // Invalidate any previous values.
    //
    if(histogram != NULL)
        memset(histogram, 0, (self.maxValue + 1) * sizeof(int));
    [self.voteHistory removeAllObjects];
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

- (void) clear
{
    nextin = history;
    historyct = 0;
    if(histogram != NULL)
        memset(histogram, 0, (self.maxValue + 1) * sizeof(int));
    [self.voteHistory removeAllObjects];
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
