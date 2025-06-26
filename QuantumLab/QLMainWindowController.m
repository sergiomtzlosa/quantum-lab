#import "QLMainWindowController.h"
#import "QL2DPlotView.h"
#import "QL3DPlotView.h"
#import "QLColorMap.h"
#import "QLHeisenbergSolver.h"
#import "QLParameterCatalog.h"
#import "QLPlotStyle.h"
#import "QLSchrodingerSolver.h"
#import "QLSimulationConfig.h"
#import "QLSimulationResult.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#include <complex.h>
#include <math.h>

@interface QLCancelToken : NSObject
@property (atomic, getter=isCancelled) BOOL cancelled;
@end
@implementation QLCancelToken
@end

@interface QLWindowBackgroundView : NSView
@end

@implementation QLWindowBackgroundView
- (BOOL)isOpaque { return YES; }
- (void)drawRect:(NSRect)dirtyRect {
    [NSColor.windowBackgroundColor setFill];
    NSRectFill(dirtyRect);
}
- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];
    [self setNeedsDisplay:YES];
}
@end

@interface QLMainWindowController () <NSWindowDelegate>
@end

@implementation QLMainWindowController {
    NSSplitView *_splitView;
    NSView *_sidebar;
    NSView *_mainPanel;
    QLParameterFormView *_form;
    NSScrollView *_formScroll;
    NSSegmentedControl *_modeSegmented;
    NSPopUpButton *_systemPopup;
    NSPopUpButton *_presetPopup;
    NSButton *_solveButton;
    NSButton *_resetButton;
    NSProgressIndicator *_progress;
    NSTextField *_sidebarStatus;
    NSTextField *_validationLabel;

    NSSegmentedControl *_viewSegmented;
    NSPopUpButton *_plotTypePopup;
    NSButton *_playButton;
    NSButton *_backButton;
    NSButton *_forwardButton;
    NSButton *_resetFrameButton;
    NSSlider *_frameSlider;
    NSTextField *_timeLabel;
    NSPopUpButton *_speedPopup;
    NSTextField *_statusLeft;
    NSTextField *_statusRight;
    NSView *_plotContainer;
    QL2DPlotView *_plot2D;
    QL3DPlotView *_plot3D;

    NSPopover *_optionsPopover;
    NSPopUpButton *_colorMapPopup;
    NSPopUpButton *_meshPopup;
    NSButton *_logCheck;
    NSButton *_potentialCheck;
    NSButton *_phaseCheck;
    NSButton *_realImagCheck;
    NSButton *_autoRotateCheck;

    QLSimulationMode _mode;
    NSInteger _variant;
    QLSimulationResult *_result;
    QLPlotOptions *_options;
    NSInteger _frameIndex;
    NSTimer *_playTimer;
    BOOL _playing;
    double _playAccumulator;
    double _speed;
    BOOL _isSolving;
    BOOL _pendingSolve;
    NSInteger _generation;
    QLCancelToken *_cancelToken;
    id _keyMonitor;
    NSDictionary<NSString *, id> *_savedParameterValues;
    BOOL _savedView3D;
    NSInteger _savedSpeedIndex;
    BOOL _oscillatorTimeSeries;
}

- (instancetype)init {
    NSRect frame = NSMakeRect(0, 0, 1280, 820);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                                              NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable)
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.title = @"QuantumLab";
    window.minSize = NSMakeSize(1040, 680);
    window.frameAutosaveName = @"QuantumLabMainWindow";
    window.delegate = self;
    [window center];
    self = [super initWithWindow:window];
    if (self) {
        _mode = QLSimulationModeSchrodinger;
        _variant = 0;
        _speed = 1.0;
        _options = [QLPlotOptions new];
        [self loadPersistedState];
        [self buildUI];
        _modeSegmented.selectedSegment = _mode;
        [self updateSystemPopup];
        [_systemPopup selectItemAtIndex:_variant];
        [self rebuildFormForCurrentMode];
        if (_savedParameterValues.count > 0) {
            QLParameterSet *saved = [[QLParameterSet alloc] initWithDictionary:_savedParameterValues];
            NSArray<QLParameterDefinition *> *defs = [QLParameterCatalog definitionsForMode:_mode variant:_variant];
            [saved applyDefaults:defs];
            [_form reloadWithDefinitions:defs parameters:saved];
            [_presetPopup selectItemAtIndex:0];
        }
        [self applyPersistedViewState];
        _keyMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown
                                                            handler:^NSEvent *(NSEvent *event) {
            if (event.window != self.window) return event;
            if ((event.modifierFlags & NSEventModifierFlagCommand) != 0) return event;
            id responder = self.window.firstResponder;
            if ([responder isKindOfClass:NSTextView.class] || [responder isKindOfClass:NSControl.class]) return event;
            if (event.keyCode == 49) {
                [self togglePlayPressed:nil];
                return nil;
            }
            if (event.keyCode == 123) {
                [self stepBackPressed:nil];
                return nil;
            }
            if (event.keyCode == 124) {
                [self stepForwardPressed:nil];
                return nil;
            }
            return event;
        }];
    }
    return self;
}

- (void)dealloc {
    if (_keyMonitor) [NSEvent removeMonitor:_keyMonitor];
    [_playTimer invalidate];
}

- (void)windowWillClose:(NSNotification *)notification {
    [self saveState];
    [_playTimer invalidate];
    _playTimer = nil;
    _generation++;
    _cancelToken.cancelled = YES;
}

- (void)persistState {
    [self saveState];
}

- (void)loadPersistedState {
    _savedSpeedIndex = 2;
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if ([defaults integerForKey:@"QLStateVersion"] != 1) return;

    NSInteger mode = [defaults integerForKey:@"QLStateMode"];
    NSInteger variant = [defaults integerForKey:@"QLStateVariant"];
    if (mode == QLSimulationModeSchrodinger || mode == QLSimulationModeHeisenberg) {
        _mode = (QLSimulationMode)mode;
        if (variant >= 0 && variant <= 1) _variant = variant;
    }
    _savedParameterValues = [defaults dictionaryForKey:@"QLStateParameters"];

    NSString *colorMap = [defaults stringForKey:@"QLStateColorMap"];
    if (colorMap.length > 0) _options.colorMapName = colorMap;
    _options.logScale = [defaults boolForKey:@"QLStateLogScale"];
    if ([defaults objectForKey:@"QLStateShowPotential"]) _options.showPotential = [defaults boolForKey:@"QLStateShowPotential"];
    if ([defaults objectForKey:@"QLStateShowPhase"]) _options.showPhase = [defaults boolForKey:@"QLStateShowPhase"];
    if ([defaults objectForKey:@"QLStateShowRealImag"]) _options.showRealImag = [defaults boolForKey:@"QLStateShowRealImag"];
    _options.autoRotate = [defaults boolForKey:@"QLStateAutoRotate"];
    NSInteger mesh = [defaults integerForKey:@"QLStateMeshResolution"];
    if (mesh == 64 || mesh == 96 || mesh == 128 || mesh == 192) _options.meshResolution = mesh;
    if ([defaults objectForKey:@"QLState3D"]) _savedView3D = [defaults boolForKey:@"QLState3D"];
    if ([defaults objectForKey:@"QLStateSpeed"]) _savedSpeedIndex = [defaults integerForKey:@"QLStateSpeed"];
    if ([defaults objectForKey:@"QLStateOscillatorTimeSeries"]) _oscillatorTimeSeries = [defaults boolForKey:@"QLStateOscillatorTimeSeries"];
}

- (void)applyPersistedViewState {
    _viewSegmented.selectedSegment = _savedView3D ? 1 : 0;
    _plot3D.hidden = !_savedView3D;
    _plot2D.hidden = _savedView3D;
    [_speedPopup selectItemAtIndex:MIN(MAX(0, _savedSpeedIndex), 4)];
    [self speedChanged:nil];
    [_plotTypePopup selectItemAtIndex:_oscillatorTimeSeries ? 1 : 0];
}

- (void)saveState {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setInteger:1 forKey:@"QLStateVersion"];
    [defaults setInteger:_mode forKey:@"QLStateMode"];
    [defaults setInteger:_variant forKey:@"QLStateVariant"];

    NSMutableDictionary *values = [NSMutableDictionary dictionary];
    for (NSString *key in _form.parameterSet.values) {
        id value = _form.parameterSet.values[key];
        if ([value isKindOfClass:NSNumber.class] || [value isKindOfClass:NSString.class]) {
            values[key] = value;
        }
    }
    [defaults setObject:values forKey:@"QLStateParameters"];
    [defaults setObject:(_options.colorMapName ?: @"Viridis") forKey:@"QLStateColorMap"];
    [defaults setBool:_options.logScale forKey:@"QLStateLogScale"];
    [defaults setBool:_options.showPotential forKey:@"QLStateShowPotential"];
    [defaults setBool:_options.showPhase forKey:@"QLStateShowPhase"];
    [defaults setBool:_options.showRealImag forKey:@"QLStateShowRealImag"];
    [defaults setBool:_options.autoRotate forKey:@"QLStateAutoRotate"];
    [defaults setInteger:_options.meshResolution forKey:@"QLStateMeshResolution"];
    [defaults setBool:(_viewSegmented.selectedSegment == 1) forKey:@"QLState3D"];
    [defaults setInteger:_speedPopup.indexOfSelectedItem forKey:@"QLStateSpeed"];
    [defaults setBool:_oscillatorTimeSeries forKey:@"QLStateOscillatorTimeSeries"];
}

#pragma mark - UI construction

- (void)buildUI {
    NSView *content = self.window.contentView;
    content.wantsLayer = YES;

    _splitView = [[NSSplitView alloc] initWithFrame:content.bounds];
    _splitView.vertical = YES;
    _splitView.dividerStyle = NSSplitViewDividerStyleThin;
    _splitView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [content addSubview:_splitView];

    NSVisualEffectView *sidebar = [[NSVisualEffectView alloc] initWithFrame:NSMakeRect(0, 0, 350, NSHeight(content.bounds))];
    sidebar.material = NSVisualEffectMaterialSidebar;
    sidebar.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    sidebar.state = NSVisualEffectStateActive;
    sidebar.autoresizingMask = NSViewHeightSizable;
    _sidebar = sidebar;

    NSView *main = [[QLWindowBackgroundView alloc] initWithFrame:NSMakeRect(351, 0, NSWidth(content.bounds) - 351, NSHeight(content.bounds))];
    main.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    _mainPanel = main;

    [_splitView addSubview:sidebar];
    [_splitView addSubview:main];
    [_splitView setPosition:350 ofDividerAtIndex:0];
    [self buildSidebar];
    [self buildMainPanel];
}

- (void)buildSidebar {
    NSTextField *title = [NSTextField labelWithString:@"QUANTUMLAB"];
    title.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
    title.textColor = NSColor.secondaryLabelColor;

    NSTextField *subtitle = [NSTextField labelWithString:@"Schrödinger · Heisenberg"];
    subtitle.font = [NSFont systemFontOfSize:9.5];
    subtitle.textColor = NSColor.tertiaryLabelColor;

    _modeSegmented = [NSSegmentedControl segmentedControlWithLabels:@[@"Schrödinger", @"Heisenberg"]
                                                     trackingMode:NSSegmentSwitchTrackingSelectOne
                                                           target:self
                                                           action:@selector(modeChanged:)];
    _modeSegmented.selectedSegment = 0;
    _modeSegmented.controlSize = NSControlSizeSmall;

    _systemPopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    _systemPopup.controlSize = NSControlSizeSmall;
    _systemPopup.font = [NSFont systemFontOfSize:11.5];
    _systemPopup.target = self;
    _systemPopup.action = @selector(variantChanged:);
    [_systemPopup addItemsWithTitles:@[@"1D", @"2D"]];

    _presetPopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    _presetPopup.controlSize = NSControlSizeSmall;
    _presetPopup.font = [NSFont systemFontOfSize:10.5];
    _presetPopup.target = self;
    _presetPopup.action = @selector(presetChanged:);

    NSTextField *units = [NSTextField labelWithString:@"Natural units · every solver parameter editable"];
    units.font = [NSFont systemFontOfSize:9];
    units.textColor = NSColor.tertiaryLabelColor;
    units.maximumNumberOfLines = 2;
    units.lineBreakMode = NSLineBreakByWordWrapping;

    _form = [[QLParameterFormView alloc] initWithFrame:NSZeroRect];
    _form.delegate = self;
    _form.translatesAutoresizingMaskIntoConstraints = NO;

    _formScroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    _formScroll.translatesAutoresizingMaskIntoConstraints = NO;
    _formScroll.hasVerticalScroller = YES;
    _formScroll.autohidesScrollers = NO;
    _formScroll.scrollerStyle = NSScrollerStyleLegacy;
    _formScroll.drawsBackground = NO;
    _formScroll.borderType = NSNoBorder;
    _formScroll.documentView = _form;

    NSView *clip = _formScroll.contentView;
    [NSLayoutConstraint activateConstraints:@[
        [_form.leadingAnchor constraintEqualToAnchor:clip.leadingAnchor],
        [_form.topAnchor constraintEqualToAnchor:clip.topAnchor],
        [_form.widthAnchor constraintEqualToAnchor:clip.widthAnchor]
    ]];

    _solveButton = [NSButton buttonWithTitle:@"Solve" target:self action:@selector(solvePressed:)];
    _solveButton.bezelStyle = NSBezelStyleRounded;
    _solveButton.controlSize = NSControlSizeLarge;
    _solveButton.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
    _solveButton.keyEquivalent = @"\r";

    _resetButton = [NSButton buttonWithTitle:@"Defaults" target:self action:@selector(resetDefaults:)];
    _resetButton.bezelStyle = NSBezelStyleRounded;
    _resetButton.font = [NSFont systemFontOfSize:11];

    NSStackView *buttonRow = [NSStackView stackViewWithViews:@[_solveButton, _resetButton]];
    buttonRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    buttonRow.spacing = 8;
    [_resetButton.widthAnchor constraintEqualToConstant:78].active = YES;
    [_solveButton setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];

    _progress = [[NSProgressIndicator alloc] initWithFrame:NSZeroRect];
    _progress.style = NSProgressIndicatorStyleBar;
    _progress.indeterminate = NO;
    _progress.minValue = 0;
    _progress.maxValue = 1;
    _progress.doubleValue = 0;
    _progress.hidden = YES;
    _progress.translatesAutoresizingMaskIntoConstraints = NO;
    [_progress.heightAnchor constraintEqualToConstant:4].active = YES;

    _sidebarStatus = [NSTextField labelWithString:@"Ready"];
    _sidebarStatus.font = [NSFont systemFontOfSize:9.5];
    _sidebarStatus.textColor = NSColor.secondaryLabelColor;
    _sidebarStatus.maximumNumberOfLines = 3;
    _sidebarStatus.lineBreakMode = NSLineBreakByWordWrapping;

    _validationLabel = [NSTextField labelWithString:@""];
    _validationLabel.font = [NSFont systemFontOfSize:9.5];
    _validationLabel.textColor = NSColor.systemRedColor;
    _validationLabel.maximumNumberOfLines = 3;
    _validationLabel.lineBreakMode = NSLineBreakByWordWrapping;
    _validationLabel.hidden = YES;

    NSStackView *topStack = [NSStackView stackViewWithViews:@[title, subtitle, _modeSegmented, _systemPopup, _presetPopup, units]];
    topStack.orientation = NSUserInterfaceLayoutOrientationVertical;
    topStack.alignment = NSLayoutAttributeLeading;
    topStack.spacing = 6;
    topStack.translatesAutoresizingMaskIntoConstraints = NO;
    [_modeSegmented.widthAnchor constraintEqualToAnchor:topStack.widthAnchor].active = YES;
    [_systemPopup.widthAnchor constraintEqualToAnchor:topStack.widthAnchor].active = YES;
    [_presetPopup.widthAnchor constraintEqualToAnchor:topStack.widthAnchor].active = YES;

    NSStackView *bottomStack = [NSStackView stackViewWithViews:@[buttonRow, _progress, _sidebarStatus, _validationLabel]];
    bottomStack.orientation = NSUserInterfaceLayoutOrientationVertical;
    bottomStack.alignment = NSLayoutAttributeWidth;
    bottomStack.spacing = 7;
    bottomStack.translatesAutoresizingMaskIntoConstraints = NO;
    [buttonRow.widthAnchor constraintEqualToAnchor:bottomStack.widthAnchor].active = YES;

    [_sidebar addSubview:topStack];
    [_sidebar addSubview:_formScroll];
    [_sidebar addSubview:bottomStack];
    [NSLayoutConstraint activateConstraints:@[
        [topStack.topAnchor constraintEqualToAnchor:_sidebar.topAnchor constant:14],
        [topStack.leadingAnchor constraintEqualToAnchor:_sidebar.leadingAnchor constant:16],
        [topStack.trailingAnchor constraintEqualToAnchor:_sidebar.trailingAnchor constant:-16],
        [_formScroll.topAnchor constraintEqualToAnchor:topStack.bottomAnchor constant:12],
        [_formScroll.leadingAnchor constraintEqualToAnchor:_sidebar.leadingAnchor],
        [_formScroll.trailingAnchor constraintEqualToAnchor:_sidebar.trailingAnchor],
        [_formScroll.bottomAnchor constraintEqualToAnchor:bottomStack.topAnchor constant:-10],
        [bottomStack.leadingAnchor constraintEqualToAnchor:_sidebar.leadingAnchor constant:16],
        [bottomStack.trailingAnchor constraintEqualToAnchor:_sidebar.trailingAnchor constant:-16],
        [bottomStack.bottomAnchor constraintEqualToAnchor:_sidebar.bottomAnchor constant:-14]
    ]];
}

- (void)buildMainPanel {
    _viewSegmented = [NSSegmentedControl segmentedControlWithLabels:@[@"2D", @"3D"]
                                                     trackingMode:NSSegmentSwitchTrackingSelectOne
                                                           target:self
                                                           action:@selector(viewChanged:)];
    _viewSegmented.selectedSegment = 0;
    _viewSegmented.controlSize = NSControlSizeSmall;
    [_viewSegmented.widthAnchor constraintEqualToConstant:92].active = YES;

    _plotTypePopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [_plotTypePopup addItemsWithTitles:@[@"Phase Portrait", @"Time Series"]];
    _plotTypePopup.controlSize = NSControlSizeSmall;
    _plotTypePopup.font = [NSFont systemFontOfSize:11];
    _plotTypePopup.target = self;
    _plotTypePopup.action = @selector(plotTypeChanged:);
    _plotTypePopup.hidden = YES;
    [_plotTypePopup.widthAnchor constraintEqualToConstant:120].active = YES;

    NSView *spacer = [[NSView alloc] initWithFrame:NSZeroRect];
    [spacer setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];

    NSButton *optionsButton = [NSButton buttonWithTitle:@"Options" target:self action:@selector(showOptions:)];
    optionsButton.bezelStyle = NSBezelStyleRounded;
    optionsButton.controlSize = NSControlSizeSmall;
    optionsButton.font = [NSFont systemFontOfSize:11];

    NSButton *pngButton = [NSButton buttonWithTitle:@"PNG" target:self action:@selector(exportPNG:)];
    pngButton.bezelStyle = NSBezelStyleRounded;
    pngButton.controlSize = NSControlSizeSmall;
    pngButton.font = [NSFont systemFontOfSize:11];

    NSButton *csvButton = [NSButton buttonWithTitle:@"CSV" target:self action:@selector(exportCSV:)];
    csvButton.bezelStyle = NSBezelStyleRounded;
    csvButton.controlSize = NSControlSizeSmall;
    csvButton.font = [NSFont systemFontOfSize:11];

    NSStackView *topRow = [NSStackView stackViewWithViews:@[_viewSegmented, _plotTypePopup, spacer, optionsButton, pngButton, csvButton]];
    topRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    topRow.spacing = 8;
    topRow.translatesAutoresizingMaskIntoConstraints = NO;

    _playButton = [NSButton buttonWithTitle:@"Play" target:self action:@selector(togglePlayPressed:)];
    _playButton.bezelStyle = NSBezelStyleRounded;
    _playButton.controlSize = NSControlSizeSmall;
    _playButton.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    [_playButton.widthAnchor constraintEqualToConstant:58].active = YES;

    _backButton = [NSButton buttonWithTitle:@"◀" target:self action:@selector(stepBackPressed:)];
    _backButton.bezelStyle = NSBezelStyleRounded;
    _backButton.controlSize = NSControlSizeSmall;
    [_backButton.widthAnchor constraintEqualToConstant:30].active = YES;

    _forwardButton = [NSButton buttonWithTitle:@"▶" target:self action:@selector(stepForwardPressed:)];
    _forwardButton.bezelStyle = NSBezelStyleRounded;
    _forwardButton.controlSize = NSControlSizeSmall;
    [_forwardButton.widthAnchor constraintEqualToConstant:30].active = YES;

    _resetFrameButton = [NSButton buttonWithTitle:@"Reset" target:self action:@selector(resetSimulationPressed:)];
    _resetFrameButton.bezelStyle = NSBezelStyleRounded;
    _resetFrameButton.controlSize = NSControlSizeSmall;
    _resetFrameButton.font = [NSFont systemFontOfSize:11];
    [_resetFrameButton.widthAnchor constraintEqualToConstant:56].active = YES;

    _frameSlider = [[NSSlider alloc] initWithFrame:NSZeroRect];
    _frameSlider.minValue = 0;
    _frameSlider.maxValue = 1;
    _frameSlider.doubleValue = 0;
    _frameSlider.continuous = YES;
    _frameSlider.target = self;
    _frameSlider.action = @selector(frameSliderChanged:);
    [_frameSlider setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];

    _timeLabel = [NSTextField labelWithString:@"t = 0.000 / 0.000"];
    _timeLabel.font = [NSFont monospacedDigitSystemFontOfSize:10 weight:NSFontWeightRegular];
    _timeLabel.textColor = NSColor.secondaryLabelColor;
    [_timeLabel.widthAnchor constraintEqualToConstant:122].active = YES;

    _speedPopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [_speedPopup addItemsWithTitles:@[@"0.25×", @"0.5×", @"1×", @"2×", @"4×"]];
    [_speedPopup selectItemAtIndex:2];
    _speedPopup.controlSize = NSControlSizeSmall;
    _speedPopup.font = [NSFont systemFontOfSize:10.5];
    _speedPopup.target = self;
    _speedPopup.action = @selector(speedChanged:);
    [_speedPopup.widthAnchor constraintEqualToConstant:66].active = YES;

    NSStackView *playRow = [NSStackView stackViewWithViews:@[_playButton, _backButton, _forwardButton, _resetFrameButton, _frameSlider, _timeLabel, _speedPopup]];
    playRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    playRow.spacing = 7;
    playRow.translatesAutoresizingMaskIntoConstraints = NO;

    NSStackView *topContainer = [NSStackView stackViewWithViews:@[topRow, playRow]];
    topContainer.orientation = NSUserInterfaceLayoutOrientationVertical;
    topContainer.alignment = NSLayoutAttributeWidth;
    topContainer.spacing = 8;
    topContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [_mainPanel addSubview:topContainer];

    _statusLeft = [NSTextField labelWithString:@"Ready"];
    _statusLeft.font = [NSFont monospacedDigitSystemFontOfSize:9.5 weight:NSFontWeightRegular];
    _statusLeft.textColor = NSColor.secondaryLabelColor;
    _statusLeft.lineBreakMode = NSLineBreakByTruncatingTail;
    _statusLeft.translatesAutoresizingMaskIntoConstraints = NO;

    _statusRight = [NSTextField labelWithString:@""];
    _statusRight.font = [NSFont monospacedDigitSystemFontOfSize:9.5 weight:NSFontWeightRegular];
    _statusRight.textColor = NSColor.tertiaryLabelColor;
    _statusRight.alignment = NSTextAlignmentRight;
    _statusRight.lineBreakMode = NSLineBreakByTruncatingHead;
    _statusRight.translatesAutoresizingMaskIntoConstraints = NO;

    NSVisualEffectView *statusBar = [[NSVisualEffectView alloc] initWithFrame:NSZeroRect];
    statusBar.translatesAutoresizingMaskIntoConstraints = NO;
    statusBar.material = NSVisualEffectMaterialHeaderView;
    statusBar.blendingMode = NSVisualEffectBlendingModeWithinWindow;
    statusBar.state = NSVisualEffectStateActive;
    [statusBar addSubview:_statusLeft];
    [statusBar addSubview:_statusRight];
    [_mainPanel addSubview:statusBar];

    _plotContainer = [[NSView alloc] initWithFrame:NSZeroRect];
    _plotContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [_mainPanel addSubview:_plotContainer];

    _plot2D = [[QL2DPlotView alloc] initWithFrame:NSZeroRect];
    _plot2D.translatesAutoresizingMaskIntoConstraints = NO;
    _plot2D.options = _options;
    [_plotContainer addSubview:_plot2D];

    _plot3D = [[QL3DPlotView alloc] initWithFrame:NSZeroRect];
    _plot3D.translatesAutoresizingMaskIntoConstraints = NO;
    _plot3D.options = _options;
    _plot3D.hidden = YES;
    [_plotContainer addSubview:_plot3D];

    [NSLayoutConstraint activateConstraints:@[
        [topContainer.topAnchor constraintEqualToAnchor:_mainPanel.topAnchor constant:12],
        [topContainer.leadingAnchor constraintEqualToAnchor:_mainPanel.leadingAnchor constant:12],
        [topContainer.trailingAnchor constraintEqualToAnchor:_mainPanel.trailingAnchor constant:-12],

        [_plotContainer.topAnchor constraintEqualToAnchor:topContainer.bottomAnchor constant:8],
        [_plotContainer.leadingAnchor constraintEqualToAnchor:_mainPanel.leadingAnchor constant:12],
        [_plotContainer.trailingAnchor constraintEqualToAnchor:_mainPanel.trailingAnchor constant:-12],
        [_plotContainer.bottomAnchor constraintEqualToAnchor:statusBar.topAnchor constant:-6],

        [_plot2D.topAnchor constraintEqualToAnchor:_plotContainer.topAnchor],
        [_plot2D.leadingAnchor constraintEqualToAnchor:_plotContainer.leadingAnchor],
        [_plot2D.trailingAnchor constraintEqualToAnchor:_plotContainer.trailingAnchor],
        [_plot2D.bottomAnchor constraintEqualToAnchor:_plotContainer.bottomAnchor],
        [_plot3D.topAnchor constraintEqualToAnchor:_plotContainer.topAnchor],
        [_plot3D.leadingAnchor constraintEqualToAnchor:_plotContainer.leadingAnchor],
        [_plot3D.trailingAnchor constraintEqualToAnchor:_plotContainer.trailingAnchor],
        [_plot3D.bottomAnchor constraintEqualToAnchor:_plotContainer.bottomAnchor],

        [statusBar.leadingAnchor constraintEqualToAnchor:_mainPanel.leadingAnchor],
        [statusBar.trailingAnchor constraintEqualToAnchor:_mainPanel.trailingAnchor],
        [statusBar.bottomAnchor constraintEqualToAnchor:_mainPanel.bottomAnchor],
        [statusBar.heightAnchor constraintEqualToConstant:26],

        [_statusLeft.leadingAnchor constraintEqualToAnchor:statusBar.leadingAnchor constant:14],
        [_statusLeft.centerYAnchor constraintEqualToAnchor:statusBar.centerYAnchor],
        [_statusRight.trailingAnchor constraintEqualToAnchor:statusBar.trailingAnchor constant:-14],
        [_statusRight.centerYAnchor constraintEqualToAnchor:statusBar.centerYAnchor],
        [_statusLeft.trailingAnchor constraintLessThanOrEqualToAnchor:_statusRight.leadingAnchor constant:-12]
    ]];
}

#pragma mark - Mode and form

- (void)runDefaultSimulation {
    [self.window makeKeyAndOrderFront:nil];
    [self ensureWindowOnScreen];
    [NSApp activateIgnoringOtherApps:YES];
    [self solvePressed:nil];
}

- (void)ensureWindowOnScreen {
    NSScreen *screen = self.window.screen ?: NSScreen.mainScreen;
    if (!screen) return;
    NSRect visible = screen.visibleFrame;
    NSRect frame = self.window.frame;
    NSRect intersection = NSIntersectionRect(frame, visible);
    if (NSIsEmptyRect(intersection) || intersection.size.width < 200 || intersection.size.height < 150) {
        [self.window center];
    }
}

- (void)rebuildFormForCurrentMode {
    [self rebuildFormForCurrentModePreservingValues:NO];
}

- (BOOL)definition:(QLParameterDefinition *)definition acceptsValue:(id)value {
    if (!value || value == NSNull.null) return NO;
    if (definition.type == QLParameterTypeEnum) {
        return [definition.enumValues containsObject:@([value integerValue])];
    }
    if (definition.type == QLParameterTypeBool) {
        return [value isKindOfClass:NSNumber.class];
    }
    if (![value isKindOfClass:NSNumber.class]) return NO;
    double number = [value doubleValue];
    if (!isfinite(number)) return NO;
    if (definition.minValue && number < definition.minValue.doubleValue) return NO;
    if (definition.maxValue && number > definition.maxValue.doubleValue) return NO;
    return YES;
}

- (void)rebuildFormForCurrentModePreservingValues:(BOOL)preserveValues {
    NSArray<QLParameterDefinition *> *defs = [QLParameterCatalog definitionsForMode:_mode variant:_variant];
    QLParameterSet *parameters = [QLParameterCatalog defaultParametersForMode:_mode variant:_variant];
    if (preserveValues) {
        NSDictionary<NSString *, id> *oldValues = [_form.parameterSet.values copy];
        for (QLParameterDefinition *definition in defs) {
            id oldValue = oldValues[definition.key];
            if ([self definition:definition acceptsValue:oldValue]) {
                parameters.values[definition.key] = oldValue;
            }
        }
    }
    if (_mode == QLSimulationModeSchrodinger) {
        parameters.values[@"dimension"] = @(_variant);
    } else {
        parameters.values[@"system"] = @(_variant);
    }
    [_form reloadWithDefinitions:defs parameters:parameters];
    [self updatePresetPopupSelectingFirst:!preserveValues];
    [self updatePlotTypeVisibility];
}

- (void)updatePresetPopupSelectingFirst:(BOOL)selectFirst {
    [_presetPopup removeAllItems];
    NSMutableArray<NSString *> *items = [NSMutableArray arrayWithObject:@"Custom"];
    [items addObjectsFromArray:[QLParameterCatalog presetNamesForMode:_mode variant:_variant]];
    [_presetPopup addItemsWithTitles:items];
    [_presetPopup selectItemAtIndex:selectFirst ? 1 : 0];
}

- (BOOL)applyPresetNamed:(NSString *)presetName
                    mode:(QLSimulationMode)mode
                 variant:(NSInteger)variant {
    if (presetName.length == 0) return NO;
    if (mode != QLSimulationModeSchrodinger && mode != QLSimulationModeHeisenberg) return NO;
    if (variant < 0 || variant > 1) return NO;

    NSArray<NSString *> *names = [QLParameterCatalog presetNamesForMode:mode variant:variant];
    NSUInteger index = [names indexOfObject:presetName];
    if (index == NSNotFound) return NO;

    _mode = mode;
    _variant = variant;
    _modeSegmented.selectedSegment = mode;
    [self updateSystemPopup];
    [_systemPopup selectItemAtIndex:variant];
    [self rebuildFormForCurrentModePreservingValues:NO];
    [_presetPopup selectItemAtIndex:(NSInteger)index + 1];
    [self presetChanged:nil];
    return YES;
}

- (void)presetChanged:(id)sender {
    NSInteger selection = _presetPopup.indexOfSelectedItem;
    if (selection <= 0) return;
    NSInteger index = selection - 1;
    NSArray<QLParameterDefinition *> *defs = [QLParameterCatalog definitionsForMode:_mode variant:_variant];
    QLParameterSet *preset = [QLParameterCatalog presetParametersForMode:_mode variant:_variant index:index];
    [_form reloadWithDefinitions:defs parameters:preset];
    [self updatePlotTypeVisibility];
    if (_isSolving) {
        _pendingSolve = YES;
        _cancelToken.cancelled = YES;
        _sidebarStatus.stringValue = @"Loading preset…";
    } else {
        [self solvePressed:nil];
    }
}

- (void)updateSystemPopup {
    [_systemPopup removeAllItems];
    if (_mode == QLSimulationModeSchrodinger) {
        [_systemPopup addItemsWithTitles:@[@"1D", @"2D"]];
    } else {
        [_systemPopup addItemsWithTitles:@[@"Spin-1/2", @"Harmonic Oscillator"]];
    }
    [_systemPopup selectItemAtIndex:0];
}

- (void)modeChanged:(id)sender {
    _mode = (QLSimulationMode)_modeSegmented.selectedSegment;
    _variant = 0;
    [self updateSystemPopup];
    [self rebuildFormForCurrentModePreservingValues:YES];
    if (_isSolving) {
        _pendingSolve = YES;
        _cancelToken.cancelled = YES;
        _sidebarStatus.stringValue = @"Switching mode…";
    } else {
        [self solvePressed:nil];
    }
}

- (void)variantChanged:(id)sender {
    _variant = _systemPopup.indexOfSelectedItem;
    [self rebuildFormForCurrentModePreservingValues:YES];
    if (_isSolving) {
        _pendingSolve = YES;
        _cancelToken.cancelled = YES;
        _sidebarStatus.stringValue = @"Switching system…";
    } else {
        [self solvePressed:nil];
    }
}

- (void)resetDefaults:(id)sender {
    [self rebuildFormForCurrentMode];
    if (_isSolving) {
        _pendingSolve = YES;
        _cancelToken.cancelled = YES;
    } else {
        [self solvePressed:nil];
    }
}

- (void)parameterFormDidChange:(QLParameterFormView *)form key:(NSString *)key {
    if (_presetPopup.indexOfSelectedItem != 0) [_presetPopup selectItemAtIndex:0];
    [self updatePlotTypeVisibility];
}

- (void)updatePlotTypeVisibility {
    BOOL show = _result.isOscillator;
    _plotTypePopup.hidden = !show;
    if (show) [_plotTypePopup selectItemAtIndex:_oscillatorTimeSeries ? 1 : 0];
}

#pragma mark - Solve

- (void)solvePressed:(id)sender {
    if (_isSolving) {
        _pendingSolve = NO;
        _cancelToken.cancelled = YES;
        _sidebarStatus.stringValue = @"Cancelling…";
        return;
    }
    _validationLabel.hidden = YES;
    _validationLabel.textColor = NSColor.systemRedColor;
    if (!_form.allValid) {
        _validationLabel.stringValue = @"One or more parameters are outside their allowed range.";
        _validationLabel.hidden = NO;
        return;
    }

    NSError *error = nil;
    QLSimulationConfig *config = [QLSimulationConfig configFromParameters:_form.parameterSet
                                                                     mode:_mode
                                                                  variant:_variant
                                                                    error:&error];
    if (!config) {
        _validationLabel.stringValue = error.localizedDescription ?: @"Invalid parameters.";
        _validationLabel.hidden = NO;
        return;
    }

    _isSolving = YES;
    _generation++;
    NSInteger generation = _generation;
    QLCancelToken *token = [QLCancelToken new];
    _cancelToken = token;

    _solveButton.title = @"Cancel";
    _progress.hidden = NO;
    _progress.doubleValue = 0;
    _sidebarStatus.stringValue = @"Solving…";
    _validationLabel.hidden = YES;
    [_form setFormEnabled:NO];
    [self pausePlayback];

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSError *solveError = nil;
        QLSimulationResult *result = nil;
        if (config.mode == QLSimulationModeSchrodinger) {
            result = [QLSchrodingerSolver solveConfig:config progress:^BOOL(double fraction) {
                if (token.cancelled) return NO;
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (generation == self->_generation) self->_progress.doubleValue = fraction;
                });
                return !token.cancelled;
            } error:&solveError];
        } else {
            result = [QLHeisenbergSolver solveConfig:config progress:^BOOL(double fraction) {
                if (token.cancelled) return NO;
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (generation == self->_generation) self->_progress.doubleValue = fraction;
                });
                return !token.cancelled;
            } error:&solveError];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf finishSolveWithResult:result error:solveError generation:generation config:config];
        });
    });
}

- (void)finishSolveWithResult:(QLSimulationResult *)result
                        error:(NSError *)error
                   generation:(NSInteger)generation
                       config:(QLSimulationConfig *)config {
    if (generation != _generation) return;
    _isSolving = NO;
    _cancelToken = nil;
    _solveButton.title = @"Solve";
    _progress.hidden = YES;
    [_form setFormEnabled:YES];

    if (_pendingSolve) {
        _pendingSolve = NO;
        _validationLabel.hidden = YES;
        [self solvePressed:nil];
        return;
    }

    if (!result) {
        _sidebarStatus.stringValue = @"No result";
        if (error && !(error.code == 2 && [error.domain isEqualToString:QuantumLabErrorDomain])) {
            _validationLabel.stringValue = error.localizedDescription ?: @"Solve failed.";
            _validationLabel.hidden = NO;
        } else {
            _validationLabel.stringValue = @"Simulation cancelled.";
            _validationLabel.textColor = NSColor.secondaryLabelColor;
            _validationLabel.hidden = NO;
        }
        return;
    }

    _validationLabel.hidden = YES;
    _result = result;
    _frameIndex = 0;
    _plot2D.result = result;
    _plot2D.options = _options;
    _plot2D.plotKindOverride = result.isOscillator
        ? (_oscillatorTimeSeries ? QLPlotKindOscillatorTimeSeries : QLPlotKindOscillatorPhase)
        : -1;
    _plot3D.result = result;
    _plot3D.options = _options;
    _plot3D.frameIndex = 0;
    _frameSlider.maxValue = MAX(1, result.frameCount - 1);
    _frameSlider.doubleValue = 0;
    [self updatePlotTypeVisibility];
    [self updateFrameUI];

    _sidebarStatus.stringValue = [NSString stringWithFormat:@"%@\nSolved in %.2f s", [config summaryString], result.solveDuration];
    if (result.warnings.count > 0) {
        _validationLabel.textColor = NSColor.systemOrangeColor;
        _validationLabel.stringValue = [result.warnings componentsJoinedByString:@"  "];
        _validationLabel.hidden = NO;
    }

    _statusRight.stringValue = [NSString stringWithFormat:@"%ld frames · %.2f s · %@",
                                (long)result.frameCount, result.solveDuration,
                                result.isSchrodinger
                                    ? [NSString stringWithFormat:@"%ld×%ld grid", (long)result.nx, (long)result.ny]
                                    : (result.isSpin ? @"Bloch vector" : @"phase space")];
    [self saveState];
    [self startPlayback];
}

#pragma mark - Playback

- (void)startPlayback {
    if (!_result || _result.frameCount < 2) return;
    if (_frameIndex >= _result.frameCount - 1) _frameIndex = 0;
    [_playTimer invalidate];
    _playing = YES;
    _playAccumulator = 0;
    _playButton.title = @"Pause";
    _playTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / 30.0
                                                  target:self
                                                selector:@selector(playTick:)
                                                userInfo:nil
                                                 repeats:YES];
    [self updateFrameUI];
}

- (void)pausePlayback {
    _playing = NO;
    [_playTimer invalidate];
    _playTimer = nil;
    _playButton.title = @"Play";
}

- (void)togglePlayPressed:(id)sender {
    if (!_result) return;
    if (_playing) [self pausePlayback];
    else [self startPlayback];
}

- (void)playTick:(NSTimer *)timer {
    if (!_playing || !_result) return;
    _playAccumulator += _speed;
    NSInteger advance = (NSInteger)floor(_playAccumulator);
    if (advance < 1) return;
    _playAccumulator -= (double)advance;
    _frameIndex += advance;
    if (_frameIndex >= _result.frameCount - 1) {
        _frameIndex = _result.frameCount - 1;
        [self updateFrameUI];
        [self pausePlayback];
        return;
    }
    [self updateFrameUI];
}

- (void)stepBackPressed:(id)sender {
    if (!_result) return;
    [self pausePlayback];
    _frameIndex = MAX(0, _frameIndex - 1);
    [self updateFrameUI];
}

- (void)stepForwardPressed:(id)sender {
    if (!_result) return;
    [self pausePlayback];
    _frameIndex = MIN(_result.frameCount - 1, _frameIndex + 1);
    [self updateFrameUI];
}

- (void)resetSimulationPressed:(id)sender {
    if (!_result) return;
    [self pausePlayback];
    _frameIndex = 0;
    [self updateFrameUI];
}

- (void)frameSliderChanged:(id)sender {
    if (!_result) return;
    _frameIndex = (NSInteger)llround(_frameSlider.doubleValue);
    [self updateFrameUI];
}

- (void)speedChanged:(id)sender {
    NSArray<NSNumber *> *speeds = @[@0.25, @0.5, @1.0, @2.0, @4.0];
    NSInteger index = _speedPopup.indexOfSelectedItem;
    if (index >= 0 && index < (NSInteger)speeds.count) _speed = speeds[(NSUInteger)index].doubleValue;
}

- (void)updateFrameUI {
    if (!_result) return;
    _frameIndex = MIN(MAX(0, _frameIndex), _result.frameCount - 1);
    _plot2D.frameIndex = _frameIndex;
    if (!_plot3D.hidden) _plot3D.frameIndex = _frameIndex;
    _frameSlider.doubleValue = _frameIndex;
    double t = _result.times[(NSUInteger)_frameIndex].doubleValue;
    _timeLabel.stringValue = [NSString stringWithFormat:@"t = %.3f / %.3f", t, _result.tmax];
    _statusLeft.stringValue = [self statusStringForFrame:_frameIndex];
}

- (NSString *)statusStringForFrame:(NSInteger)frame {
    if (!_result) return @"Ready";
    double t = _result.times[(NSUInteger)frame].doubleValue;
    if (_result.isSchrodinger) {
        double norm = frame < (NSInteger)_result.normValues.count
            ? _result.normValues[(NSUInteger)frame].doubleValue : 1.0;
        return [NSString stringWithFormat:@"Norm %.8f   ·   frame %ld/%ld   ·   t %.3f",
                norm, (long)frame + 1, (long)_result.frameCount, t];
    }
    if (_result.isSpin) {
        double mag = frame < (NSInteger)_result.normValues.count
            ? _result.normValues[(NSUInteger)frame].doubleValue : 1.0;
        return [NSString stringWithFormat:@"|S| %.8f   ·   frame %ld/%ld   ·   t %.3f",
                mag, (long)frame + 1, (long)_result.frameCount, t];
    }
    double energy = frame < (NSInteger)_result.energyValues.count
        ? _result.energyValues[(NSUInteger)frame].doubleValue : 0.0;
    return [NSString stringWithFormat:@"E %.8f   ·   frame %ld/%ld   ·   t %.3f",
            energy, (long)frame + 1, (long)_result.frameCount, t];
}

#pragma mark - View and options

- (void)viewChanged:(id)sender {
    BOOL show3D = (_viewSegmented.selectedSegment == 1);
    _plot3D.hidden = !show3D;
    _plot2D.hidden = show3D;
    if (show3D) {
        [_plot2D clearHover];
    }
    if (show3D && _result) {
        _plot3D.frameIndex = _frameIndex;
    }
}

- (void)set2DView:(id)sender {
    _viewSegmented.selectedSegment = 0;
    [self viewChanged:nil];
}

- (void)set3DView:(id)sender {
    _viewSegmented.selectedSegment = 1;
    [self viewChanged:nil];
}

- (void)plotTypeChanged:(id)sender {
    _oscillatorTimeSeries = (_plotTypePopup.indexOfSelectedItem == 1);
    if (!_result.isOscillator) return;
    _plot2D.plotKindOverride = _oscillatorTimeSeries
        ? QLPlotKindOscillatorTimeSeries : QLPlotKindOscillatorPhase;
}

- (void)toggleSidebar:(id)sender {
    _sidebar.hidden = !_sidebar.hidden;
    [_splitView adjustSubviews];
}

- (void)resetCamera:(id)sender {
    [_plot3D resetCamera];
}

- (void)showOptions:(id)sender {
    if (!_optionsPopover) {
        [self buildOptionsPopover];
    }
    [_optionsPopover showRelativeToRect:((NSButton *)sender).bounds ofView:sender preferredEdge:NSRectEdgeMaxY];
}

- (void)buildOptionsPopover {
    NSViewController *vc = [NSViewController new];
    NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 260, 310)];

    _colorMapPopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [_colorMapPopup addItemsWithTitles:[QLColorMap colorMapNames]];
    [_colorMapPopup selectItemWithTitle:_options.colorMapName];
    _colorMapPopup.controlSize = NSControlSizeSmall;
    _colorMapPopup.target = self;
    _colorMapPopup.action = @selector(optionsChanged:);

    _logCheck = [NSButton checkboxWithTitle:@"Log density scale" target:self action:@selector(optionsChanged:)];
    _logCheck.state = _options.logScale ? NSControlStateValueOn : NSControlStateValueOff;
    _potentialCheck = [NSButton checkboxWithTitle:@"Show potential in 1D" target:self action:@selector(optionsChanged:)];
    _potentialCheck.state = _options.showPotential ? NSControlStateValueOn : NSControlStateValueOff;
    _phaseCheck = [NSButton checkboxWithTitle:@"Show phase in 2D" target:self action:@selector(optionsChanged:)];
    _phaseCheck.state = _options.showPhase ? NSControlStateValueOn : NSControlStateValueOff;
    _realImagCheck = [NSButton checkboxWithTitle:@"Show Re / Im in 1D" target:self action:@selector(optionsChanged:)];
    _realImagCheck.state = _options.showRealImag ? NSControlStateValueOn : NSControlStateValueOff;
    _autoRotateCheck = [NSButton checkboxWithTitle:@"Auto-rotate 3D view" target:self action:@selector(optionsChanged:)];
    _autoRotateCheck.state = _options.autoRotate ? NSControlStateValueOn : NSControlStateValueOff;

    _meshPopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [_meshPopup addItemsWithTitles:@[@"64", @"96", @"128", @"192"]];
    [_meshPopup selectItemWithTitle:[NSString stringWithFormat:@"%ld", (long)_options.meshResolution]];
    _meshPopup.controlSize = NSControlSizeSmall;
    _meshPopup.target = self;
    _meshPopup.action = @selector(optionsChanged:);

    NSButton *resetCameraButton = [NSButton buttonWithTitle:@"Reset 3D Camera" target:self action:@selector(resetCamera:)];
    resetCameraButton.bezelStyle = NSBezelStyleRounded;
    resetCameraButton.controlSize = NSControlSizeSmall;

    NSTextField *colorLabel = [NSTextField labelWithString:@"Color map"];
    colorLabel.font = [NSFont systemFontOfSize:10.5];
    colorLabel.textColor = NSColor.secondaryLabelColor;
    NSTextField *meshLabel = [NSTextField labelWithString:@"3D mesh resolution"];
    meshLabel.font = [NSFont systemFontOfSize:10.5];
    meshLabel.textColor = NSColor.secondaryLabelColor;

    NSStackView *stack = [NSStackView stackViewWithViews:@[colorLabel, _colorMapPopup, _logCheck, _potentialCheck,
                                                          _phaseCheck, _realImagCheck, meshLabel, _meshPopup,
                                                          _autoRotateCheck, resetCameraButton]];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.spacing = 7;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:view.topAnchor constant:12],
        [stack.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:12],
        [stack.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-12],
        [_colorMapPopup.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
        [_meshPopup.widthAnchor constraintEqualToAnchor:stack.widthAnchor]
    ]];
    vc.view = view;
    _optionsPopover = [[NSPopover alloc] init];
    _optionsPopover.contentViewController = vc;
    _optionsPopover.behavior = NSPopoverBehaviorTransient;
    _optionsPopover.contentSize = NSMakeSize(260, 310);
}

- (void)optionsChanged:(id)sender {
    _options.colorMapName = _colorMapPopup.titleOfSelectedItem ?: @"Viridis";
    _options.logScale = _logCheck.state == NSControlStateValueOn;
    _options.showPotential = _potentialCheck.state == NSControlStateValueOn;
    _options.showPhase = _phaseCheck.state == NSControlStateValueOn;
    _options.showRealImag = _realImagCheck.state == NSControlStateValueOn;
    _options.autoRotate = _autoRotateCheck.state == NSControlStateValueOn;
    NSInteger mesh = _meshPopup.titleOfSelectedItem.integerValue;
    if (mesh > 0) _options.meshResolution = mesh;
    _plot2D.options = _options;
    _plot3D.options = _options;
    [self updateFrameUI];
}

#pragma mark - Export

- (void)exportPNG:(id)sender {
    if (!_result) return;
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.allowedContentTypes = @[UTTypePNG];
    panel.nameFieldStringValue = @"quantumlab-plot.png";
    __weak typeof(self) weakSelf = self;
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
        if (response != NSModalResponseOK || !panel.URL) return;
        __strong typeof(weakSelf) strongSelf = weakSelf;
        NSImage *image = strongSelf->_plot3D.hidden ? [strongSelf->_plot2D snapshotImage] : [strongSelf->_plot3D snapshot];
        NSData *tiff = image.TIFFRepresentation;
        NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData:tiff];
        NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        NSError *writeError = nil;
        if (![png writeToURL:panel.URL options:NSDataWritingAtomic error:&writeError]) {
            [strongSelf showAlertWithMessage:@"Could not export PNG." error:writeError];
        }
    }];
}

- (void)exportCSV:(id)sender {
    if (!_result) return;
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.allowedContentTypes = @[UTTypeCommaSeparatedText];
    panel.nameFieldStringValue = @"quantumlab-data.csv";
    __weak typeof(self) weakSelf = self;
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
        if (response != NSModalResponseOK || !panel.URL) return;
        __strong typeof(weakSelf) strongSelf = weakSelf;
        NSString *csv = [strongSelf csvString];
        NSError *writeError = nil;
        if (![csv writeToURL:panel.URL atomically:YES encoding:NSUTF8StringEncoding error:&writeError]) {
            [strongSelf showAlertWithMessage:@"Could not export CSV." error:writeError];
        }
    }];
}

- (NSString *)csvString {
    NSMutableString *csv = [NSMutableString string];
    if (_result.isSchrodinger && !_result.is2D) {
        const double complex *psi = [_result wavefunctionAtFrame:_frameIndex];
        double dx = _result.lx / (double)_result.nx;
        double xmin = -_result.lx * 0.5;
        double t = _result.times[(NSUInteger)_frameIndex].doubleValue;
        [csv appendString:@"time,x,re,im,density\n"];
        for (NSInteger i = 0; i < _result.nx; i++) {
            double x = xmin + ((double)i + 0.5) * dx;
            double density = creal(psi[i] * conj(psi[i]));
            [csv appendFormat:@"%.9g,%.9g,%.9g,%.9g,%.9g\n", t, x, creal(psi[i]), cimag(psi[i]), density];
        }
    } else if (_result.is2D) {
        const float *density = [_result densityAtFrame:_frameIndex];
        const float *phase = [_result phaseAtFrame:_frameIndex];
        double dx = _result.lx / (double)_result.nx;
        double dy = _result.ly / (double)_result.ny;
        double xmin = -_result.lx * 0.5;
        double ymin = -_result.ly * 0.5;
        [csv appendString:phase ? @"x,y,density,phase\n" : @"x,y,density\n"];
        for (NSInteger j = 0; j < _result.ny; j++) {
            double y = ymin + ((double)j + 0.5) * dy;
            for (NSInteger i = 0; i < _result.nx; i++) {
                double x = xmin + ((double)i + 0.5) * dx;
                if (phase) {
                    [csv appendFormat:@"%.9g,%.9g,%.9g,%.9g\n", x, y, density[j * _result.nx + i], phase[j * _result.nx + i]];
                } else {
                    [csv appendFormat:@"%.9g,%.9g,%.9g\n", x, y, density[j * _result.nx + i]];
                }
            }
        }
    } else if (_result.isSpin) {
        QLSeries *sx = [_result seriesNamed:@"Sx"];
        QLSeries *sy = [_result seriesNamed:@"Sy"];
        QLSeries *sz = [_result seriesNamed:@"Sz"];
        [csv appendString:@"t,Sx,Sy,Sz,|S|\n"];
        for (NSInteger i = 0; i < _result.frameCount; i++) {
            [csv appendFormat:@"%.9g,%.9g,%.9g,%.9g,%.9g\n",
             _result.times[(NSUInteger)i].doubleValue,
             sx.yValues[(NSUInteger)i].doubleValue,
             sy.yValues[(NSUInteger)i].doubleValue,
             sz.yValues[(NSUInteger)i].doubleValue,
             _result.normValues[(NSUInteger)i].doubleValue];
        }
    } else {
        QLSeries *xSeries = [_result seriesNamed:@"x(t)"];
        QLSeries *pSeries = [_result seriesNamed:@"p(t)"];
        [csv appendString:@"t,x,p,energy\n"];
        for (NSInteger i = 0; i < _result.frameCount; i++) {
            [csv appendFormat:@"%.9g,%.9g,%.9g,%.9g\n",
             _result.times[(NSUInteger)i].doubleValue,
             xSeries.yValues[(NSUInteger)i].doubleValue,
             pSeries.yValues[(NSUInteger)i].doubleValue,
             _result.energyValues[(NSUInteger)i].doubleValue];
        }
    }
    return csv;
}

- (void)showAlertWithMessage:(NSString *)message error:(NSError *)error {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = message;
    alert.informativeText = error.localizedDescription ?: @"";
    [alert beginSheetModalForWindow:self.window completionHandler:nil];
}

@end
