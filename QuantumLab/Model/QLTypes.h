#import <Foundation/Foundation.h>
#include <complex.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, QLSimulationMode) {
    QLSimulationModeSchrodinger = 0,
    QLSimulationModeHeisenberg = 1
};

typedef NS_ENUM(NSInteger, QLSchrodingerDimension) {
    QLSchrodingerDimension1D = 0,
    QLSchrodingerDimension2D = 1
};

typedef NS_ENUM(NSInteger, QLHeisenbergSystem) {
    QLHeisenbergSystemSpin = 0,
    QLHeisenbergSystemOscillator = 1
};

typedef NS_ENUM(NSInteger, QLPlotKind) {
    QLPlotKindWavefunction1D = 0,
    QLPlotKindDensityHeatmap2D = 1,
    QLPlotKindSpinTimeSeries = 2,
    QLPlotKindOscillatorPhase = 3,
    QLPlotKindOscillatorTimeSeries = 4
};

typedef NS_ENUM(NSInteger, QLPotentialType) {
    QLPotentialTypeFree = 0,
    QLPotentialTypeHarmonic = 1,
    QLPotentialTypeBarrier = 2,
    QLPotentialTypeDoubleBarrier = 3,
    QLPotentialTypeLinear = 4,
    QLPotentialTypeLattice = 5,
    QLPotentialTypeDoubleSlit = 6,
    QLPotentialTypeCircularWell = 7
};

static inline BOOL QLIsPowerOfTwo(NSInteger value) {
    return value > 0 && (value & (value - 1)) == 0;
}

extern NSString *const QuantumLabErrorDomain;

NS_ASSUME_NONNULL_END
