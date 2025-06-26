#import "QL2DPlotView.h"
#import "QLColorMap.h"
#import "QLPlotStyle.h"
#include <complex.h>
#include <math.h>

typedef struct {
    double step;
    double start;
    int count;
} QLTicks;

static double QLNiceStep(double range, int target) {
    if (!(range > 0) || target < 1) return 1.0;
    double rough = range / (double)target;
    double magnitude = pow(10.0, floor(log10(rough)));
    double normalized = rough / magnitude;
    double nice;
    if (normalized <= 1.0) nice = 1.0;
    else if (normalized <= 2.0) nice = 2.0;
    else if (normalized <= 5.0) nice = 5.0;
    else nice = 10.0;
    return nice * magnitude;
}

static QLTicks QLTicksForRange(double min, double max, int target) {
    QLTicks ticks = {1.0, 0.0, 0};
    if (!isfinite(min) || !isfinite(max) || max <= min) {
        max = min + 1.0;
    }
    ticks.step = QLNiceStep(max - min, target);
    ticks.start = ceil(min / ticks.step) * ticks.step;
    ticks.count = (int)floor((max - ticks.start) / ticks.step) + 1;
    if (ticks.count < 2) {
        ticks.start = min;
        ticks.step = (max - min);
        ticks.count = 2;
    }
    if (ticks.count > 30) {
        ticks.count = 30;
    }
    return ticks;
}

static void QLDrawText(NSString *text, NSRect rect, NSTextAlignment alignment, NSFont *font, NSColor *color) {
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.alignment = alignment;
    style.lineBreakMode = NSLineBreakByClipping;
    NSDictionary *attrs = @{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: color,
        NSParagraphStyleAttributeName: style
    };
    [text drawInRect:rect withAttributes:attrs];
}

static NSString *QLFormatTick(double value, double step) {
    if (fabs(value) < step * 1e-6) value = 0.0;
    double absValue = fabs(value);
    if (absValue >= 1e5 || (absValue > 0 && absValue < 1e-3)) {
        return [NSString stringWithFormat:@"%.2e", value];
    }
    if (step >= 1.0) return [NSString stringWithFormat:@"%.0f", value];
    if (step >= 0.01) return [NSString stringWithFormat:@"%.2f", value];
    return [NSString stringWithFormat:@"%.3g", value];
}

@implementation QL2DPlotView {
    NSTrackingArea *_trackingArea;
    NSPoint _hoverPoint;
    BOOL _hasHover;
    NSRect _lastPlotRect;
    NSRect _lastImageRect;
    NSRect _lastColorBarRect;
}

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _options = [QLPlotOptions new];
        _plotKindOverride = -1;
        _frameIndex = 0;
        self.wantsLayer = YES;
    }
    return self;
}

- (BOOL)isFlipped { return NO; }
- (BOOL)acceptsFirstResponder { return YES; }

- (void)setResult:(QLSimulationResult *)result {
    _result = result;
    _frameIndex = 0;
    _hasHover = NO;
    [self setNeedsDisplay:YES];
}

- (void)setFrameIndex:(NSInteger)frameIndex {
    NSInteger count = self.result.frameCount;
    if (count < 1) count = 1;
    _frameIndex = MIN(MAX(0, frameIndex), count - 1);
    [self setNeedsDisplay:YES];
}

- (void)setOptions:(QLPlotOptions *)options {
    _options = [options copy];
    [self setNeedsDisplay:YES];
}

- (void)setPlotKindOverride:(QLPlotKind)plotKindOverride {
    _plotKindOverride = plotKindOverride;
    [self setNeedsDisplay:YES];
}

- (QLPlotKind)effectivePlotKind {
    if (!self.result) return QLPlotKindWavefunction1D;
    if (self.result.isOscillator) {
        return self.plotKindOverride == QLPlotKindOscillatorTimeSeries
            ? QLPlotKindOscillatorTimeSeries
            : QLPlotKindOscillatorPhase;
    }
    return self.result.plotKind;
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    if (_trackingArea) [self removeTrackingArea:_trackingArea];
    _trackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds
                                                options:(NSTrackingMouseMoved | NSTrackingMouseEnteredAndExited |
                                                         NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect)
                                                  owner:self
                                               userInfo:nil];
    [self addTrackingArea:_trackingArea];
}

- (void)mouseMoved:(NSEvent *)event {
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    _hasHover = NSMouseInRect(point, _lastPlotRect, NO);
    _hoverPoint = point;
    [self setNeedsDisplay:YES];
}

- (void)mouseExited:(NSEvent *)event {
    _hasHover = NO;
    [self setNeedsDisplay:YES];
}

- (void)clearHover {
    _hasHover = NO;
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    [NSColor.controlBackgroundColor setFill];
    NSRectFill(self.bounds);

    if (!self.result) {
        NSDictionary *attrs = @{
            NSFontAttributeName: [NSFont systemFontOfSize:14 weight:NSFontWeightMedium],
            NSForegroundColorAttributeName: NSColor.secondaryLabelColor
        };
        NSString *message = @"Configure parameters and press Solve";
        NSSize size = [message sizeWithAttributes:attrs];
        [message drawAtPoint:NSMakePoint(NSMidX(self.bounds) - size.width / 2, NSMidY(self.bounds) - size.height / 2)
              withAttributes:attrs];
        return;
    }

    QLPlotKind kind = [self effectivePlotKind];
    BOOL heatmap = (kind == QLPlotKindDensityHeatmap2D);
    CGFloat rightMargin = heatmap ? 92.0 : 30.0;
    NSRect plot = NSMakeRect(64, 50, NSWidth(self.bounds) - 64 - rightMargin, NSHeight(self.bounds) - 50 - 34);
    if (plot.size.width < 80 || plot.size.height < 60) return;
    _lastPlotRect = plot;

    switch (kind) {
        case QLPlotKindWavefunction1D:
            [self drawWavefunctionInRect:plot];
            break;
        case QLPlotKindDensityHeatmap2D:
            [self drawHeatmapInRect:plot];
            break;
        case QLPlotKindSpinTimeSeries:
            [self drawSpinInRect:plot];
            break;
        case QLPlotKindOscillatorPhase:
            [self drawOscillatorPhaseInRect:plot];
            break;
        case QLPlotKindOscillatorTimeSeries:
            [self drawOscillatorTimeSeriesInRect:plot];
            break;
    }

    if (_hasHover) {
        [self drawHoverInRect:plot];
    }
}

- (void)drawAxesInRect:(NSRect)rect
                 xMin:(double)xMin
                 xMax:(double)xMax
                 yMin:(double)yMin
                 yMax:(double)yMax
               xLabel:(NSString *)xLabel
               yLabel:(NSString *)yLabel
              showGrid:(BOOL)showGrid {
    if (yMax <= yMin) yMax = yMin + 1.0;
    if (xMax <= xMin) xMax = xMin + 1.0;

    NSColor *gridColor = [NSColor.separatorColor colorWithAlphaComponent:0.35];
    NSColor *borderColor = NSColor.separatorColor;
    NSFont *tickFont = [NSFont monospacedDigitSystemFontOfSize:9.5 weight:NSFontWeightRegular];
    NSColor *textColor = NSColor.secondaryLabelColor;

    QLTicks xTicks = QLTicksForRange(xMin, xMax, 7);
    QLTicks yTicks = QLTicksForRange(yMin, yMax, 6);

    if (showGrid) {
        [gridColor setStroke];
        NSBezierPath *grid = [NSBezierPath bezierPath];
        grid.lineWidth = 0.5;
        for (int i = 0; i < xTicks.count; i++) {
            double value = xTicks.start + i * xTicks.step;
            if (value < xMin - xTicks.step * 0.01 || value > xMax + xTicks.step * 0.01) continue;
            CGFloat x = rect.origin.x + (value - xMin) / (xMax - xMin) * rect.size.width;
            [grid moveToPoint:NSMakePoint(x, rect.origin.y)];
            [grid lineToPoint:NSMakePoint(x, rect.origin.y + rect.size.height)];
        }
        for (int i = 0; i < yTicks.count; i++) {
            double value = yTicks.start + i * yTicks.step;
            if (value < yMin - yTicks.step * 0.01 || value > yMax + yTicks.step * 0.01) continue;
            CGFloat y = rect.origin.y + (value - yMin) / (yMax - yMin) * rect.size.height;
            [grid moveToPoint:NSMakePoint(rect.origin.x, y)];
            [grid lineToPoint:NSMakePoint(rect.origin.x + rect.size.width, y)];
        }
        [grid stroke];
    }

    [borderColor setStroke];
    NSBezierPath *border = [NSBezierPath bezierPathWithRect:rect];
    border.lineWidth = 1.0;
    [border stroke];

    for (int i = 0; i < xTicks.count; i++) {
        double value = xTicks.start + i * xTicks.step;
        if (value < xMin - xTicks.step * 0.01 || value > xMax + xTicks.step * 0.01) continue;
        CGFloat x = rect.origin.x + (value - xMin) / (xMax - xMin) * rect.size.width;
        [borderColor setStroke];
        NSBezierPath *tick = [NSBezierPath bezierPath];
        [tick moveToPoint:NSMakePoint(x, rect.origin.y)];
        [tick lineToPoint:NSMakePoint(x, rect.origin.y - 4)];
        [tick stroke];
        QLDrawText(QLFormatTick(value, xTicks.step),
                   NSMakeRect(x - 40, rect.origin.y - 19, 80, 13),
                   NSTextAlignmentCenter, tickFont, textColor);
    }

    for (int i = 0; i < yTicks.count; i++) {
        double value = yTicks.start + i * yTicks.step;
        if (value < yMin - yTicks.step * 0.01 || value > yMax + yTicks.step * 0.01) continue;
        CGFloat y = rect.origin.y + (value - yMin) / (yMax - yMin) * rect.size.height;
        [borderColor setStroke];
        NSBezierPath *tick = [NSBezierPath bezierPath];
        [tick moveToPoint:NSMakePoint(rect.origin.x, y)];
        [tick lineToPoint:NSMakePoint(rect.origin.x - 4, y)];
        [tick stroke];
        QLDrawText(QLFormatTick(value, yTicks.step),
                   NSMakeRect(rect.origin.x - 62, y - 7, 55, 14),
                   NSTextAlignmentRight, tickFont, textColor);
    }

    QLDrawText(xLabel, NSMakeRect(rect.origin.x, 8, rect.size.width, 16),
               NSTextAlignmentCenter, [NSFont systemFontOfSize:11 weight:NSFontWeightMedium], NSColor.labelColor);
    QLDrawText(yLabel, NSMakeRect(rect.origin.x - 4, rect.origin.y + rect.size.height + 8, 220, 16),
               NSTextAlignmentLeft, [NSFont systemFontOfSize:11 weight:NSFontWeightMedium], NSColor.labelColor);
}

- (CGFloat)mapX:(double)value min:(double)min max:(double)max rect:(NSRect)rect {
    return rect.origin.x + (value - min) / (max - min) * rect.size.width;
}

- (CGFloat)mapY:(double)value min:(double)min max:(double)max rect:(NSRect)rect {
    return rect.origin.y + (value - min) / (max - min) * rect.size.height;
}

- (void)drawLegendEntries:(NSArray<NSDictionary *> *)entries inRect:(NSRect)plot {
    CGFloat x = plot.origin.x + 10;
    CGFloat y = plot.origin.y + plot.size.height - 18;
    for (NSDictionary *entry in entries) {
        NSColor *color = entry[@"color"];
        NSString *name = entry[@"name"];
        [color setFill];
        NSRectFill(NSMakeRect(x, y + 4, 9, 9));
        QLDrawText(name, NSMakeRect(x + 14, y - 1, 130, 16), NSTextAlignmentLeft,
                   [NSFont systemFontOfSize:10], NSColor.secondaryLabelColor);
        x += 14 + [name sizeWithAttributes:@{NSFontAttributeName: [NSFont systemFontOfSize:10]}].width + 16;
    }
}

- (void)drawWavefunctionInRect:(NSRect)plot {
    const double complex *psi = [self.result wavefunctionAtFrame:self.frameIndex];
    if (!psi) return;
    NSInteger nx = self.result.nx;
    double dx = self.result.lx / (double)nx;
    double xmin = -self.result.lx * 0.5;
    double xmax = self.result.lx * 0.5;
    double yMax = self.result.globalDensityMax * 1.08;
    if (yMax <= 0) yMax = 1.0;

    [self drawAxesInRect:plot xMin:xmin xMax:xmax yMin:0 yMax:yMax
                  xLabel:@"x" yLabel:@"|ψ|²" showGrid:YES];

    NSColor *densityColor = NSColor.systemBlueColor;
    NSBezierPath *fill = [NSBezierPath bezierPath];
    [fill moveToPoint:NSMakePoint(plot.origin.x, plot.origin.y)];
    for (NSInteger i = 0; i < nx; i++) {
        double x = xmin + ((double)i + 0.5) * dx;
        double density = creal(psi[i] * conj(psi[i]));
        CGFloat px = [self mapX:x min:xmin max:xmax rect:plot];
        CGFloat py = [self mapY:density min:0 max:yMax rect:plot];
        [fill lineToPoint:NSMakePoint(px, py)];
    }
    [fill lineToPoint:NSMakePoint(plot.origin.x + plot.size.width, plot.origin.y)];
    [fill closePath];
    [[densityColor colorWithAlphaComponent:0.28] setFill];
    [fill fill];
    [densityColor setStroke];
    fill.lineWidth = 1.7;
    [fill stroke];

    if (self.options.showRealImag) {
        double maxAmp = 0.0;
        for (NSInteger i = 0; i < nx; i++) maxAmp = fmax(maxAmp, cabs(psi[i]));
        if (maxAmp > 0) {
            NSBezierPath *rePath = [NSBezierPath bezierPath];
            NSBezierPath *imPath = [NSBezierPath bezierPath];
            for (NSInteger i = 0; i < nx; i++) {
                double x = xmin + ((double)i + 0.5) * dx;
                CGFloat px = [self mapX:x min:xmin max:xmax rect:plot];
                CGFloat pyRe = plot.origin.y + plot.size.height * (0.5 + 0.42 * creal(psi[i]) / maxAmp);
                CGFloat pyIm = plot.origin.y + plot.size.height * (0.5 + 0.42 * cimag(psi[i]) / maxAmp);
                if (i == 0) {
                    [rePath moveToPoint:NSMakePoint(px, pyRe)];
                    [imPath moveToPoint:NSMakePoint(px, pyIm)];
                } else {
                    [rePath lineToPoint:NSMakePoint(px, pyRe)];
                    [imPath lineToPoint:NSMakePoint(px, pyIm)];
                }
            }
            rePath.lineWidth = 0.9;
            imPath.lineWidth = 0.9;
            [[NSColor systemPinkColor] setStroke];
            [rePath stroke];
            [[NSColor systemTealColor] setStroke];
            [imPath stroke];
        }
    }

    BOOL drewPotential = NO;
    if (self.options.showPotential && self.result.potentialV.count > 0) {
        double vmin = INFINITY, vmax = -INFINITY;
        for (NSNumber *v in self.result.potentialV) {
            vmin = fmin(vmin, v.doubleValue);
            vmax = fmax(vmax, v.doubleValue);
        }
        if (isfinite(vmin) && isfinite(vmax) && fabs(vmax - vmin) > 1e-12) {
            NSBezierPath *path = [NSBezierPath bezierPath];
            for (NSInteger i = 0; i < nx; i++) {
                double x = xmin + ((double)i + 0.5) * dx;
                double v = self.result.potentialV[(NSUInteger)i].doubleValue;
                CGFloat px = [self mapX:x min:xmin max:xmax rect:plot];
                CGFloat py = [self mapY:v min:vmin max:vmax rect:plot];
                if (i == 0) [path moveToPoint:NSMakePoint(px, py)];
                else [path lineToPoint:NSMakePoint(px, py)];
            }
            CGFloat dash[] = {4.0, 3.0};
            [path setLineDash:dash count:2 phase:0];
            path.lineWidth = 1.0;
            [[NSColor.secondaryLabelColor colorWithAlphaComponent:0.65] setStroke];
            [path stroke];
            drewPotential = YES;
        }
    }

    NSMutableArray *legend = [NSMutableArray arrayWithObjects:
                              @{@"name": @"|ψ|²", @"color": densityColor}, nil];
    if (drewPotential) {
        [legend addObject:@{@"name": @"V (scaled)", @"color": NSColor.secondaryLabelColor}];
    }
    [self drawLegendEntries:legend inRect:plot];

    double t = self.result.times[(NSUInteger)self.frameIndex].doubleValue;
    QLDrawText([NSString stringWithFormat:@"t = %.3f", t],
               NSMakeRect(plot.origin.x + plot.size.width - 100, plot.origin.y + plot.size.height + 8, 100, 16),
               NSTextAlignmentRight, [NSFont monospacedDigitSystemFontOfSize:10 weight:NSFontWeightRegular],
               NSColor.secondaryLabelColor);
}

- (void)drawHeatmapInRect:(NSRect)plot {
    const float *density = [self.result densityAtFrame:self.frameIndex];
    if (!density) return;
    NSInteger nx = self.result.nx;
    NSInteger ny = self.result.ny;
    BOOL phaseMode = self.options.showPhase && self.result.hasPhase;
    const float *phase = phaseMode ? [self.result phaseAtFrame:self.frameIndex] : NULL;
    if (phaseMode && !phase) phaseMode = NO;

    QLColorMap *map = phaseMode ? [QLColorMap colorMapNamed:@"CoolWarm"]
                                : [QLColorMap colorMapNamed:self.options.colorMapName];
    uint8_t lut[256][3];
    for (NSInteger i = 0; i < 256; i++) {
        NSColor *color = [[map colorAtIndex:i] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
        lut[i][0] = (uint8_t)lround(fmin(1.0, fmax(0.0, color.redComponent)) * 255.0);
        lut[i][1] = (uint8_t)lround(fmin(1.0, fmax(0.0, color.greenComponent)) * 255.0);
        lut[i][2] = (uint8_t)lround(fmin(1.0, fmax(0.0, color.blueComponent)) * 255.0);
    }

    double frameMax = 0.0;
    for (NSInteger i = 0; i < nx * ny; i++) {
        if (density[i] > frameMax) frameMax = density[i];
    }
    double normalizeMax = fmax(frameMax, 1e-12);

    NSMutableData *rgba = [NSMutableData dataWithLength:(NSUInteger)(nx * ny * 4)];
    uint8_t *pixels = rgba.mutableBytes;
    for (NSInteger j = 0; j < ny; j++) {
        NSInteger row = ny - 1 - j;
        for (NSInteger i = 0; i < nx; i++) {
            double value;
            if (phaseMode) {
                value = ((double)phase[j * nx + i] + M_PI) / (2.0 * M_PI);
            } else {
                double d = density[j * nx + i] / normalizeMax;
                if (self.options.logScale) {
                    value = log10(1.0 + 9999.0 * fmax(0.0, d)) / 4.0;
                } else {
                    value = d;
                }
            }
            NSInteger index = (NSInteger)llround(fmin(1.0, fmax(0.0, value)) * 255.0);
            NSUInteger offset = (NSUInteger)((row * nx + i) * 4);
            pixels[offset + 0] = lut[index][0];
            pixels[offset + 1] = lut[index][1];
            pixels[offset + 2] = lut[index][2];
            pixels[offset + 3] = 255;
        }
    }

    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)rgba);
    CGBitmapInfo bitmapInfo = (CGBitmapInfo)kCGImageAlphaPremultipliedLast;
    bitmapInfo |= (CGBitmapInfo)kCGBitmapByteOrderDefault;
    CGImageRef image = CGImageCreate((size_t)nx, (size_t)ny, 8, 32, (size_t)nx * 4, space,
                                     bitmapInfo, provider, NULL, false, kCGRenderingIntentDefault);
    CGContextRef ctx = NSGraphicsContext.currentContext.CGContext;
    CGContextSaveGState(ctx);
    CGContextSetInterpolationQuality(ctx, kCGInterpolationNone);
    CGContextDrawImage(ctx, plot, image);
    CGContextRestoreGState(ctx);
    CGImageRelease(image);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(space);

    [self drawAxesInRect:plot xMin:-self.result.lx * 0.5 xMax:self.result.lx * 0.5
                    yMin:-self.result.ly * 0.5 yMax:self.result.ly * 0.5
                  xLabel:@"x" yLabel:@"y" showGrid:NO];

    NSRect bar = NSMakeRect(plot.origin.x + plot.size.width + 22, plot.origin.y, 16, plot.size.height);
    _lastColorBarRect = bar;
    [[map gradient] drawInRect:bar angle:90];
    [NSColor.separatorColor setStroke];
    [NSBezierPath strokeRect:bar];
    NSFont *font = [NSFont monospacedDigitSystemFontOfSize:9 weight:NSFontWeightRegular];
    if (phaseMode) {
        QLDrawText(@"-π", NSMakeRect(bar.origin.x + 20, bar.origin.y - 5, 50, 12), NSTextAlignmentLeft, font, NSColor.secondaryLabelColor);
        QLDrawText(@"π", NSMakeRect(bar.origin.x + 20, bar.origin.y + bar.size.height - 8, 50, 12), NSTextAlignmentLeft, font, NSColor.secondaryLabelColor);
        QLDrawText(@"phase", NSMakeRect(bar.origin.x - 8, bar.origin.y + bar.size.height + 8, 80, 14), NSTextAlignmentLeft,
                   [NSFont systemFontOfSize:10 weight:NSFontWeightMedium], NSColor.labelColor);
    } else {
        QLDrawText(@"0", NSMakeRect(bar.origin.x + 20, bar.origin.y - 5, 50, 12), NSTextAlignmentLeft, font, NSColor.secondaryLabelColor);
        QLDrawText([NSString stringWithFormat:@"%.3g", normalizeMax],
                   NSMakeRect(bar.origin.x + 20, bar.origin.y + bar.size.height - 8, 60, 12),
                   NSTextAlignmentLeft, font, NSColor.secondaryLabelColor);
        QLDrawText(@"|ψ|²", NSMakeRect(bar.origin.x - 8, bar.origin.y + bar.size.height + 8, 80, 14), NSTextAlignmentLeft,
                   [NSFont systemFontOfSize:10 weight:NSFontWeightMedium], NSColor.labelColor);
    }

    double t = self.result.times[(NSUInteger)self.frameIndex].doubleValue;
    QLDrawText([NSString stringWithFormat:@"t = %.3f", t],
               NSMakeRect(plot.origin.x + plot.size.width - 100, plot.origin.y + plot.size.height + 8, 100, 16),
               NSTextAlignmentRight, [NSFont monospacedDigitSystemFontOfSize:10 weight:NSFontWeightRegular],
               NSColor.secondaryLabelColor);
}

- (void)drawSeriesInRect:(NSRect)plot
                  xMin:(double)xMin
                  xMax:(double)xMax
                  yMin:(double)yMin
                  yMax:(double)yMax
                 xLabel:(NSString *)xLabel
                 yLabel:(NSString *)yLabel
             cursorTime:(double)cursorTime
                 series:(NSArray<QLSeries *> *)series {
    [self drawAxesInRect:plot xMin:xMin xMax:xMax yMin:yMin yMax:yMax xLabel:xLabel yLabel:yLabel showGrid:YES];
    for (QLSeries *seriesItem in series) {
        NSBezierPath *path = [NSBezierPath bezierPath];
        NSInteger count = MIN(seriesItem.xValues.count, seriesItem.yValues.count);
        for (NSInteger i = 0; i < count; i++) {
            double x = seriesItem.xValues[(NSUInteger)i].doubleValue;
            double y = seriesItem.yValues[(NSUInteger)i].doubleValue;
            CGFloat px = [self mapX:x min:xMin max:xMax rect:plot];
            CGFloat py = [self mapY:y min:yMin max:yMax rect:plot];
            if (i == 0) [path moveToPoint:NSMakePoint(px, py)];
            else [path lineToPoint:NSMakePoint(px, py)];
        }
        path.lineWidth = seriesItem.lineWidth > 0 ? seriesItem.lineWidth : 1.6;
        [seriesItem.color setStroke];
        [path stroke];
    }
    if (cursorTime >= xMin && cursorTime <= xMax) {
        CGFloat x = [self mapX:cursorTime min:xMin max:xMax rect:plot];
        [[NSColor.labelColor colorWithAlphaComponent:0.5] setStroke];
        NSBezierPath *cursor = [NSBezierPath bezierPath];
        CGFloat dash[] = {3.0, 3.0};
        [cursor setLineDash:dash count:2 phase:0];
        [cursor moveToPoint:NSMakePoint(x, plot.origin.y)];
        [cursor lineToPoint:NSMakePoint(x, plot.origin.y + plot.size.height)];
        [cursor stroke];
    }
    NSMutableArray *legend = [NSMutableArray array];
    for (QLSeries *seriesItem in series) {
        [legend addObject:@{@"name": seriesItem.name, @"color": seriesItem.color}];
    }
    [self drawLegendEntries:legend inRect:plot];
}

- (void)drawSpinInRect:(NSRect)plot {
    double t = self.result.times[(NSUInteger)self.frameIndex].doubleValue;
    [self drawSeriesInRect:plot xMin:0 xMax:self.result.tmax yMin:-1.05 yMax:1.05
                    xLabel:@"time" yLabel:@"S" cursorTime:t series:self.result.series];
}

- (void)drawOscillatorPhaseInRect:(NSRect)plot {
    QLSeries *xSeries = [self.result seriesNamed:@"x(t)"];
    QLSeries *pSeries = [self.result seriesNamed:@"p(t)"];
    if (!xSeries || !pSeries) return;
    double xmin = INFINITY, xmax = -INFINITY, pmin = INFINITY, pmax = -INFINITY;
    for (NSInteger i = 0; i < xSeries.yValues.count; i++) {
        double x = xSeries.yValues[(NSUInteger)i].doubleValue;
        xmin = fmin(xmin, x);
        xmax = fmax(xmax, x);
    }
    for (NSInteger i = 0; i < pSeries.yValues.count; i++) {
        double p = pSeries.yValues[(NSUInteger)i].doubleValue;
        pmin = fmin(pmin, p);
        pmax = fmax(pmax, p);
    }
    if (!isfinite(xmin) || !isfinite(pmin)) return;
    double xPad = fmax(0.1, (xmax - xmin) * 0.1);
    double pPad = fmax(0.1, (pmax - pmin) * 0.1);
    xmin -= xPad; xmax += xPad; pmin -= pPad; pmax += pPad;

    [self drawAxesInRect:plot xMin:xmin xMax:xmax yMin:pmin yMax:pmax xLabel:@"x" yLabel:@"p" showGrid:YES];
    NSInteger count = MIN(xSeries.yValues.count, pSeries.yValues.count);
    NSInteger current = MIN(MAX(0, self.frameIndex), count - 1);

    NSBezierPath *full = [NSBezierPath bezierPath];
    for (NSInteger i = 0; i < count; i++) {
        CGFloat px = [self mapX:xSeries.yValues[(NSUInteger)i].doubleValue min:xmin max:xmax rect:plot];
        CGFloat py = [self mapY:pSeries.yValues[(NSUInteger)i].doubleValue min:pmin max:pmax rect:plot];
        if (i == 0) [full moveToPoint:NSMakePoint(px, py)];
        else [full lineToPoint:NSMakePoint(px, py)];
    }
    [[NSColor.systemBlueColor colorWithAlphaComponent:0.22] setStroke];
    full.lineWidth = 2.4;
    [full stroke];

    NSBezierPath *trail = [NSBezierPath bezierPath];
    for (NSInteger i = 0; i <= current; i++) {
        CGFloat px = [self mapX:xSeries.yValues[(NSUInteger)i].doubleValue min:xmin max:xmax rect:plot];
        CGFloat py = [self mapY:pSeries.yValues[(NSUInteger)i].doubleValue min:pmin max:pmax rect:plot];
        if (i == 0) [trail moveToPoint:NSMakePoint(px, py)];
        else [trail lineToPoint:NSMakePoint(px, py)];
    }
    [NSColor.systemBlueColor setStroke];
    trail.lineWidth = 2.0;
    [trail stroke];

    CGFloat px = [self mapX:xSeries.yValues[(NSUInteger)current].doubleValue min:xmin max:xmax rect:plot];
    CGFloat py = [self mapY:pSeries.yValues[(NSUInteger)current].doubleValue min:pmin max:pmax rect:plot];
    [[NSColor systemOrangeColor] setFill];
    NSRectFill(NSMakeRect(px - 4, py - 4, 8, 8));
    [[NSColor whiteColor] setStroke];
    NSBezierPath *marker = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(px - 4, py - 4, 8, 8)];
    [marker stroke];

    NSArray *legend = @[@{@"name": @"trajectory", @"color": NSColor.systemBlueColor},
                        @{@"name": @"current", @"color": NSColor.systemOrangeColor}];
    [self drawLegendEntries:legend inRect:plot];
    double t = self.result.times[(NSUInteger)self.frameIndex].doubleValue;
    QLDrawText([NSString stringWithFormat:@"t = %.3f", t],
               NSMakeRect(plot.origin.x + plot.size.width - 100, plot.origin.y + plot.size.height + 8, 100, 16),
               NSTextAlignmentRight, [NSFont monospacedDigitSystemFontOfSize:10 weight:NSFontWeightRegular],
               NSColor.secondaryLabelColor);
}

- (void)drawOscillatorTimeSeriesInRect:(NSRect)plot {
    QLSeries *xSeries = [self.result seriesNamed:@"x(t)"];
    QLSeries *pSeries = [self.result seriesNamed:@"p(t)"];
    if (!xSeries || !pSeries) return;
    double ymin = INFINITY, ymax = -INFINITY;
    for (NSNumber *v in xSeries.yValues) { ymin = fmin(ymin, v.doubleValue); ymax = fmax(ymax, v.doubleValue); }
    for (NSNumber *v in pSeries.yValues) { ymin = fmin(ymin, v.doubleValue); ymax = fmax(ymax, v.doubleValue); }
    double pad = fmax(0.1, (ymax - ymin) * 0.1);
    double cursorTime = self.result.times[(NSUInteger)self.frameIndex].doubleValue;
    [self drawSeriesInRect:plot xMin:0 xMax:self.result.tmax yMin:ymin - pad yMax:ymax + pad
                    xLabel:@"time" yLabel:@"x, p" cursorTime:cursorTime series:self.result.series];
}

- (NSString *)hoverReadoutForPlot:(NSRect)plot point:(NSPoint)point {
    QLPlotKind kind = [self effectivePlotKind];
    CGFloat normalizedX = (point.x - plot.origin.x) / plot.size.width;
    CGFloat normalizedY = (point.y - plot.origin.y) / plot.size.height;
    normalizedX = fmin(1.0, fmax(0.0, normalizedX));
    normalizedY = fmin(1.0, fmax(0.0, normalizedY));

    if (kind == QLPlotKindWavefunction1D) {
        const double complex *psi = [self.result wavefunctionAtFrame:self.frameIndex];
        if (!psi) return nil;
        NSInteger nx = self.result.nx;
        NSInteger index = MIN(nx - 1, MAX(0, (NSInteger)llround(normalizedX * (nx - 1))));
        double x = -self.result.lx * 0.5 + ((double)index + 0.5) * self.result.lx / (double)nx;
        double density = creal(psi[index] * conj(psi[index]));
        return [NSString stringWithFormat:@"x = %.3f    |ψ|² = %.5g", x, density];
    }
    if (kind == QLPlotKindDensityHeatmap2D) {
        const float *density = [self.result densityAtFrame:self.frameIndex];
        if (!density) return nil;
        NSInteger nx = self.result.nx;
        NSInteger ny = self.result.ny;
        NSInteger ix = MIN(nx - 1, MAX(0, (NSInteger)llround(normalizedX * (nx - 1))));
        NSInteger iy = MIN(ny - 1, MAX(0, (NSInteger)llround((1.0 - normalizedY) * (ny - 1))));
        double x = -self.result.lx * 0.5 + ((double)ix + 0.5) * self.result.lx / (double)nx;
        double y = -self.result.ly * 0.5 + ((double)iy + 0.5) * self.result.ly / (double)ny;
        return [NSString stringWithFormat:@"x = %.2f  y = %.2f    |ψ|² = %.5g", x, y, density[iy * nx + ix]];
    }
    if (kind == QLPlotKindSpinTimeSeries) {
        NSInteger index = MIN(self.result.frameCount - 1, MAX(0, (NSInteger)llround(normalizedX * (self.result.frameCount - 1))));
        QLSeries *sx = [self.result seriesNamed:@"Sx"];
        QLSeries *sy = [self.result seriesNamed:@"Sy"];
        QLSeries *sz = [self.result seriesNamed:@"Sz"];
        if (!sx || !sy || !sz) return nil;
        return [NSString stringWithFormat:@"t = %.3f    Sx %.3f  Sy %.3f  Sz %.3f",
                self.result.times[(NSUInteger)index].doubleValue,
                sx.yValues[(NSUInteger)index].doubleValue,
                sy.yValues[(NSUInteger)index].doubleValue,
                sz.yValues[(NSUInteger)index].doubleValue];
    }
    if (kind == QLPlotKindOscillatorPhase) {
        QLSeries *xSeries = [self.result seriesNamed:@"x(t)"];
        QLSeries *pSeries = [self.result seriesNamed:@"p(t)"];
        if (!xSeries || !pSeries) return nil;
        double xmin = INFINITY, xmax = -INFINITY, pmin = INFINITY, pmax = -INFINITY;
        for (NSNumber *v in xSeries.yValues) { xmin = fmin(xmin, v.doubleValue); xmax = fmax(xmax, v.doubleValue); }
        for (NSNumber *v in pSeries.yValues) { pmin = fmin(pmin, v.doubleValue); pmax = fmax(pmax, v.doubleValue); }
        double xPad = fmax(0.1, (xmax - xmin) * 0.1);
        double pPad = fmax(0.1, (pmax - pmin) * 0.1);
        xmin -= xPad; xmax += xPad; pmin -= pPad; pmax += pPad;
        double x = xmin + normalizedX * (xmax - xmin);
        double p = pmin + normalizedY * (pmax - pmin);
        return [NSString stringWithFormat:@"x = %.3f    p = %.3f", x, p];
    }
    if (kind == QLPlotKindOscillatorTimeSeries) {
        NSInteger index = MIN(self.result.frameCount - 1, MAX(0, (NSInteger)llround(normalizedX * (self.result.frameCount - 1))));
        QLSeries *xSeries = [self.result seriesNamed:@"x(t)"];
        QLSeries *pSeries = [self.result seriesNamed:@"p(t)"];
        if (!xSeries || !pSeries) return nil;
        return [NSString stringWithFormat:@"t = %.3f    x = %.3f    p = %.3f",
                self.result.times[(NSUInteger)index].doubleValue,
                xSeries.yValues[(NSUInteger)index].doubleValue,
                pSeries.yValues[(NSUInteger)index].doubleValue];
    }
    return nil;
}

- (void)drawHoverInRect:(NSRect)plot {
    CGFloat x = _hoverPoint.x;
    CGFloat y = _hoverPoint.y;
    if (x < plot.origin.x || x > plot.origin.x + plot.size.width ||
        y < plot.origin.y || y > plot.origin.y + plot.size.height) {
        return;
    }
    [[NSColor.labelColor colorWithAlphaComponent:0.5] setStroke];
    NSBezierPath *cross = [NSBezierPath bezierPath];
    CGFloat dash[] = {2.0, 3.0};
    [cross setLineDash:dash count:2 phase:0];
    [cross moveToPoint:NSMakePoint(x, plot.origin.y)];
    [cross lineToPoint:NSMakePoint(x, plot.origin.y + plot.size.height)];
    [cross moveToPoint:NSMakePoint(plot.origin.x, y)];
    [cross lineToPoint:NSMakePoint(plot.origin.x + plot.size.width, y)];
    [cross stroke];

    NSString *readout = [self hoverReadoutForPlot:plot point:_hoverPoint];
    if (readout.length == 0) return;
    NSFont *font = [NSFont monospacedDigitSystemFontOfSize:9.5 weight:NSFontWeightRegular];
    NSDictionary *attrs = @{NSFontAttributeName: font, NSForegroundColorAttributeName: NSColor.labelColor};
    NSSize size = [readout sizeWithAttributes:attrs];
    CGFloat labelWidth = size.width + 12;
    CGFloat labelHeight = size.height + 6;
    CGFloat labelX = x + 10;
    CGFloat labelY = y + 10;
    if (labelX + labelWidth > NSMaxX(plot)) labelX = x - labelWidth - 10;
    if (labelY + labelHeight > NSMaxY(plot)) labelY = y - labelHeight - 10;
    NSRect labelRect = NSMakeRect(labelX, labelY, labelWidth, labelHeight);
    NSBezierPath *background = [NSBezierPath bezierPathWithRoundedRect:labelRect xRadius:4 yRadius:4];
    [[NSColor.windowBackgroundColor colorWithAlphaComponent:0.92] setFill];
    [background fill];
    [NSColor.separatorColor setStroke];
    background.lineWidth = 0.5;
    [background stroke];
    [readout drawInRect:NSInsetRect(labelRect, 6, 3) withAttributes:attrs];
}

- (NSImage *)snapshotImage {
    NSBitmapImageRep *rep = [self bitmapImageRepForCachingDisplayInRect:self.bounds];
    [self cacheDisplayInRect:self.bounds toBitmapImageRep:rep];
    NSImage *image = [[NSImage alloc] initWithSize:self.bounds.size];
    [image addRepresentation:rep];
    return image;
}

@end
