#import <Foundation/Foundation.h>
#import "QLTypes.h"
#import "QLParameterSet.h"

NS_ASSUME_NONNULL_BEGIN

@interface QLSimulationConfig : NSObject

@property (nonatomic, assign) QLSimulationMode mode;
@property (nonatomic, assign) NSInteger variant;
@property (nonatomic, assign) QLSchrodingerDimension dimension;
@property (nonatomic, assign) QLHeisenbergSystem system;
@property (nonatomic, assign) QLPotentialType potential;

@property (nonatomic, assign) NSInteger nx;
@property (nonatomic, assign) NSInteger ny;
@property (nonatomic, assign) NSInteger frames;
@property (nonatomic, assign) double lx;
@property (nonatomic, assign) double ly;
@property (nonatomic, assign) double hbar;
@property (nonatomic, assign) double mass;
@property (nonatomic, assign) double dt;
@property (nonatomic, assign) double tmax;

@property (nonatomic, assign) double x0;
@property (nonatomic, assign) double y0;
@property (nonatomic, assign) double sigmaX;
@property (nonatomic, assign) double sigmaY;
@property (nonatomic, assign) double kx0;
@property (nonatomic, assign) double ky0;
@property (nonatomic, assign) NSInteger vortex;

@property (nonatomic, assign) double v0;
@property (nonatomic, assign) double omega;
@property (nonatomic, assign) double barrierX;
@property (nonatomic, assign) double barrierWidth;
@property (nonatomic, assign) double barrierSeparation;
@property (nonatomic, assign) double wallThickness;
@property (nonatomic, assign) double slitSeparation;
@property (nonatomic, assign) double slitWidth;
@property (nonatomic, assign) double wellRadius;
@property (nonatomic, assign) double latticePeriod;
@property (nonatomic, assign) double field;

@property (nonatomic, assign) double absWidth;
@property (nonatomic, assign) double absStrength;
@property (nonatomic, assign) BOOL renormalize;
@property (nonatomic, assign) BOOL storePhase;

@property (nonatomic, assign) double gamma;
@property (nonatomic, assign) double bx;
@property (nonatomic, assign) double by;
@property (nonatomic, assign) double bz;
@property (nonatomic, assign) double driveAmp;
@property (nonatomic, assign) double driveFreq;
@property (nonatomic, assign) double drivePhase;
@property (nonatomic, assign) NSInteger driveAxis;
@property (nonatomic, assign) double theta0;
@property (nonatomic, assign) double phi0;
@property (nonatomic, assign) double x0Osc;
@property (nonatomic, assign) double p0Osc;
@property (nonatomic, assign) double damping;

@property (nonatomic, assign) NSInteger steps;
@property (nonatomic, assign) double actualDt;
@property (nonatomic, assign) NSUInteger estimatedBytes;
@property (nonatomic, copy) NSArray<NSString *> *warnings;
@property (nonatomic, assign) double maxPotential;

+ (nullable instancetype)configFromParameters:(QLParameterSet *)parameters
                                         mode:(QLSimulationMode)mode
                                      variant:(NSInteger)variant
                                        error:(NSError **)error;

- (NSString *)summaryString;

@end

NS_ASSUME_NONNULL_END
