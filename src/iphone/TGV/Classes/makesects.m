// makesects.m     Carve image into sections and analyze
//
#import <math.h>
#import "filters.h"
#import "makesects.h"
#import "Section.h"


NSArray *makesects(uint16_t *lumi, int width, int height,
                        int otsu_thresh, int vvd_thresh, int units)
{
    // Carve the image into (units * units) rectangles and determine
    // their properties. Return NSArray of Section objects.
    //
# define MIN_DS_WID 5
    int x, y;
    int secwidth = (width + units - 1) / units;
    int secheight = (height + units - 1) / units;
    int mindepth = (otsu_thresh - vvd_thresh) / 6;
    int curwidth, curheight;
    NSMutableArray *mres = [[NSMutableArray alloc] init];
    Section *s;

    for(y = 0; y < height; y += secheight) {
        curheight = secheight;
        if(y + secheight > height)
            curheight = height - y;
        for(x = 0; x < width; x += secwidth) {
            curwidth = secwidth;
            if(x + secwidth > width)
                curwidth = width - x;
            s = [[Section alloc] init];
            s.x = x;
            s.y = y;
            s.w = curwidth;
            s.h = curheight;
            s.meanLuminance =
                lumi_rect_mean(lumi, width, height,
                                x, y, curwidth, curheight);
            int dsct =
                lumi_rect_downslopes(lumi, width, height,
                                    x, y, curwidth, curheight,
                                    MIN_DS_WID, mindepth);
            s.variegation =
                (double) dsct / sqrt(curheight * curheight * curwidth);
            [mres addObject: s];
            [s release];
        }
    }
    NSArray *res = [[mres copy] autorelease];
    [mres release];
    return res;
}
