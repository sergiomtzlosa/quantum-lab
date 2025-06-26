#import "QLParameterCatalog.h"
#include <math.h>

@implementation QLParameterCatalog

+ (NSArray<QLParameterDefinition *> *)definitionsForMode:(QLSimulationMode)mode
                                                 variant:(NSInteger)variant {
    if (mode == QLSimulationModeSchrodinger) {
        return [self schrodingerDefinitionsForDimension:variant];
    }
    return [self heisenbergDefinitionsForSystem:variant];
}

+ (NSArray<QLParameterDefinition *> *)schrodingerDefinitionsForDimension:(NSInteger)dimension {
    BOOL is2D = (dimension == QLSchrodingerDimension2D);
    NSMutableArray<QLParameterDefinition *> *defs = [NSMutableArray array];

    [defs addObject:[QLParameterDefinition enumWithKey:@"potential"
                                                  label:@"Potential"
                                                  group:@"Grid"
                                           defaultValue:0
                                                  labels:(is2D
                                                          ? @[@"Free", @"Harmonic", @"Double Slit", @"Circular Well", @"Periodic Lattice"]
                                                          : @[@"Free", @"Harmonic", @"Barrier", @"Double Barrier", @"Linear Field", @"Periodic Lattice"])
                                                  values:(is2D
                                                          ? @[@0, @1, @6, @7, @5]
                                                          : @[@0, @1, @2, @3, @4, @5])]];

    [defs addObject:[QLParameterDefinition integerWithKey:@"nx" label:@"Grid points X" unit:@"" group:@"Grid"
                                             defaultValue:(is2D ? 128 : 512) min:32 max:2048]];
    [defs addObject:[[QLParameterDefinition integerWithKey:@"ny" label:@"Grid points Y" unit:@"" group:@"Grid"
                                              defaultValue:128 min:32 max:2048]
                     visibleForKey:@"dimension" values:@[@(QLSchrodingerDimension2D)]]];
    [defs addObject:[QLParameterDefinition doubleWithKey:@"lx" label:@"Domain width X" unit:@"" group:@"Grid"
                                            defaultValue:(is2D ? 40.0 : 60.0) min:1.0 max:10000.0]];
    [defs addObject:[[QLParameterDefinition doubleWithKey:@"ly" label:@"Domain width Y" unit:@"" group:@"Grid"
                                             defaultValue:40.0 min:1.0 max:10000.0]
                     visibleForKey:@"dimension" values:@[@(QLSchrodingerDimension2D)]]];
    [defs addObject:[QLParameterDefinition doubleWithKey:@"hbar" label:@"ħ" unit:@"" group:@"Grid"
                                            defaultValue:1.0 min:1e-9 max:1e9]];
    [defs addObject:[QLParameterDefinition doubleWithKey:@"mass" label:@"Mass m" unit:@"" group:@"Grid"
                                            defaultValue:1.0 min:1e-9 max:1e9]];

    [defs addObject:[QLParameterDefinition doubleWithKey:@"dt" label:@"Time step Δt" unit:@"" group:@"Time"
                                            defaultValue:(is2D ? 0.002 : 0.005) min:1e-9 max:10.0]];
    [defs addObject:[QLParameterDefinition doubleWithKey:@"tmax" label:@"End time" unit:@"" group:@"Time"
                                            defaultValue:(is2D ? 4.0 : 6.0) min:1e-6 max:10000.0]];
    [defs addObject:[QLParameterDefinition integerWithKey:@"frames" label:@"Output frames" unit:@"" group:@"Time"
                                             defaultValue:(is2D ? 200 : 240) min:2 max:2000]];

    [defs addObject:[QLParameterDefinition doubleWithKey:@"x0" label:@"Initial center x₀" unit:@"" group:@"Initial State"
                                            defaultValue:(is2D ? -8.0 : -12.0) min:-100000.0 max:100000.0]];
    [defs addObject:[[QLParameterDefinition doubleWithKey:@"y0" label:@"Initial center y₀" unit:@"" group:@"Initial State"
                                             defaultValue:0.0 min:-100000.0 max:100000.0]
                     visibleForKey:@"dimension" values:@[@(QLSchrodingerDimension2D)]]];
    [defs addObject:[QLParameterDefinition doubleWithKey:@"sigmaX" label:@"Packet width σx" unit:@"" group:@"Initial State"
                                            defaultValue:(is2D ? 2.0 : 1.5) min:1e-6 max:100000.0]];
    [defs addObject:[[QLParameterDefinition doubleWithKey:@"sigmaY" label:@"Packet width σy" unit:@"" group:@"Initial State"
                                             defaultValue:2.0 min:1e-6 max:100000.0]
                     visibleForKey:@"dimension" values:@[@(QLSchrodingerDimension2D)]]];
    [defs addObject:[QLParameterDefinition doubleWithKey:@"kx0" label:@"Initial momentum kx₀" unit:@"" group:@"Initial State"
                                            defaultValue:2.0 min:-100000.0 max:100000.0]];
    [defs addObject:[[QLParameterDefinition doubleWithKey:@"ky0" label:@"Initial momentum ky₀" unit:@"" group:@"Initial State"
                                             defaultValue:0.0 min:-100000.0 max:100000.0]
                     visibleForKey:@"dimension" values:@[@(QLSchrodingerDimension2D)]]];
    [defs addObject:[[QLParameterDefinition integerWithKey:@"vortex" label:@"Vortex charge l" unit:@"" group:@"Initial State"
                                              defaultValue:0 min:0 max:3]
                     visibleForKey:@"dimension" values:@[@(QLSchrodingerDimension2D)]]];

    [defs addObject:[[QLParameterDefinition doubleWithKey:@"v0" label:@"Potential strength V₀" unit:@"" group:@"Potential"
                                             defaultValue:(is2D ? 50.0 : 20.0) min:-1e9 max:1e9]
                     visibleForKey:@"potential" values:(is2D ? @[@6, @7, @5] : @[@2, @3, @5])]];
    [defs addObject:[[QLParameterDefinition doubleWithKey:@"omega" label:@"Trap frequency ω" unit:@"" group:@"Potential"
                                             defaultValue:1.0 min:1e-9 max:1e9]
                     visibleForKey:@"potential" values:@[@1]]];
    if (!is2D) {
        [defs addObject:[[QLParameterDefinition doubleWithKey:@"barrierX" label:@"Barrier position xb" unit:@"" group:@"Potential"
                                                 defaultValue:0.0 min:-100000.0 max:100000.0]
                         visibleForKey:@"potential" values:@[@2]]];
        [defs addObject:[[QLParameterDefinition doubleWithKey:@"barrierWidth" label:@"Barrier width w" unit:@"" group:@"Potential"
                                                 defaultValue:1.0 min:1e-6 max:100000.0]
                         visibleForKey:@"potential" values:@[@2, @3]]];
        [defs addObject:[[QLParameterDefinition doubleWithKey:@"barrierSeparation" label:@"Barrier separation d" unit:@"" group:@"Potential"
                                                 defaultValue:6.0 min:1e-6 max:100000.0]
                         visibleForKey:@"potential" values:@[@3]]];
        [defs addObject:[[QLParameterDefinition doubleWithKey:@"field" label:@"Linear field F" unit:@"" group:@"Potential"
                                                 defaultValue:0.5 min:-1e9 max:1e9]
                         visibleForKey:@"potential" values:@[@4]]];
    } else {
        [defs addObject:[[QLParameterDefinition doubleWithKey:@"barrierX" label:@"Wall position xb" unit:@"" group:@"Potential"
                                                 defaultValue:0.0 min:-100000.0 max:100000.0]
                         visibleForKey:@"potential" values:@[@6]]];
        [defs addObject:[[QLParameterDefinition doubleWithKey:@"wallThickness" label:@"Wall thickness t" unit:@"" group:@"Potential"
                                                 defaultValue:1.0 min:1e-6 max:100000.0]
                         visibleForKey:@"potential" values:@[@6]]];
        [defs addObject:[[QLParameterDefinition doubleWithKey:@"slitSeparation" label:@"Slit separation d" unit:@"" group:@"Potential"
                                                 defaultValue:4.0 min:0.0 max:100000.0]
                         visibleForKey:@"potential" values:@[@6]]];
        [defs addObject:[[QLParameterDefinition doubleWithKey:@"slitWidth" label:@"Slit width w" unit:@"" group:@"Potential"
                                                 defaultValue:2.0 min:1e-6 max:100000.0]
                         visibleForKey:@"potential" values:@[@6]]];
        [defs addObject:[[QLParameterDefinition doubleWithKey:@"wellRadius" label:@"Well radius R" unit:@"" group:@"Potential"
                                                 defaultValue:5.0 min:1e-6 max:100000.0]
                         visibleForKey:@"potential" values:@[@7]]];
    }
    [defs addObject:[[QLParameterDefinition doubleWithKey:@"latticePeriod" label:@"Lattice period a" unit:@"" group:@"Potential"
                                             defaultValue:4.0 min:1e-6 max:100000.0]
                     visibleForKey:@"potential" values:@[@5]]];

    [defs addObject:[QLParameterDefinition doubleWithKey:@"absWidth" label:@"Absorbing width" unit:@"" group:@"Boundaries"
                                            defaultValue:0.0 min:0.0 max:100000.0]];
    [defs addObject:[[QLParameterDefinition doubleWithKey:@"absStrength" label:@"Absorbing strength" unit:@"" group:@"Boundaries"
                                             defaultValue:20.0 min:1e-9 max:1e9]
                     visibleForKey:@"absWidth" minValue:1e-9]];
    [defs addObject:[QLParameterDefinition booleanWithKey:@"renormalize" label:@"Renormalize each step" group:@"Boundaries"
                                             defaultValue:NO]];
    [defs addObject:[[QLParameterDefinition booleanWithKey:@"storePhase" label:@"Store phase (2D)" group:@"Output"
                                              defaultValue:NO]
                     visibleForKey:@"dimension" values:@[@(QLSchrodingerDimension2D)]]];

    return defs;
}

+ (NSArray<QLParameterDefinition *> *)heisenbergDefinitionsForSystem:(NSInteger)system {
    NSMutableArray<QLParameterDefinition *> *defs = [NSMutableArray array];

    [defs addObject:[QLParameterDefinition doubleWithKey:@"dt" label:@"Time step Δt" unit:@"" group:@"Time"
                                            defaultValue:0.002 min:1e-9 max:10.0]];
    [defs addObject:[QLParameterDefinition doubleWithKey:@"tmax" label:@"End time" unit:@"" group:@"Time"
                                            defaultValue:20.0 min:1e-6 max:100000.0]];
    [defs addObject:[QLParameterDefinition integerWithKey:@"frames" label:@"Output frames" unit:@"" group:@"Time"
                                             defaultValue:400 min:2 max:2000]];

    if (system == QLHeisenbergSystemSpin) {
        [defs addObject:[QLParameterDefinition doubleWithKey:@"theta0" label:@"Initial polar θ₀" unit:@"°" group:@"Initial State"
                                                defaultValue:80.0 min:0.0 max:180.0]];
        [defs addObject:[QLParameterDefinition doubleWithKey:@"phi0" label:@"Initial azimuth φ₀" unit:@"°" group:@"Initial State"
                                                defaultValue:0.0 min:-720.0 max:720.0]];
        [defs addObject:[QLParameterDefinition doubleWithKey:@"gamma" label:@"Gyromagnetic ratio γ" unit:@"" group:@"Field"
                                                defaultValue:1.0 min:-1e9 max:1e9]];
        [defs addObject:[QLParameterDefinition doubleWithKey:@"bx" label:@"Static field Bx" unit:@"" group:@"Field"
                                                defaultValue:0.2 min:-1e9 max:1e9]];
        [defs addObject:[QLParameterDefinition doubleWithKey:@"by" label:@"Static field By" unit:@"" group:@"Field"
                                                defaultValue:0.0 min:-1e9 max:1e9]];
        [defs addObject:[QLParameterDefinition doubleWithKey:@"bz" label:@"Static field Bz" unit:@"" group:@"Field"
                                                defaultValue:1.0 min:-1e9 max:1e9]];
        [defs addObject:[QLParameterDefinition doubleWithKey:@"driveAmp" label:@"Drive amplitude" unit:@"" group:@"Drive"
                                                defaultValue:0.0 min:0.0 max:1e9]];
        [defs addObject:[[QLParameterDefinition doubleWithKey:@"driveFreq" label:@"Drive frequency ωrf" unit:@"" group:@"Drive"
                                                 defaultValue:1.0 min:1e-9 max:1e9]
                         visibleForKey:@"driveAmp" minValue:1e-9]];
        [defs addObject:[[QLParameterDefinition doubleWithKey:@"drivePhase" label:@"Drive phase φ" unit:@"°" group:@"Drive"
                                                 defaultValue:0.0 min:-720.0 max:720.0]
                         visibleForKey:@"driveAmp" minValue:1e-9]];
        [defs addObject:[[QLParameterDefinition enumWithKey:@"driveAxis" label:@"Drive axis" group:@"Drive"
                                               defaultValue:0
                                                      labels:@[@"x", @"y", @"z"]
                                                      values:@[@0, @1, @2]]
                         visibleForKey:@"driveAmp" minValue:1e-9]];
    } else {
        [defs addObject:[QLParameterDefinition doubleWithKey:@"mass" label:@"Mass m" unit:@"" group:@"Oscillator"
                                                defaultValue:1.0 min:1e-9 max:1e9]];
        [defs addObject:[QLParameterDefinition doubleWithKey:@"omega" label:@"Frequency ω" unit:@"" group:@"Oscillator"
                                                defaultValue:1.0 min:1e-9 max:1e9]];
        [defs addObject:[QLParameterDefinition doubleWithKey:@"x0" label:@"Initial x₀" unit:@"" group:@"Oscillator"
                                                defaultValue:1.0 min:-1e9 max:1e9]];
        [defs addObject:[QLParameterDefinition doubleWithKey:@"p0" label:@"Initial p₀" unit:@"" group:@"Oscillator"
                                                defaultValue:0.0 min:-1e9 max:1e9]];
        [defs addObject:[QLParameterDefinition doubleWithKey:@"damping" label:@"Damping γd (non-H)" unit:@"" group:@"Oscillator"
                                                defaultValue:0.0 min:0.0 max:1e9]];
    }

    return defs;
}

+ (QLParameterSet *)defaultParametersForMode:(QLSimulationMode)mode
                                     variant:(NSInteger)variant {
    QLParameterSet *set = [QLParameterSet new];
    if (mode == QLSimulationModeSchrodinger) {
        set.values[@"dimension"] = @(variant);
        set.values[@"potential"] = @(QLPotentialTypeFree);
        set.values[@"nx"] = @(variant == QLSchrodingerDimension2D ? 128 : 512);
        set.values[@"ny"] = @128;
        set.values[@"lx"] = @(variant == QLSchrodingerDimension2D ? 40.0 : 60.0);
        set.values[@"ly"] = @40.0;
        set.values[@"hbar"] = @1.0;
        set.values[@"mass"] = @1.0;
        set.values[@"dt"] = @(variant == QLSchrodingerDimension2D ? 0.002 : 0.005);
        set.values[@"tmax"] = @(variant == QLSchrodingerDimension2D ? 4.0 : 6.0);
        set.values[@"frames"] = @(variant == QLSchrodingerDimension2D ? 200 : 240);
        set.values[@"x0"] = @(variant == QLSchrodingerDimension2D ? -8.0 : -12.0);
        set.values[@"y0"] = @0.0;
        set.values[@"sigmaX"] = @(variant == QLSchrodingerDimension2D ? 2.0 : 1.5);
        set.values[@"sigmaY"] = @2.0;
        set.values[@"kx0"] = @2.0;
        set.values[@"ky0"] = @0.0;
        set.values[@"vortex"] = @0;
        set.values[@"v0"] = @(variant == QLSchrodingerDimension2D ? 50.0 : 20.0);
        set.values[@"omega"] = @1.0;
        set.values[@"barrierX"] = @0.0;
        set.values[@"barrierWidth"] = @1.0;
        set.values[@"barrierSeparation"] = @6.0;
        set.values[@"wallThickness"] = @1.0;
        set.values[@"slitSeparation"] = @4.0;
        set.values[@"slitWidth"] = @2.0;
        set.values[@"wellRadius"] = @5.0;
        set.values[@"latticePeriod"] = @4.0;
        set.values[@"field"] = @0.5;
        set.values[@"absWidth"] = @0.0;
        set.values[@"absStrength"] = @20.0;
        set.values[@"renormalize"] = @NO;
        set.values[@"storePhase"] = @NO;
    } else {
        set.values[@"system"] = @(variant);
        set.values[@"dt"] = @0.002;
        set.values[@"tmax"] = @20.0;
        set.values[@"frames"] = @400;
        if (variant == QLHeisenbergSystemSpin) {
            set.values[@"theta0"] = @80.0;
            set.values[@"phi0"] = @0.0;
            set.values[@"gamma"] = @1.0;
            set.values[@"bx"] = @0.2;
            set.values[@"by"] = @0.0;
            set.values[@"bz"] = @1.0;
            set.values[@"driveAmp"] = @0.0;
            set.values[@"driveFreq"] = @1.0;
            set.values[@"drivePhase"] = @0.0;
            set.values[@"driveAxis"] = @0;
        } else {
            set.values[@"mass"] = @1.0;
            set.values[@"omega"] = @1.0;
            set.values[@"x0"] = @1.0;
            set.values[@"p0"] = @0.0;
            set.values[@"damping"] = @0.0;
        }
    }
    [set applyDefaults:[self definitionsForMode:mode variant:variant]];
    return set;
}

+ (NSArray<NSString *> *)presetNamesForMode:(QLSimulationMode)mode
                                    variant:(NSInteger)variant {
    if (mode == QLSimulationModeSchrodinger) {
        if (variant == QLSchrodingerDimension2D) {
            return @[@"Free Gaussian packet", @"Double slit", @"Vortex packet"];
        }
        return @[@"Free Gaussian packet", @"Harmonic coherent state", @"Tunneling barrier"];
    }
    if (variant == QLHeisenbergSystemSpin) {
        return @[@"Spin precession", @"Driven spin"];
    }
    return @[@"Oscillator phase space"];
}

+ (QLParameterSet *)presetParametersForMode:(QLSimulationMode)mode
                                    variant:(NSInteger)variant
                                      index:(NSInteger)index {
    QLParameterSet *set = [self defaultParametersForMode:mode variant:variant];
    NSArray<NSString *> *names = [self presetNamesForMode:mode variant:variant];
    if (index < 0 || index >= (NSInteger)names.count) return set;
    NSString *name = names[(NSUInteger)index];

    if ([name isEqualToString:@"Harmonic coherent state"]) {
        set.values[@"potential"] = @(QLPotentialTypeHarmonic);
        set.values[@"omega"] = @1.0;
        set.values[@"x0"] = @5.0;
        set.values[@"kx0"] = @0.0;
        set.values[@"sigmaX"] = @(1.0 / sqrt(2.0));
        set.values[@"tmax"] = @12.0;
        set.values[@"frames"] = @300;
        set.values[@"absWidth"] = @0.0;
    } else if ([name isEqualToString:@"Tunneling barrier"]) {
        set.values[@"potential"] = @(QLPotentialTypeBarrier);
        set.values[@"v0"] = @20.0;
        set.values[@"barrierX"] = @0.0;
        set.values[@"barrierWidth"] = @2.0;
        set.values[@"x0"] = @(-20.0);
        set.values[@"kx0"] = @2.0;
        set.values[@"sigmaX"] = @2.0;
        set.values[@"tmax"] = @10.0;
        set.values[@"frames"] = @300;
        set.values[@"absWidth"] = @0.0;
    } else if ([name isEqualToString:@"Double slit"]) {
        set.values[@"potential"] = @(QLPotentialTypeDoubleSlit);
        set.values[@"nx"] = @128;
        set.values[@"ny"] = @128;
        set.values[@"lx"] = @40.0;
        set.values[@"ly"] = @40.0;
        set.values[@"x0"] = @(-8.0);
        set.values[@"y0"] = @0.0;
        set.values[@"sigmaX"] = @2.0;
        set.values[@"sigmaY"] = @2.0;
        set.values[@"kx0"] = @2.0;
        set.values[@"ky0"] = @0.0;
        set.values[@"v0"] = @50.0;
        set.values[@"barrierX"] = @0.0;
        set.values[@"wallThickness"] = @1.0;
        set.values[@"slitSeparation"] = @4.0;
        set.values[@"slitWidth"] = @2.0;
        set.values[@"tmax"] = @4.0;
        set.values[@"frames"] = @200;
        set.values[@"absWidth"] = @0.0;
    } else if ([name isEqualToString:@"Vortex packet"]) {
        set.values[@"potential"] = @(QLPotentialTypeHarmonic);
        set.values[@"omega"] = @1.0;
        set.values[@"x0"] = @3.0;
        set.values[@"y0"] = @0.0;
        set.values[@"kx0"] = @0.0;
        set.values[@"ky0"] = @0.0;
        set.values[@"sigmaX"] = @1.5;
        set.values[@"sigmaY"] = @1.5;
        set.values[@"vortex"] = @1;
        set.values[@"tmax"] = @4.0;
        set.values[@"frames"] = @200;
        set.values[@"absWidth"] = @0.0;
    } else if ([name isEqualToString:@"Driven spin"]) {
        set.values[@"bx"] = @0.0;
        set.values[@"by"] = @0.0;
        set.values[@"bz"] = @1.0;
        set.values[@"driveAmp"] = @0.3;
        set.values[@"driveFreq"] = @1.0;
        set.values[@"driveAxis"] = @0;
        set.values[@"theta0"] = @20.0;
        set.values[@"phi0"] = @0.0;
        set.values[@"tmax"] = @20.0;
    }
    [set applyDefaults:[self definitionsForMode:mode variant:variant]];
    return set;
}

+ (NSString *)potentialNameForType:(QLPotentialType)type {
    switch (type) {
        case QLPotentialTypeFree: return @"Free";
        case QLPotentialTypeHarmonic: return @"Harmonic";
        case QLPotentialTypeBarrier: return @"Barrier";
        case QLPotentialTypeDoubleBarrier: return @"Double Barrier";
        case QLPotentialTypeLinear: return @"Linear Field";
        case QLPotentialTypeLattice: return @"Periodic Lattice";
        case QLPotentialTypeDoubleSlit: return @"Double Slit";
        case QLPotentialTypeCircularWell: return @"Circular Well";
    }
    return @"Unknown";
}

@end
