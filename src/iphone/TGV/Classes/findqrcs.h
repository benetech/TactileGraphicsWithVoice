/* findqrcs.h     Find and classify QR codes in an image
 */
#if TARGET_MAC
#import <Cocoa/Cocoa.h>
#else
#import <UIKit/UIKit.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

#import "bitmap.h"
    
NSArray *findqrcs(int min_qr_size, int max_qr_size, TGV_BITMAP *bitmap,
                        RUN **starts, NSMutableDictionary *blobs,
                        NSArray *fpblobs);

#ifdef __cplusplus
}
#endif
