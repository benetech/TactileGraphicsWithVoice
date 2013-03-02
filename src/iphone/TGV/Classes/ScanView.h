// ScanView.h
//
// Simple subclass of UIView. The only difference right now is that this
// class tracks touches for use in accessibility experiments.
//

#import <UIKit/UIKit.h>

@protocol ScanViewDelegate;

@interface ScanView : UIView
@property (nonatomic, assign) IBOutlet id <ScanViewDelegate> delegate;
@end

@protocol ScanViewDelegate
- (BOOL) scanViewShouldReportTouches: (ScanView *) scanView;
- (void) scanView: (ScanView *) scanView didFeelTouchesAtPoints: (NSArray *) points;
@end