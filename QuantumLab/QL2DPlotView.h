#import <Cocoa/Cocoa.h>
#import "QLSimulationResult.h"

NS_ASSUME_NONNULL_BEGIN

@class QLPlotOptions;

@interface QL2DPlotView : NSView

@property (nonatomic, strong, nullable) QLSimulationResult *result;
@property (nonatomic, assign) NSInteger frameIndex;
@property (nonatomic, strong) QLPlotOptions *options;
@property (nonatomic, assign) QLPlotKind plotKindOverride;

- (void)setResult:(nullable QLSimulationResult *)result;
- (void)clearHover;
- (NSImage *)snapshotImage;

@end

NS_ASSUME_NONNULL_END
