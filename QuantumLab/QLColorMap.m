#import "QLColorMap.h"

@implementation QLColorMap {
    NSArray<NSColor *> *_lut;
}

+ (NSArray<NSString *> *)colorMapNames {
    return @[@"Viridis", @"Inferno", @"CoolWarm", @"Grayscale"];
}

+ (instancetype)defaultMap {
    return [self colorMapNamed:@"Viridis"];
}

+ (instancetype)colorMapNamed:(NSString *)name {
    QLColorMap *map = [[QLColorMap alloc] init];
    map->_name = [name copy] ?: @"Viridis";
    NSArray<NSColor *> *stops = nil;
    if ([name isEqualToString:@"Inferno"]) {
        stops = @[
            [NSColor colorWithSRGBRed:0.001 green:0.000 blue:0.014 alpha:1],
            [NSColor colorWithSRGBRed:0.130 green:0.047 blue:0.225 alpha:1],
            [NSColor colorWithSRGBRed:0.290 green:0.055 blue:0.396 alpha:1],
            [NSColor colorWithSRGBRed:0.454 green:0.090 blue:0.400 alpha:1],
            [NSColor colorWithSRGBRed:0.612 green:0.148 blue:0.343 alpha:1],
            [NSColor colorWithSRGBRed:0.750 green:0.240 blue:0.251 alpha:1],
            [NSColor colorWithSRGBRed:0.865 green:0.361 blue:0.142 alpha:1],
            [NSColor colorWithSRGBRed:0.945 green:0.520 blue:0.041 alpha:1],
            [NSColor colorWithSRGBRed:0.978 green:0.710 blue:0.058 alpha:1],
            [NSColor colorWithSRGBRed:0.941 green:0.900 blue:0.220 alpha:1],
            [NSColor colorWithSRGBRed:0.988 green:0.998 blue:0.645 alpha:1]
        ];
    } else if ([name isEqualToString:@"CoolWarm"]) {
        stops = @[
            [NSColor colorWithSRGBRed:0.230 green:0.299 blue:0.754 alpha:1],
            [NSColor colorWithSRGBRed:0.322 green:0.440 blue:0.887 alpha:1],
            [NSColor colorWithSRGBRed:0.475 green:0.618 blue:0.966 alpha:1],
            [NSColor colorWithSRGBRed:0.667 green:0.779 blue:0.997 alpha:1],
            [NSColor colorWithSRGBRed:0.870 green:0.900 blue:0.950 alpha:1],
            [NSColor colorWithSRGBRed:0.958 green:0.842 blue:0.756 alpha:1],
            [NSColor colorWithSRGBRed:0.968 green:0.689 blue:0.556 alpha:1],
            [NSColor colorWithSRGBRed:0.935 green:0.503 blue:0.373 alpha:1],
            [NSColor colorWithSRGBRed:0.843 green:0.316 blue:0.257 alpha:1],
            [NSColor colorWithSRGBRed:0.706 green:0.157 blue:0.190 alpha:1],
            [NSColor colorWithSRGBRed:0.541 green:0.031 blue:0.153 alpha:1]
        ];
    } else if ([name isEqualToString:@"Grayscale"]) {
        stops = @[
            [NSColor colorWithWhite:0.05 alpha:1],
            [NSColor colorWithWhite:0.95 alpha:1]
        ];
    } else {
        stops = @[
            [NSColor colorWithSRGBRed:0.267 green:0.005 blue:0.329 alpha:1],
            [NSColor colorWithSRGBRed:0.283 green:0.141 blue:0.458 alpha:1],
            [NSColor colorWithSRGBRed:0.254 green:0.265 blue:0.530 alpha:1],
            [NSColor colorWithSRGBRed:0.207 green:0.372 blue:0.553 alpha:1],
            [NSColor colorWithSRGBRed:0.164 green:0.471 blue:0.558 alpha:1],
            [NSColor colorWithSRGBRed:0.128 green:0.567 blue:0.551 alpha:1],
            [NSColor colorWithSRGBRed:0.135 green:0.659 blue:0.518 alpha:1],
            [NSColor colorWithSRGBRed:0.267 green:0.749 blue:0.441 alpha:1],
            [NSColor colorWithSRGBRed:0.478 green:0.821 blue:0.318 alpha:1],
            [NSColor colorWithSRGBRed:0.741 green:0.873 blue:0.150 alpha:1],
            [NSColor colorWithSRGBRed:0.993 green:0.906 blue:0.144 alpha:1]
        ];
    }
    map->_stops = stops;
    NSMutableArray<NSColor *> *lut = [NSMutableArray arrayWithCapacity:256];
    for (NSInteger i = 0; i < 256; i++) {
        [lut addObject:[map colorAtUnit:(double)i / 255.0 usingStops:stops]];
    }
    map->_lut = lut;
    return map;
}

- (NSColor *)colorAtUnit:(double)unit usingStops:(NSArray<NSColor *> *)stops {
    if (stops.count == 0) return NSColor.blackColor;
    double u = fmin(1.0, fmax(0.0, unit));
    double scaled = u * (double)(stops.count - 1);
    NSInteger index = (NSInteger)floor(scaled);
    if (index >= (NSInteger)stops.count - 1) {
        return stops.lastObject;
    }
    double t = scaled - (double)index;
    NSColor *a = [stops[(NSUInteger)index] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
    NSColor *b = [stops[(NSUInteger)index + 1] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
    return [NSColor colorWithSRGBRed:a.redComponent + (b.redComponent - a.redComponent) * t
                               green:a.greenComponent + (b.greenComponent - a.greenComponent) * t
                                blue:a.blueComponent + (b.blueComponent - a.blueComponent) * t
                               alpha:1.0];
}

- (NSColor *)colorAtIndex:(NSInteger)index {
    NSInteger clamped = MIN(255, MAX(0, index));
    return _lut[(NSUInteger)clamped];
}

- (NSColor *)colorAtUnit:(double)unit {
    return [self colorAtIndex:(NSInteger)llround(fmin(1.0, fmax(0.0, unit)) * 255.0)];
}

- (NSImage *)gradientImage {
    return [NSImage imageWithSize:NSMakeSize(256, 1) flipped:NO drawingHandler:^BOOL(NSRect rect) {
        for (NSInteger i = 0; i < 256; i++) {
            [self colorAtIndex:i];
            [[self colorAtIndex:i] setFill];
            NSRectFill(NSMakeRect((CGFloat)i, 0, 1, 1));
        }
        return YES;
    }];
}

- (NSGradient *)gradient {
    return [[NSGradient alloc] initWithColors:self.stops];
}

@end
