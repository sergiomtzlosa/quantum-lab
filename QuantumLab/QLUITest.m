#import "QLUITest.h"

#if DEBUG

#import "AppDelegate.h"
#import "QLMainWindowController.h"
#import "QLParameterDefinition.h"
#import "QLParameterFormView.h"
#import "QLParameterRow.h"
#import "QLSimulationResult.h"
#import "QLPlotStyle.h"
#import "QL2DPlotView.h"
#import "QL3DPlotView.h"
#import "QLColorMap.h"
#import "QLHelpWindowController.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#include <math.h>
#import <objc/message.h>

typedef void (^QLTestContinuation)(void);
typedef void (^QLTestStep)(QLTestContinuation done);

@interface AppDelegate (QLUITestHelpAccess)
- (QLHelpWindowController *)helpController;
- (void)showHelp:(nullable id)sender;
- (void)showQuickStart:(nullable id)sender;
- (void)showShortcuts:(nullable id)sender;
- (void)showTroubleshooting:(nullable id)sender;
@end

@interface QLMainWindowController (QLUITestAccess)
- (void)updateSystemPopup;
- (void)viewChanged:(id)sender;
- (void)resetDefaults:(id)sender;
- (void)rebuildFormForCurrentMode;
- (void)buildOptionsPopover;
- (void)modeChanged:(id)sender;
- (void)variantChanged:(id)sender;
- (void)presetChanged:(id)sender;
- (void)plotTypeChanged:(id)sender;
- (void)optionsChanged:(id)sender;
- (void)showOptions:(id)sender;
- (void)speedChanged:(id)sender;
- (void)frameSliderChanged:(id)sender;
@end

@interface QLParameterRow (QLUITestAccess)
- (void)controlChanged:(id)sender;
@end

@interface QL3DPlotView (QLUITestAccess)
- (void)centerView:(id)sender;
@end

@interface QLUITest ()
- (instancetype)initWithWindowController:(QLMainWindowController *)controller;
- (void)startWithCompletion:(void (^)(BOOL ok))completion;
- (void)runNextStep;
- (void)finish;
- (void)watchdog;
- (NSArray<QLTestStep> *)buildSteps;

- (void)check:(BOOL)condition name:(NSString *)name;
- (void)fail:(NSString *)message;
- (id)value:(NSString *)key;
- (BOOL)boolValue:(NSString *)key;
- (NSInteger)integerValue:(NSString *)key;
- (QLSimulationResult *)result;
- (void)setupMode:(NSInteger)mode variant:(NSInteger)variant;
- (QLParameterRow *)rowForKey:(NSString *)key form:(QLParameterFormView *)form;
- (void)setRow:(NSString *)key form:(QLParameterFormView *)form value:(id)value;
- (NSButton *)findButtonTitled:(NSString *)title inView:(NSView *)view;
- (NSView *)findViewWithIdentifier:(NSString *)identifier inView:(NSView *)view;
- (BOOL)writePNG:(NSImage *)image path:(NSString *)path;
- (BOOL)writeViewSnapshot:(NSView *)view path:(NSString *)path;
- (BOOL)writeCSV:(NSString *)csv path:(NSString *)path;
- (BOOL)menuContainsTitle:(NSString *)title menu:(NSMenu *)menu;
- (NSMenuItem *)menuItemWithTitle:(NSString *)title menu:(NSMenu *)menu;
- (void)afterDelay:(NSTimeInterval)delay completion:(void (^)(void))completion;
- (void)waitForCondition:(BOOL (^)(void))condition
                 timeout:(NSTimeInterval)timeout
              completion:(void (^)(BOOL ok))completion;
- (void)stopPlayback;
- (BOOL)isSolving;
- (void)waitForActiveSolveNamed:(NSString *)name
                        timeout:(NSTimeInterval)timeout
                     completion:(void (^)(BOOL ok))completion;
- (void)solveAndWaitNamed:(NSString *)name
                  timeout:(NSTimeInterval)timeout
               completion:(void (^)(BOOL ok))completion;
- (void)invokeSelector:(SEL)selector;
- (void)invokeSelector:(SEL)selector object:(nullable id)object;
- (void)performAction:(SEL)selector
               object:(nullable id)object
                named:(NSString *)name
              timeout:(NSTimeInterval)timeout
           completion:(void (^)(BOOL ok))completion;

- (void)check1DResult;
- (void)check2DResult;
- (void)checkSpinResult;
- (void)checkOscillatorResult;
- (void)testIconAndChrome;
- (void)exerciseParameterRowsForStage:(NSString *)stage;
- (void)exerciseGroupsForStage:(NSString *)stage;
- (void)testOptionsForStage:(NSString *)stage;
- (void)testViewSwitchingForStage:(NSString *)stage;
- (void)testPlaybackForStage:(NSString *)stage completion:(void (^)(void))completion;
- (void)checkCSVForStage:(NSString *)stage header:(NSString *)header minimumRows:(NSInteger)minimumRows;
- (void)stepInitial:(QLTestContinuation)done;
- (void)stepAbout:(QLTestContinuation)done;
- (void)stepHelp:(QLTestContinuation)done;
- (void)stepSchrodinger1D:(QLTestContinuation)done;
- (void)stepSchrodinger1DInteractions:(QLTestContinuation)done;
- (void)stepSchrodinger1DPreset:(QLTestContinuation)done;
- (void)stepSchrodinger1DReset:(QLTestContinuation)done;
- (void)stepSchrodinger2D:(QLTestContinuation)done;
- (void)stepSchrodinger2DInteractions:(QLTestContinuation)done;
- (void)stepSpin:(QLTestContinuation)done;
- (void)stepSpinInteractions:(QLTestContinuation)done;
- (void)stepOscillator:(QLTestContinuation)done;
- (void)stepOscillatorInteractions:(QLTestContinuation)done;
- (void)stepValidation:(QLTestContinuation)done;
- (void)stepCancellation:(QLTestContinuation)done;
- (void)stepChrome:(QLTestContinuation)done;
- (void)stepFinalSolve:(QLTestContinuation)done;
- (void)stepSavePanels:(QLTestContinuation)done;
- (void)stepPersistence:(QLTestContinuation)done;
@end

static QLUITest *gRunningTest = nil;

@implementation QLUITest {
    QLMainWindowController *_controller;
    NSMutableArray<NSString *> *_failures;
    NSInteger _passed;
    NSInteger _failed;
    NSArray<QLTestStep> *_steps;
    NSUInteger _stepIndex;
    void (^_completion)(BOOL ok);
    BOOL _finished;
}

+ (void)runWithWindowController:(QLMainWindowController *)controller completion:(void (^)(BOOL))completion {
    gRunningTest = [[QLUITest alloc] initWithWindowController:controller];
    [gRunningTest startWithCompletion:completion];
}

- (instancetype)initWithWindowController:(QLMainWindowController *)controller {
    self = [super init];
    if (self) {
        self->_controller = controller;
        _failures = [NSMutableArray array];
        _stepIndex = 0;
    }
    return self;
}

- (void)startWithCompletion:(void (^)(BOOL))completion {
    setvbuf(stdout, NULL, _IONBF, 0);
    _completion = [completion copy];
    printf("QuantumLab UI test\n==================\n");

    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(180.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [weakSelf watchdog];
    });

    _steps = [self buildSteps];
    [self runNextStep];
}

- (NSArray<QLTestStep> *)buildSteps {
    NSMutableArray<QLTestStep> *steps = [NSMutableArray array];
    __weak typeof(self) weakSelf = self;
    [steps addObject:^(QLTestContinuation done) { [weakSelf stepInitial:done]; }];
    [steps addObject:^(QLTestContinuation done) { [weakSelf stepAbout:done]; }];
    [steps addObject:^(QLTestContinuation done) { [weakSelf stepHelp:done]; }];
    [steps addObject:^(QLTestContinuation done) { [weakSelf stepSchrodinger1D:done]; }];
    [steps addObject:^(QLTestContinuation done) { [weakSelf stepSchrodinger1DInteractions:done]; }];
    [steps addObject:^(QLTestContinuation done) { [weakSelf stepSchrodinger1DPreset:done]; }];
    [steps addObject:^(QLTestContinuation done) { [weakSelf stepSchrodinger1DReset:done]; }];
    [steps addObject:^(QLTestContinuation done) { [weakSelf stepSchrodinger2D:done]; }];
    [steps addObject:^(QLTestContinuation done) { [weakSelf stepSchrodinger2DInteractions:done]; }];
    [steps addObject:^(QLTestContinuation done) { [weakSelf stepSpin:done]; }];
    [steps addObject:^(QLTestContinuation done) { [weakSelf stepSpinInteractions:done]; }];
    [steps addObject:^(QLTestContinuation done) { [weakSelf stepOscillator:done]; }];
    [steps addObject:^(QLTestContinuation done) { [weakSelf stepOscillatorInteractions:done]; }];
    [steps addObject:^(QLTestContinuation done) { [weakSelf stepValidation:done]; }];
    [steps addObject:^(QLTestContinuation done) { [weakSelf stepCancellation:done]; }];
    [steps addObject:^(QLTestContinuation done) { [weakSelf stepChrome:done]; }];
    [steps addObject:^(QLTestContinuation done) { [weakSelf stepFinalSolve:done]; }];
    [steps addObject:^(QLTestContinuation done) { [weakSelf stepSavePanels:done]; }];
    [steps addObject:^(QLTestContinuation done) { [weakSelf stepPersistence:done]; }];
    return steps;
}

- (void)runNextStep {
    if (_finished) return;
    if (_stepIndex >= _steps.count) {
        [self finish];
        return;
    }

    QLTestStep step = _steps[_stepIndex++];
    __block BOOL didFinish = NO;
    QLTestContinuation done = ^{
        if (didFinish) return;
        didFinish = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self runNextStep];
        });
    };

    @try {
        step(done);
    } @catch (NSException *exception) {
        [self fail:[NSString stringWithFormat:@"Uncaught UI exception: %@ (%@)", exception.reason,
                    exception.callStackSymbols]];
        done();
    }
}

- (void)watchdog {
    if (_finished) return;
    [self fail:@"UI test watchdog timed out"];
    [self finish];
}

- (void)finish {
    if (_finished) return;
    _finished = YES;

    printf("\n--------------------\n");
    printf("%ld passed, %ld failed\n", (long)_passed, (long)_failed);
    for (NSString *failure in _failures) {
        printf("  FAILED: %s\n", failure.UTF8String);
    }
    fflush(stdout);

    void (^completion)(BOOL) = _completion;
    _completion = nil;
    if (completion) completion(_failed == 0);
}

#pragma mark - Harness helpers

- (void)check:(BOOL)condition name:(NSString *)name {
    if (condition) {
        _passed++;
        printf("  PASS  %s\n", name.UTF8String);
    } else {
        _failed++;
        [_failures addObject:name];
        printf("  FAIL  %s\n", name.UTF8String);
    }
}

- (void)fail:(NSString *)message {
    [self check:NO name:message];
}

- (id)value:(NSString *)key {
    @try {
        return [self->_controller valueForKey:key];
    } @catch (NSException *exception) {
        [self fail:[NSString stringWithFormat:@"KVC %@ threw: %@", key, exception.reason]];
        return nil;
    }
}

- (BOOL)boolValue:(NSString *)key {
    return [[self value:key] boolValue];
}

- (NSInteger)integerValue:(NSString *)key {
    return [[self value:key] integerValue];
}

- (QLSimulationResult *)result {
    id result = [self value:@"result"];
    return [result isKindOfClass:QLSimulationResult.class] ? result : nil;
}

- (void)setupMode:(NSInteger)mode variant:(NSInteger)variant {
    NSSegmentedControl *modeControl = [self value:@"modeSegmented"];
    NSPopUpButton *systemPopup = [self value:@"systemPopup"];
    [self->_controller setValue:@(mode) forKey:@"mode"];
    [modeControl setSelectedSegment:mode];
    [self invokeSelector:@selector(updateSystemPopup)];
    [systemPopup selectItemAtIndex:variant];
    [self->_controller setValue:@(variant) forKey:@"variant"];
    [self invokeSelector:@selector(rebuildFormForCurrentMode)];
    [self->_controller.window displayIfNeeded];
}

- (QLParameterRow *)rowForKey:(NSString *)key form:(QLParameterFormView *)form {
    NSArray<QLParameterRow *> *rows = [form valueForKey:@"rows"];
    for (QLParameterRow *row in rows) {
        if ([row.definition.key isEqualToString:key]) return row;
    }
    return nil;
}

- (void)setRow:(NSString *)key form:(QLParameterFormView *)form value:(id)value {
    QLParameterRow *row = [self rowForKey:key form:form];
    if (!row) {
        [self fail:[NSString stringWithFormat:@"Missing parameter row %@", key]];
        return;
    }
    [row setParameterValue:value];
    ((void (*)(id, SEL, id))objc_msgSend)(row, @selector(controlChanged:), nil);
}

- (NSButton *)findButtonTitled:(NSString *)title inView:(NSView *)view {
    if (!view) return nil;
    if ([view isKindOfClass:NSButton.class] && [((NSButton *)view).title isEqualToString:title]) {
        return (NSButton *)view;
    }
    for (NSView *subview in view.subviews) {
        NSButton *found = [self findButtonTitled:title inView:subview];
        if (found) return found;
    }
    return nil;
}

- (NSView *)findViewWithIdentifier:(NSString *)identifier inView:(NSView *)view {
    if (!view) return nil;
    if ([view.identifier isEqualToString:identifier]) return view;
    for (NSView *subview in view.subviews) {
        NSView *found = [self findViewWithIdentifier:identifier inView:subview];
        if (found) return found;
    }
    return nil;
}

- (BOOL)writePNG:(NSImage *)image path:(NSString *)path {
    if (!image) return NO;
    NSData *tiff = image.TIFFRepresentation;
    if (!tiff) return NO;
    NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData:tiff];
    NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    return png && [png writeToFile:path atomically:YES];
}

- (BOOL)writeViewSnapshot:(NSView *)view path:(NSString *)path {
    if (!view) return NO;
    [view.window displayIfNeeded];
    [view layoutSubtreeIfNeeded];
    NSRect bounds = view.bounds;
    if (bounds.size.width < 1 || bounds.size.height < 1) return NO;
    NSBitmapImageRep *rep = [view bitmapImageRepForCachingDisplayInRect:bounds];
    if (!rep) return NO;
    [view cacheDisplayInRect:bounds toBitmapImageRep:rep];
    NSImage *image = [[NSImage alloc] initWithSize:bounds.size];
    [image addRepresentation:rep];
    return [self writePNG:image path:path];
}

- (BOOL)writeCSV:(NSString *)csv path:(NSString *)path {
    return csv.length > 0 && [csv writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

- (BOOL)menuContainsTitle:(NSString *)title menu:(NSMenu *)menu {
    for (NSMenuItem *item in menu.itemArray) {
        if ([item.title isEqualToString:title]) return YES;
        if (item.submenu && [self menuContainsTitle:title menu:item.submenu]) return YES;
    }
    return NO;
}

- (NSMenuItem *)menuItemWithTitle:(NSString *)title menu:(NSMenu *)menu {
    for (NSMenuItem *item in menu.itemArray) {
        if ([item.title isEqualToString:title]) return item;
        if (item.submenu) {
            NSMenuItem *found = [self menuItemWithTitle:title menu:item.submenu];
            if (found) return found;
        }
    }
    return nil;
}

- (void)afterDelay:(NSTimeInterval)delay completion:(void (^)(void))completion {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), completion);
}

- (void)waitForCondition:(BOOL (^)(void))condition
                 timeout:(NSTimeInterval)timeout
              completion:(void (^)(BOOL ok))completion {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
    __block NSTimer *timer = nil;
    timer = [NSTimer scheduledTimerWithTimeInterval:0.02 repeats:YES block:^(NSTimer *t) {
        if (condition()) {
            [t invalidate];
            completion(YES);
        } else if ([deadline timeIntervalSinceNow] <= 0) {
            [t invalidate];
            completion(NO);
        }
    }];
}

- (void)stopPlayback {
    if ([self boolValue:@"playing"]) {
        [self->_controller togglePlayPressed:nil];
    }
}

- (BOOL)isSolving {
    return [self boolValue:@"isSolving"];
}

- (void)waitForActiveSolveNamed:(NSString *)name
                        timeout:(NSTimeInterval)timeout
                     completion:(void (^)(BOOL ok))completion {
    if (![self isSolving]) {
        [self fail:[NSString stringWithFormat:@"%@ did not start a solve", name]];
        completion(NO);
        return;
    }
    [self waitForCondition:^BOOL { return ![self isSolving]; } timeout:timeout completion:^(BOOL ok) {
        if (!ok) {
            [self fail:[NSString stringWithFormat:@"%@ solve timed out", name]];
        } else {
            [self stopPlayback];
        }
        completion(ok);
    }];
}

- (void)solveAndWaitNamed:(NSString *)name
                  timeout:(NSTimeInterval)timeout
               completion:(void (^)(BOOL ok))completion {
    [self->_controller solvePressed:nil];
    [self waitForActiveSolveNamed:name timeout:timeout completion:completion];
}

- (void)invokeSelector:(SEL)selector {
    ((void (*)(id, SEL))objc_msgSend)(self->_controller, selector);
}

- (void)invokeSelector:(SEL)selector object:(nullable id)object {
    ((void (*)(id, SEL, id))objc_msgSend)(self->_controller, selector, object);
}

- (void)performAction:(SEL)selector
               object:(nullable id)object
                named:(NSString *)name
              timeout:(NSTimeInterval)timeout
           completion:(void (^)(BOOL ok))completion {
    [self invokeSelector:selector object:object];
    [self waitForActiveSolveNamed:name timeout:timeout completion:completion];
}

#pragma mark - Result checks

- (void)check1DResult {
    QLSimulationResult *result = [self result];
    [self check:result != nil name:@"1D result exists"];
    if (!result) return;
    [self check:result.isSchrodinger && !result.is2D name:@"1D result has the right kind"];
    [self check:result.frameCount >= 2 && result.times.count == (NSUInteger)result.frameCount name:@"1D frame metadata is consistent"];
    [self check:[result wavefunctionAtFrame:0] != NULL name:@"1D wavefunction data exists"];
    [self check:result.normValues.count > 0 && fabs(result.normValues.firstObject.doubleValue - 1.0) < 1e-3 name:@"1D initial norm is one"];
    [self check:result.times.lastObject.doubleValue > 0 name:@"1D time series advances"];
}

- (void)check2DResult {
    QLSimulationResult *result = [self result];
    [self check:result != nil name:@"2D result exists"];
    if (!result) return;
    [self check:result.isSchrodinger && result.is2D name:@"2D result has the right kind"];
    [self check:[result densityAtFrame:0] != NULL name:@"2D density data exists"];
    [self check:result.frameCount >= 2 name:@"2D has multiple frames"];
    [self check:result.normValues.count > 0 && fabs(result.normValues.firstObject.doubleValue - 1.0) < 1e-2 name:@"2D initial norm is one"];
}

- (void)checkSpinResult {
    QLSimulationResult *result = [self result];
    [self check:result != nil name:@"Spin result exists"];
    if (!result) return;
    [self check:result.isSpin name:@"Spin result has the right kind"];
    [self check:[result seriesNamed:@"Sx"] && [result seriesNamed:@"Sy"] && [result seriesNamed:@"Sz"] name:@"Spin series exist"];
    [self check:result.normValues.count > 0 && fabs(result.normValues.firstObject.doubleValue - 1.0) < 1e-5 name:@"Spin magnitude is one"];
}

- (void)checkOscillatorResult {
    QLSimulationResult *result = [self result];
    [self check:result != nil name:@"Oscillator result exists"];
    if (!result) return;
    [self check:result.isOscillator name:@"Oscillator result has the right kind"];
    [self check:[result seriesNamed:@"x(t)"] && [result seriesNamed:@"p(t)"] name:@"Oscillator series exist"];
    [self check:result.energyValues.count > 0 name:@"Oscillator energy series exists"];
}

#pragma mark - UI checks

- (void)testIconAndChrome {
    printf("\n-- Bundle, icon, and controls --\n");
    NSWindow *window = self->_controller.window;
    [self check:window != nil name:@"Main window exists"];
    [self check:[window.title isEqualToString:@"QuantumLab"] name:@"Window title is QuantumLab"];
    [self check:window.isVisible name:@"Main window is visible"];
    [self check:window.minSize.width >= 1040 && window.minSize.height >= 680 name:@"Minimum window size is enforced"];

    NSString *iconName = NSBundle.mainBundle.infoDictionary[@"CFBundleIconName"];
    NSString *iconPath = [NSBundle.mainBundle pathForResource:@"AppIcon" ofType:@"icns"];
    NSImage *bundleIcon = [NSWorkspace.sharedWorkspace iconForFile:NSBundle.mainBundle.bundlePath];
    NSImage *applicationIcon = NSApp.applicationIconImage;
    [self check:iconName.length > 0 name:@"Info.plist declares CFBundleIconName"];
    [self check:iconPath.length > 0 name:@"AppIcon.icns is present in the bundle"];
    [self check:bundleIcon != nil name:@"Finder can read the app icon"];
    [self check:applicationIcon != nil name:@"Application icon is active"];
    [self check:[self writePNG:bundleIcon path:@"/tmp/quantumlab-ui-icon.png"] name:@"App icon renders to PNG"];

    NSArray<NSString *> *controlKeys = @[@"form", @"formScroll", @"modeSegmented", @"systemPopup",
                                         @"presetPopup", @"solveButton", @"resetButton", @"progress",
                                         @"sidebarStatus", @"validationLabel", @"viewSegmented",
                                         @"plotTypePopup", @"playButton", @"backButton", @"forwardButton",
                                         @"resetFrameButton", @"frameSlider", @"timeLabel", @"speedPopup",
                                         @"statusLeft", @"statusRight", @"plotContainer", @"plot2D", @"plot3D"];
    for (NSString *key in controlKeys) {
        [self check:[self value:key] != nil name:[NSString stringWithFormat:@"Control %@ exists", key]];
    }

    NSSegmentedControl *mode = [self value:@"modeSegmented"];
    NSPopUpButton *system = [self value:@"systemPopup"];
    NSPopUpButton *preset = [self value:@"presetPopup"];
    NSPopUpButton *speed = [self value:@"speedPopup"];
    [self check:mode.segmentCount == 2 name:@"Mode control has two segments"];
    [self check:system.numberOfItems == 2 name:@"System control has two items"];
    [self check:preset.numberOfItems >= 2 name:@"Preset control has Custom plus presets"];
    [self check:[preset.itemTitles.firstObject isEqualToString:@"Custom"] name:@"Preset control starts with Custom"];
    [self check:speed.numberOfItems == 5 name:@"Speed control has five speeds"];

    QLMainWindowController *controller = self->_controller;
    NSButton *solve = [self value:@"solveButton"];
    NSButton *reset = [self value:@"resetButton"];
    NSButton *play = [self value:@"playButton"];
    NSButton *back = [self value:@"backButton"];
    NSButton *forward = [self value:@"forwardButton"];
    NSButton *resetFrame = [self value:@"resetFrameButton"];
    NSSegmentedControl *view = [self value:@"viewSegmented"];
    NSSlider *slider = [self value:@"frameSlider"];
    NSPopUpButton *plotType = [self value:@"plotTypePopup"];
    [self check:solve.target == controller && solve.action == @selector(solvePressed:) name:@"Solve button is wired"];
    [self check:reset.target == controller && reset.action == @selector(resetDefaults:) name:@"Defaults button is wired"];
    [self check:play.target == controller && play.action == @selector(togglePlayPressed:) name:@"Play button is wired"];
    [self check:back.target == controller && back.action == @selector(stepBackPressed:) name:@"Step-back button is wired"];
    [self check:forward.target == controller && forward.action == @selector(stepForwardPressed:) name:@"Step-forward button is wired"];
    [self check:resetFrame.target == controller && resetFrame.action == @selector(resetSimulationPressed:) name:@"Reset-frame button is wired"];
    [self check:view.target == controller && view.action == @selector(viewChanged:) name:@"2D/3D control is wired"];
    [self check:slider.target == controller && slider.action == @selector(frameSliderChanged:) name:@"Frame slider is wired"];
    [self check:speed.target == controller && speed.action == @selector(speedChanged:) name:@"Speed control is wired"];
    [self check:plotType.target == controller && plotType.action == @selector(plotTypeChanged:) name:@"Plot type control is wired"];
    [self check:mode.target == controller && mode.action == @selector(modeChanged:) name:@"Mode control is wired"];
    [self check:system.target == controller && system.action == @selector(variantChanged:) name:@"System control is wired"];
    [self check:preset.target == controller && preset.action == @selector(presetChanged:) name:@"Preset control is wired"];
    [self check:[solve.keyEquivalent isEqualToString:@"\r"] name:@"Solve button is the default action"];

    [self check:[self findButtonTitled:@"Options" inView:[self value:@"mainPanel"]] != nil name:@"Options button is present"];
    NSButton *optionsButton = [self findButtonTitled:@"Options" inView:[self value:@"mainPanel"]];
    NSButton *pngButton = [self findButtonTitled:@"PNG" inView:[self value:@"mainPanel"]];
    NSButton *csvButton = [self findButtonTitled:@"CSV" inView:[self value:@"mainPanel"]];
    [self check:optionsButton != nil name:@"Options button is present"];
    [self check:pngButton != nil name:@"PNG export button is present"];
    [self check:csvButton != nil name:@"CSV export button is present"];
    [self check:optionsButton.target == controller && optionsButton.action == @selector(showOptions:) name:@"Options button is wired"];
    [self check:pngButton.target == controller && pngButton.action == @selector(exportPNG:) name:@"PNG button is wired"];
    [self check:csvButton.target == controller && csvButton.action == @selector(exportCSV:) name:@"CSV button is wired"];

    QL3DPlotView *plot3D = [self value:@"plot3D"];
    NSButton *center = [self findButtonTitled:@"Center" inView:plot3D];
    [self check:center != nil name:@"3D Center overlay button exists"];
    [self check:center.target == plot3D name:@"Center button targets the 3D view"];
    [self check:center.action == @selector(centerView:) name:@"Center button action is wired"];
    [self check:plot3D.allowsCameraControl name:@"3D camera control is enabled"];

    NSMenu *mainMenu = NSApp.mainMenu;
    [self check:mainMenu != nil name:@"Main menu exists"];
    NSArray<NSString *> *menuTitles = @[@"About QuantumLab", @"Export Plot PNG…", @"Export Data CSV…",
                                       @"Solve", @"Play / Pause", @"Step Back", @"Step Forward",
                                       @"Reset Frame", @"2D Plot", @"3D Plot", @"Toggle Sidebar",
                                       @"Reset 3D Camera", @"QuantumLab Help", @"Quick Start",
                                       @"Keyboard Shortcuts", @"Troubleshooting"];
    for (NSString *title in menuTitles) {
        [self check:[self menuContainsTitle:title menu:mainMenu] name:[NSString stringWithFormat:@"Menu item %@ exists", title]];
    }
    NSDictionary<NSString *, NSString *> *menuActions = @{
        @"Export Plot PNG…": NSStringFromSelector(@selector(exportPNG:)),
        @"Export Data CSV…": NSStringFromSelector(@selector(exportCSV:)),
        @"Solve": NSStringFromSelector(@selector(solvePressed:)),
        @"Play / Pause": NSStringFromSelector(@selector(togglePlayPressed:)),
        @"Step Back": NSStringFromSelector(@selector(stepBackPressed:)),
        @"Step Forward": NSStringFromSelector(@selector(stepForwardPressed:)),
        @"Reset Frame": NSStringFromSelector(@selector(resetSimulationPressed:)),
        @"2D Plot": NSStringFromSelector(@selector(set2DView:)),
        @"3D Plot": NSStringFromSelector(@selector(set3DView:)),
        @"Toggle Sidebar": NSStringFromSelector(@selector(toggleSidebar:)),
        @"Reset 3D Camera": NSStringFromSelector(@selector(resetCamera:)),
        @"QuantumLab Help": NSStringFromSelector(@selector(showHelp:)),
        @"Quick Start": NSStringFromSelector(@selector(showQuickStart:)),
        @"Keyboard Shortcuts": NSStringFromSelector(@selector(showShortcuts:)),
        @"Troubleshooting": NSStringFromSelector(@selector(showTroubleshooting:))
    };
    for (NSString *title in menuActions) {
        NSMenuItem *item = [self menuItemWithTitle:title menu:mainMenu];
        [self check:item.target == NSApp.delegate && [NSStringFromSelector(item.action) isEqualToString:menuActions[title]]
                name:[NSString stringWithFormat:@"Menu action for %@ is wired", title]];
    }
    NSMenuItem *solveMenu = [self menuItemWithTitle:@"Solve" menu:mainMenu];
    NSMenuItem *view2DMenu = [self menuItemWithTitle:@"2D Plot" menu:mainMenu];
    NSMenuItem *view3DMenu = [self menuItemWithTitle:@"3D Plot" menu:mainMenu];
    NSMenuItem *toggleMenu = [self menuItemWithTitle:@"Toggle Sidebar" menu:mainMenu];
    [self check:[solveMenu.keyEquivalent isEqualToString:@"r"] && solveMenu.keyEquivalentModifierMask == NSEventModifierFlagCommand name:@"Solve shortcut is Command-R"];
    [self check:[view2DMenu.keyEquivalent isEqualToString:@"1"] && view2DMenu.keyEquivalentModifierMask == NSEventModifierFlagCommand name:@"2D shortcut is Command-1"];
    [self check:[view3DMenu.keyEquivalent isEqualToString:@"2"] && view3DMenu.keyEquivalentModifierMask == NSEventModifierFlagCommand name:@"3D shortcut is Command-2"];
    [self check:[toggleMenu.keyEquivalent isEqualToString:@"s"] && toggleMenu.keyEquivalentModifierMask == (NSEventModifierFlagCommand | NSEventModifierFlagControl) name:@"Sidebar shortcut is Control-Command-S"];
    NSMenuItem *helpMenu = [self menuItemWithTitle:@"QuantumLab Help" menu:mainMenu];
    [self check:[helpMenu.keyEquivalent isEqualToString:@"?"] && helpMenu.keyEquivalentModifierMask == NSEventModifierFlagCommand name:@"Help shortcut is Command-?"];

    NSMenuItem *exportPNG = [self menuItemWithTitle:@"Export Plot PNG…" menu:mainMenu];
    NSMenuItem *exportCSV = [self menuItemWithTitle:@"Export Data CSV…" menu:mainMenu];
    [self check:exportPNG.action == @selector(exportPNG:) && [exportPNG.keyEquivalent isEqualToString:@"e"] name:@"PNG menu item action and shortcut"];
    [self check:exportCSV.action == @selector(exportCSV:) && [exportCSV.keyEquivalent isEqualToString:@"e"] name:@"CSV menu item action and shortcut"];
    [self check:exportCSV.keyEquivalentModifierMask == (NSEventModifierFlagCommand | NSEventModifierFlagShift) name:@"CSV menu shortcut includes Shift"];
}

- (void)exerciseParameterRowsForStage:(NSString *)stage {
    QLParameterFormView *form = [self value:@"form"];
    NSArray<QLParameterRow *> *rows = [form valueForKey:@"rows"];
    [self check:rows.count > 0 name:[NSString stringWithFormat:@"%@ parameter rows loaded", stage]];

    for (QLParameterRow *row in rows) {
        QLParameterDefinition *definition = row.definition;
        NSString *label = [NSString stringWithFormat:@"%@ %@", stage, definition.key];
        id oldValue = [row parameterValue];
        [self check:oldValue != nil name:[NSString stringWithFormat:@"%@ has a value", label]];
        if (!oldValue) continue;

        [row setParameterValue:oldValue];
        ((void (*)(id, SEL, id))objc_msgSend)(row, @selector(controlChanged:), nil);
        [self check:form.parameterSet.values[definition.key] != nil name:[NSString stringWithFormat:@"%@ round-trips", label]];

        if (definition.type == QLParameterTypeEnum && definition.enumValues.count > 0) {
            for (NSNumber *enumValue in definition.enumValues) {
                [row setParameterValue:enumValue];
                ((void (*)(id, SEL, id))objc_msgSend)(row, @selector(controlChanged:), nil);
                id stored = form.parameterSet.values[definition.key];
                [self check:[stored isEqual:enumValue] name:[NSString stringWithFormat:@"%@ accepts enum %@", label, enumValue]];
            }
        } else if (definition.type == QLParameterTypeBool) {
            for (NSNumber *boolValue in @[@NO, @YES]) {
                [row setParameterValue:boolValue];
                ((void (*)(id, SEL, id))objc_msgSend)(row, @selector(controlChanged:), nil);
                id stored = form.parameterSet.values[definition.key];
                [self check:[stored isEqual:boolValue] name:[NSString stringWithFormat:@"%@ accepts bool %@", label, boolValue]];
            }
        } else if (definition.minValue) {
            double minValue = definition.minValue.doubleValue;
            double invalidValue = minValue - MAX(1.0, fabs(minValue) * 0.01);
            [row setParameterValue:@(invalidValue)];
            ((void (*)(id, SEL, id))objc_msgSend)(row, @selector(controlChanged:), nil);
            [self check:!row.isValid name:[NSString stringWithFormat:@"%@ flags an out-of-range value", label]];
        }

        [row setParameterValue:oldValue];
        ((void (*)(id, SEL, id))objc_msgSend)(row, @selector(controlChanged:), nil);
    }
}

- (void)exerciseGroupsForStage:(NSString *)stage {
    QLParameterFormView *form = [self value:@"form"];
    NSDictionary<NSString *, NSButton *> *headers = [form valueForKey:@"headers"];
    NSDictionary<NSString *, NSArray<QLParameterRow *> *> *rowsByGroup = [form valueForKey:@"rowsByGroup"];
    [self check:headers.count > 0 name:[NSString stringWithFormat:@"%@ groups exist", stage]];
    for (NSString *group in headers) {
        NSButton *header = headers[group];
        if (header.hidden) continue;
        NSArray<QLParameterRow *> *rows = rowsByGroup[group];
        [header performClick:nil];
        BOOL allHidden = YES;
        for (QLParameterRow *row in rows) {
            if (!row.hidden) allHidden = NO;
        }
        [self check:allHidden name:[NSString stringWithFormat:@"%@ collapses %@", stage, group]];
        [header performClick:nil];
        [self check:!header.hidden name:[NSString stringWithFormat:@"%@ expands %@", stage, group]];
    }
}

- (void)testOptionsForStage:(NSString *)stage {
    [self invokeSelector:@selector(buildOptionsPopover)];
    NSPopUpButton *colorMap = [self value:@"colorMapPopup"];
    NSPopUpButton *mesh = [self value:@"meshPopup"];
    NSButton *log = [self value:@"logCheck"];
    NSButton *potential = [self value:@"potentialCheck"];
    NSButton *phase = [self value:@"phaseCheck"];
    NSButton *realImag = [self value:@"realImagCheck"];
    NSButton *autoRotate = [self value:@"autoRotateCheck"];
    QLPlotOptions *options = [self value:@"options"];
    [self check:colorMap && mesh && log && potential && phase && realImag && autoRotate && options
            name:[NSString stringWithFormat:@"%@ options controls exist", stage]];

    for (NSString *name in [QLColorMap colorMapNames]) {
        [colorMap selectItemWithTitle:name];
        [self invokeSelector:@selector(optionsChanged:) object:colorMap];
        [self check:[options.colorMapName isEqualToString:name]
                name:[NSString stringWithFormat:@"%@ color map %@", stage, name]];
    }

    log.state = NSControlStateValueOn;
    potential.state = NSControlStateValueOff;
    phase.state = NSControlStateValueOn;
    realImag.state = NSControlStateValueOn;
    autoRotate.state = NSControlStateValueOn;
    [mesh selectItemWithTitle:@"128"];
    [self invokeSelector:@selector(optionsChanged:) object:nil];
    [self check:options.logScale && !options.showPotential && options.showPhase && options.showRealImag && options.autoRotate
            name:[NSString stringWithFormat:@"%@ toggles options", stage]];
    [self check:options.meshResolution == 128 name:[NSString stringWithFormat:@"%@ changes mesh resolution", stage]];

    [colorMap selectItemWithTitle:@"Viridis"];
    log.state = NSControlStateValueOff;
    potential.state = NSControlStateValueOn;
    phase.state = NSControlStateValueOff;
    realImag.state = NSControlStateValueOff;
    autoRotate.state = NSControlStateValueOff;
    [mesh selectItemWithTitle:@"96"];
    [self invokeSelector:@selector(optionsChanged:) object:nil];
    [self check:[options.colorMapName isEqualToString:@"Viridis"] && !options.logScale && options.showPotential
            name:[NSString stringWithFormat:@"%@ restores options", stage]];

    NSButton *optionsButton = [self findButtonTitled:@"Options" inView:[self value:@"mainPanel"]];
    if (optionsButton) {
        [self invokeSelector:@selector(showOptions:) object:optionsButton];
        NSPopover *popover = [self value:@"optionsPopover"];
        [self check:popover != nil name:[NSString stringWithFormat:@"%@ options popover opens", stage]];
        [popover close];
    }
}

- (void)testViewSwitchingForStage:(NSString *)stage {
    QL2DPlotView *plot2D = [self value:@"plot2D"];
    QL3DPlotView *plot3D = [self value:@"plot3D"];
    [self->_controller set2DView:nil];
    [self check:!plot2D.hidden && plot3D.hidden name:[NSString stringWithFormat:@"%@ switches to 2D", stage]];
    NSInteger frame = [self integerValue:@"frameIndex"];
    [self->_controller set3DView:nil];
    [self check:plot2D.hidden && !plot3D.hidden name:[NSString stringWithFormat:@"%@ switches to 3D", stage]];
    [self check:plot3D.frameIndex == frame name:[NSString stringWithFormat:@"%@ preserves the frame in 3D", stage]];
    [plot3D layoutSubtreeIfNeeded];
    NSButton *center = [self findButtonTitled:@"Center" inView:plot3D];
    if (center) {
        [self check:!center.hidden && center.frame.size.width > 0 && center.frame.size.height > 0
                name:[NSString stringWithFormat:@"%@ Center overlay has a visible frame", stage]];
        [self check:NSContainsRect(plot3D.bounds, center.frame)
                name:[NSString stringWithFormat:@"%@ Center overlay is inside the 3D view", stage]];
        [center performClick:nil];
        [self check:YES name:[NSString stringWithFormat:@"%@ Center button runs without crashing", stage]];
    }
    [self->_controller set2DView:nil];
    [self check:!plot2D.hidden && plot3D.hidden name:[NSString stringWithFormat:@"%@ returns to 2D", stage]];
}

- (void)testPlaybackForStage:(NSString *)stage completion:(void (^)(void))completion {
    [self stopPlayback];
    [self->_controller set2DView:nil];
    [self->_controller resetSimulationPressed:nil];
    NSPopUpButton *speed = [self value:@"speedPopup"];
    [speed selectItemAtIndex:4];
    [self invokeSelector:@selector(speedChanged:) object:speed];
    [self check:fabs([[self value:@"speed"] doubleValue] - 4.0) < 1e-9
            name:[NSString stringWithFormat:@"%@ changes playback speed", stage]];

    [self->_controller resetSimulationPressed:nil];
    [self->_controller togglePlayPressed:nil];
    [self afterDelay:0.35 completion:^{
        [self->_controller togglePlayPressed:nil];
        NSInteger afterPlay = [self integerValue:@"frameIndex"];
        [self check:afterPlay > 0 name:[NSString stringWithFormat:@"%@ playback advances frames", stage]];

        [self->_controller stepBackPressed:nil];
        [self check:[self integerValue:@"frameIndex"] == MAX(0, afterPlay - 1)
                name:[NSString stringWithFormat:@"%@ step back", stage]];
        [self->_controller stepForwardPressed:nil];
        [self check:[self integerValue:@"frameIndex"] == afterPlay
                name:[NSString stringWithFormat:@"%@ step forward", stage]];

        NSSlider *slider = [self value:@"frameSlider"];
        slider.doubleValue = MIN(5, slider.maxValue);
        [self invokeSelector:@selector(frameSliderChanged:) object:slider];
        [self check:[self integerValue:@"frameIndex"] == (NSInteger)llround(slider.doubleValue)
                name:[NSString stringWithFormat:@"%@ frame slider scrubs", stage]];
        [self->_controller resetSimulationPressed:nil];
        [self check:[self integerValue:@"frameIndex"] == 0 name:[NSString stringWithFormat:@"%@ reset frame", stage]];
        [speed selectItemAtIndex:2];
        [self invokeSelector:@selector(speedChanged:) object:speed];
        completion();
    }];
}

- (void)checkCSVForStage:(NSString *)stage header:(NSString *)header minimumRows:(NSInteger)minimumRows {
    NSString *csv = [self value:@"csvString"];
    [self check:[csv hasPrefix:header] name:[NSString stringWithFormat:@"%@ CSV header", stage]];
    NSArray<NSString *> *lines = [csv componentsSeparatedByString:@"\n"];
    [self check:lines.count >= minimumRows + 1 name:[NSString stringWithFormat:@"%@ CSV row count", stage]];
    [self check:[self writeCSV:csv path:[NSString stringWithFormat:@"/tmp/quantumlab-ui-%@.csv", stage]]
            name:[NSString stringWithFormat:@"%@ CSV writes to disk", stage]];
}

#pragma mark - Async steps

- (void)stepInitial:(QLTestContinuation)done {
    [self testIconAndChrome];
    done();
}

- (void)stepAbout:(QLTestContinuation)done {
    NSArray<NSWindow *> *before = NSApp.windows;
    [NSApp orderFrontStandardAboutPanel:nil];
    [self afterDelay:0.2 completion:^{
        NSWindow *about = nil;
        for (NSWindow *window in NSApp.windows) {
            if (![before containsObject:window] && window.isVisible) {
                about = window;
                break;
            }
        }
        [self check:about != nil name:@"About QuantumLab panel opens"];
        if (about) [about orderOut:nil];
        done();
    }];
}

- (void)stepHelp:(QLTestContinuation)done {
    printf("\n-- Help --\n");
    AppDelegate *delegate = (AppDelegate *)NSApp.delegate;
    [delegate showHelp:nil];
    [self afterDelay:0.35 completion:^{
        QLHelpWindowController *help = [delegate helpController];
        NSWindow *window = help.window;
        [self check:help != nil name:@"Help controller is created"];
        [self check:window != nil && window.isVisible name:@"Help window opens"];
        if (!help || !window) {
            done();
            return;
        }

        [self check:[window.title isEqualToString:@"QuantumLab Help"] name:@"Help window has the expected title"];
        [self check:window.minSize.width >= 800 && window.minSize.height >= 500 name:@"Help window has a sensible minimum size"];
        [self check:[window.frameAutosaveName isEqualToString:@"QuantumLabHelpWindow"] name:@"Help window restores its frame"];
        [self check:window.contentView != nil && NSWidth(window.contentView.bounds) > 0 && NSHeight(window.contentView.bounds) > 0 name:@"Help content view has a nonzero size"];
        [window.contentView layoutSubtreeIfNeeded];

        NSView *searchView = [self findViewWithIdentifier:@"help.search" inView:window.contentView];
        NSView *tableView = [self findViewWithIdentifier:@"help.topics" inView:window.contentView];
        NSView *bodyView = [self findViewWithIdentifier:@"help.body" inView:window.contentView];
        NSView *titleView = [self findViewWithIdentifier:@"help.topic.title" inView:window.contentView];
        NSView *noResultsView = [self findViewWithIdentifier:@"help.noresults" inView:window.contentView];
        [self check:[searchView isKindOfClass:NSSearchField.class] name:@"Help search field exists"];
        [self check:[tableView isKindOfClass:NSTableView.class] name:@"Help topic table exists"];
        [self check:[bodyView isKindOfClass:NSTextView.class] name:@"Help content text view exists"];
        [self check:[titleView isKindOfClass:NSTextField.class] name:@"Help topic header exists"];
        [self check:[noResultsView isKindOfClass:NSTextField.class] name:@"Help no-results label exists"];

        NSSearchField *searchField = (NSSearchField *)searchView;
        NSTableView *topicTable = (NSTableView *)tableView;
        NSTextView *textView = (NSTextView *)bodyView;
        [self check:(id)searchField.delegate == (id)help name:@"Help search is wired to the controller"];
        [self check:(id)topicTable.delegate == (id)help && (id)topicTable.dataSource == (id)help name:@"Help topic table is wired to the controller"];
        [self check:(id)textView.delegate == (id)help name:@"Help content view is wired to the controller"];

        NSArray<NSString *> *expectedTopics = @[QLHelpTopicWelcome, QLHelpTopicQuickStart, QLHelpTopicInterface,
                                                QLHelpTopicSchrodinger1D, QLHelpTopicSchrodinger2D, QLHelpTopicSpin,
                                                QLHelpTopicOscillator, QLHelpTopicViews, QLHelpTopicOptions,
                                                QLHelpTopicPlayback, QLHelpTopicExport, QLHelpTopicPhysics,
                                                QLHelpTopicShortcuts, QLHelpTopicTroubleshooting];
        NSArray<NSString *> *identifiers = help.topicIdentifiers;
        [self check:identifiers.count == expectedTopics.count name:@"Help exposes every topic"];
        [self check:[NSSet setWithArray:identifiers].count == identifiers.count name:@"Help topic identifiers are unique"];
        for (NSString *identifier in expectedTopics) {
            [self check:[identifiers containsObject:identifier] name:[NSString stringWithFormat:@"Help includes %@", identifier]];
        }
        [self check:[help.selectedTopicIdentifier isEqualToString:QLHelpTopicWelcome] name:@"Help starts on the Welcome topic"];
        [self check:topicTable.numberOfRows > 0 name:@"Help sidebar lists topics"];

        [help focusSearch];
        [self check:searchField.currentEditor != nil name:@"Help focuses its search field"];

        NSUInteger topicIndex = 0;
        for (NSString *identifier in identifiers) {
            BOOL selected = [help selectTopicWithIdentifier:identifier];
            [self check:selected name:[NSString stringWithFormat:@"Help selects %@", identifier]];
            [self check:[help.selectedTopicIdentifier isEqualToString:identifier] name:[NSString stringWithFormat:@"Help marks %@ selected", identifier]];
            NSString *content = help.currentContentText;
            [self check:content.length > 150 name:[NSString stringWithFormat:@"Help topic %@ has content", identifier]];
            [self check:[content rangeOfString:@"TODO"].location == NSNotFound name:[NSString stringWithFormat:@"Help topic %@ has no placeholder", identifier]];
            [self check:[titleView isKindOfClass:NSTextField.class] && ((NSTextField *)titleView).stringValue.length > 0 name:[NSString stringWithFormat:@"Help topic %@ has a header", identifier]];
            topicIndex++;
        }
        [self check:topicIndex == identifiers.count name:@"Help checked every topic"];
        [self check:window.isVisible name:@"Help stays open while browsing topics"];

        [help selectTopicWithIdentifier:QLHelpTopicWelcome];
        [help searchForText:@"bloch"];
        [window.contentView layoutSubtreeIfNeeded];
        [self check:help.visibleTopicIdentifiers.count > 0 name:@"Help search returns results for Bloch"];
        [self check:[help.visibleTopicIdentifiers containsObject:QLHelpTopicSpin] name:@"Help search finds the spin topic"];
        [self check:[help.selectedTopicIdentifier isEqualToString:QLHelpTopicSpin] name:@"Help selects the best search match"];
        [self check:[help.currentContentText rangeOfString:@"Bloch" options:NSCaseInsensitiveSearch].location != NSNotFound name:@"Help search result contains the query"];
        __block NSInteger highlightRuns = 0;
        [textView.textStorage enumerateAttribute:NSBackgroundColorAttributeName
                                        inRange:NSMakeRange(0, textView.textStorage.length)
                                        options:0
                                     usingBlock:^(id value, NSRange range, BOOL *stop) {
            if (value) highlightRuns++;
        }];
        [self check:highlightRuns > 0 name:@"Help highlights search matches"];
        [self check:[self writeViewSnapshot:window.contentView path:@"/tmp/quantumlab-ui-help-search.png"]
                name:@"Help search snapshot writes"];

        [help searchForText:@"orbit"];
        [self check:help.visibleTopicIdentifiers.count >= 2 name:@"Help search matches multiple topics"];
        [help searchForText:@"zzzz-no-such-topic"];
        [self check:help.visibleTopicIdentifiers.count == 0 name:@"Help handles a search with no results"];
        [self check:help.selectedTopicIdentifier.length == 0 name:@"Help clears selection when nothing matches"];
        [self check:[help.currentContentText rangeOfString:@"Nothing found"].location != NSNotFound name:@"Help shows a no-results state"];
        [self check:!searchField.hidden && searchField.stringValue.length > 0 name:@"Help preserves the no-results query"];
        [self check:[self writeViewSnapshot:window.contentView path:@"/tmp/quantumlab-ui-help-empty.png"]
                name:@"Help empty-state snapshot writes"];
        [help searchForText:@""];
        [self check:help.visibleTopicIdentifiers.count == identifiers.count name:@"Clearing search restores every topic"];
        [self check:[help.selectedTopicIdentifier isEqualToString:QLHelpTopicWelcome] name:@"Clearing search restores the topic from before the search"];

        [help searchForText:@"zzzz-no-such-topic"];
        __block NSURL *clearURL = nil;
        [textView.textStorage enumerateAttribute:NSLinkAttributeName
                                        inRange:NSMakeRange(0, textView.textStorage.length)
                                        options:0
                                     usingBlock:^(id value, NSRange range, BOOL *stop) {
            NSURL *url = [value isKindOfClass:NSURL.class] ? value : nil;
            if ([url.scheme isEqualToString:@"qlhelp"] && [url.host isEqualToString:@"action"] &&
                [url.path containsString:@"clear-search"]) {
                clearURL = url;
                *stop = YES;
            }
        }];
        [self check:clearURL != nil name:@"Help empty state offers a clear-search link"];
        if (clearURL) {
            BOOL handledClear = [help handleHelpURL:clearURL];
            [self check:handledClear name:@"Help handles the clear-search link"];
            [self check:searchField.stringValue.length == 0 name:@"Clear-search link empties the field"];
            [self check:[help.selectedTopicIdentifier isEqualToString:QLHelpTopicWelcome] name:@"Clear-search link restores the pre-search topic"];
        }

        [help selectTopicWithIdentifier:QLHelpTopicWelcome];
        __block NSURL *topicURL = nil;
        [textView.textStorage enumerateAttribute:NSLinkAttributeName
                                        inRange:NSMakeRange(0, textView.textStorage.length)
                                        options:0
                                     usingBlock:^(id value, NSRange range, BOOL *stop) {
            NSURL *url = [value isKindOfClass:NSURL.class] ? value : nil;
            if ([url.scheme isEqualToString:@"qlhelp"] && [url.host isEqualToString:@"topic"]) {
                NSString *path = [url.path stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];
                if (![path isEqualToString:QLHelpTopicWelcome]) {
                    topicURL = url;
                    *stop = YES;
                }
            }
        }];
        [self check:topicURL != nil name:@"Help content contains topic links"];
        if (topicURL) {
            NSString *expectedTopic = [topicURL.path stringByTrimmingCharactersInSet:
                                       [NSCharacterSet characterSetWithCharactersInString:@"/"]];
            BOOL handled = [help handleHelpURL:topicURL];
            [self check:handled name:@"Help handles a topic link"];
            [self check:[help.selectedTopicIdentifier isEqualToString:expectedTopic] name:@"Help topic link navigates"];
        }

        [help selectTopicWithIdentifier:QLHelpTopicWelcome];
        [window.contentView layoutSubtreeIfNeeded];
        [self check:[self writeViewSnapshot:window.contentView path:@"/tmp/quantumlab-ui-help-welcome.png"]
                name:@"Help welcome snapshot writes"];
        [help selectTopicWithIdentifier:QLHelpTopicShortcuts];
        [window.contentView layoutSubtreeIfNeeded];
        [self check:[self writeViewSnapshot:window.contentView path:@"/tmp/quantumlab-ui-help-shortcuts.png"]
                name:@"Help shortcuts snapshot writes"];

        [delegate showQuickStart:nil];
        [self check:[help.selectedTopicIdentifier isEqualToString:QLHelpTopicQuickStart] name:@"Quick Start menu selects its topic"];
        [delegate showShortcuts:nil];
        [self check:[help.selectedTopicIdentifier isEqualToString:QLHelpTopicShortcuts] name:@"Shortcuts menu selects its topic"];
        [delegate showTroubleshooting:nil];
        [self check:[help.selectedTopicIdentifier isEqualToString:QLHelpTopicTroubleshooting] name:@"Troubleshooting menu selects its topic"];

        NSMenuItem *quickStartItem = [self menuItemWithTitle:@"Quick Start" menu:NSApp.mainMenu];
        NSMenuItem *shortcutsItem = [self menuItemWithTitle:@"Keyboard Shortcuts" menu:NSApp.mainMenu];
        [help selectTopicWithIdentifier:QLHelpTopicWelcome];
        BOOL sentQuickStart = [NSApp sendAction:quickStartItem.action to:quickStartItem.target from:quickStartItem];
        [self check:sentQuickStart && [help.selectedTopicIdentifier isEqualToString:QLHelpTopicQuickStart]
                name:@"Quick Start routes through the menu target"];
        BOOL sentShortcuts = [NSApp sendAction:shortcutsItem.action to:shortcutsItem.target from:shortcutsItem];
        [self check:sentShortcuts && [help.selectedTopicIdentifier isEqualToString:QLHelpTopicShortcuts]
                name:@"Shortcuts routes through the menu target"];

        NSSplitView *splitView = [help valueForKey:@"splitView"];
        NSView *sidebarView = [help valueForKey:@"sidebarView"];
        [self check:splitView != nil && sidebarView != nil name:@"Help split view and sidebar exist"];
        [self check:NSWidth(sidebarView.frame) >= 230 && NSWidth(sidebarView.frame) <= 340 name:@"Help sidebar width is constrained"];
        id<NSSplitViewDelegate> splitDelegate = splitView.delegate;
        if ([splitDelegate respondsToSelector:@selector(splitView:constrainMinCoordinate:ofSubviewAt:)]) {
            CGFloat minimum = [splitDelegate splitView:splitView constrainMinCoordinate:0 ofSubviewAt:0];
            CGFloat maximum = [splitDelegate splitView:splitView constrainMaxCoordinate:100000 ofSubviewAt:0];
            [self check:minimum >= 230 && maximum <= 340 name:@"Help divider keeps the sidebar readable"];
        }

        NSRect originalFrame = window.frame;
        [window setFrame:NSMakeRect(120, 120, window.minSize.width, window.minSize.height) display:YES];
        [window.contentView layoutSubtreeIfNeeded];
        [self check:NSWidth(textView.frame) > 100 && NSHeight(textView.frame) > 100 name:@"Help lays out at its minimum size"];
        NSView *sidebarAtMin = [help valueForKey:@"sidebarView"];
        [self check:NSWidth(sidebarAtMin.frame) >= 230 name:@"Help keeps its sidebar usable at the minimum window size"];
        NSAppearance *oldAppearance = window.appearance;
        window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
        [help selectTopicWithIdentifier:QLHelpTopicWelcome];
        [window displayIfNeeded];
        [self check:help.currentContentText.length > 0 name:@"Help keeps content in dark mode"];
        [self check:[self writeViewSnapshot:window.contentView path:@"/tmp/quantumlab-ui-help-dark.png"]
                name:@"Help dark-mode snapshot writes"];
        window.appearance = oldAppearance;
        [window setFrame:originalFrame display:YES];
        [window.contentView layoutSubtreeIfNeeded];

        [help selectTopicWithIdentifier:QLHelpTopicSpin];
        __block NSURL *presetURL = nil;
        [textView.textStorage enumerateAttribute:NSLinkAttributeName
                                        inRange:NSMakeRange(0, textView.textStorage.length)
                                        options:0
                                     usingBlock:^(id value, NSRange range, BOOL *stop) {
            NSURL *url = [value isKindOfClass:NSURL.class] ? value : nil;
            if ([url.scheme isEqualToString:@"qlhelp"] && [url.host isEqualToString:@"preset"]) {
                presetURL = url;
                *stop = YES;
            }
        }];
        [self check:presetURL != nil name:@"Help content contains preset links"];
        if (!presetURL) {
            presetURL = [NSURL URLWithString:@"qlhelp://preset?name=Spin%20precession&mode=1&variant=0"];
        }
        BOOL handledPreset = [help handleHelpURL:presetURL];
        [self check:handledPreset name:@"Help handles a preset link"];
        [self check:!window.isVisible name:@"A preset link closes Help"];
        [self check:[[self value:@"mode"] integerValue] == QLSimulationModeHeisenberg name:@"A preset link switches to Heisenberg"];
        [self check:[[self value:@"variant"] integerValue] == 0 name:@"A preset link selects the spin system"];
        [self check:[[self value:@"presetPopup"] indexOfSelectedItem] > 0 name:@"A preset link selects a real preset"];
        [self waitForActiveSolveNamed:@"help preset" timeout:20.0 completion:^(BOOL ok) {
            [self check:ok name:@"A help preset starts a solve"];
            if (ok) [self checkSpinResult];
            if (help.window.isVisible) [help.window orderOut:nil];
            done();
        }];
    }];
}

- (void)stepSchrodinger1D:(QLTestContinuation)done {
    printf("\n-- Schrödinger 1D --\n");
    [self setupMode:0 variant:0];
    [self->_controller runDefaultSimulation];
    [self waitForActiveSolveNamed:@"default launch" timeout:10.0 completion:^(BOOL ok) {
        if (ok) [self check1DResult];
        done();
    }];
}

- (void)stepSchrodinger1DInteractions:(QLTestContinuation)done {
    QLParameterFormView *form = [self value:@"form"];
    [self setRow:@"potential" form:form value:@0];
    [self check:![[self rowForKey:@"v0" form:form] isVisibleForValues:form.parameterSet.values] name:@"1D free potential hides V0"];
    [self setRow:@"potential" form:form value:@2];
    [self check:[[self rowForKey:@"v0" form:form] isVisibleForValues:form.parameterSet.values] name:@"1D barrier shows V0"];
    [self check:[[self rowForKey:@"barrierWidth" form:form] isVisibleForValues:form.parameterSet.values] name:@"1D barrier shows width"];
    [self setRow:@"potential" form:form value:@1];
    [self check:[[self rowForKey:@"omega" form:form] isVisibleForValues:form.parameterSet.values] name:@"1D harmonic shows omega"];
    [self check:![[self rowForKey:@"v0" form:form] isVisibleForValues:form.parameterSet.values] name:@"1D harmonic hides V0"];
    [self setRow:@"potential" form:form value:@0];

    [self exerciseParameterRowsForStage:@"1D"];
    [self exerciseGroupsForStage:@"1D"];
    [self testOptionsForStage:@"1D"];
    [self testViewSwitchingForStage:@"1D"];
    if (![self result]) {
        done();
        return;
    }
    [self testPlaybackForStage:@"1D" completion:^{
        [self->_controller set2DView:nil];
        QL2DPlotView *lineView = [self value:@"plot2D"];
        NSImage *snapshot2D = [lineView snapshotImage];
        [self check:[self writePNG:snapshot2D path:@"/tmp/quantumlab-ui-1d-2d.png"] name:@"1D 2D plot renders"];
        [self->_controller set3DView:nil];
        [self afterDelay:0.4 completion:^{
            QL3DPlotView *surfaceView = [self value:@"plot3D"];
            NSImage *snapshot3D = [surfaceView snapshot];
            [self check:[self writePNG:snapshot3D path:@"/tmp/quantumlab-ui-1d-3d.png"] name:@"1D 3D surface renders"];
            [self->_controller set2DView:nil];
            QLSimulationResult *result = [self result];
            [self checkCSVForStage:@"1d" header:@"time,x,re,im,density" minimumRows:result.nx];
            done();
        }];
    }];
}

- (void)stepSchrodinger1DPreset:(QLTestContinuation)done {
    NSPopUpButton *preset = [self value:@"presetPopup"];
    if (preset.numberOfItems <= 2) {
        done();
        return;
    }
    [preset selectItemAtIndex:2];
    [self performAction:@selector(presetChanged:) object:preset named:@"1D preset" timeout:10.0 completion:^(BOOL ok) {
        if (ok) [self check1DResult];
        done();
    }];
}

- (void)stepSchrodinger1DReset:(QLTestContinuation)done {
    [self setupMode:0 variant:0];
    [self solveAndWaitNamed:@"1D reset" timeout:10.0 completion:^(BOOL ok) {
        if (ok) [self check1DResult];
        done();
    }];
}

- (void)stepSchrodinger2D:(QLTestContinuation)done {
    printf("\n-- Schrödinger 2D --\n");
    [self setupMode:0 variant:1];
    NSPopUpButton *system = [self value:@"systemPopup"];
    [system selectItemAtIndex:1];
    [self performAction:@selector(variantChanged:) object:system named:@"2D" timeout:30.0 completion:^(BOOL ok) {
        if (ok) [self check2DResult];
        done();
    }];
}

- (void)stepSchrodinger2DInteractions:(QLTestContinuation)done {
    QLParameterFormView *form = [self value:@"form"];
    [self setRow:@"potential" form:form value:@6];
    [self check:[[self rowForKey:@"v0" form:form] isVisibleForValues:form.parameterSet.values] name:@"2D double slit shows V0"];
    [self check:[[self rowForKey:@"wallThickness" form:form] isVisibleForValues:form.parameterSet.values] name:@"2D double slit shows wall thickness"];
    [self check:[[self rowForKey:@"slitSeparation" form:form] isVisibleForValues:form.parameterSet.values] name:@"2D double slit shows slit separation"];
    [self check:![[self rowForKey:@"wellRadius" form:form] isVisibleForValues:form.parameterSet.values] name:@"2D double slit hides well radius"];
    [self setRow:@"potential" form:form value:@7];
    [self check:[[self rowForKey:@"wellRadius" form:form] isVisibleForValues:form.parameterSet.values] name:@"2D circular well shows radius"];
    [self check:![[self rowForKey:@"wallThickness" form:form] isVisibleForValues:form.parameterSet.values] name:@"2D circular well hides wall thickness"];
    [self setRow:@"potential" form:form value:@0];

    [self exerciseParameterRowsForStage:@"2D"];
    [self exerciseGroupsForStage:@"2D"];
    [self testOptionsForStage:@"2D"];
    [self testViewSwitchingForStage:@"2D"];
    if (![self result]) {
        done();
        return;
    }
    [self testPlaybackForStage:@"2D" completion:^{
        [self->_controller set2DView:nil];
        [self->_controller set3DView:nil];
        [self afterDelay:0.5 completion:^{
            QL3DPlotView *surfaceView = [self value:@"plot3D"];
            NSImage *snapshot3D = [surfaceView snapshot];
            [self check:[self writePNG:snapshot3D path:@"/tmp/quantumlab-ui-2d-3d.png"] name:@"2D density surface renders"];
            [self->_controller set2DView:nil];
            QLSimulationResult *result = [self result];
            [self checkCSVForStage:@"2d" header:@"x,y,density" minimumRows:result.nx * result.ny];
            done();
        }];
    }];
}

- (void)stepSpin:(QLTestContinuation)done {
    printf("\n-- Heisenberg spin --\n");
    NSSegmentedControl *mode = [self value:@"modeSegmented"];
    [mode setSelectedSegment:1];
    [self performAction:@selector(modeChanged:) object:mode named:@"Spin" timeout:10.0 completion:^(BOOL ok) {
        if (ok) [self checkSpinResult];
        done();
    }];
}

- (void)stepSpinInteractions:(QLTestContinuation)done {
    [self exerciseParameterRowsForStage:@"Spin"];
    [self exerciseGroupsForStage:@"Spin"];
    [self testOptionsForStage:@"Spin"];
    [self testViewSwitchingForStage:@"Spin"];

    QLParameterFormView *form = [self value:@"form"];
    [self setRow:@"driveAmp" form:form value:@0.0];
    [self check:![[self rowForKey:@"driveFreq" form:form] isVisibleForValues:form.parameterSet.values]
            name:@"Spin drive fields hide at zero drive"];
    [self setRow:@"driveAmp" form:form value:@0.3];
    [self check:[[self rowForKey:@"driveFreq" form:form] isVisibleForValues:form.parameterSet.values]
            name:@"Spin drive fields show with drive"];
    [self setRow:@"driveAmp" form:form value:@0.0];

    if (![self result]) {
        done();
        return;
    }
    [self testPlaybackForStage:@"Spin" completion:^{
        [self->_controller set3DView:nil];
        [self afterDelay:0.4 completion:^{
            QL3DPlotView *surfaceView = [self value:@"plot3D"];
            NSImage *snapshot3D = [surfaceView snapshot];
            [self check:[self writePNG:snapshot3D path:@"/tmp/quantumlab-ui-spin-3d.png"] name:@"Bloch sphere renders"];
            QLSimulationResult *result = [self result];
            [self checkCSVForStage:@"spin" header:@"t,Sx,Sy,Sz,|S|" minimumRows:result.frameCount];
            done();
        }];
    }];
}

- (void)stepOscillator:(QLTestContinuation)done {
    printf("\n-- Heisenberg oscillator --\n");
    NSPopUpButton *system = [self value:@"systemPopup"];
    [system selectItemAtIndex:1];
    [self performAction:@selector(variantChanged:) object:system named:@"Oscillator" timeout:10.0 completion:^(BOOL ok) {
        if (ok) [self checkOscillatorResult];
        done();
    }];
}

- (void)stepOscillatorInteractions:(QLTestContinuation)done {
    [self exerciseParameterRowsForStage:@"Oscillator"];
    [self exerciseGroupsForStage:@"Oscillator"];
    [self testOptionsForStage:@"Oscillator"];
    [self testViewSwitchingForStage:@"Oscillator"];

    NSPopUpButton *plotType = [self value:@"plotTypePopup"];
    [self check:!plotType.hidden name:@"Oscillator plot type control is visible"];
    [plotType selectItemAtIndex:1];
    [self invokeSelector:@selector(plotTypeChanged:) object:plotType];
    [self check:[self boolValue:@"oscillatorTimeSeries"] name:@"Oscillator time-series plot selected"];
    [plotType selectItemAtIndex:0];
    [self invokeSelector:@selector(plotTypeChanged:) object:plotType];
    [self check:![self boolValue:@"oscillatorTimeSeries"] name:@"Oscillator phase portrait selected"];

    if (![self result]) {
        done();
        return;
    }
    [self testPlaybackForStage:@"Oscillator" completion:^{
        [self->_controller set3DView:nil];
        [self afterDelay:0.4 completion:^{
            QL3DPlotView *surfaceView = [self value:@"plot3D"];
            NSImage *snapshot3D = [surfaceView snapshot];
            [self check:[self writePNG:snapshot3D path:@"/tmp/quantumlab-ui-oscillator-3d.png"] name:@"Oscillator 3D curve renders"];
            [self->_controller set2DView:nil];
            QLSimulationResult *result = [self result];
            [self checkCSVForStage:@"oscillator" header:@"t,x,p,energy" minimumRows:result.frameCount];
            done();
        }];
    }];
}

- (void)stepValidation:(QLTestContinuation)done {
    printf("\n-- Validation --\n");
    [self setupMode:0 variant:0];
    QLParameterFormView *form = [self value:@"form"];
    QLParameterRow *nxRow = [self rowForKey:@"nx" form:form];
    id oldNX = [nxRow parameterValue];
    [self setRow:@"nx" form:form value:@100];
    [self check:form.allValid name:@"Invalid non-power-of-two is accepted by the row range check"];
    [self->_controller solvePressed:nil];
    [self check:![self isSolving] name:@"Invalid configuration does not start a solve"];
    NSTextField *validation = [self value:@"validationLabel"];
    [self check:!validation.hidden && validation.stringValue.length > 0 name:@"Invalid configuration shows a message"];

    [self setRow:@"nx" form:form value:@0];
    [self check:!form.allValid name:@"Out-of-range value is rejected by the form"];
    [self->_controller solvePressed:nil];
    [self check:![self isSolving] name:@"Out-of-range form does not start a solve"];
    [self setRow:@"nx" form:form value:oldNX ?: @512];
    [self check:form.allValid name:@"Valid grid size restores form validity"];
    [self solveAndWaitNamed:@"1D recovery" timeout:10.0 completion:^(BOOL ok) {
        if (ok) [self check1DResult];
        done();
    }];
}

- (void)stepCancellation:(QLTestContinuation)done {
    printf("\n-- Cancellation and chrome --\n");
    [self setupMode:0 variant:1];
    QLParameterFormView *form = [self value:@"form"];
    [self setRow:@"nx" form:form value:@512];
    [self setRow:@"ny" form:form value:@512];
    [self setRow:@"frames" form:form value:@20];
    [self->_controller solvePressed:nil];
    [self check:[self isSolving] name:@"Large 2D solve starts"];
    [self afterDelay:0.1 completion:^{
        [self check:[self isSolving] name:@"Large 2D solve is still running before cancel"];
        [self->_controller solvePressed:nil];
        [self waitForCondition:^BOOL { return ![self isSolving]; } timeout:8.0 completion:^(BOOL ok) {
            [self check:ok name:@"Cancellation finishes"];
            [self stopPlayback];
            NSTextField *validation = [self value:@"validationLabel"];
            [self check:!validation.hidden && [validation.stringValue.lowercaseString containsString:@"cancel"]
                    name:@"Cancellation reports a cancel message"];
            done();
        }];
    }];
}

- (void)stepChrome:(QLTestContinuation)done {
    [self setupMode:0 variant:0];
    NSView *sidebar = [self value:@"sidebar"];
    BOOL sidebarHidden = sidebar.hidden;
    [self->_controller toggleSidebar:nil];
    [self check:sidebar.hidden != sidebarHidden name:@"Sidebar hides"];
    [self->_controller toggleSidebar:nil];
    [self check:sidebar.hidden == sidebarHidden name:@"Sidebar restores"];

    NSScrollView *scroll = [self value:@"formScroll"];
    NSClipView *clipView = scroll.contentView;
    NSPoint top = clipView.bounds.origin;
    [clipView scrollToPoint:NSMakePoint(top.x, NSMaxY(scroll.documentView.bounds) - NSHeight(clipView.bounds))];
    [scroll reflectScrolledClipView:clipView];
    [clipView scrollToPoint:top];
    [scroll reflectScrolledClipView:clipView];
    [self check:scroll.hasVerticalScroller name:@"Parameter form has a vertical scroller"];

    NSWindow *window = self->_controller.window;
    NSRect savedFrame = window.frame;
    [window setFrame:NSMakeRect(savedFrame.origin.x, savedFrame.origin.y, 1040, 680) display:YES];
    [self check:window.frame.size.width >= 1039 && window.frame.size.height >= 679 name:@"Window resizes to its minimum"];
    [window setFrame:savedFrame display:YES];

    NSAppearance *savedAppearance = NSApp.appearance;
    NSApp.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    [self afterDelay:0.2 completion:^{
        QL3DPlotView *plot3D = [self value:@"plot3D"];
        [self check:plot3D.backgroundColor != nil name:@"3D view survives dark appearance"];
        NSApp.appearance = savedAppearance;
        [self afterDelay:0.1 completion:^{
            [self check:((QL3DPlotView *)[self value:@"plot3D"]).backgroundColor != nil name:@"3D view survives appearance restore"];
            [self->_controller set2DView:nil];
            QL2DPlotView *plot2D = [self value:@"plot2D"];
            [plot2D layoutSubtreeIfNeeded];
            NSPoint local = NSMakePoint(NSMidX(plot2D.bounds), NSMidY(plot2D.bounds));
            NSPoint windowPoint = [plot2D convertPoint:local toView:nil];
            NSEvent *mouse = [NSEvent mouseEventWithType:NSEventTypeMouseMoved
                                               location:windowPoint
                                          modifierFlags:0
                                              timestamp:[NSProcessInfo processInfo].systemUptime
                                           windowNumber:window.windowNumber
                                                context:nil
                                            eventNumber:0
                                             clickCount:0
                                               pressure:0];
            @try {
                [plot2D mouseMoved:mouse];
                [plot2D clearHover];
                [plot2D mouseExited:mouse];
                [self check:YES name:@"2D hover handling runs without crashing"];
            } @catch (NSException *exception) {
                [self check:NO name:[NSString stringWithFormat:@"2D hover handling threw: %@", exception.reason]];
            }
            done();
        }];
    }];
}

- (void)stepFinalSolve:(QLTestContinuation)done {
    [self setupMode:0 variant:0];
    [self solveAndWaitNamed:@"final 1D" timeout:10.0 completion:^(BOOL ok) {
        if (ok) [self check1DResult];
        done();
    }];
}

- (void)stepSavePanels:(QLTestContinuation)done {
    printf("\n-- Export save panels --\n");
    if (![self result]) {
        [self fail:@"Save-panel test has a result"];
        done();
        return;
    }
    NSWindow *window = self->_controller.window;
    [self->_controller exportPNG:nil];
    [self afterDelay:0.25 completion:^{
        NSSavePanel *pngPanel = [window.attachedSheet isKindOfClass:NSSavePanel.class]
            ? (NSSavePanel *)window.attachedSheet : nil;
        [self check:pngPanel != nil name:@"PNG save panel opens"];
        [self check:[pngPanel.allowedContentTypes containsObject:UTTypePNG] name:@"PNG save panel accepts PNG"];
        [pngPanel cancel:nil];
        [self afterDelay:0.2 completion:^{
            [self check:window.attachedSheet == nil name:@"PNG save panel closes"];
            [self->_controller exportCSV:nil];
            [self afterDelay:0.25 completion:^{
                NSSavePanel *csvPanel = [window.attachedSheet isKindOfClass:NSSavePanel.class]
                    ? (NSSavePanel *)window.attachedSheet : nil;
                [self check:csvPanel != nil name:@"CSV save panel opens"];
                [self check:[csvPanel.allowedContentTypes containsObject:UTTypeCommaSeparatedText] name:@"CSV save panel accepts CSV"];
                [csvPanel cancel:nil];
                [self afterDelay:0.2 completion:^{
                    [self check:window.attachedSheet == nil name:@"CSV save panel closes"];
                    done();
                }];
            }];
        }];
    }];
}

- (void)stepPersistence:(QLTestContinuation)done {
    printf("\n-- Persistence --\n");
    [self->_controller persistState];
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [self check:[defaults integerForKey:@"QLStateVersion"] == 1 name:@"State version is written"];
    [self check:[defaults integerForKey:@"QLStateMode"] == 0 name:@"State mode is written"];
    NSDictionary *parameters = [defaults dictionaryForKey:@"QLStateParameters"];
    [self check:parameters.count > 0 name:@"State parameters are written"];
    [self check:[defaults objectForKey:@"QLStateColorMap"] != nil name:@"State plot options are written"];

    QLMainWindowController *loaded = [[QLMainWindowController alloc] init];
    QLParameterFormView *loadedForm = [loaded valueForKey:@"form"];
    [self check:[[loaded valueForKey:@"mode"] integerValue] == 0 name:@"Saved mode restores"];
    [self check:[[loaded valueForKey:@"variant"] integerValue] == 0 name:@"Saved variant restores"];
    [self check:[loadedForm.parameterSet.values[@"dimension"] integerValue] == 0 name:@"Saved parameters restore"];
    [self check:[loaded valueForKey:@"plot2D"] != nil && [loaded valueForKey:@"plot3D"] != nil name:@"Restored window has plot views"];
    [loaded.window close];
    done();
}

@end

#else

@implementation QLUITest

+ (void)runWithWindowController:(QLMainWindowController *)controller completion:(void (^)(BOOL ok))completion {
    if (completion) completion(NO);
}

@end

#endif
