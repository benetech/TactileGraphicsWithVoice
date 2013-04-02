// findfinders.h     Find finder patterns as separate blobs
//
#if TARGET_MAC
#import <Cocoa/Cocoa.h>
#else
#import <UIKit/UIKit.h>
#endif

NSArray *findfinders(int min_qr_size, int max_qr_size, TGV_BITMAP *bitmap,
                        RUN **starts, NSMutableDictionary *blobs);
