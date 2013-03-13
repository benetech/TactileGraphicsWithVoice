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
    
NSArray *findqrcs_x(RUN ***startsp, uint16_t *lumi, uint16_t *dil,
                    size_t width, size_t height,
                    int ld_thresh, int vvd_thresh);
NSArray *findqrcs(uint16_t *lumi, uint16_t *dil, size_t width, size_t height,
                    int ld_thresh, int vvd_thresh);

#ifdef __cplusplus
}
#endif
