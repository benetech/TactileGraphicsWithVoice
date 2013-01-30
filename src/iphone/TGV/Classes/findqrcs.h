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
    
NSArray *findqrcs_x(RUN ***startsp, uint8_t *bitmap,
                    size_t width, size_t height);
NSArray *findqrcs(uint8_t *bitmap, size_t width, size_t height);

#ifdef __cplusplus
}
#endif
