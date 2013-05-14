// Majority.h     Track changing (small nonnegative int) value
//
// Jeffrey Scofield, Psellos
// http://psellos.com
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
