#import <Cocoa/Cocoa.h>
#import "QLTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface QLSeries : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) NSColor *color;
@property (nonatomic, copy) NSArray<NSNumber *> *xValues;
@property (nonatomic, copy) NSArray<NSNumber *> *yValues;
@property (nonatomic, assign) CGFloat lineWidth;
@property (nonatomic, assign) BOOL dashed;
@end

@interface QLSimulationResult : NSObject

@property (nonatomic, assign) QLSimulationMode mode;
@property (nonatomic, assign) QLSchrodingerDimension dimension;
@property (nonatomic, assign) QLHeisenbergSystem system;
@property (nonatomic, assign) QLPlotKind plotKind;
@property (nonatomic, assign) QLPotentialType potential;

@property (nonatomic, assign) NSInteger nx;
@property (nonatomic, assign) NSInteger ny;
@property (nonatomic, assign) NSInteger frameCount;
@property (nonatomic, assign) double lx;
@property (nonatomic, assign) double ly;
@property (nonatomic, assign) double hbar;
@property (nonatomic, assign) double mass;
@property (nonatomic, assign) double dt;
@property (nonatomic, assign) double tmax;
@property (nonatomic, assign) BOOL storePhase;
@property (nonatomic, assign) BOOL hasPhase;

@property (nonatomic, copy) NSArray<NSNumber *> *times;
@property (nonatomic, copy) NSArray<NSData *> *frames;
@property (nonatomic, copy) NSArray<NSData *> *phaseFrames;
@property (nonatomic, copy) NSArray<QLSeries *> *series;
@property (nonatomic, copy) NSArray<NSNumber *> *normValues;
@property (nonatomic, copy) NSArray<NSNumber *> *energyValues;
@property (nonatomic, copy) NSArray<NSNumber *> *potentialX;
@property (nonatomic, copy) NSArray<NSNumber *> *potentialV;
@property (nonatomic, copy) NSArray<NSString *> *warnings;

@property (nonatomic, assign) double globalDensityMax;
@property (nonatomic, assign) double minDensity;
@property (nonatomic, assign) double maxDensity;
@property (nonatomic, assign) double solveDuration;
@property (nonatomic, assign) NSUInteger estimatedBytes;

- (BOOL)isSchrodinger;
- (BOOL)is2D;
- (BOOL)isSpin;
- (BOOL)isOscillator;

- (nullable const double complex *)wavefunctionAtFrame:(NSInteger)frame;
- (nullable const float *)densityAtFrame:(NSInteger)frame;
- (nullable const float *)phaseAtFrame:(NSInteger)frame;

- (nullable QLSeries *)seriesNamed:(NSString *)name;

@end

NS_ASSUME_NONNULL_END
