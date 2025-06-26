#import "QLSimulationConfig.h"
#import "QLParameterCatalog.h"

NSString *const QuantumLabErrorDomain = @"QuantumLabErrorDomain";

static NSError *QLError(NSString *message, NSString *suggestion) {
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[NSLocalizedDescriptionKey] = message;
    if (suggestion.length > 0) {
        info[NSLocalizedRecoverySuggestionErrorKey] = suggestion;
    }
    return [NSError errorWithDomain:QuantumLabErrorDomain code:1 userInfo:info];
}

@implementation QLSimulationConfig

+ (instancetype)configFromParameters:(QLParameterSet *)parameters
                                mode:(QLSimulationMode)mode
                             variant:(NSInteger)variant
                               error:(NSError **)error {
    QLSimulationConfig *c = [QLSimulationConfig new];
    c.mode = mode;
    c.variant = variant;
    NSMutableArray<NSString *> *warnings = [NSMutableArray array];

    if (mode == QLSimulationModeSchrodinger) {
        c.dimension = (variant == 1) ? QLSchrodingerDimension2D : QLSchrodingerDimension1D;
        BOOL is2D = (c.dimension == QLSchrodingerDimension2D);
        c.potential = (QLPotentialType)[parameters integerForKey:@"potential"];
        c.nx = [parameters integerForKey:@"nx"];
        c.ny = is2D ? [parameters integerForKey:@"ny"] : 1;
        c.lx = [parameters doubleForKey:@"lx"];
        c.ly = is2D ? [parameters doubleForKey:@"ly"] : 1.0;
        c.hbar = [parameters doubleForKey:@"hbar"];
        c.mass = [parameters doubleForKey:@"mass"];
        c.dt = [parameters doubleForKey:@"dt"];
        c.tmax = [parameters doubleForKey:@"tmax"];
        c.frames = (NSInteger)[parameters integerForKey:@"frames"];
        c.x0 = [parameters doubleForKey:@"x0"];
        c.y0 = is2D ? [parameters doubleForKey:@"y0"] : 0.0;
        c.sigmaX = [parameters doubleForKey:@"sigmaX"];
        c.sigmaY = is2D ? [parameters doubleForKey:@"sigmaY"] : c.sigmaX;
        c.kx0 = [parameters doubleForKey:@"kx0"];
        c.ky0 = is2D ? [parameters doubleForKey:@"ky0"] : 0.0;
        c.vortex = is2D ? [parameters integerForKey:@"vortex"] : 0;
        c.v0 = [parameters doubleForKey:@"v0"];
        c.omega = [parameters doubleForKey:@"omega"];
        c.barrierX = [parameters doubleForKey:@"barrierX"];
        c.barrierWidth = [parameters doubleForKey:@"barrierWidth"];
        c.barrierSeparation = [parameters doubleForKey:@"barrierSeparation"];
        c.wallThickness = [parameters doubleForKey:@"wallThickness"];
        c.slitSeparation = [parameters doubleForKey:@"slitSeparation"];
        c.slitWidth = [parameters doubleForKey:@"slitWidth"];
        c.wellRadius = [parameters doubleForKey:@"wellRadius"];
        c.latticePeriod = [parameters doubleForKey:@"latticePeriod"];
        c.field = [parameters doubleForKey:@"field"];
        c.absWidth = [parameters doubleForKey:@"absWidth"];
        c.absStrength = [parameters doubleForKey:@"absStrength"];
        c.renormalize = [parameters boolForKey:@"renormalize"];
        c.storePhase = is2D && [parameters boolForKey:@"storePhase"];

        if (!QLIsPowerOfTwo(c.nx) || c.nx < 32 || c.nx > 2048) {
            if (error) *error = QLError(@"Grid points X must be a power of two between 32 and 2048.",
                                        @"Use 128, 256, or 512 for typical simulations.");
            return nil;
        }
        if (is2D && (!QLIsPowerOfTwo(c.ny) || c.ny < 32 || c.ny > 2048)) {
            if (error) *error = QLError(@"Grid points Y must be a power of two between 32 and 2048.",
                                        @"Use 128, 256, or 512 for typical simulations.");
            return nil;
        }
        if (c.lx <= 0 || (is2D && c.ly <= 0)) {
            if (error) *error = QLError(@"Domain widths must be positive.", nil);
            return nil;
        }
        if (c.hbar <= 0 || c.mass <= 0) {
            if (error) *error = QLError(@"ħ and mass must be positive.", nil);
            return nil;
        }
        if (c.dt <= 0 || c.tmax <= 0) {
            if (error) *error = QLError(@"Time step and end time must be positive.", nil);
            return nil;
        }
        if (c.sigmaX <= 0 || c.sigmaY <= 0) {
            if (error) *error = QLError(@"Packet widths must be positive.", nil);
            return nil;
        }
        if (c.frames < 2) {
            if (error) *error = QLError(@"At least two output frames are required.", nil);
            return nil;
        }

        double rawSteps = c.tmax / c.dt;
        if (rawSteps < 1.0) {
            if (error) *error = QLError(@"End time must be at least one time step.", nil);
            return nil;
        }
        if (rawSteps > 2000000.0) {
            if (error) *error = QLError(@"The simulation would require more than 2,000,000 internal steps.",
                                        @"Increase Δt or reduce the end time.");
            return nil;
        }
        c.steps = (NSInteger)llround(rawSteps);
        if (c.steps < 1) c.steps = 1;
        c.actualDt = c.tmax / (double)c.steps;
        NSInteger maxFrames = c.steps + 1;
        if (c.frames > maxFrames) {
            c.frames = maxFrames;
            [warnings addObject:@"Output frame count was reduced to one per internal step."];
        }
        if (is2D && c.frames > 800) {
            if (error) *error = QLError(@"2D simulations are limited to 800 output frames.",
                                        @"Reduce the frame count or use a 1D simulation.");
            return nil;
        }

        NSUInteger bytes = 0;
        if (is2D) {
            bytes = (NSUInteger)c.nx * (NSUInteger)c.ny * 4u * (NSUInteger)c.frames;
            if (c.storePhase) {
                bytes += (NSUInteger)c.nx * (NSUInteger)c.ny * 4u * (NSUInteger)c.frames;
            }
            if (bytes > 1500000000ull) {
                if (error) *error = QLError(@"The requested 2D output would exceed 1.5 GB.",
                                            @"Reduce the grid size, frame count, or turn off phase storage.");
                return nil;
            }
            if (bytes > 512000000ull) {
                [warnings addObject:[NSString stringWithFormat:@"Large output: approximately %.0f MB. The solve may take a while.",
                                     bytes / 1000000.0]];
            }
        } else {
            bytes = (NSUInteger)c.nx * sizeof(double complex) * (NSUInteger)c.frames;
        }
        c.estimatedBytes = bytes;

        double halfX = c.lx * 0.5;
        double halfY = c.ly * 0.5;
        if (fabs(c.x0) + 4.0 * c.sigmaX > halfX) {
            [warnings addObject:@"The initial packet may extend beyond the X domain."];
        }
        if (is2D && fabs(c.y0) + 4.0 * c.sigmaY > halfY) {
            [warnings addObject:@"The initial packet may extend beyond the Y domain."];
        }
        if (c.absWidth >= halfX || (is2D && c.absWidth >= halfY)) {
            [warnings addObject:@"The absorbing boundary is wider than half the domain."];
        }
        if (c.absWidth < 0) {
            if (error) *error = QLError(@"Absorbing width cannot be negative.", nil);
            return nil;
        }
        if (c.absWidth > 0 && c.absStrength <= 0) {
            if (error) *error = QLError(@"Absorbing strength must be positive when absorption is enabled.", nil);
            return nil;
        }
        if (c.potential == QLPotentialTypeHarmonic && c.omega <= 0) {
            if (error) *error = QLError(@"Trap frequency must be positive.", nil);
            return nil;
        }
        if (c.potential == QLPotentialTypeLattice && c.latticePeriod <= 0) {
            if (error) *error = QLError(@"Lattice period must be positive.", nil);
            return nil;
        }
        if (c.potential == QLPotentialTypeBarrier && c.barrierWidth <= 0) {
            if (error) *error = QLError(@"Barrier width must be positive.", nil);
            return nil;
        }
    } else {
        c.system = (variant == 1) ? QLHeisenbergSystemOscillator : QLHeisenbergSystemSpin;
        c.dt = [parameters doubleForKey:@"dt"];
        c.tmax = [parameters doubleForKey:@"tmax"];
        c.frames = (NSInteger)[parameters integerForKey:@"frames"];
        c.hbar = 1.0;
        c.mass = [parameters doubleForKey:@"mass"];
        c.omega = [parameters doubleForKey:@"omega"];
        c.x0Osc = [parameters doubleForKey:@"x0"];
        c.p0Osc = [parameters doubleForKey:@"p0"];
        c.damping = [parameters doubleForKey:@"damping"];
        c.gamma = [parameters doubleForKey:@"gamma"];
        c.bx = [parameters doubleForKey:@"bx"];
        c.by = [parameters doubleForKey:@"by"];
        c.bz = [parameters doubleForKey:@"bz"];
        c.driveAmp = [parameters doubleForKey:@"driveAmp"];
        c.driveFreq = [parameters doubleForKey:@"driveFreq"];
        c.drivePhase = [parameters doubleForKey:@"drivePhase"];
        c.driveAxis = [parameters integerForKey:@"driveAxis"];
        c.theta0 = [parameters doubleForKey:@"theta0"];
        c.phi0 = [parameters doubleForKey:@"phi0"];

        if (c.dt <= 0 || c.tmax <= 0) {
            if (error) *error = QLError(@"Time step and end time must be positive.", nil);
            return nil;
        }
        if (c.frames < 2) {
            if (error) *error = QLError(@"At least two output frames are required.", nil);
            return nil;
        }
        double rawSteps = c.tmax / c.dt;
        if (rawSteps < 1.0) {
            if (error) *error = QLError(@"End time must be at least one time step.", nil);
            return nil;
        }
        if (rawSteps > 2000000.0) {
            if (error) *error = QLError(@"The simulation would require more than 2,000,000 internal steps.",
                                        @"Increase Δt or reduce the end time.");
            return nil;
        }
        c.steps = (NSInteger)llround(rawSteps);
        if (c.steps < 1) c.steps = 1;
        c.actualDt = c.tmax / (double)c.steps;
        if (c.frames > c.steps + 1) {
            c.frames = c.steps + 1;
            [warnings addObject:@"Output frame count was reduced to one per internal step."];
        }
        if (c.frames > 2000) {
            if (error) *error = QLError(@"At most 2000 output frames are allowed.", nil);
            return nil;
        }
        c.estimatedBytes = (NSUInteger)c.frames * 4u * sizeof(double);

        if (c.system == QLHeisenbergSystemSpin) {
            if (c.driveAmp > 0 && c.driveFreq <= 0) {
                if (error) *error = QLError(@"Drive frequency must be positive.", nil);
                return nil;
            }
        } else {
            if (c.mass <= 0) {
                if (error) *error = QLError(@"Oscillator mass must be positive.", nil);
                return nil;
            }
            if (c.omega <= 0) {
                if (error) *error = QLError(@"Oscillator frequency must be positive.", nil);
                return nil;
            }
            if (c.damping < 0) {
                if (error) *error = QLError(@"Damping rate cannot be negative.", nil);
                return nil;
            }
        }
    }

    c.warnings = warnings;
    return c;
}

- (NSString *)summaryString {
    if (self.mode == QLSimulationModeSchrodinger) {
        return [NSString stringWithFormat:@"Schrödinger %@ · %@ · %ld×%ld · %ld steps",
                self.dimension == QLSchrodingerDimension2D ? @"2D" : @"1D",
                [QLParameterCatalog potentialNameForType:self.potential],
                (long)self.nx, (long)self.ny, (long)self.steps];
    }
    return [NSString stringWithFormat:@"Heisenberg · %@ · %ld steps",
            self.system == QLHeisenbergSystemSpin ? @"Spin-1/2" : @"Harmonic oscillator",
            (long)self.steps];
}

@end
