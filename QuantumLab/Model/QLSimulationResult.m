#import "QLSimulationResult.h"

@implementation QLSeries
@end

@implementation QLSimulationResult

- (instancetype)init {
    self = [super init];
    if (self) {
        _times = @[];
        _frames = @[];
        _phaseFrames = @[];
        _series = @[];
        _normValues = @[];
        _energyValues = @[];
        _potentialX = @[];
        _potentialV = @[];
        _warnings = @[];
        _globalDensityMax = 1.0;
        _maxDensity = 1.0;
    }
    return self;
}

- (BOOL)isSchrodinger { return self.mode == QLSimulationModeSchrodinger; }
- (BOOL)is2D { return self.mode == QLSimulationModeSchrodinger && self.dimension == QLSchrodingerDimension2D; }
- (BOOL)isSpin { return self.mode == QLSimulationModeHeisenberg && self.system == QLHeisenbergSystemSpin; }
- (BOOL)isOscillator { return self.mode == QLSimulationModeHeisenberg && self.system == QLHeisenbergSystemOscillator; }

- (const double complex *)wavefunctionAtFrame:(NSInteger)frame {
    if (frame < 0 || frame >= (NSInteger)self.frames.count || !self.isSchrodinger || self.is2D) {
        return NULL;
    }
    NSData *data = self.frames[(NSUInteger)frame];
    if (data.length < (NSUInteger)self.nx * sizeof(double complex)) {
        return NULL;
    }
    return (const double complex *)data.bytes;
}

- (const float *)densityAtFrame:(NSInteger)frame {
    if (frame < 0 || frame >= (NSInteger)self.frames.count || !self.is2D) {
        return NULL;
    }
    NSData *data = self.frames[(NSUInteger)frame];
    NSUInteger expected = (NSUInteger)self.nx * (NSUInteger)self.ny * sizeof(float);
    if (data.length < expected) {
        return NULL;
    }
    return (const float *)data.bytes;
}

- (const float *)phaseAtFrame:(NSInteger)frame {
    if (!self.hasPhase || frame < 0 || frame >= (NSInteger)self.phaseFrames.count) {
        return NULL;
    }
    NSData *data = self.phaseFrames[(NSUInteger)frame];
    NSUInteger expected = (NSUInteger)self.nx * (NSUInteger)self.ny * sizeof(float);
    if (data.length < expected) {
        return NULL;
    }
    return (const float *)data.bytes;
}

- (QLSeries *)seriesNamed:(NSString *)name {
    for (QLSeries *series in self.series) {
        if ([series.name isEqualToString:name]) {
            return series;
        }
    }
    return nil;
}

@end
