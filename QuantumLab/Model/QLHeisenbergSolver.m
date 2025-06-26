#import "QLHeisenbergSolver.h"
#include <math.h>

static NSError *QLHeisenbergError(NSString *message, NSInteger code) {
    return [NSError errorWithDomain:QuantumLabErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

typedef struct {
    double x;
    double p;
} QLOscillatorState;

typedef struct {
    double x;
    double y;
    double z;
} QLVector3;

@implementation QLHeisenbergSolver

+ (QLSimulationResult *)solveConfig:(QLSimulationConfig *)config
                           progress:(QLHeisenbergProgressCallback)progress
                              error:(NSError **)error {
    NSDate *startDate = [NSDate date];
    if (config.system == QLHeisenbergSystemSpin) {
        return [self solveSpinConfig:config progress:progress startDate:startDate error:error];
    }
    return [self solveOscillatorConfig:config progress:progress startDate:startDate error:error];
}

+ (QLVector3)fieldAtTime:(double)t config:(QLSimulationConfig *)config {
    double drive = config.driveAmp * cos(config.driveFreq * t + config.drivePhase * M_PI / 180.0);
    QLVector3 b = { config.bx, config.by, config.bz };
    if (config.driveAxis == 0) b.x += drive;
    else if (config.driveAxis == 1) b.y += drive;
    else b.z += drive;
    return b;
}

+ (QLVector3)spinDerivative:(QLVector3)s t:(double)t config:(QLSimulationConfig *)config {
    QLVector3 b = [self fieldAtTime:t config:config];
    QLVector3 d;
    d.x = config.gamma * (s.y * b.z - s.z * b.y);
    d.y = config.gamma * (s.z * b.x - s.x * b.z);
    d.z = config.gamma * (s.x * b.y - s.y * b.x);
    return d;
}

+ (QLSimulationResult *)solveSpinConfig:(QLSimulationConfig *)config
                               progress:(QLHeisenbergProgressCallback)progress
                              startDate:(NSDate *)startDate
                                  error:(NSError **)error {
    NSInteger frames = config.frames;
    NSInteger steps = config.steps;
    double dt = config.actualDt;
    NSInteger *frameSteps = calloc((size_t)frames, sizeof(NSInteger));
    if (!frameSteps) {
        if (error) *error = QLHeisenbergError(@"Not enough memory for the simulation.", 3);
        return nil;
    }
    for (NSInteger f = 0; f < frames; f++) {
        frameSteps[f] = (NSInteger)llround((double)f * (double)steps / (double)(frames - 1));
    }

    double theta = config.theta0 * M_PI / 180.0;
    double phi = config.phi0 * M_PI / 180.0;
    QLVector3 s = { sin(theta) * cos(phi), sin(theta) * sin(phi), cos(theta) };
    double t = 0.0;
    NSInteger nextFrame = 0;

    NSMutableArray<NSNumber *> *times = [NSMutableArray arrayWithCapacity:(NSUInteger)frames];
    NSMutableArray<NSNumber *> *sx = [NSMutableArray arrayWithCapacity:(NSUInteger)frames];
    NSMutableArray<NSNumber *> *sy = [NSMutableArray arrayWithCapacity:(NSUInteger)frames];
    NSMutableArray<NSNumber *> *sz = [NSMutableArray arrayWithCapacity:(NSUInteger)frames];
    NSMutableArray<NSNumber *> *magnitudes = [NSMutableArray arrayWithCapacity:(NSUInteger)frames];
    BOOL cancelled = NO;
    double maxMagnitudeError = 0.0;

    for (NSInteger step = 0; step <= steps; step++) {
        while (nextFrame < frames && frameSteps[nextFrame] == step) {
            [times addObject:@(t)];
            [sx addObject:@(s.x)];
            [sy addObject:@(s.y)];
            [sz addObject:@(s.z)];
            double mag = sqrt(s.x * s.x + s.y * s.y + s.z * s.z);
            [magnitudes addObject:@(mag)];
            maxMagnitudeError = MAX(maxMagnitudeError, fabs(mag - 1.0));
            nextFrame++;
        }
        if (step == steps) break;

        QLVector3 k1 = [self spinDerivative:s t:t config:config];
        QLVector3 s2 = { s.x + 0.5 * dt * k1.x, s.y + 0.5 * dt * k1.y, s.z + 0.5 * dt * k1.z };
        QLVector3 k2 = [self spinDerivative:s2 t:t + 0.5 * dt config:config];
        QLVector3 s3 = { s.x + 0.5 * dt * k2.x, s.y + 0.5 * dt * k2.y, s.z + 0.5 * dt * k2.z };
        QLVector3 k3 = [self spinDerivative:s3 t:t + 0.5 * dt config:config];
        QLVector3 s4 = { s.x + dt * k3.x, s.y + dt * k3.y, s.z + dt * k3.z };
        QLVector3 k4 = [self spinDerivative:s4 t:t + dt config:config];
        s.x += dt / 6.0 * (k1.x + 2.0 * k2.x + 2.0 * k3.x + k4.x);
        s.y += dt / 6.0 * (k1.y + 2.0 * k2.y + 2.0 * k3.y + k4.y);
        s.z += dt / 6.0 * (k1.z + 2.0 * k2.z + 2.0 * k3.z + k4.z);
        t += dt;

        if (progress && (step % MAX(1, steps / 100) == 0 || step == steps - 1)) {
            if (!progress((double)step / (double)steps)) {
                cancelled = YES;
                break;
            }
        }
    }
    free(frameSteps);

    if (cancelled) {
        if (error) *error = QLHeisenbergError(@"Simulation cancelled.", 2);
        return nil;
    }

    QLSimulationResult *result = [QLSimulationResult new];
    result.mode = QLSimulationModeHeisenberg;
    result.system = QLHeisenbergSystemSpin;
    result.plotKind = QLPlotKindSpinTimeSeries;
    result.frameCount = (NSInteger)times.count;
    result.times = times;
    result.dt = dt;
    result.tmax = config.tmax;
    result.solveDuration = -[startDate timeIntervalSinceNow];

    QLSeries *xSeries = [QLSeries new];
    xSeries.name = @"Sx";
    xSeries.color = [NSColor systemBlueColor];
    xSeries.xValues = times;
    xSeries.yValues = sx;
    xSeries.lineWidth = 1.8;

    QLSeries *ySeries = [QLSeries new];
    ySeries.name = @"Sy";
    ySeries.color = [NSColor systemGreenColor];
    ySeries.xValues = times;
    ySeries.yValues = sy;
    ySeries.lineWidth = 1.8;

    QLSeries *zSeries = [QLSeries new];
    zSeries.name = @"Sz";
    zSeries.color = [NSColor systemOrangeColor];
    zSeries.xValues = times;
    zSeries.yValues = sz;
    zSeries.lineWidth = 1.8;

    result.series = @[xSeries, ySeries, zSeries];
    result.normValues = magnitudes;

    NSMutableArray<NSString *> *warnings = [config.warnings mutableCopy] ?: [NSMutableArray array];
    if (maxMagnitudeError > 1e-4) {
        [warnings addObject:[NSString stringWithFormat:@"Bloch vector magnitude drifted by %.2e.", maxMagnitudeError]];
    }
    result.warnings = warnings;
    return result;
}

+ (QLOscillatorState)oscillatorDerivative:(QLOscillatorState)s config:(QLSimulationConfig *)config {
    QLOscillatorState d;
    d.x = s.p / config.mass;
    d.p = -config.mass * config.omega * config.omega * s.x - 2.0 * config.damping * s.p;
    return d;
}

+ (QLSimulationResult *)solveOscillatorConfig:(QLSimulationConfig *)config
                                     progress:(QLHeisenbergProgressCallback)progress
                                    startDate:(NSDate *)startDate
                                        error:(NSError **)error {
    NSInteger frames = config.frames;
    NSInteger steps = config.steps;
    double dt = config.actualDt;
    NSInteger *frameSteps = calloc((size_t)frames, sizeof(NSInteger));
    if (!frameSteps) {
        if (error) *error = QLHeisenbergError(@"Not enough memory for the simulation.", 3);
        return nil;
    }
    for (NSInteger f = 0; f < frames; f++) {
        frameSteps[f] = (NSInteger)llround((double)f * (double)steps / (double)(frames - 1));
    }

    QLOscillatorState state = { config.x0Osc, config.p0Osc };
    double t = 0.0;
    NSInteger nextFrame = 0;
    NSMutableArray<NSNumber *> *times = [NSMutableArray arrayWithCapacity:(NSUInteger)frames];
    NSMutableArray<NSNumber *> *xValues = [NSMutableArray arrayWithCapacity:(NSUInteger)frames];
    NSMutableArray<NSNumber *> *pValues = [NSMutableArray arrayWithCapacity:(NSUInteger)frames];
    NSMutableArray<NSNumber *> *energies = [NSMutableArray arrayWithCapacity:(NSUInteger)frames];
    BOOL cancelled = NO;

    for (NSInteger step = 0; step <= steps; step++) {
        while (nextFrame < frames && frameSteps[nextFrame] == step) {
            double energy = state.p * state.p / (2.0 * config.mass) +
                            0.5 * config.mass * config.omega * config.omega * state.x * state.x;
            [times addObject:@(t)];
            [xValues addObject:@(state.x)];
            [pValues addObject:@(state.p)];
            [energies addObject:@(energy)];
            nextFrame++;
        }
        if (step == steps) break;

        QLOscillatorState k1 = [self oscillatorDerivative:state config:config];
        QLOscillatorState s2 = { state.x + 0.5 * dt * k1.x, state.p + 0.5 * dt * k1.p };
        QLOscillatorState k2 = [self oscillatorDerivative:s2 config:config];
        QLOscillatorState s3 = { state.x + 0.5 * dt * k2.x, state.p + 0.5 * dt * k2.p };
        QLOscillatorState k3 = [self oscillatorDerivative:s3 config:config];
        QLOscillatorState s4 = { state.x + dt * k3.x, state.p + dt * k3.p };
        QLOscillatorState k4 = [self oscillatorDerivative:s4 config:config];
        state.x += dt / 6.0 * (k1.x + 2.0 * k2.x + 2.0 * k3.x + k4.x);
        state.p += dt / 6.0 * (k1.p + 2.0 * k2.p + 2.0 * k3.p + k4.p);
        t += dt;

        if (progress && (step % MAX(1, steps / 100) == 0 || step == steps - 1)) {
            if (!progress((double)step / (double)steps)) {
                cancelled = YES;
                break;
            }
        }
    }
    free(frameSteps);

    if (cancelled) {
        if (error) *error = QLHeisenbergError(@"Simulation cancelled.", 2);
        return nil;
    }

    QLSimulationResult *result = [QLSimulationResult new];
    result.mode = QLSimulationModeHeisenberg;
    result.system = QLHeisenbergSystemOscillator;
    result.plotKind = QLPlotKindOscillatorPhase;
    result.frameCount = (NSInteger)times.count;
    result.times = times;
    result.dt = dt;
    result.tmax = config.tmax;
    result.solveDuration = -[startDate timeIntervalSinceNow];

    QLSeries *xSeries = [QLSeries new];
    xSeries.name = @"x(t)";
    xSeries.color = [NSColor systemBlueColor];
    xSeries.xValues = times;
    xSeries.yValues = xValues;
    xSeries.lineWidth = 1.8;

    QLSeries *pSeries = [QLSeries new];
    pSeries.name = @"p(t)";
    pSeries.color = [NSColor systemOrangeColor];
    pSeries.xValues = times;
    pSeries.yValues = pValues;
    pSeries.lineWidth = 1.8;

    result.series = @[xSeries, pSeries];
    result.energyValues = energies;

    NSMutableArray<NSString *> *warnings = [config.warnings mutableCopy] ?: [NSMutableArray array];
    if (config.damping == 0 && energies.count > 1) {
        double e0 = energies.firstObject.doubleValue;
        double maxE = 0.0;
        for (NSNumber *e in energies) maxE = MAX(maxE, fabs(e.doubleValue - e0));
        if (e0 != 0 && maxE / fabs(e0) > 0.01) {
            [warnings addObject:@"Oscillator energy drift exceeds 1%; reduce Δt."];
        }
    }
    result.warnings = warnings;
    return result;
}

@end
