// Section.h     Section of grid laid over image
//
#import <Foundation/Foundation.h>

@interface Section : NSObject
@property (nonatomic) int x;
@property (nonatomic) int y;
@property (nonatomic) int w;
@property (nonatomic) int h;
@property (nonatomic) int meanLuminance;
@property (nonatomic) double variegation; 
@end
