#import "QLSchrodingerSolver.h"
#import "QLFFT.h"
#import "QLPotential.h"
#import "QLParameterCatalog.h"
#include <complex.h>
#include <math.h>
#include <stdlib.h>

static NSError *QLSolveError(NSString *message, NSInteger code) {
    return [NSError errorWithDomain:QuantumLabErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

@implementation QLSchrodingerSolver

+ (QLSimulationResult *)solveConfig:(QLSimulationConfig *)config
                           progress:(QLProgressCallback)progress
                              error:(NSError **)error {
    NSDate *startDate = [NSDate date];
    BOOL is2D = (config.dimension == QLSchrodingerDimension2D);
    NSInteger nx = config.nx;
    NSInteger ny = is2D ? config.ny : 1;
    NSInteger count = nx * ny;
    double dx = config.lx / (double)nx;
    double dy = is2D ? config.ly / (double)ny : 1.0;
    double cellVolume = dx * (is2D ? dy : 1.0);
    double xmin = -config.lx * 0.5;
    double ymin = is2D ? -config.ly * 0.5 : 0.0;

    double *potential = calloc((size_t)count, sizeof(double));
    double *mask = calloc((size_t)count, sizeof(double));
    double complex *psi = calloc((size_t)count, sizeof(double complex));
    double complex *kinetic = calloc((size_t)count, sizeof(double complex));
    double complex *potentialPhase = calloc((size_t)count, sizeof(double complex));
    double *kx = calloc((size_t)nx, sizeof(double));
    double *ky = calloc((size_t)MAX(ny, 1), sizeof(double));
    double complex *scratch = calloc((size_t)MAX(nx, ny), sizeof(double complex));
    NSInteger *frameSteps = calloc((size_t)config.frames, sizeof(NSInteger));
    if (!potential || !mask || !psi || !kinetic || !potentialPhase || !kx || !ky || !scratch || !frameSteps) {
        free(potential); free(mask); free(psi); free(kinetic); free(potentialPhase);
        free(kx); free(ky); free(scratch); free(frameSteps);
        if (error) *error = QLSolveError(@"Not enough memory for the simulation grid.", 3);
        return nil;
    }

    double vmaxAbs = 0.0;
    for (NSInteger j = 0; j < ny; j++) {
        double y = is2D ? ymin + ((double)j + 0.5) * dy : 0.0;
        for (NSInteger i = 0; i < nx; i++) {
            double x = xmin + ((double)i + 0.5) * dx;
            double v = QLPotentialValue(config.potential, x, y, config, is2D);
            potential[j * nx + i] = v;
            if (fabs(v) > vmaxAbs) vmaxAbs = fabs(v);
        }
    }
    config.maxPotential = vmaxAbs;

    // Frequencies.
    for (NSInteger i = 0; i < nx; i++) {
        NSInteger signedIndex = (i < nx / 2) ? i : (i - nx);
        kx[i] = 2.0 * M_PI * (double)signedIndex / config.lx;
    }
    if (is2D) {
        for (NSInteger j = 0; j < ny; j++) {
            NSInteger signedIndex = (j < ny / 2) ? j : (j - ny);
            ky[j] = 2.0 * M_PI * (double)signedIndex / config.ly;
        }
    }

    double kineticPrefactor = -config.hbar * config.actualDt / (2.0 * config.mass);
    for (NSInteger j = 0; j < ny; j++) {
        double kyj = is2D ? ky[j] : 0.0;
        for (NSInteger i = 0; i < nx; i++) {
            double k2 = kx[i] * kx[i] + kyj * kyj;
            kinetic[j * nx + i] = cexp(I * kineticPrefactor * k2);
            potentialPhase[j * nx + i] = cexp(-I * potential[j * nx + i] * config.actualDt / (2.0 * config.hbar));
        }
    }

    // Absorbing mask. Initialized to 1.
    for (NSInteger i = 0; i < count; i++) mask[i] = 1.0;
    if (config.absWidth > 0) {
        for (NSInteger j = 0; j < ny; j++) {
            double y = is2D ? ymin + ((double)j + 0.5) * dy : 0.0;
            for (NSInteger i = 0; i < nx; i++) {
                double x = xmin + ((double)i + 0.5) * dx;
                double edgeX = fmin(x - xmin, config.lx * 0.5 - x);
                double dist = edgeX;
                if (is2D) {
                    double edgeY = fmin(y - ymin, config.ly * 0.5 - y);
                    dist = fmin(edgeX, edgeY);
                }
                if (dist < config.absWidth) {
                    double t = (config.absWidth - dist) / config.absWidth;
                    double W = config.absStrength * t * t;
                    mask[j * nx + i] = exp(-W * config.actualDt / config.hbar);
                }
            }
        }
    }

    // Initial Gaussian packet.
    for (NSInteger j = 0; j < ny; j++) {
        double y = is2D ? ymin + ((double)j + 0.5) * dy : 0.0;
        for (NSInteger i = 0; i < nx; i++) {
            double x = xmin + ((double)i + 0.5) * dx;
            double dx0 = x - config.x0;
            double dy0 = is2D ? (y - config.y0) : 0.0;
            double envelope = exp(-(dx0 * dx0) / (4.0 * config.sigmaX * config.sigmaX));
            if (is2D) {
                envelope *= exp(-(dy0 * dy0) / (4.0 * config.sigmaY * config.sigmaY));
            }
            double phase = config.kx0 * x + (is2D ? config.ky0 * y : 0.0);
            double complex value = envelope * cexp(I * phase);
            if (is2D && config.vortex != 0) {
                double theta = atan2(dy0, dx0);
                value *= cexp(I * (double)config.vortex * theta);
            }
            psi[j * nx + i] = value;
        }
    }

    // Normalize.
    double normSum = 0.0;
    for (NSInteger i = 0; i < count; i++) normSum += creal(psi[i] * conj(psi[i]));
    double norm = normSum * cellVolume;
    if (!(norm > 0.0) || !isfinite(norm)) {
        free(potential); free(mask); free(psi); free(kinetic); free(potentialPhase);
        free(kx); free(ky); free(scratch); free(frameSteps);
        if (error) *error = QLSolveError(@"The initial wavefunction could not be normalized.", 4);
        return nil;
    }
    double initialScale = 1.0 / sqrt(norm);
    for (NSInteger i = 0; i < count; i++) psi[i] *= initialScale;

    // FFT plans.
    QLFFTPlan *rowPlan = QLFFTPlanCreate((size_t)nx);
    QLFFTPlan *colPlan = is2D ? QLFFTPlanCreate((size_t)ny) : NULL;
    if (!rowPlan || (is2D && !colPlan)) {
        QLFFTPlanDestroy(rowPlan);
        QLFFTPlanDestroy(colPlan);
        free(potential); free(mask); free(psi); free(kinetic); free(potentialPhase);
        free(kx); free(ky); free(scratch); free(frameSteps);
        if (error) *error = QLSolveError(@"Could not create FFT plans. Grid sizes must be powers of two.", 5);
        return nil;
    }

    // Uniformly spaced output frames.
    for (NSInteger f = 0; f < config.frames; f++) {
        NSInteger s = (NSInteger)llround((double)f * (double)config.steps / (double)(config.frames - 1));
        if (s < 0) s = 0;
        if (s > config.steps) s = config.steps;
        frameSteps[f] = s;
    }

    NSMutableArray<NSData *> *frames = [NSMutableArray arrayWithCapacity:(NSUInteger)config.frames];
    NSMutableArray<NSData *> *phaseFrames = [NSMutableArray arrayWithCapacity:(NSUInteger)config.frames];
    NSMutableArray<NSNumber *> *normValues = [NSMutableArray arrayWithCapacity:(NSUInteger)config.frames];
    double globalDensityMax = 0.0;
    double minDensity = INFINITY;
    double maxDensity = 0.0;
    NSInteger nextFrame = 0;
    BOOL cancelled = NO;

    for (NSInteger step = 0; step <= config.steps; step++) {
        while (nextFrame < config.frames && frameSteps[nextFrame] == step) {
            if (is2D) {
                NSMutableData *densityData = [NSMutableData dataWithLength:(NSUInteger)count * sizeof(float)];
                float *density = densityData.mutableBytes;
                NSMutableData *phaseData = config.storePhase
                    ? [NSMutableData dataWithLength:(NSUInteger)count * sizeof(float)] : nil;
                float *phase = phaseData.mutableBytes;
                double densitySum = 0.0;
                for (NSInteger i = 0; i < count; i++) {
                    double d = creal(psi[i] * conj(psi[i]));
                    if (d < 0.0) d = 0.0;
                    density[i] = (float)d;
                    densitySum += d;
                    if (d > globalDensityMax) globalDensityMax = d;
                    if (d < minDensity) minDensity = d;
                    if (d > maxDensity) maxDensity = d;
                    if (phase) phase[i] = (float)carg(psi[i]);
                }
                [frames addObject:densityData];
                if (phaseData) [phaseFrames addObject:phaseData];
                [normValues addObject:@(densitySum * cellVolume)];
            } else {
                NSData *data = [NSData dataWithBytes:psi length:(NSUInteger)count * sizeof(double complex)];
                [frames addObject:data];
                double densityMaxFrame = 0.0;
                double densitySum = 0.0;
                for (NSInteger i = 0; i < count; i++) {
                    double d = creal(psi[i] * conj(psi[i]));
                    densitySum += d;
                    if (d > densityMaxFrame) densityMaxFrame = d;
                }
                if (densityMaxFrame > globalDensityMax) globalDensityMax = densityMaxFrame;
                if (densityMaxFrame > maxDensity) maxDensity = densityMaxFrame;
                [normValues addObject:@(densitySum * cellVolume)];
            }
            nextFrame++;
        }

        if (step == config.steps) break;

        for (NSInteger i = 0; i < count; i++) psi[i] *= potentialPhase[i];
        if (is2D) {
            QLFFT2DExecute(rowPlan, colPlan, psi, (size_t)nx, (size_t)ny, NO, scratch);
            for (NSInteger i = 0; i < count; i++) psi[i] *= kinetic[i];
            QLFFT2DExecute(rowPlan, colPlan, psi, (size_t)nx, (size_t)ny, YES, scratch);
        } else {
            QLFFTExecute(rowPlan, psi, NO);
            for (NSInteger i = 0; i < count; i++) psi[i] *= kinetic[i];
            QLFFTExecute(rowPlan, psi, YES);
        }
        for (NSInteger i = 0; i < count; i++) {
            psi[i] *= potentialPhase[i];
            psi[i] *= mask[i];
        }

        if (config.renormalize) {
            double sum = 0.0;
            for (NSInteger i = 0; i < count; i++) sum += creal(psi[i] * conj(psi[i]));
            double n = sum * cellVolume;
            if (n > 0.0) {
                double scale = 1.0 / sqrt(n);
                for (NSInteger i = 0; i < count; i++) psi[i] *= scale;
            }
        }

        if (progress && (step % MAX(1, config.steps / 100) == 0 || step == config.steps - 1)) {
            if (!progress((double)step / (double)config.steps)) {
                cancelled = YES;
                break;
            }
        }
    }

    QLFFTPlanDestroy(rowPlan);
    QLFFTPlanDestroy(colPlan);

    if (cancelled) {
        free(potential); free(mask); free(psi); free(kinetic); free(potentialPhase);
        free(kx); free(ky); free(scratch); free(frameSteps);
        if (error) *error = QLSolveError(@"Simulation cancelled.", 2);
        return nil;
    }

    QLSimulationResult *result = [QLSimulationResult new];
    result.mode = QLSimulationModeSchrodinger;
    result.dimension = config.dimension;
    result.potential = config.potential;
    result.plotKind = is2D ? QLPlotKindDensityHeatmap2D : QLPlotKindWavefunction1D;
    result.nx = nx;
    result.ny = ny;
    result.frameCount = (NSInteger)frames.count;
    result.lx = config.lx;
    result.ly = is2D ? config.ly : 0.0;
    result.hbar = config.hbar;
    result.mass = config.mass;
    result.dt = config.actualDt;
    result.tmax = config.tmax;
    result.storePhase = config.storePhase;
    result.hasPhase = phaseFrames.count > 0;
    result.frames = frames;
    result.phaseFrames = phaseFrames;
    result.normValues = normValues;
    result.globalDensityMax = MAX(globalDensityMax, 1e-12);
    result.minDensity = isfinite(minDensity) ? minDensity : 0.0;
    result.maxDensity = maxDensity;
    result.estimatedBytes = config.estimatedBytes;
    result.solveDuration = -[startDate timeIntervalSinceNow];

    NSMutableArray<NSNumber *> *times = [NSMutableArray arrayWithCapacity:(NSUInteger)result.frameCount];
    for (NSInteger f = 0; f < result.frameCount; f++) {
        [times addObject:@(config.tmax * (double)f / (double)MAX(1, result.frameCount - 1))];
    }
    result.times = times;

    if (!is2D) {
        NSMutableArray<NSNumber *> *px = [NSMutableArray arrayWithCapacity:(NSUInteger)nx];
        NSMutableArray<NSNumber *> *pv = [NSMutableArray arrayWithCapacity:(NSUInteger)nx];
        for (NSInteger i = 0; i < nx; i++) {
            [px addObject:@(xmin + ((double)i + 0.5) * dx)];
            [pv addObject:@(potential[i])];
        }
        result.potentialX = px;
        result.potentialV = pv;
    }

    NSMutableArray<NSString *> *warnings = [config.warnings mutableCopy] ?: [NSMutableArray array];
    double kmax2 = 0.0;
    for (NSInteger i = 0; i < nx; i++) kmax2 = MAX(kmax2, kx[i] * kx[i]);
    if (is2D) {
        for (NSInteger j = 0; j < ny; j++) kmax2 = MAX(kmax2, ky[j] * ky[j] + kx[nx / 2] * kx[nx / 2]);
    }
    double phaseMax = (config.hbar * kmax2 / (2.0 * config.mass) + vmaxAbs) * config.actualDt / config.hbar;
    if (phaseMax > M_PI) {
        [warnings addObject:[NSString stringWithFormat:@"Max phase per step is %.2fπ; reduce Δt for accuracy.", phaseMax / M_PI]];
    } else if (phaseMax > 0.5) {
        [warnings addObject:[NSString stringWithFormat:@"Max phase per step is %.2f rad; consider a smaller Δt.", phaseMax]];
    }
    result.warnings = warnings;

    free(potential); free(mask); free(psi); free(kinetic); free(potentialPhase);
    free(kx); free(ky); free(scratch); free(frameSteps);
    return result;
}

@end
