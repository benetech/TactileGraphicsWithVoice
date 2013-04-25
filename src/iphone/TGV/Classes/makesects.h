// makesects.h     Carve image into sections and analyze
//
// Jeffrey Scofield, Psellos
// http://psellos.com
//
#if TARGET_MAC
#import <Cocoa/Cocoa.h>
#else
#import <UIKit/UIKit.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif
    
NSArray *makesects(uint16_t *lumi, int width, int height,
                        int otsu_thresh, int vvd_thresh, int units);

#ifdef __cplusplus
}
#endif
