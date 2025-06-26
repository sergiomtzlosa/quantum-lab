#import <SceneKit/SceneKit.h>
#import "QLSimulationResult.h"

NS_ASSUME_NONNULL_BEGIN

@class QLPlotOptions;

@interface QL3DPlotView : SCNView

@property (nonatomic, strong, nullable) QLSimulationResult *result;
@property (nonatomic, assign) NSInteger frameIndex;
@property (nonatomic, strong) QLPlotOptions *options;

- (void)setResult:(nullable QLSimulationResult *)result;
- (void)resetCamera;

@end

NS_ASSUME_NONNULL_END
