// findfinders.h     Find finder patterns as separate blobs
//
// Jeffrey Scofield, Psellos
// http://psellos.com
//
#if TARGET_MAC
#import <Cocoa/Cocoa.h>
#else
#import <UIKit/UIKit.h>
#endif

NSArray *findfinders(int min_qr_size, int max_qr_size, TGV_BITMAP *bitmap,
                        RUN **starts, NSMutableDictionary *blobs);
