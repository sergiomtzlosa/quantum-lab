#import "QLPlotStyle.h"

@implementation QLPlotOptions

- (instancetype)init {
    self = [super init];
    if (self) {
        _colorMapName = @"Viridis";
        _logScale = NO;
        _showPotential = YES;
        _showPhase = NO;
        _showRealImag = NO;
        _meshResolution = 96;
        _autoRotate = NO;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    QLPlotOptions *copy = [[QLPlotOptions allocWithZone:zone] init];
    copy.colorMapName = self.colorMapName;
    copy.logScale = self.logScale;
    copy.showPotential = self.showPotential;
    copy.showPhase = self.showPhase;
    copy.showRealImag = self.showRealImag;
    copy.meshResolution = self.meshResolution;
    copy.autoRotate = self.autoRotate;
    return copy;
}

@end
