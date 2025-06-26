#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface QLPlotOptions : NSObject <NSCopying>

@property (nonatomic, copy) NSString *colorMapName;
@property (nonatomic, assign) BOOL logScale;
@property (nonatomic, assign) BOOL showPotential;
@property (nonatomic, assign) BOOL showPhase;
@property (nonatomic, assign) BOOL showRealImag;
@property (nonatomic, assign) NSInteger meshResolution;
@property (nonatomic, assign) BOOL autoRotate;

@end

NS_ASSUME_NONNULL_END
