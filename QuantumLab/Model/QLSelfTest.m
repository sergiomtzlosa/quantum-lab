#import "QLSelfTest.h"
#import "QLFFT.h"
#import "QLParameterCatalog.h"
#import "QLParameterSet.h"
#import "QLSimulationConfig.h"
#import "QLSimulationResult.h"
#import "QLSchrodingerSolver.h"
#import "QLHeisenbergSolver.h"
#include <complex.h>
#include <math.h>

static int QLPassCount = 0;
static int QLFailCount = 0;

static void QLCheck(BOOL condition, NSString *name, NSString *detail) {
    if (condition) {
        QLPassCount++;
        printf("  PASS  %s\n", name.UTF8String);
    } else {
        QLFailCount++;
        printf("  FAIL  %s  (%s)\n", name.UTF8String, detail.UTF8String);
    }
}

static QLSimulationConfig *QLConfig(QLSimulationMode mode, NSInteger variant, NSDictionary<NSString *, id> *overrides) {
    QLParameterSet *params = [QLParameterCatalog defaultParametersForMode:mode variant:variant];
    for (NSString *key in overrides) {
        [params setValue:overrides[key] forKey:key];
    }
    NSError *error = nil;
    QLSimulationConfig *config = [QLSimulationConfig configFromParameters:params mode:mode variant:variant error:&error];
    if (!config) {
        printf("  ERROR building config: %s\n", error.localizedDescription.UTF8String);
    }
    return config;
}

static double QLMeanX(QLSimulationResult *result, NSInteger frame, double *secondMoment) {
    const double complex *psi = [result wavefunctionAtFrame:frame];
    if (!psi) return NAN;
    double dx = result.lx / (double)result.nx;
    double xmin = -result.lx * 0.5;
    double sum = 0.0;
    double sum2 = 0.0;
    double norm = 0.0;
    for (NSInteger i = 0; i < result.nx; i++) {
        double x = xmin + ((double)i + 0.5) * dx;
        double d = creal(psi[i] * conj(psi[i]));
        sum += x * d;
        sum2 += x * x * d;
        norm += d;
    }
    if (norm <= 0) return NAN;
    double mean = sum / norm;
    if (secondMoment) *secondMoment = sum2 / norm;
    return mean;
}

@implementation QLSelfTest

+ (BOOL)runAll {
    printf("QuantumLab self-test\n");
    printf("====================\n");

    // FFT round trip, 1D.
    {
        const size_t n = 128;
        double complex *data = calloc(n, sizeof(double complex));
        double complex *copy = calloc(n, sizeof(double complex));
        for (size_t i = 0; i < n; i++) {
            data[i] = cos(0.37 * (double)i) + I * sin(0.11 * (double)i);
            copy[i] = data[i];
        }
        QLFFTPlan *plan = QLFFTPlanCreate(n);
        QLFFTExecute(plan, data, NO);
        QLFFTExecute(plan, data, YES);
        double maxError = 0.0;
        for (size_t i = 0; i < n; i++) maxError = fmax(maxError, cabs(data[i] - copy[i]));
        QLCheck(maxError < 1e-10, @"FFT 1D round trip", [NSString stringWithFormat:@"max error %.3e", maxError]);
        QLFFTPlanDestroy(plan);
        free(data);
        free(copy);
    }

    // FFT round trip, 2D.
    {
        const size_t nx = 16, ny = 16;
        double complex *data = calloc(nx * ny, sizeof(double complex));
        double complex *copy = calloc(nx * ny, sizeof(double complex));
        double complex *scratch = calloc(ny, sizeof(double complex));
        for (size_t i = 0; i < nx * ny; i++) {
            data[i] = cos(0.21 * (double)i) + I * sin(0.17 * (double)i);
            copy[i] = data[i];
        }
        QLFFTPlan *rp = QLFFTPlanCreate(nx);
        QLFFTPlan *cp = QLFFTPlanCreate(ny);
        QLFFT2DExecute(rp, cp, data, nx, ny, NO, scratch);
        QLFFT2DExecute(rp, cp, data, nx, ny, YES, scratch);
        double maxError = 0.0;
        for (size_t i = 0; i < nx * ny; i++) maxError = fmax(maxError, cabs(data[i] - copy[i]));
        QLCheck(maxError < 1e-10, @"FFT 2D round trip", [NSString stringWithFormat:@"max error %.3e", maxError]);
        QLFFTPlanDestroy(rp);
        QLFFTPlanDestroy(cp);
        free(data);
        free(copy);
        free(scratch);
    }

    // 1D free packet: norm conservation and analytic spreading.
    {
        NSError *error = nil;
        QLSimulationConfig *config = QLConfig(QLSimulationModeSchrodinger, 0, @{});
        QLSimulationResult *result = [QLSchrodingerSolver solveConfig:config progress:nil error:&error];
        QLCheck(result != nil, @"Schrödinger 1D solve", error.localizedDescription ?: @"no result");
        if (result) {
            double maxNormError = 0.0;
            for (NSNumber *norm in result.normValues) {
                maxNormError = fmax(maxNormError, fabs(norm.doubleValue - 1.0));
            }
            QLCheck(maxNormError < 1e-8, @"Schrödinger 1D norm conservation",
                    [NSString stringWithFormat:@"max |N-1| = %.3e", maxNormError]);

            double second = 0.0;
            QLMeanX(result, result.frameCount - 1, &second);
            double mean = QLMeanX(result, result.frameCount - 1, NULL);
            double width = sqrt(fmax(0.0, second - mean * mean));
            double sigma0 = config.sigmaX;
            double expected = sigma0 * sqrt(1.0 + pow(config.hbar * result.tmax / (2.0 * config.mass * sigma0 * sigma0), 2.0));
            double relative = fabs(width - expected) / expected;
            QLCheck(relative < 0.02, @"Free packet spreading matches analytic width",
                    [NSString stringWithFormat:@"width %.4f vs %.4f", width, expected]);
        }
    }

    // 1D harmonic oscillator coherent state: <x> returns after one period.
    {
        NSError *error = nil;
        QLSimulationConfig *config = QLConfig(QLSimulationModeSchrodinger, 0, @{
            @"potential": @(QLPotentialTypeHarmonic),
            @"omega": @1.0,
            @"x0": @5.0,
            @"kx0": @0.0,
            @"sigmaX": @(1.0 / sqrt(2.0)),
            @"lx": @40.0,
            @"tmax": @(2.0 * M_PI),
            @"dt": @0.005,
            @"frames": @300
        });
        QLSimulationResult *result = [QLSchrodingerSolver solveConfig:config progress:nil error:&error];
        QLCheck(result != nil, @"Harmonic oscillator solve", error.localizedDescription ?: @"no result");
        if (result) {
            double mean = QLMeanX(result, result.frameCount - 1, NULL);
            QLCheck(fabs(mean - 5.0) < 0.15, @"Coherent state returns after one period",
                    [NSString stringWithFormat:@"<x> = %.4f, expected 5.0", mean]);
            // Half a period: <x> should be near -5.
            NSInteger half = (NSInteger)llround(0.5 * (result.frameCount - 1));
            double halfMean = QLMeanX(result, half, NULL);
            QLCheck(fabs(halfMean + 5.0) < 0.15, @"Coherent state inverts at half period",
                    [NSString stringWithFormat:@"<x> = %.4f, expected -5.0", halfMean]);
        }
    }

    // 2D norm conservation.
    {
        NSError *error = nil;
        QLSimulationConfig *config = QLConfig(QLSimulationModeSchrodinger, 1, @{
            @"nx": @64,
            @"ny": @64,
            @"lx": @20.0,
            @"ly": @20.0,
            @"x0": @(-4.0),
            @"sigmaX": @1.5,
            @"sigmaY": @1.5,
            @"kx0": @1.0,
            @"tmax": @1.0,
            @"dt": @0.005,
            @"frames": @100
        });
        QLSimulationResult *result = [QLSchrodingerSolver solveConfig:config progress:nil error:&error];
        QLCheck(result != nil, @"Schrödinger 2D solve", error.localizedDescription ?: @"no result");
        if (result) {
            double maxNormError = 0.0;
            for (NSNumber *norm in result.normValues) {
                maxNormError = fmax(maxNormError, fabs(norm.doubleValue - 1.0));
            }
            QLCheck(maxNormError < 1e-7, @"Schrödinger 2D norm conservation",
                    [NSString stringWithFormat:@"max |N-1| = %.3e", maxNormError]);
            QLCheck(result.globalDensityMax > 0.0, @"2D density is non-zero",
                    [NSString stringWithFormat:@"max %.3e", result.globalDensityMax]);
        }
    }

    // Heisenberg spin: one Larmor period returns to the initial vector.
    {
        NSError *error = nil;
        QLSimulationConfig *config = QLConfig(QLSimulationModeHeisenberg, 0, @{
            @"bx": @0.0,
            @"by": @0.0,
            @"bz": @1.0,
            @"gamma": @1.0,
            @"theta0": @90.0,
            @"phi0": @0.0,
            @"tmax": @(2.0 * M_PI),
            @"dt": @0.001,
            @"frames": @400,
            @"driveAmp": @0.0
        });
        QLSimulationResult *result = [QLHeisenbergSolver solveConfig:config progress:nil error:&error];
        QLCheck(result != nil, @"Heisenberg spin solve", error.localizedDescription ?: @"no result");
        if (result) {
            QLSeries *sx = [result seriesNamed:@"Sx"];
            QLSeries *sy = [result seriesNamed:@"Sy"];
            QLSeries *sz = [result seriesNamed:@"Sz"];
            double dx = sx.yValues.lastObject.doubleValue - 1.0;
            double dy = sy.yValues.lastObject.doubleValue - 0.0;
            double dz = sz.yValues.lastObject.doubleValue - 0.0;
            double err = sqrt(dx * dx + dy * dy + dz * dz);
            QLCheck(err < 1e-3, @"Spin returns after one Larmor period",
                    [NSString stringWithFormat:@"endpoint error %.3e", err]);
            double maxMagError = 0.0;
            for (NSNumber *mag in result.normValues) {
                maxMagError = fmax(maxMagError, fabs(mag.doubleValue - 1.0));
            }
            QLCheck(maxMagError < 1e-8, @"Bloch vector magnitude conserved",
                    [NSString stringWithFormat:@"max |S|-1 = %.3e", maxMagError]);
        }
    }

    // Heisenberg oscillator energy conservation.
    {
        NSError *error = nil;
        QLSimulationConfig *config = QLConfig(QLSimulationModeHeisenberg, 1, @{
            @"tmax": @20.0,
            @"dt": @0.002,
            @"frames": @400
        });
        QLSimulationResult *result = [QLHeisenbergSolver solveConfig:config progress:nil error:&error];
        QLCheck(result != nil, @"Heisenberg oscillator solve", error.localizedDescription ?: @"no result");
        if (result && result.energyValues.count > 1) {
            double e0 = result.energyValues.firstObject.doubleValue;
            double maxError = 0.0;
            for (NSNumber *e in result.energyValues) {
                maxError = fmax(maxError, fabs(e.doubleValue - e0));
            }
            double relative = e0 == 0 ? maxError : maxError / fabs(e0);
            QLCheck(relative < 1e-8, @"Oscillator energy conserved",
                    [NSString stringWithFormat:@"relative drift %.3e", relative]);
        }
    }

    printf("--------------------\n");
    printf("%d passed, %d failed\n", QLPassCount, QLFailCount);
    return QLFailCount == 0;
}

@end
