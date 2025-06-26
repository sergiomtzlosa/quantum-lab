#import "QLHelpWindowController.h"

NSString * const QLHelpTopicWelcome = @"welcome";
NSString * const QLHelpTopicQuickStart = @"quickstart";
NSString * const QLHelpTopicInterface = @"interface";
NSString * const QLHelpTopicSchrodinger1D = @"schrodinger-1d";
NSString * const QLHelpTopicSchrodinger2D = @"schrodinger-2d";
NSString * const QLHelpTopicSpin = @"spin";
NSString * const QLHelpTopicOscillator = @"oscillator";
NSString * const QLHelpTopicViews = @"views";
NSString * const QLHelpTopicOptions = @"options";
NSString * const QLHelpTopicPlayback = @"playback";
NSString * const QLHelpTopicExport = @"export";
NSString * const QLHelpTopicPhysics = @"physics";
NSString * const QLHelpTopicShortcuts = @"shortcuts";
NSString * const QLHelpTopicTroubleshooting = @"troubleshooting";

static NSString * const QLHelpScheme = @"qlhelp";
static NSString * const QLHelpSidebarWidthKey = @"QLHelpSidebarWidth";

#pragma mark - Private models

@interface QLHelpTopic : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *section;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, copy) NSString *symbolName;
@property (nonatomic, copy) NSString *keywords;
@property (nonatomic, copy) NSAttributedString *content;
@property (nonatomic, copy) NSString *plainContent;
@end

@implementation QLHelpTopic
@end

@interface QLHelpLink : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong) NSURL *URL;
@end

@implementation QLHelpLink
@end

typedef NS_ENUM(NSInteger, QLHelpSidebarRowKind) {
    QLHelpSidebarRowKindGroup,
    QLHelpSidebarRowKindTopic
};

@interface QLHelpSidebarRow : NSObject
@property (nonatomic, assign) QLHelpSidebarRowKind kind;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *topicIdentifier;
@property (nonatomic, copy) NSString *symbolName;
@end

@implementation QLHelpSidebarRow
@end

@interface QLHelpContentBackgroundView : NSView
@end

@implementation QLHelpContentBackgroundView

- (BOOL)isOpaque {
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect {
    [[NSColor textBackgroundColor] setFill];
    NSRectFill(dirtyRect);
}

- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];
    self.needsDisplay = YES;
}

@end

@interface QLHelpRowView : NSTableRowView
@end

@implementation QLHelpRowView

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    if (!self.isSelected) return;
    NSRect pill = NSInsetRect(self.bounds, 6, 2);
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:pill xRadius:7 yRadius:7];
    [[NSColor.controlAccentColor colorWithAlphaComponent:0.16] setFill];
    [path fill];

    NSRect bar = NSMakeRect(NSMinX(pill) + 1, NSMinY(pill) + 6, 3, MAX(4, NSHeight(pill) - 12));
    NSBezierPath *barPath = [NSBezierPath bezierPathWithRoundedRect:bar xRadius:1.5 yRadius:1.5];
    [[NSColor.controlAccentColor colorWithAlphaComponent:0.9] setFill];
    [barPath fill];
}

- (void)drawSelectionInRect:(NSRect)dirtyRect {
    // The custom accent-tinted pill in -drawRect: replaces the system emphasis.
}

@end

#pragma mark - Attributed string helpers

static NSColor *QLHelpAccentColor(void) {
    return NSColor.controlAccentColor;
}

static NSParagraphStyle *QLHelpParagraphStyle(CGFloat lineSpacing, CGFloat before, CGFloat after) {
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.lineSpacing = lineSpacing;
    style.paragraphSpacingBefore = before;
    style.paragraphSpacing = after;
    style.lineBreakMode = NSLineBreakByWordWrapping;
    return style;
}

static NSDictionary<NSAttributedStringKey, id> *QLHelpAttributes(NSFont *font, NSColor *color, NSParagraphStyle *style) {
    return @{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: color,
        NSParagraphStyleAttributeName: style
    };
}

static void QLHelpAppendRun(NSMutableAttributedString *out, NSString *text, NSDictionary<NSAttributedStringKey, id> *attributes) {
    if (text.length == 0) return;
    [out appendAttributedString:[[NSAttributedString alloc] initWithString:text attributes:attributes]];
}

/// Appends text with **bold** and `code` inline markup.
static void QLHelpAppendInline(NSMutableAttributedString *out,
                               NSString *text,
                               CGFloat fontSize,
                               NSColor *color,
                               NSParagraphStyle *style) {
    NSFont *regularFont = [NSFont systemFontOfSize:fontSize];
    NSFont *boldFont = [NSFont systemFontOfSize:fontSize weight:NSFontWeightSemibold];
    NSFont *codeFont = [NSFont monospacedSystemFontOfSize:MAX(10.0, fontSize - 0.8)
                                                   weight:NSFontWeightMedium];

    NSDictionary *regular = QLHelpAttributes(regularFont, color, style);
    NSDictionary *bold = QLHelpAttributes(boldFont, color, style);
    NSMutableDictionary *code = [QLHelpAttributes(codeFont, NSColor.labelColor, style) mutableCopy];
    code[NSBackgroundColorAttributeName] = [NSColor.labelColor colorWithAlphaComponent:0.075];
    code[NSBaselineOffsetAttributeName] = @(0.4);

    NSUInteger index = 0;
    while (index < text.length) {
        NSRange remainder = NSMakeRange(index, text.length - index);
        NSRange boldMarker = [text rangeOfString:@"**" options:0 range:remainder];
        NSRange codeMarker = [text rangeOfString:@"`" options:0 range:remainder];
        BOOL boldFirst = boldMarker.location != NSNotFound &&
                         (codeMarker.location == NSNotFound || boldMarker.location < codeMarker.location);
        NSRange marker = boldFirst ? boldMarker : codeMarker;

        if (marker.location == NSNotFound) {
            QLHelpAppendRun(out, [text substringWithRange:remainder], regular);
            break;
        }
        if (marker.location > index) {
            QLHelpAppendRun(out, [text substringWithRange:NSMakeRange(index, marker.location - index)], regular);
        }

        if (boldFirst) {
            NSUInteger start = marker.location + 2;
            NSRange close = NSMakeRange(NSNotFound, 0);
            if (start <= text.length) {
                close = [text rangeOfString:@"**" options:0 range:NSMakeRange(start, text.length - start)];
            }
            if (close.location == NSNotFound) {
                QLHelpAppendRun(out, [text substringFromIndex:marker.location], regular);
                break;
            }
            QLHelpAppendRun(out, [text substringWithRange:NSMakeRange(start, close.location - start)], bold);
            index = NSMaxRange(close);
        } else {
            NSUInteger start = marker.location + 1;
            NSRange close = NSMakeRange(NSNotFound, 0);
            if (start <= text.length) {
                close = [text rangeOfString:@"`" options:0 range:NSMakeRange(start, text.length - start)];
            }
            if (close.location == NSNotFound) {
                QLHelpAppendRun(out, [text substringFromIndex:marker.location], regular);
                break;
            }
            QLHelpAppendRun(out, [text substringWithRange:NSMakeRange(start, close.location - start)], code);
            index = NSMaxRange(close);
        }
    }
}

static void QLHelpParagraph(NSMutableAttributedString *out, NSString *text) {
    NSParagraphStyle *style = QLHelpParagraphStyle(3.0, 0, 10.0);
    QLHelpAppendInline(out, text, 13.0, NSColor.labelColor, style);
    QLHelpAppendRun(out, @"\n", QLHelpAttributes([NSFont systemFontOfSize:13.0], NSColor.labelColor, style));
}

static void QLHelpHeading(NSMutableAttributedString *out, NSString *text) {
    NSMutableParagraphStyle *style = [QLHelpParagraphStyle(1.5, out.length > 0 ? 20.0 : 2.0, 7.0) mutableCopy];
    NSFont *font = [NSFont systemFontOfSize:15.5 weight:NSFontWeightSemibold];
    NSDictionary *barAttributes = QLHelpAttributes(font, QLHelpAccentColor(), style);
    NSDictionary *textAttributes = QLHelpAttributes(font, NSColor.labelColor, style);

    QLHelpAppendRun(out, @"▏  ", barAttributes);
    QLHelpAppendRun(out, text, textAttributes);
    QLHelpAppendRun(out, @"\n", textAttributes);
}

static void QLHelpMiniHeading(NSMutableAttributedString *out, NSString *text, NSColor *color, CGFloat before) {
    NSMutableParagraphStyle *style = [QLHelpParagraphStyle(1.0, before, 4.0) mutableCopy];
    NSFont *font = [NSFont systemFontOfSize:9.5 weight:NSFontWeightSemibold];
    NSDictionary *attributes = @{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: color,
        NSParagraphStyleAttributeName: style,
        NSKernAttributeName: @(0.8)
    };
    QLHelpAppendRun(out, text.uppercaseString, attributes);
    QLHelpAppendRun(out, @"\n", attributes);
}

static void QLHelpList(NSMutableAttributedString *out, NSArray<NSString *> *items, BOOL ordered) {
    [items enumerateObjectsUsingBlock:^(NSString *item, NSUInteger index, BOOL *stop) {
        NSMutableParagraphStyle *style = [QLHelpParagraphStyle(2.5, 0, 4.0) mutableCopy];
        style.firstLineHeadIndent = 4.0;
        style.headIndent = ordered ? 24.0 : 20.0;
        NSDictionary *markerAttributes = QLHelpAttributes([NSFont systemFontOfSize:13.0 weight:NSFontWeightSemibold],
                                                          QLHelpAccentColor(), style);
        NSDictionary *textAttributes = QLHelpAttributes([NSFont systemFontOfSize:13.0],
                                                        NSColor.labelColor, style);
        NSString *marker = ordered
            ? [NSString stringWithFormat:@"%lu.", (unsigned long)(index + 1)]
            : @"•";
        QLHelpAppendRun(out, [marker stringByAppendingString:@"  "], markerAttributes);
        QLHelpAppendInline(out, item, 13.0, NSColor.labelColor, style);
        QLHelpAppendRun(out, @"\n", textAttributes);
    }];
}

static void QLHelpCallout(NSMutableAttributedString *out,
                          NSString *label,
                          NSString *text,
                          NSColor *tint) {
    NSMutableParagraphStyle *style = [QLHelpParagraphStyle(2.5, 8.0, 12.0) mutableCopy];
    style.firstLineHeadIndent = 2.0;
    style.headIndent = 17.0;

    NSFont *barFont = [NSFont systemFontOfSize:11.0 weight:NSFontWeightBold];
    QLHelpAppendRun(out, @"▎ ", QLHelpAttributes(barFont, tint, style));
    NSDictionary *labelAttributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:9.5 weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName: tint,
        NSParagraphStyleAttributeName: style,
        NSKernAttributeName: @(0.5)
    };
    QLHelpAppendRun(out, [label.uppercaseString stringByAppendingString:@"  "], labelAttributes);
    QLHelpAppendInline(out, text, 12.5, NSColor.secondaryLabelColor, style);
    QLHelpAppendRun(out, @"\n",
                    QLHelpAttributes([NSFont systemFontOfSize:12.5], NSColor.secondaryLabelColor, style));
}

static void QLHelpFormula(NSMutableAttributedString *out, NSString *text) {
    NSMutableParagraphStyle *style = [QLHelpParagraphStyle(2.0, 2.0, 12.0) mutableCopy];
    style.firstLineHeadIndent = 10.0;
    style.headIndent = 10.0;
    NSFont *font = [NSFont monospacedSystemFontOfSize:11.5 weight:NSFontWeightRegular];
    NSMutableDictionary *attributes = [QLHelpAttributes(font, NSColor.secondaryLabelColor, style) mutableCopy];
    attributes[NSBackgroundColorAttributeName] = [NSColor.labelColor colorWithAlphaComponent:0.045];
    QLHelpAppendRun(out, [text stringByAppendingString:@"\n"], attributes);
}

static QLHelpLink *QLHelpTopicLink(NSString *title, NSString *topicIdentifier) {
    NSURLComponents *components = [[NSURLComponents alloc] init];
    components.scheme = QLHelpScheme;
    components.host = @"topic";
    components.path = [@"/" stringByAppendingString:topicIdentifier];
    QLHelpLink *link = [[QLHelpLink alloc] init];
    link.title = title;
    link.URL = components.URL;
    return link;
}

static QLHelpLink *QLHelpPresetLink(NSString *title,
                                    NSString *presetName,
                                    NSInteger mode,
                                    NSInteger variant) {
    NSURLComponents *components = [[NSURLComponents alloc] init];
    components.scheme = QLHelpScheme;
    components.host = @"preset";
    components.queryItems = @[
        [NSURLQueryItem queryItemWithName:@"name" value:presetName],
        [NSURLQueryItem queryItemWithName:@"mode" value:[NSString stringWithFormat:@"%ld", (long)mode]],
        [NSURLQueryItem queryItemWithName:@"variant" value:[NSString stringWithFormat:@"%ld", (long)variant]]
    ];
    QLHelpLink *link = [[QLHelpLink alloc] init];
    link.title = title;
    link.URL = components.URL;
    return link;
}

static void QLHelpAppendLink(NSMutableAttributedString *out,
                             QLHelpLink *link,
                             CGFloat fontSize,
                             NSParagraphStyle *style) {
    NSDictionary *attributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:fontSize weight:NSFontWeightMedium],
        NSForegroundColorAttributeName: NSColor.linkColor,
        NSLinkAttributeName: link.URL,
        NSParagraphStyleAttributeName: style
    };
    QLHelpAppendRun(out, link.title, attributes);
}

static void QLHelpSeeAlso(NSMutableAttributedString *out, NSArray<QLHelpLink *> *links) {
    NSMutableParagraphStyle *style = [QLHelpParagraphStyle(2.0, 18.0, 2.0) mutableCopy];
    NSDictionary *labelAttributes = @{
        NSFontAttributeName: [NSFont systemFontOfSize:9.5 weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName: NSColor.tertiaryLabelColor,
        NSParagraphStyleAttributeName: style,
        NSKernAttributeName: @(0.8)
    };
    QLHelpAppendRun(out, @"SEE ALSO  ", labelAttributes);
    [links enumerateObjectsUsingBlock:^(QLHelpLink *link, NSUInteger index, BOOL *stop) {
        if (index > 0) {
            QLHelpAppendRun(out, @"  ·  ", QLHelpAttributes([NSFont systemFontOfSize:11.5],
                                                            NSColor.tertiaryLabelColor, style));
        }
        QLHelpAppendLink(out, link, 12.0, style);
    }];
    QLHelpAppendRun(out, @"\n", QLHelpAttributes([NSFont systemFontOfSize:12.0],
                                                 NSColor.tertiaryLabelColor, style));
}

static void QLHelpTryPresets(NSMutableAttributedString *out, NSArray<QLHelpLink *> *links) {
    QLHelpMiniHeading(out, @"Try it", QLHelpAccentColor(), 16.0);
    [links enumerateObjectsUsingBlock:^(QLHelpLink *link, NSUInteger index, BOOL *stop) {
        NSMutableParagraphStyle *style = [QLHelpParagraphStyle(2.0, 0, 3.0) mutableCopy];
        style.firstLineHeadIndent = 2.0;
        style.headIndent = 17.0;
        QLHelpAppendRun(out, @"▸  ", QLHelpAttributes([NSFont systemFontOfSize:11.0 weight:NSFontWeightSemibold],
                                                      QLHelpAccentColor(), style));
        QLHelpAppendLink(out, link, 12.5, style);
        QLHelpAppendRun(out, @"\n", QLHelpAttributes([NSFont systemFontOfSize:12.5],
                                                     NSColor.labelColor, style));
    }];
    NSMutableParagraphStyle *noteStyle = [QLHelpParagraphStyle(1.5, 4.0, 10.0) mutableCopy];
    NSDictionary *noteAttributes = QLHelpAttributes([NSFont systemFontOfSize:10.5],
                                                    NSColor.tertiaryLabelColor, noteStyle);
    QLHelpAppendRun(out, @"Preset links open in the main window and close Help.\n", noteAttributes);
}

static void QLHelpShortcut(NSMutableAttributedString *out, NSString *action, NSString *keys) {
    NSMutableParagraphStyle *style = [QLHelpParagraphStyle(2.0, 0, 5.0) mutableCopy];
    style.firstLineHeadIndent = 2.0;
    style.headIndent = 184.0;
    NSTextTab *keyTab = [[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentLeft
                                                        location:184.0
                                                         options:@{}];
    style.tabStops = @[keyTab];

    QLHelpAppendRun(out, action, QLHelpAttributes([NSFont systemFontOfSize:13.0 weight:NSFontWeightMedium],
                                                  NSColor.labelColor, style));
    QLHelpAppendRun(out, @"\t", QLHelpAttributes([NSFont systemFontOfSize:13.0],
                                                  NSColor.tertiaryLabelColor, style));
    NSMutableDictionary *keyAttributes = [QLHelpAttributes([NSFont monospacedSystemFontOfSize:11.5
                                                                                       weight:NSFontWeightSemibold],
                                                           NSColor.labelColor, style) mutableCopy];
    keyAttributes[NSBackgroundColorAttributeName] = [NSColor.labelColor colorWithAlphaComponent:0.08];
    QLHelpAppendRun(out, [NSString stringWithFormat:@" %@ ", keys], keyAttributes);
    QLHelpAppendRun(out, @"\n", QLHelpAttributes([NSFont systemFontOfSize:12.0],
                                                 NSColor.labelColor, style));
}

static QLHelpTopic *QLHelpMakeTopic(NSString *identifier,
                                    NSString *section,
                                    NSString *title,
                                    NSString *subtitle,
                                    NSString *symbolName,
                                    NSString *keywords,
                                    void (^build)(NSMutableAttributedString *content)) {
    QLHelpTopic *topic = [[QLHelpTopic alloc] init];
    topic.identifier = identifier;
    topic.section = section;
    topic.title = title;
    topic.subtitle = subtitle;
    topic.symbolName = symbolName;
    topic.keywords = keywords ?: @"";
    NSMutableAttributedString *content = [[NSMutableAttributedString alloc] init];
    build(content);
    topic.content = [content copy];
    topic.plainContent = content.string;
    return topic;
}

#pragma mark - Help window

@interface QLHelpWindowController () <NSTableViewDataSource, NSTableViewDelegate,
                                      NSSearchFieldDelegate, NSTextViewDelegate,
                                      NSSplitViewDelegate>
@end

@implementation QLHelpWindowController {
    NSSplitView *_splitView;
    NSVisualEffectView *_sidebarView;
    NSSearchField *_searchField;
    NSTableView *_topicTable;
    NSScrollView *_tableScroll;
    NSTextField *_noResultsLabel;
    NSView *_contentPane;
    NSTextField *_sectionLabel;
    NSTextField *_titleLabel;
    NSTextField *_subtitleLabel;
    NSScrollView *_contentScroll;
    NSTextView *_contentTextView;

    NSArray<QLHelpTopic *> *_topics;
    NSDictionary<NSString *, QLHelpTopic *> *_topicsByIdentifier;
    NSMutableArray<QLHelpSidebarRow *> *_rows;
    NSArray<QLHelpTopic *> *_searchResults;
    NSString *_searchQuery;
    NSString *_selectedTopicID;
    NSString *_lastTopicID;
    NSString *_topicBeforeSearch;
    BOOL _suppressSelection;
    id _keyMonitor;
}

#pragma mark Lifecycle

- (instancetype)init {
    NSRect frame = NSMakeRect(0, 0, 1040, 720);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                                              NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable)
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.title = @"QuantumLab Help";
    window.minSize = NSMakeSize(860, 560);
    window.frameAutosaveName = @"QuantumLabHelpWindow";
    window.releasedWhenClosed = NO;
    window.tabbingMode = NSWindowTabbingModeDisallowed;
    [window center];

    self = [super initWithWindow:window];
    if (self) {
        _searchQuery = nil;
        _rows = [NSMutableArray array];
        _topics = [self buildTopics];
        NSMutableDictionary *byIdentifier = [NSMutableDictionary dictionary];
        for (QLHelpTopic *topic in _topics) {
            byIdentifier[topic.identifier] = topic;
        }
        _topicsByIdentifier = byIdentifier;
        [self buildUI];
        [self applySearchQuery:@""];
        [self installKeyMonitor];
    }
    return self;
}

- (void)dealloc {
    if (_keyMonitor) {
        [NSEvent removeMonitor:_keyMonitor];
        _keyMonitor = nil;
    }
}

- (void)windowDidLoad {
    [super windowDidLoad];
}

#pragma mark Public API

- (NSString *)selectedTopicIdentifier {
    return _selectedTopicID ?: @"";
}

- (NSArray<NSString *> *)topicIdentifiers {
    NSMutableArray *identifiers = [NSMutableArray arrayWithCapacity:_topics.count];
    for (QLHelpTopic *topic in _topics) {
        [identifiers addObject:topic.identifier];
    }
    return identifiers;
}

- (NSArray<NSString *> *)visibleTopicIdentifiers {
    NSMutableArray *identifiers = [NSMutableArray array];
    for (QLHelpSidebarRow *row in _rows) {
        if (row.kind == QLHelpSidebarRowKindTopic) {
            [identifiers addObject:row.topicIdentifier];
        }
    }
    return identifiers;
}

- (NSString *)currentContentText {
    return _contentTextView.string ?: @"";
}

- (void)showTopicWithIdentifier:(NSString *)identifier {
    [self selectTopicWithIdentifier:identifier];
    [self showWindow:nil];
    [self.window makeKeyAndOrderFront:nil];
}

- (BOOL)selectTopicWithIdentifier:(NSString *)identifier {
    QLHelpTopic *topic = _topicsByIdentifier[identifier];
    if (!topic) return NO;
    if (_searchQuery.length > 0 && ![_searchResults containsObject:topic]) {
        [self searchForText:@""];
    }
    [self displayTopic:topic scrollToTop:YES];
    return YES;
}

- (void)searchForText:(NSString *)query {
    NSString *text = query ?: @"";
    _searchField.stringValue = text;
    [self applySearchQuery:text];
}

- (void)focusSearch {
    if (!self.window.isVisible) [self showWindow:nil];
    [self.window makeFirstResponder:_searchField];
    [_searchField selectText:nil];
}

- (BOOL)handleHelpURL:(NSURL *)url {
    if (!url) return NO;
    if (![url.scheme isEqualToString:QLHelpScheme]) {
        if (url.isFileURL || [url.scheme isEqualToString:@"https"] || [url.scheme isEqualToString:@"http"]) {
            return [[NSWorkspace sharedWorkspace] openURL:url];
        }
        return NO;
    }

    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    NSString *host = components.host;
    NSString *path = [components.path stringByTrimmingCharactersInSet:
                      [NSCharacterSet characterSetWithCharactersInString:@"/"]];

    if ([host isEqualToString:@"topic"]) {
        return [self selectTopicWithIdentifier:path];
    }
    if ([host isEqualToString:@"action"] && [path isEqualToString:@"clear-search"]) {
        [self searchForText:@""];
        [self focusSearch];
        return YES;
    }
    if ([host isEqualToString:@"preset"]) {
        NSMutableDictionary<NSString *, NSString *> *values = [NSMutableDictionary dictionary];
        for (NSURLQueryItem *item in components.queryItems) {
            if (item.name && item.value) values[item.name] = item.value;
        }
        NSString *name = values[@"name"];
        NSInteger mode = values[@"mode"].integerValue;
        NSInteger variant = values[@"variant"].integerValue;
        if (name.length == 0) return NO;
        if ([_delegate respondsToSelector:@selector(helpWindowController:openPresetNamed:mode:variant:)]) {
            BOOL opened = [_delegate helpWindowController:self openPresetNamed:name mode:mode variant:variant];
            if (opened) [self.window orderOut:nil];
            return opened;
        }
        return NO;
    }
    return NO;
}

#pragma mark Window construction

- (void)buildUI {
    NSView *content = self.window.contentView;
    content.identifier = @"help.root";
    content.wantsLayer = YES;

    _splitView = [[NSSplitView alloc] initWithFrame:content.bounds];
    _splitView.vertical = YES;
    _splitView.dividerStyle = NSSplitViewDividerStyleThin;
    _splitView.delegate = self;
    _splitView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [content addSubview:_splitView];

    _sidebarView = [[NSVisualEffectView alloc] initWithFrame:NSMakeRect(0, 0, 246, NSHeight(content.bounds))];
    _sidebarView.material = NSVisualEffectMaterialSidebar;
    _sidebarView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    _sidebarView.state = NSVisualEffectStateActive;
    _sidebarView.autoresizingMask = NSViewHeightSizable;
    _sidebarView.identifier = @"help.sidebar";

    _contentPane = [[QLHelpContentBackgroundView alloc] initWithFrame:NSMakeRect(247, 0,
                                                                                 NSWidth(content.bounds) - 247,
                                                                                 NSHeight(content.bounds))];
    _contentPane.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    _contentPane.identifier = @"help.content";

    [_splitView addSubview:_sidebarView];
    [_splitView addSubview:_contentPane];
    [_splitView setPosition:246 ofDividerAtIndex:0];
    [_splitView setHoldingPriority:NSLayoutPriorityDefaultHigh forSubviewAtIndex:0];
    [_splitView setHoldingPriority:NSLayoutPriorityDefaultLow forSubviewAtIndex:1];
    _splitView.autosaveName = @"QuantumLabHelpSplitView";

    [self buildSidebar];
    [self buildContentPane];
}

- (void)buildSidebar {
    NSTextField *kicker = [NSTextField labelWithString:@"QUANTUMLAB"];
    kicker.font = [NSFont systemFontOfSize:9.5 weight:NSFontWeightSemibold];
    kicker.attributedStringValue = [[NSAttributedString alloc]
        initWithString:@"QUANTUMLAB"
            attributes:@{NSFontAttributeName: [NSFont systemFontOfSize:9.5 weight:NSFontWeightSemibold],
                         NSForegroundColorAttributeName: NSColor.secondaryLabelColor,
                         NSKernAttributeName: @(0.8)}];
    kicker.translatesAutoresizingMaskIntoConstraints = NO;

    NSImage *appIcon = NSApp.applicationIconImage ?: [NSImage imageNamed:NSImageNameApplicationIcon];
    NSImageView *iconView = [[NSImageView alloc] initWithFrame:NSZeroRect];
    iconView.image = appIcon;
    iconView.imageScaling = NSImageScaleProportionallyUpOrDown;
    iconView.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *title = [NSTextField labelWithString:@"Help"];
    title.font = [NSFont systemFontOfSize:23 weight:NSFontWeightBold];
    title.textColor = NSColor.labelColor;
    title.translatesAutoresizingMaskIntoConstraints = NO;

    NSStackView *titleRow = [NSStackView stackViewWithViews:@[iconView, title]];
    titleRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    titleRow.alignment = NSLayoutAttributeCenterY;
    titleRow.spacing = 9;
    titleRow.translatesAutoresizingMaskIntoConstraints = NO;

    _searchField = [[NSSearchField alloc] initWithFrame:NSZeroRect];
    _searchField.placeholderString = @"Search help";
    _searchField.controlSize = NSControlSizeSmall;
    _searchField.font = [NSFont systemFontOfSize:12];
    _searchField.sendsSearchStringImmediately = YES;
    _searchField.sendsWholeSearchString = NO;
    _searchField.target = self;
    _searchField.action = @selector(searchFieldChanged:);
    _searchField.delegate = self;
    _searchField.translatesAutoresizingMaskIntoConstraints = NO;
    _searchField.identifier = @"help.search";
    _searchField.accessibilityLabel = @"Search help topics";

    _topicTable = [[NSTableView alloc] initWithFrame:NSMakeRect(0, 0, 246, 400)];
    _topicTable.dataSource = self;
    _topicTable.delegate = self;
    _topicTable.headerView = nil;
    _topicTable.rowHeight = 27;
    _topicTable.intercellSpacing = NSMakeSize(0, 0);
    _topicTable.backgroundColor = NSColor.clearColor;
    _topicTable.style = NSTableViewStyleSourceList;
    _topicTable.selectionHighlightStyle = NSTableViewSelectionHighlightStyleNone;
    _topicTable.allowsMultipleSelection = NO;
    _topicTable.allowsEmptySelection = YES;
    _topicTable.focusRingType = NSFocusRingTypeNone;
    _topicTable.columnAutoresizingStyle = NSTableViewUniformColumnAutoresizingStyle;
    _topicTable.autoresizingMask = NSViewWidthSizable;
    _topicTable.identifier = @"help.topics";
    _topicTable.accessibilityLabel = @"Help topics";
    NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:@"main"];
    column.resizingMask = NSTableColumnAutoresizingMask;
    [_topicTable addTableColumn:column];

    _tableScroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    _tableScroll.documentView = _topicTable;
    _tableScroll.hasVerticalScroller = YES;
    _tableScroll.autohidesScrollers = YES;
    _tableScroll.drawsBackground = NO;
    _tableScroll.borderType = NSNoBorder;
    _tableScroll.scrollerStyle = NSScrollerStyleOverlay;
    _tableScroll.contentInsets = NSEdgeInsetsMake(2, 0, 0, 0);
    _tableScroll.translatesAutoresizingMaskIntoConstraints = NO;

    _noResultsLabel = [NSTextField labelWithString:@"No matching topics.\nTry a broader search."];
    _noResultsLabel.font = [NSFont systemFontOfSize:11];
    _noResultsLabel.textColor = NSColor.secondaryLabelColor;
    _noResultsLabel.maximumNumberOfLines = 2;
    _noResultsLabel.lineBreakMode = NSLineBreakByWordWrapping;
    _noResultsLabel.hidden = YES;
    _noResultsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _noResultsLabel.identifier = @"help.noresults";

    NSTextField *hint = [NSTextField labelWithString:@"⌘F search  ·  ⌘? opens Help"];
    hint.font = [NSFont systemFontOfSize:9.5];
    hint.textColor = NSColor.tertiaryLabelColor;
    hint.translatesAutoresizingMaskIntoConstraints = NO;

    [_sidebarView addSubview:kicker];
    [_sidebarView addSubview:titleRow];
    [_sidebarView addSubview:_searchField];
    [_sidebarView addSubview:_tableScroll];
    [_sidebarView addSubview:_noResultsLabel];
    [_sidebarView addSubview:hint];

    [NSLayoutConstraint activateConstraints:@[
        [iconView.widthAnchor constraintEqualToConstant:26],
        [iconView.heightAnchor constraintEqualToConstant:26],

        [kicker.topAnchor constraintEqualToAnchor:_sidebarView.topAnchor constant:16],
        [kicker.leadingAnchor constraintEqualToAnchor:_sidebarView.leadingAnchor constant:16],
        [kicker.trailingAnchor constraintLessThanOrEqualToAnchor:_sidebarView.trailingAnchor constant:-16],

        [titleRow.topAnchor constraintEqualToAnchor:kicker.bottomAnchor constant:4],
        [titleRow.leadingAnchor constraintEqualToAnchor:_sidebarView.leadingAnchor constant:16],
        [titleRow.trailingAnchor constraintLessThanOrEqualToAnchor:_sidebarView.trailingAnchor constant:-16],

        [_searchField.topAnchor constraintEqualToAnchor:titleRow.bottomAnchor constant:14],
        [_searchField.leadingAnchor constraintEqualToAnchor:_sidebarView.leadingAnchor constant:16],
        [_searchField.trailingAnchor constraintEqualToAnchor:_sidebarView.trailingAnchor constant:-16],

        [_tableScroll.topAnchor constraintEqualToAnchor:_searchField.bottomAnchor constant:10],
        [_tableScroll.leadingAnchor constraintEqualToAnchor:_sidebarView.leadingAnchor],
        [_tableScroll.trailingAnchor constraintEqualToAnchor:_sidebarView.trailingAnchor],
        [_tableScroll.bottomAnchor constraintEqualToAnchor:hint.topAnchor constant:-10],

        [_noResultsLabel.topAnchor constraintEqualToAnchor:_searchField.bottomAnchor constant:22],
        [_noResultsLabel.leadingAnchor constraintEqualToAnchor:_sidebarView.leadingAnchor constant:18],
        [_noResultsLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_sidebarView.trailingAnchor constant:-18],

        [hint.leadingAnchor constraintEqualToAnchor:_sidebarView.leadingAnchor constant:16],
        [hint.trailingAnchor constraintLessThanOrEqualToAnchor:_sidebarView.trailingAnchor constant:-16],
        [hint.bottomAnchor constraintEqualToAnchor:_sidebarView.bottomAnchor constant:-12]
    ]];
}

- (void)buildContentPane {
    NSView *column = [[NSView alloc] initWithFrame:NSZeroRect];
    column.translatesAutoresizingMaskIntoConstraints = NO;
    [_contentPane addSubview:column];

    _sectionLabel = [NSTextField labelWithString:@"GETTING STARTED"];
    _sectionLabel.font = [NSFont systemFontOfSize:9.5 weight:NSFontWeightSemibold];
    _sectionLabel.textColor = QLHelpAccentColor();
    _sectionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _sectionLabel.identifier = @"help.topic.section";

    _titleLabel = [NSTextField labelWithString:@"Welcome to QuantumLab"];
    _titleLabel.font = [NSFont systemFontOfSize:27 weight:NSFontWeightBold];
    _titleLabel.textColor = NSColor.labelColor;
    _titleLabel.maximumNumberOfLines = 1;
    _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.identifier = @"help.topic.title";

    _subtitleLabel = [NSTextField labelWithString:@""];
    _subtitleLabel.font = [NSFont systemFontOfSize:13];
    _subtitleLabel.textColor = NSColor.secondaryLabelColor;
    _subtitleLabel.maximumNumberOfLines = 3;
    _subtitleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _subtitleLabel.identifier = @"help.topic.subtitle";

    NSBox *separator = [[NSBox alloc] initWithFrame:NSZeroRect];
    separator.boxType = NSBoxSeparator;
    separator.translatesAutoresizingMaskIntoConstraints = NO;

    _contentTextView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 680, 520)];
    _contentTextView.editable = NO;
    _contentTextView.selectable = YES;
    _contentTextView.richText = YES;
    _contentTextView.drawsBackground = NO;
    _contentTextView.usesFindPanel = NO;
    _contentTextView.textContainerInset = NSMakeSize(0, 2);
    _contentTextView.textContainer.lineFragmentPadding = 0;
    _contentTextView.textContainer.widthTracksTextView = YES;
    _contentTextView.textContainer.containerSize = NSMakeSize(0, CGFLOAT_MAX);
    _contentTextView.minSize = NSZeroSize;
    _contentTextView.maxSize = NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);
    _contentTextView.verticallyResizable = YES;
    _contentTextView.horizontallyResizable = NO;
    _contentTextView.autoresizingMask = NSViewWidthSizable;
    _contentTextView.delegate = self;
    _contentTextView.linkTextAttributes = @{
        NSForegroundColorAttributeName: NSColor.linkColor,
        NSUnderlineStyleAttributeName: @(NSUnderlineStyleNone)
    };
    _contentTextView.identifier = @"help.body";
    _contentTextView.accessibilityLabel = @"Help content";

    _contentScroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    _contentScroll.documentView = _contentTextView;
    _contentScroll.hasVerticalScroller = YES;
    _contentScroll.autohidesScrollers = YES;
    _contentScroll.drawsBackground = NO;
    _contentScroll.borderType = NSNoBorder;
    _contentScroll.scrollerStyle = NSScrollerStyleOverlay;
    _contentScroll.translatesAutoresizingMaskIntoConstraints = NO;
    _contentScroll.identifier = @"help.scroll";

    [column addSubview:_sectionLabel];
    [column addSubview:_titleLabel];
    [column addSubview:_subtitleLabel];
    [column addSubview:separator];
    [column addSubview:_contentScroll];

    NSLayoutConstraint *leading = [column.leadingAnchor constraintEqualToAnchor:_contentPane.leadingAnchor constant:28];
    leading.priority = 750;
    leading.active = YES;
    NSLayoutConstraint *trailing = [column.trailingAnchor constraintEqualToAnchor:_contentPane.trailingAnchor constant:-28];
    trailing.priority = 750;
    trailing.active = YES;

    [NSLayoutConstraint activateConstraints:@[
        [column.centerXAnchor constraintEqualToAnchor:_contentPane.centerXAnchor],
        [column.widthAnchor constraintLessThanOrEqualToConstant:760],
        [column.topAnchor constraintEqualToAnchor:_contentPane.topAnchor],
        [column.bottomAnchor constraintEqualToAnchor:_contentPane.bottomAnchor],

        [_sectionLabel.topAnchor constraintEqualToAnchor:column.topAnchor constant:27],
        [_sectionLabel.leadingAnchor constraintEqualToAnchor:column.leadingAnchor],
        [_sectionLabel.trailingAnchor constraintLessThanOrEqualToAnchor:column.trailingAnchor],

        [_titleLabel.topAnchor constraintEqualToAnchor:_sectionLabel.bottomAnchor constant:5],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:column.leadingAnchor],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:column.trailingAnchor],

        [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:6],
        [_subtitleLabel.leadingAnchor constraintEqualToAnchor:column.leadingAnchor],
        [_subtitleLabel.trailingAnchor constraintEqualToAnchor:column.trailingAnchor],

        [separator.topAnchor constraintEqualToAnchor:_subtitleLabel.bottomAnchor constant:18],
        [separator.leadingAnchor constraintEqualToAnchor:column.leadingAnchor],
        [separator.trailingAnchor constraintEqualToAnchor:column.trailingAnchor],

        [_contentScroll.topAnchor constraintEqualToAnchor:separator.bottomAnchor constant:14],
        [_contentScroll.leadingAnchor constraintEqualToAnchor:column.leadingAnchor],
        [_contentScroll.trailingAnchor constraintEqualToAnchor:column.trailingAnchor],
        [_contentScroll.bottomAnchor constraintEqualToAnchor:column.bottomAnchor constant:-24]
    ]];
}

#pragma mark Split view

- (void)splitView:(NSSplitView *)splitView resizeSubviewsWithOldSize:(NSSize)oldSize {
    if (splitView.subviews.count < 2) {
        [splitView adjustSubviews];
        return;
    }
    NSView *sidebar = splitView.subviews[0];
    NSView *content = splitView.subviews[1];
    CGFloat divider = splitView.dividerThickness;
    CGFloat totalWidth = NSWidth(splitView.bounds);
    CGFloat desiredWidth = NSWidth(sidebar.frame);
    if (desiredWidth <= 0) desiredWidth = 246.0;

    CGFloat minimumWidth = 230.0;
    CGFloat maximumWidth = MIN(340.0, totalWidth - 480.0 - divider);
    if (maximumWidth < minimumWidth) maximumWidth = minimumWidth;
    desiredWidth = MIN(MAX(desiredWidth, minimumWidth), maximumWidth);

    sidebar.frame = NSMakeRect(0, 0, desiredWidth, NSHeight(splitView.bounds));
    content.frame = NSMakeRect(desiredWidth + divider, 0,
                               MAX(0, totalWidth - desiredWidth - divider),
                               NSHeight(splitView.bounds));
}

- (CGFloat)splitView:(NSSplitView *)splitView
    constrainMinCoordinate:(CGFloat)proposedMinimumPosition
               ofSubviewAt:(NSInteger)dividerIndex {
    return MAX(230.0, proposedMinimumPosition);
}

- (CGFloat)splitView:(NSSplitView *)splitView
    constrainMaxCoordinate:(CGFloat)proposedMaximumPosition
               ofSubviewAt:(NSInteger)dividerIndex {
    CGFloat roomForContent = NSWidth(splitView.bounds) - 480.0 - splitView.dividerThickness;
    CGFloat maximum = MIN(340.0, MAX(220.0, roomForContent));
    return MIN(proposedMaximumPosition, maximum);
}

- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview {
    return NO;
}

#pragma mark Key handling

- (void)installKeyMonitor {
    __weak typeof(self) weakSelf = self;
    _keyMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown
                                                        handler:^NSEvent *(NSEvent *event) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || event.window != strongSelf.window) return event;
        if (event.keyCode == 53) {
            if (strongSelf->_searchField.stringValue.length > 0) {
                [strongSelf searchForText:@""];
            } else {
                [strongSelf.window performClose:nil];
            }
            return nil;
        }
        NSEventModifierFlags flags = event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask;
        if (flags == NSEventModifierFlagCommand &&
            [event.charactersIgnoringModifiers isEqualToString:@"f"]) {
            [strongSelf focusSearch];
            return nil;
        }
        return event;
    }];
}

#pragma mark Topics

- (NSArray<QLHelpTopic *> *)buildTopics {
    NSMutableArray<QLHelpTopic *> *topics = [NSMutableArray array];

    [topics addObject:QLHelpMakeTopic(QLHelpTopicWelcome, @"Getting Started",
        @"Welcome to QuantumLab",
        @"A native lab for wavefunctions, spins, and phase-space orbits.",
        @"sparkles",
        @"overview introduction start quantum schrodinger heisenberg wavefunction spin oscillator help",
        ^(NSMutableAttributedString *content) {
            QLHelpParagraph(content,
                @"QuantumLab explores the two complementary pictures of quantum dynamics. In the Schrödinger picture you propagate a wavefunction on a periodic grid. In the Heisenberg picture you follow the dynamics of a spin-1/2 or a harmonic oscillator. Everything runs on the CPU in dimensionless natural units.");
            QLHelpHeading(content, @"What you can explore");
            QLHelpList(content, @[
                @"Launch a Gaussian wave packet and watch it disperse, reflect, tunnel, or interfere.",
                @"Trap a packet in a harmonic well, add a linear field, or drive it through a periodic lattice.",
                @"Precess a spin-1/2 on the Bloch sphere, with an optional resonant drive.",
                @"Follow a harmonic oscillator through phase space with optional phenomenological damping.",
                @"Animate every result in 2D or 3D, then export a PNG or the underlying CSV."
            ], NO);
            QLHelpHeading(content, @"Find your way");
            QLHelpList(content, @[
                @"**Quick Start** walks from launch to animation in five steps and includes one-click demo presets.",
                @"**Window & Controls** maps the sidebar, plot area, status bar, and 3D overlays.",
                @"**Physics & Units** explains the split-step method, RK4, natural units, and accuracy warnings."
            ], NO);
            QLHelpCallout(content, @"Note",
                @"Every solver parameter is editable. Presets replace physics values only; plot options and view preferences are preserved.",
                NSColor.secondaryLabelColor);
            QLHelpSeeAlso(content, @[
                QLHelpTopicLink(@"Quick Start", QLHelpTopicQuickStart),
                QLHelpTopicLink(@"Window & Controls", QLHelpTopicInterface),
                QLHelpTopicLink(@"Physics & Units", QLHelpTopicPhysics)
            ]);
        })];

    [topics addObject:QLHelpMakeTopic(QLHelpTopicQuickStart, @"Getting Started",
        @"Quick Start",
        @"From launch to animation in five steps.",
        @"bolt.fill",
        @"quick start tutorial first steps solve play preset launch default",
        ^(NSMutableAttributedString *content) {
            QLHelpParagraph(content,
                @"QuantumLab launches with a live Schrödinger 1D free packet. Follow these steps to explore any of the four systems.");
            QLHelpList(content, @[
                @"Choose a picture at the top of the sidebar: **Schrödinger** or **Heisenberg**.",
                @"Choose a system: **1D**, **2D**, **Spin-1/2**, or **Harmonic Oscillator**.",
                @"Pick a preset, or edit any value. Changing a value marks the preset as **Custom**; fields that do not apply are hidden.",
                @"Press **Solve** or ⌘R. The solve runs in the background; press **Cancel** to stop. Progress and validation messages appear above the button.",
                @"Play with Space, step with ← and →, scrub the slider, and switch views with ⌘1 and ⌘2.",
                @"Open **Options** for color and overlays. Export the plot with **PNG** (⌘E) or the data with **CSV** (⇧⌘E)."
            ], YES);
            QLHelpHeading(content, @"Good to know");
            QLHelpList(content, @[
                @"The default free packet auto-solves on launch. Changing the system automatically solves that system's first preset.",
                @"A solve can be cancelled without freezing the window; the previous result stays visible.",
                @"Preset choices reset physics values but keep color map, log scale, and 3D preferences."
            ], NO);
            QLHelpTryPresets(content, @[
                QLHelpPresetLink(@"Free Gaussian packet", @"Free Gaussian packet", 0, 0),
                QLHelpPresetLink(@"Tunneling barrier", @"Tunneling barrier", 0, 0),
                QLHelpPresetLink(@"Double slit", @"Double slit", 0, 1),
                QLHelpPresetLink(@"Spin precession", @"Spin precession", 1, 0),
                QLHelpPresetLink(@"Oscillator phase space", @"Oscillator phase space", 1, 1)
            ]);
            QLHelpSeeAlso(content, @[
                QLHelpTopicLink(@"Window & Controls", QLHelpTopicInterface),
                QLHelpTopicLink(@"Playback & Scrubbing", QLHelpTopicPlayback),
                QLHelpTopicLink(@"Exporting Data", QLHelpTopicExport)
            ]);
        })];

    [topics addObject:QLHelpMakeTopic(QLHelpTopicInterface, @"Getting Started",
        @"Window & Controls",
        @"A map of the sidebar, plot area, and status bar.",
        @"macwindow",
        @"interface sidebar toolbar status bar controls layout groups options buttons sliders",
        ^(NSMutableAttributedString *content) {
            QLHelpHeading(content, @"Sidebar");
            QLHelpList(content, @[
                @"**Mode** switches between the Schrödinger and Heisenberg pictures.",
                @"**System** chooses 1D/2D for Schrödinger or Spin-1/2/Harmonic Oscillator for Heisenberg.",
                @"**Preset** offers built-in demonstrations; **Custom** appears after an edit.",
                @"**Parameter groups** — Grid, Time, Initial State, Potential, Boundaries, and Output for Schrödinger; the equivalent groups for Heisenberg. Click a header to collapse it. Fields appear only when relevant.",
                @"**Solve / Cancel** runs the current parameters in the background. **Defaults** restores the current system's defaults.",
                @"**Validation messages** appear in red above the buttons and explain rejected values before a solve starts."
            ], NO);
            QLHelpHeading(content, @"Plot area");
            QLHelpList(content, @[
                @"**2D / 3D** switches renderers without losing the current frame.",
                @"**Plot type** appears for the oscillator and selects Phase Portrait or Time Series.",
                @"**Options** controls color map, log density, potential/phase/Re–Im overlays, 3D mesh resolution, auto-rotate, and camera reset.",
                @"**PNG / CSV** export the visible plot or the underlying data.",
                @"The **playback row** provides play/pause, step, reset, a frame slider, and 0.25×–4× speed."
            ], NO);
            QLHelpHeading(content, @"Status and overlays");
            QLHelpList(content, @[
                @"The status bar reports current time, frame index, norm (or |S|, or energy), grid size, step count, and solve duration.",
                @"In 2D, hover the plot for a crosshair and the nearest data values.",
                @"In 3D, the HUD reports time and axis ranges. Drag to orbit, scroll to zoom, and press **Center** at the upper right to reset the camera."
            ], NO);
            QLHelpCallout(content, @"Note",
                @"The interface and plots follow the system appearance. Selection and plot colors update when you switch between light and dark mode.",
                NSColor.secondaryLabelColor);
            QLHelpSeeAlso(content, @[
                QLHelpTopicLink(@"2D & 3D Views", QLHelpTopicViews),
                QLHelpTopicLink(@"Playback & Scrubbing", QLHelpTopicPlayback),
                QLHelpTopicLink(@"Keyboard Shortcuts", QLHelpTopicShortcuts)
            ]);
        })];

    [topics addObject:QLHelpMakeTopic(QLHelpTopicSchrodinger1D, @"Simulations",
        @"Schrödinger · 1D",
        @"Wave packets on a periodic line, from free dispersion to tunneling.",
        @"waveform.path",
        @"schrodinger 1d wave packet gaussian dispersion tunneling barrier harmonic potential split step free",
        ^(NSMutableAttributedString *content) {
            QLHelpFormula(content, @"iħ ∂ψ/∂t = −(ħ² / 2m) ∂²ψ/∂x² + V(x) ψ");
            QLHelpParagraph(content,
                @"The domain is centered on zero and periodic, with `nx` points and width `lx`. The split-step Fourier method alternates half potential kicks with a full kinetic step in Fourier space. It is second-order accurate and unconditionally stable.");
            QLHelpHeading(content, @"What to adjust");
            QLHelpList(content, @[
                @"**Grid** — `nx` (32–2048, power of two), `lx`, `hbar`, and `mass`. The spacing is Δx = lx / nx.",
                @"**Initial state** — center `x0`, width `sigmaX`, and momentum `kx0`. The packet is normalized on the discrete grid.",
                @"**Potential** — Free, Harmonic, Barrier, Double Barrier, Linear Field, or Periodic Lattice. Only the fields used by the selected potential appear.",
                @"**Time** — `dt`, `tmax`, and output `frames`. Internal steps are ceil(tmax / dt), capped at 2,000,000.",
                @"**Boundaries** — absorbing width and strength damp outgoing waves. `renormalize` keeps the norm at one when absorption is off."
            ], NO);
            QLHelpHeading(content, @"Reading the plot");
            QLHelpList(content, @[
                @"The filled curve is |ψ|². Optional Re/Im lines show the complex wavefunction.",
                @"The potential appears dashed on a scaled secondary axis when Show Potential is on.",
                @"The 3D view shows a spacetime surface (x, t, |ψ|²) with a moving time plane."
            ], NO);
            QLHelpCallout(content, @"Tip",
                @"If the packet is wider than the domain or touches an absorbing band, the solver warns you. For strong potentials or large momenta, reduce dt until the phase warning disappears.",
                QLHelpAccentColor());
            QLHelpTryPresets(content, @[
                QLHelpPresetLink(@"Free Gaussian packet", @"Free Gaussian packet", 0, 0),
                QLHelpPresetLink(@"Harmonic coherent state", @"Harmonic coherent state", 0, 0),
                QLHelpPresetLink(@"Tunneling barrier", @"Tunneling barrier", 0, 0)
            ]);
            QLHelpSeeAlso(content, @[
                QLHelpTopicLink(@"Schrödinger · 2D", QLHelpTopicSchrodinger2D),
                QLHelpTopicLink(@"Plot Options & Color", QLHelpTopicOptions),
                QLHelpTopicLink(@"Physics & Units", QLHelpTopicPhysics)
            ]);
        })];

    [topics addObject:QLHelpMakeTopic(QLHelpTopicSchrodinger2D, @"Simulations",
        @"Schrödinger · 2D",
        @"Interference, vortices, and density landscapes on a periodic plane.",
        @"square.grid.3x3.fill",
        @"schrodinger 2d double slit vortex interference heatmap phase circular well lattice memory",
        ^(NSMutableAttributedString *content) {
            QLHelpFormula(content, @"iħ ∂ψ/∂t = −(ħ² / 2m)(∂²/∂x² + ∂²/∂y²)ψ + V(x, y) ψ");
            QLHelpParagraph(content,
                @"The grid is `nx` × `ny`, with widths `lx` and `ly`. The solver transforms rows and then columns with the same split-step scheme used in 1D.");
            QLHelpHeading(content, @"What to adjust");
            QLHelpList(content, @[
                @"**Grid** — `nx`, `ny` (powers of two), `lx`, `ly`, `hbar`, and `mass`.",
                @"**Initial state** — `x0`, `y0`, `sigmaX`, `sigmaY`, `kx0`, `ky0`, and a vortex charge `vortex` (0–3). The vortex adds a phase e^{ilθ} around the packet center.",
                @"**Potential** — Free, Harmonic, Double Slit, Circular Well, or Periodic Lattice. Slit and well geometry fields appear only when selected.",
                @"**Output** — `storePhase` keeps a phase frame. This doubles the stored 2D memory."
            ], NO);
            QLHelpHeading(content, @"Reading the heatmap");
            QLHelpList(content, @[
                @"Density is mapped through the selected color map. Log scale compresses the dynamic range and makes fringes easier to see.",
                @"Show Phase displays phase with CoolWarm and adds a color bar. Phase is only available when phase storage was enabled before solving.",
                @"The color bar reports the current frame's range; the status bar reports norm and frame size."
            ], NO);
            QLHelpHeading(content, @"Memory and speed");
            QLHelpList(content, @[
                @"Each density frame costs nx × ny × 4 bytes; phase storage doubles that. The app warns above 512 MB and refuses runs above about 1.5 GB.",
                @"2D output is limited to 800 frames. Start at 128 × 128 for exploration and raise the grid after the physics looks right."
            ], NO);
            QLHelpCallout(content, @"Tip",
                @"Double-slit fringes need enough time for the two wavefronts to overlap. If the pattern is weak, increase tmax or move the initial packet closer to the wall.",
                QLHelpAccentColor());
            QLHelpTryPresets(content, @[
                QLHelpPresetLink(@"Free Gaussian packet", @"Free Gaussian packet", 0, 1),
                QLHelpPresetLink(@"Double slit", @"Double slit", 0, 1),
                QLHelpPresetLink(@"Vortex packet", @"Vortex packet", 0, 1)
            ]);
            QLHelpSeeAlso(content, @[
                QLHelpTopicLink(@"Schrödinger · 1D", QLHelpTopicSchrodinger1D),
                QLHelpTopicLink(@"Plot Options & Color", QLHelpTopicOptions),
                QLHelpTopicLink(@"Physics & Units", QLHelpTopicPhysics)
            ]);
        })];

    [topics addObject:QLHelpMakeTopic(QLHelpTopicSpin, @"Simulations",
        @"Heisenberg · Spin-1/2",
        @"A Bloch vector precessing under static and driven fields.",
        @"circle.circle",
        @"heisenberg spin 1/2 bloch sphere precession larmor drive rabi nutation magnetic gamma field",
        ^(NSMutableAttributedString *content) {
            QLHelpFormula(content, @"H = −(γħ/2) B(t)·σ        dS/dt = γ S × B(t)");
            QLHelpParagraph(content,
                @"The state is a unit Bloch vector initialized from a polar angle θ0 and azimuth φ0. The field is a static vector plus an optional sinusoidal drive along x, y, or z. RK4 integrates the motion.");
            QLHelpHeading(content, @"What to adjust");
            QLHelpList(content, @[
                @"**Field** — `gamma`, static `bx`, `by`, `bz`; drive `driveAmp`, `driveFreq`, `drivePhase`, and `driveAxis`.",
                @"**Initial state** — `theta0` in degrees (0–180) and `phi0` in degrees (0–360).",
                @"**Time** — `dt`, `tmax`, and output `frames`. Choose dt small enough to resolve the fastest precession.",
                @"A nonzero `driveAmp` adds Bdrive cos(ωrf t + φ) along the selected axis."
            ], NO);
            QLHelpHeading(content, @"Reading the plots");
            QLHelpList(content, @[
                @"2D shows Sx, Sy, and Sz versus time with a fixed [−1, 1] range.",
                @"3D draws the unit Bloch sphere, the trajectory, and the current point. The HUD reports axis ranges and time.",
                @"The status bar reports |S|; it should remain 1 for a coherent spin."
            ], NO);
            QLHelpCallout(content, @"Note",
                @"γ and B use the app's natural frequency units, not tesla or rad/s. For a static field along z, the Larmor period is 2π / (γ|B|).",
                NSColor.secondaryLabelColor);
            QLHelpTryPresets(content, @[
                QLHelpPresetLink(@"Spin precession", @"Spin precession", 1, 0),
                QLHelpPresetLink(@"Driven spin", @"Driven spin", 1, 0)
            ]);
            QLHelpSeeAlso(content, @[
                QLHelpTopicLink(@"2D & 3D Views", QLHelpTopicViews),
                QLHelpTopicLink(@"Physics & Units", QLHelpTopicPhysics),
                QLHelpTopicLink(@"Heisenberg · Oscillator", QLHelpTopicOscillator)
            ]);
        })];

    [topics addObject:QLHelpMakeTopic(QLHelpTopicOscillator, @"Simulations",
        @"Heisenberg · Oscillator",
        @"Phase-space orbits for a harmonic oscillator, with optional damping.",
        @"infinity",
        @"heisenberg harmonic oscillator phase space orbit damping energy x p mass omega",
        ^(NSMutableAttributedString *content) {
            QLHelpFormula(content, @"H = p²/2m + ½mω²x²        dx/dt = p/m        dp/dt = −mω²x − 2γd p");
            QLHelpParagraph(content,
                @"The oscillator follows the Heisenberg equations for x and p. The damping term is phenomenological: it removes energy but is not part of H. It defaults to zero.");
            QLHelpHeading(content, @"What to adjust");
            QLHelpList(content, @[
                @"**Oscillator** — mass `mass`, frequency `omega`, initial `x0` and `p0`, and damping `damping`.",
                @"**Time** — `dt`, `tmax`, and output `frames`.",
                @"**Plot type** — Phase Portrait or Time Series. The 3D view always uses (t, x, p)."
            ], NO);
            QLHelpHeading(content, @"Reading the plots");
            QLHelpList(content, @[
                @"The phase portrait plots p versus x with a trail up to the current frame and a marker at the current point.",
                @"The time series shows x(t) and p(t); the period is 2π / ω.",
                @"Energy is E = p²/2m + ½mω²x². Undamped orbits close; damping spirals inward.",
                @"3D shows the curve (t, x, p) with a moving current point."
            ], NO);
            QLHelpCallout(content, @"Note",
                @"The phase portrait scales x and p independently, so a circular orbit can look elliptical. Check the axis labels and the time series before assuming the physics changed.",
                NSColor.secondaryLabelColor);
            QLHelpTryPresets(content, @[
                QLHelpPresetLink(@"Oscillator phase space", @"Oscillator phase space", 1, 1)
            ]);
            QLHelpSeeAlso(content, @[
                QLHelpTopicLink(@"Heisenberg · Spin-1/2", QLHelpTopicSpin),
                QLHelpTopicLink(@"Playback & Scrubbing", QLHelpTopicPlayback),
                QLHelpTopicLink(@"Physics & Units", QLHelpTopicPhysics)
            ]);
        })];

    [topics addObject:QLHelpMakeTopic(QLHelpTopicViews, @"Visualization",
        @"2D & 3D Views",
        @"Core Graphics for 2D, SceneKit for 3D, one shared frame.",
        @"cube.transparent",
        @"2d 3d view camera scene kit bloch sphere surface mesh orbit zoom center hud heatmap plot",
        ^(NSMutableAttributedString *content) {
            QLHelpHeading(content, @"2D view");
            QLHelpList(content, @[
                @"Core Graphics draws axes, ticks, legends, color bars, density fills, line series, and heatmaps.",
                @"Hover for a crosshair and nearest values. Retina resolution is automatic.",
                @"1D shows density with optional Re/Im and potential. 2D shows density or phase. Spin shows three components. Oscillator shows a phase portrait or time series."
            ], NO);
            QLHelpHeading(content, @"3D view");
            QLHelpList(content, @[
                @"**Schrödinger 1D** — spacetime surface over (x, t) with a moving time plane, built once from all frames.",
                @"**Schrödinger 2D** — the current density surface, rebuilt at up to 15 fps. Mesh resolution is 64, 96, 128, or 192 cells per side.",
                @"**Spin-1/2** — translucent Bloch sphere, trajectory, and current point.",
                @"**Oscillator** — (t, x, p) curve with a moving current point."
            ], NO);
            QLHelpHeading(content, @"Camera and switching");
            QLHelpList(content, @[
                @"Drag to orbit and scroll to zoom. **Center** at the upper right resets the camera; **Options** also has Reset 3D Camera.",
                @"Enable Auto-rotate for a slow turntable.",
                @"Switching 2D/3D keeps the current frame. 3D playback is throttled to 15 fps; 2D runs up to 30 fps."
            ], NO);
            QLHelpCallout(content, @"Note",
                @"3D heights are normalized into the scene box. The HUD and status bar report the actual ranges.",
                NSColor.secondaryLabelColor);
            QLHelpSeeAlso(content, @[
                QLHelpTopicLink(@"Plot Options & Color", QLHelpTopicOptions),
                QLHelpTopicLink(@"Playback & Scrubbing", QLHelpTopicPlayback),
                QLHelpTopicLink(@"Exporting Data", QLHelpTopicExport)
            ]);
        })];

    [topics addObject:QLHelpMakeTopic(QLHelpTopicOptions, @"Visualization",
        @"Plot Options & Color",
        @"Color, scale, overlays, and 3D mesh settings.",
        @"paintpalette",
        @"options color map viridis inferno coolwarm grayscale log scale phase potential real imaginary mesh auto rotate",
        ^(NSMutableAttributedString *content) {
            QLHelpList(content, @[
                @"**Color map** — Viridis (default), Inferno, CoolWarm, or Grayscale. Phase always uses CoolWarm.",
                @"**Log density scale** — displays log10(d + ε); useful for weak fringes and long tails.",
                @"**Show potential in 1D** — dashed potential on a scaled secondary axis.",
                @"**Show phase in 2D** — requires `storePhase` at solve time.",
                @"**Show Re / Im in 1D** — adds the real and imaginary components.",
                @"**3D mesh resolution** — 64, 96, 128, or 192 cells per side. Higher is smoother and heavier.",
                @"**Auto-rotate 3D view** — a slow automatic orbit.",
                @"**Reset 3D Camera** — same as the Center overlay."
            ], NO);
            QLHelpCallout(content, @"Note",
                @"Plot options are saved separately from physics parameters and survive preset changes and relaunches.",
                NSColor.secondaryLabelColor);
            QLHelpSeeAlso(content, @[
                QLHelpTopicLink(@"2D & 3D Views", QLHelpTopicViews),
                QLHelpTopicLink(@"Exporting Data", QLHelpTopicExport),
                QLHelpTopicLink(@"Window & Controls", QLHelpTopicInterface)
            ]);
        })];

    [topics addObject:QLHelpMakeTopic(QLHelpTopicPlayback, @"Visualization",
        @"Playback & Scrubbing",
        @"Scrub, step, and animate without re-solving.",
        @"play.circle",
        @"playback play pause step scrub slider animate speed frames reset space arrows",
        ^(NSMutableAttributedString *content) {
            QLHelpList(content, @[
                @"**Play / Pause** — the button, the Simulation menu, or Space when the plot has focus.",
                @"**Step** — the ◀ and ▶ buttons or the left/right arrow keys. Step Back stops at frame 0.",
                @"**Slider** — jumps to any stored frame and updates the time label.",
                @"**Reset** — returns to frame 0; ⌘0 from the menu.",
                @"**Speed** — 0.25×, 0.5×, 1×, 2×, or 4×."
            ], NO);
            QLHelpParagraph(content,
                @"Keyboard playback only applies when the plot area has focus and no text field or control is editing, so parameter entry is never interrupted.");
            QLHelpCallout(content, @"Note",
                @"Switching between 2D and 3D keeps the frame. In 3D, frames are rendered at a 15 fps cap while the slider stays responsive.",
                NSColor.secondaryLabelColor);
            QLHelpSeeAlso(content, @[
                QLHelpTopicLink(@"Window & Controls", QLHelpTopicInterface),
                QLHelpTopicLink(@"2D & 3D Views", QLHelpTopicViews),
                QLHelpTopicLink(@"Keyboard Shortcuts", QLHelpTopicShortcuts)
            ]);
        })];

    [topics addObject:QLHelpMakeTopic(QLHelpTopicExport, @"Reference",
        @"Exporting Data",
        @"PNG snapshots and CSV data for every plot type.",
        @"square.and.arrow.up",
        @"export png csv save data file columns time density phase spin oscillator energy",
        ^(NSMutableAttributedString *content) {
            QLHelpHeading(content, @"PNG");
            QLHelpParagraph(content,
                @"**PNG** or ⌘E captures the visible plot: the 2D view's current frame or the 3D SceneKit snapshot. The save panel uses the PNG content type.");
            QLHelpHeading(content, @"CSV");
            QLHelpList(content, @[
                @"**Schrödinger 1D** — `time,x,re,im,density` for the current frame.",
                @"**Schrödinger 2D** — `x,y,density`, plus `phase` when phase storage is on.",
                @"**Spin-1/2** — `t,Sx,Sy,Sz,|S|` for every frame.",
                @"**Harmonic oscillator** — `t,x,p,energy` for every frame."
            ], NO);
            QLHelpParagraph(content,
                @"CSV or ⇧⌘E writes the current data set. Both exports use standard save panels; the app is not sandboxed, so choose any writable destination.");
            QLHelpCallout(content, @"Note",
                @"If a save fails, check the destination permissions and available space. Errors appear in an alert.",
                NSColor.secondaryLabelColor);
            QLHelpSeeAlso(content, @[
                QLHelpTopicLink(@"Window & Controls", QLHelpTopicInterface),
                QLHelpTopicLink(@"Physics & Units", QLHelpTopicPhysics),
                QLHelpTopicLink(@"Troubleshooting", QLHelpTopicTroubleshooting)
            ]);
        })];

    [topics addObject:QLHelpMakeTopic(QLHelpTopicPhysics, @"Reference",
        @"Physics & Units",
        @"What the solver does, and how to keep it accurate.",
        @"function",
        @"physics units natural split step fft rk4 accuracy phase warning norm absorbing boundaries periodic domain formula",
        ^(NSMutableAttributedString *content) {
            QLHelpHeading(content, @"Schrödinger picture");
            QLHelpParagraph(content,
                @"The solver uses the symmetric split-step Fourier method: half potential kick, full kinetic step in Fourier space, then the second half kick. FFTs are radix-2 and in-house. 2D transforms rows and then columns. The method is second-order accurate and unconditionally stable.");
            QLHelpList(content, @[
                @"**Phase warning** — the app estimates φmax = (ħkmax² / 2m + Vmax) Δt / ħ. Above 0.5 it warns; above π the step is unreliable. Reduce dt.",
                @"**Norm** — with absorption off and renormalization off, the norm should stay near 1. Absorption intentionally removes norm; the status bar reports it.",
                @"**Absorbing boundaries** — a quadratic mask inside the boundary band suppresses periodic wraparound.",
                @"**Grid** — powers of two only, 32–2048. The domain is periodic, so a packet that leaves one edge re-enters the other."
            ], NO);
            QLHelpHeading(content, @"Heisenberg picture");
            QLHelpList(content, @[
                @"**Spin-1/2** — dS/dt = γ S × B(t), integrated with RK4. S is plotted as a unit vector and |S| is checked.",
                @"**Oscillator** — dx/dt = p/m and dp/dt = −mω²x − 2γd p. Damping is phenomenological."
            ], NO);
            QLHelpHeading(content, @"Units");
            QLHelpParagraph(content,
                @"Everything is in dimensionless natural units. ħ and m are editable in the Schrödinger model; no SI or atomic-unit conversion is performed. Frequencies, fields, and times are all in the app's natural units.");
            QLHelpCallout(content, @"Tip",
                @"If a result looks wrong, first check dt, grid resolution, and whether the packet or orbit stayed inside the domain.",
                QLHelpAccentColor());
            QLHelpSeeAlso(content, @[
                QLHelpTopicLink(@"Schrödinger · 1D", QLHelpTopicSchrodinger1D),
                QLHelpTopicLink(@"Heisenberg · Spin-1/2", QLHelpTopicSpin),
                QLHelpTopicLink(@"Troubleshooting", QLHelpTopicTroubleshooting)
            ]);
        })];

    [topics addObject:QLHelpMakeTopic(QLHelpTopicShortcuts, @"Reference",
        @"Keyboard Shortcuts",
        @"Every menu shortcut, plus plot-focused keys.",
        @"keyboard",
        @"keyboard shortcuts keys command hotkey menu space arrows escape find search",
        ^(NSMutableAttributedString *content) {
            QLHelpHeading(content, @"Simulation");
            QLHelpShortcut(content, @"Solve", @"⌘R");
            QLHelpShortcut(content, @"Play / pause", @"Space");
            QLHelpShortcut(content, @"Step back", @"←");
            QLHelpShortcut(content, @"Step forward", @"→");
            QLHelpShortcut(content, @"Reset frame", @"⌘0");
            QLHelpHeading(content, @"View");
            QLHelpShortcut(content, @"2D plot", @"⌘1");
            QLHelpShortcut(content, @"3D plot", @"⌘2");
            QLHelpShortcut(content, @"Toggle sidebar", @"⌃⌘S");
            QLHelpHeading(content, @"File");
            QLHelpShortcut(content, @"Export plot PNG", @"⌘E");
            QLHelpShortcut(content, @"Export data CSV", @"⇧⌘E");
            QLHelpShortcut(content, @"Close window", @"⌘W");
            QLHelpHeading(content, @"Application");
            QLHelpShortcut(content, @"Open Help", @"⌘?");
            QLHelpShortcut(content, @"Search Help", @"⌘F");
            QLHelpShortcut(content, @"Hide", @"⌘H");
            QLHelpShortcut(content, @"Quit", @"⌘Q");
            QLHelpHeading(content, @"Text editing");
            QLHelpShortcut(content, @"Undo / redo", @"⌘Z / ⇧⌘Z");
            QLHelpShortcut(content, @"Cut / copy / paste", @"⌘X / ⌘C / ⌘V");
            QLHelpShortcut(content, @"Select all", @"⌘A");
            QLHelpCallout(content, @"Note",
                @"Space and the arrow keys are ignored while a text field or control has focus, so they only control playback from the plot. In Help, Esc clears the search or closes the window.",
                NSColor.secondaryLabelColor);
            QLHelpSeeAlso(content, @[
                QLHelpTopicLink(@"Playback & Scrubbing", QLHelpTopicPlayback),
                QLHelpTopicLink(@"Window & Controls", QLHelpTopicInterface),
                QLHelpTopicLink(@"Quick Start", QLHelpTopicQuickStart)
            ]);
        })];

    [topics addObject:QLHelpMakeTopic(QLHelpTopicTroubleshooting, @"Reference",
        @"Troubleshooting",
        @"Common questions, from a blank plot to an off-screen window.",
        @"wrench.and.screwdriver",
        @"troubleshooting problem error blank empty dark off screen norm drift slow validation memory build scheme reset",
        ^(NSMutableAttributedString *content) {
            QLHelpHeading(content, @"The window is off screen");
            QLHelpParagraph(content,
                @"The app restores the last window frame and recenters if it no longer intersects a display. To remove the saved frame, quit and run `defaults delete com.sid.QuantumLab 'NSWindow Frame QuantumLabMainWindow'`. The Help window keeps its own frame and divider width; remove those with `defaults delete com.sid.QuantumLab 'NSWindow Frame QuantumLabHelpWindow'` and `defaults delete com.sid.QuantumLab 'NSSplitView Subview Frames QuantumLabHelpSplitView'`.");
            QLHelpHeading(content, @"A solve is rejected");
            QLHelpList(content, @[
                @"Grid sizes must be powers of two between 32 and 2048.",
                @"dt, tmax, widths, masses, and ħ must be positive.",
                @"Total internal steps are capped at 2,000,000; 2D output is limited to 800 frames.",
                @"2D runs above 512 MB warn; runs above about 1.5 GB are refused."
            ], NO);
            QLHelpHeading(content, @"The plot looks empty or dark");
            QLHelpList(content, @[
                @"Turn on Log density scale to reveal weak tails and fringes.",
                @"Check that the packet is inside the domain and not absorbed.",
                @"In 3D, press Center; the camera may be inside or behind the surface.",
                @"Try a preset from the sidebar to restore known-good parameters."
            ], NO);
            QLHelpHeading(content, @"Norm drifts");
            QLHelpParagraph(content,
                @"This is expected with absorbing boundaries (norm is lost) or when renormalization is off and the split-step phase is too large. Reduce dt or enable renormalize for bound-state runs.");
            QLHelpHeading(content, @"No GUI in a headless session");
            QLHelpParagraph(content,
                @"Use `--selftest` for numerical checks. AppKit windows require a logged-in macOS session.");
            QLHelpHeading(content, @"Build or scheme errors");
            QLHelpParagraph(content,
                @"Regenerate the project with `xcodegen generate`, or open QuantumLab.xcodeproj and build the QuantumLab scheme.");
            QLHelpCallout(content, @"Tip",
                @"The Debug build supports `--uitest`, which exercises the entire interface and exits with a nonzero status on failure.",
                QLHelpAccentColor());
            QLHelpSeeAlso(content, @[
                QLHelpTopicLink(@"Physics & Units", QLHelpTopicPhysics),
                QLHelpTopicLink(@"Exporting Data", QLHelpTopicExport),
                QLHelpTopicLink(@"Quick Start", QLHelpTopicQuickStart)
            ]);
        })];

    return topics;
}

#pragma mark Search

- (NSArray<NSString *> *)termsForQuery:(NSString *)query {
    if (query.length == 0) return @[];
    NSArray<NSString *> *parts = [query componentsSeparatedByCharactersInSet:
                                  [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSMutableArray *terms = [NSMutableArray array];
    for (NSString *part in parts) {
        if (part.length > 0) [terms addObject:part];
    }
    return terms;
}

- (BOOL)string:(NSString *)haystack containsTerm:(NSString *)term {
    return [haystack rangeOfString:term
                           options:(NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch)].location != NSNotFound;
}

- (NSInteger)occurrencesOfTerm:(NSString *)term inString:(NSString *)haystack {
    if (term.length == 0 || haystack.length == 0) return 0;
    NSInteger count = 0;
    NSUInteger location = 0;
    while (location < haystack.length) {
        NSRange range = [haystack rangeOfString:term
                                        options:(NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch)
                                          range:NSMakeRange(location, haystack.length - location)];
        if (range.location == NSNotFound) break;
        count++;
        location = NSMaxRange(range);
    }
    return count;
}

- (NSInteger)scoreForTopic:(QLHelpTopic *)topic terms:(NSArray<NSString *> *)terms {
    NSInteger score = 0;
    for (NSString *term in terms) {
        if ([self string:topic.title containsTerm:term]) score += 700;
        if ([self string:topic.subtitle containsTerm:term]) score += 220;
        if ([self string:topic.keywords containsTerm:term]) score += 140;
        NSInteger bodyHits = [self occurrencesOfTerm:term inString:topic.plainContent];
        score += MIN(bodyHits, 30) * 12;
    }
    return score;
}

- (NSArray<QLHelpTopic *> *)topicsMatchingQuery:(NSString *)query {
    NSArray<NSString *> *terms = [self termsForQuery:query];
    if (terms.count == 0) return _topics;

    NSMutableArray<QLHelpTopic *> *matches = [NSMutableArray array];
    for (QLHelpTopic *topic in _topics) {
        BOOL all = YES;
        for (NSString *term in terms) {
            if (![self string:topic.title containsTerm:term] &&
                ![self string:topic.subtitle containsTerm:term] &&
                ![self string:topic.keywords containsTerm:term] &&
                ![self string:topic.plainContent containsTerm:term]) {
                all = NO;
                break;
            }
        }
        if (all) [matches addObject:topic];
    }

    NSArray<QLHelpTopic *> *ordered = _topics;
    [matches sortUsingComparator:^NSComparisonResult(QLHelpTopic *topicA, QLHelpTopic *topicB) {
        NSInteger scoreA = [self scoreForTopic:topicA terms:terms];
        NSInteger scoreB = [self scoreForTopic:topicB terms:terms];
        if (scoreA != scoreB) return scoreA > scoreB ? NSOrderedAscending : NSOrderedDescending;
        NSUInteger indexA = [ordered indexOfObjectIdenticalTo:topicA];
        NSUInteger indexB = [ordered indexOfObjectIdenticalTo:topicB];
        if (indexA == indexB) return NSOrderedSame;
        return indexA < indexB ? NSOrderedAscending : NSOrderedDescending;
    }];
    return matches;
}

- (void)rebuildRows {
    NSMutableArray<QLHelpSidebarRow *> *rows = [NSMutableArray array];
    if (_searchQuery.length > 0) {
        if (_searchResults.count > 0) {
            QLHelpSidebarRow *group = [[QLHelpSidebarRow alloc] init];
            group.kind = QLHelpSidebarRowKindGroup;
            group.title = @"Search Results";
            [rows addObject:group];
            for (QLHelpTopic *topic in _searchResults) {
                [rows addObject:[self rowForTopic:topic]];
            }
        }
    } else {
        NSString *currentSection = nil;
        for (QLHelpTopic *topic in _topics) {
            if (![topic.section isEqualToString:currentSection ?: @""]) {
                QLHelpSidebarRow *group = [[QLHelpSidebarRow alloc] init];
                group.kind = QLHelpSidebarRowKindGroup;
                group.title = topic.section;
                [rows addObject:group];
                currentSection = topic.section;
            }
            [rows addObject:[self rowForTopic:topic]];
        }
    }
    _rows = rows;
}

- (QLHelpSidebarRow *)rowForTopic:(QLHelpTopic *)topic {
    QLHelpSidebarRow *row = [[QLHelpSidebarRow alloc] init];
    row.kind = QLHelpSidebarRowKindTopic;
    row.title = topic.title;
    row.topicIdentifier = topic.identifier;
    row.symbolName = topic.symbolName;
    return row;
}

- (void)applySearchQuery:(NSString *)query {
    NSString *text = query ?: @"";
    NSString *trimmed = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([_searchQuery isEqualToString:trimmed]) return;

    BOOL wasSearching = _searchQuery.length > 0;
    NSString *restoreIdentifier = nil;
    if (!wasSearching && trimmed.length > 0) {
        _topicBeforeSearch = _selectedTopicID;
    } else if (wasSearching && trimmed.length == 0) {
        restoreIdentifier = _topicBeforeSearch;
        _topicBeforeSearch = nil;
    }
    _searchQuery = [trimmed copy];

    _searchResults = [self topicsMatchingQuery:_searchQuery];
    [self rebuildRows];

    _suppressSelection = YES;
    [_topicTable deselectAll:nil];
    [_topicTable reloadData];
    _suppressSelection = NO;

    _noResultsLabel.hidden = _rows.count > 0;

    if (_searchQuery.length > 0 && _searchResults.count == 0) {
        [self showEmptyState];
        return;
    }

    QLHelpTopic *topic = nil;
    if (_searchQuery.length > 0) {
        topic = _searchResults.firstObject;
    } else {
        topic = _topicsByIdentifier[restoreIdentifier ?: @""];
        if (!topic) topic = _topicsByIdentifier[_selectedTopicID ?: @""];
        if (!topic) topic = _topicsByIdentifier[_lastTopicID ?: @""];
        if (!topic) topic = _topicsByIdentifier[QLHelpTopicWelcome];
    }
    if (topic) {
        [self displayTopic:topic scrollToTop:YES];
    }
}

- (void)showEmptyState {
    _selectedTopicID = nil;
    _sectionLabel.attributedStringValue = [self uppercaseLabel:@"Search" color:QLHelpAccentColor()];
    _titleLabel.stringValue = @"No matching topics";
    NSString *shortQuery = _searchQuery.length > 80
        ? [[_searchQuery substringToIndex:77] stringByAppendingString:@"…"]
        : _searchQuery;
    _subtitleLabel.stringValue = [NSString stringWithFormat:@"“%@” did not match any help topic.",
                                  shortQuery];

    NSMutableAttributedString *content = [[NSMutableAttributedString alloc] init];
    QLHelpHeading(content, @"Nothing found");
    QLHelpParagraph(content,
        @"Try a shorter word, a different spelling, or browse the topics in the sidebar. Useful searches include “camera”, “export”, “spin”, and “split-step”.");
    NSMutableParagraphStyle *style = [QLHelpParagraphStyle(2.0, 4.0, 4.0) mutableCopy];
    QLHelpLink *clear = QLHelpTopicLink(@"Clear the search", QLHelpTopicWelcome);
    clear.URL = [NSURL URLWithString:@"qlhelp://action/clear-search"];
    QLHelpAppendLink(content, clear, 12.5, style);
    QLHelpAppendRun(content, @"\n", QLHelpAttributes([NSFont systemFontOfSize:12.5],
                                                     NSColor.labelColor, style));
    [_contentTextView.textStorage setAttributedString:content];
    [_contentTextView scrollRangeToVisible:NSMakeRange(0, 0)];

    _suppressSelection = YES;
    [_topicTable deselectAll:nil];
    _suppressSelection = NO;
    [self updateRowColors];
}

- (NSAttributedString *)uppercaseLabel:(NSString *)text color:(NSColor *)color {
    return [[NSAttributedString alloc] initWithString:text.uppercaseString
                                           attributes:@{
        NSFontAttributeName: [NSFont systemFontOfSize:9.5 weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName: color,
        NSKernAttributeName: @(0.8)
    }];
}

- (NSAttributedString *)headerString:(NSString *)string font:(NSFont *)font color:(NSColor *)color {
    NSMutableAttributedString *result = [[NSMutableAttributedString alloc]
        initWithString:string ?: @"" attributes:@{
            NSFontAttributeName: font,
            NSForegroundColorAttributeName: color
        }];
    if (_searchQuery.length > 0) [self highlightTermsIn:result];
    return result;
}

- (void)highlightTermsIn:(NSMutableAttributedString *)text {
    NSArray<NSString *> *terms = [self termsForQuery:_searchQuery];
    if (terms.count == 0 || text.length == 0) return;
    NSColor *highlight = [NSColor.systemYellowColor colorWithAlphaComponent:0.32];
    NSString *plain = text.string;
    for (NSString *term in terms) {
        NSUInteger location = 0;
        while (location < plain.length) {
            NSRange range = [plain rangeOfString:term
                                         options:(NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch)
                                           range:NSMakeRange(location, plain.length - location)];
            if (range.location == NSNotFound) break;
            [text addAttribute:NSBackgroundColorAttributeName value:highlight range:range];
            location = NSMaxRange(range);
        }
    }
}

- (void)displayTopic:(QLHelpTopic *)topic scrollToTop:(BOOL)scrollToTop {
    if (!topic) return;
    _selectedTopicID = topic.identifier;
    _lastTopicID = topic.identifier;

    _sectionLabel.attributedStringValue = [self uppercaseLabel:topic.section color:QLHelpAccentColor()];
    _titleLabel.attributedStringValue = [self headerString:topic.title
                                                     font:[NSFont systemFontOfSize:27 weight:NSFontWeightBold]
                                                    color:NSColor.labelColor];
    _subtitleLabel.attributedStringValue = [self headerString:topic.subtitle
                                                        font:[NSFont systemFontOfSize:13]
                                                       color:NSColor.secondaryLabelColor];
    _contentTextView.accessibilityLabel = [NSString stringWithFormat:@"Help: %@", topic.title];

    NSMutableAttributedString *content = [topic.content mutableCopy];
    if (_searchQuery.length > 0) [self highlightTermsIn:content];
    [_contentTextView.textStorage setAttributedString:content];
    if (scrollToTop) [_contentTextView scrollRangeToVisible:NSMakeRange(0, 0)];

    _noResultsLabel.hidden = _rows.count > 0;
    [self syncTableSelectionToTopic:topic.identifier];
    [self updateRowColors];
}

- (void)syncTableSelectionToTopic:(NSString *)identifier {
    NSInteger row = [self rowForTopicIdentifier:identifier];
    _suppressSelection = YES;
    if (row >= 0) {
        [_topicTable selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)row]
                 byExtendingSelection:NO];
        [_topicTable scrollRowToVisible:row];
    } else {
        [_topicTable deselectAll:nil];
    }
    _suppressSelection = NO;
}

- (NSInteger)rowForTopicIdentifier:(NSString *)identifier {
    for (NSUInteger index = 0; index < _rows.count; index++) {
        QLHelpSidebarRow *row = _rows[index];
        if (row.kind == QLHelpSidebarRowKindTopic && [row.topicIdentifier isEqualToString:identifier]) {
            return (NSInteger)index;
        }
    }
    return -1;
}

#pragma mark Table view

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return (NSInteger)_rows.count;
}

- (BOOL)tableView:(NSTableView *)tableView isGroupRow:(NSInteger)row {
    if (row < 0 || row >= (NSInteger)_rows.count) return NO;
    return _rows[(NSUInteger)row].kind == QLHelpSidebarRowKindGroup;
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row {
    if (row < 0 || row >= (NSInteger)_rows.count) return NO;
    return _rows[(NSUInteger)row].kind == QLHelpSidebarRowKindTopic;
}

- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row {
    if (row < 0 || row >= (NSInteger)_rows.count) return nil;
    if (_rows[(NSUInteger)row].kind != QLHelpSidebarRowKindTopic) return nil;
    QLHelpRowView *rowView = [[QLHelpRowView alloc] initWithFrame:NSZeroRect];
    rowView.selectionHighlightStyle = NSTableViewSelectionHighlightStyleNone;
    return rowView;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    if (row >= 0 && row < (NSInteger)_rows.count &&
        _rows[(NSUInteger)row].kind == QLHelpSidebarRowKindGroup) {
        return 25.0;
    }
    return 27.0;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (row < 0 || row >= (NSInteger)_rows.count) return nil;
    QLHelpSidebarRow *item = _rows[(NSUInteger)row];

    if (item.kind == QLHelpSidebarRowKindGroup) {
        NSTableCellView *cell = [tableView makeViewWithIdentifier:@"HelpGroupCell" owner:self];
        if (!cell) {
            cell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 246, 25)];
            cell.identifier = @"HelpGroupCell";
            NSTextField *label = [NSTextField labelWithString:@""];
            label.translatesAutoresizingMaskIntoConstraints = NO;
            label.lineBreakMode = NSLineBreakByTruncatingTail;
            [cell addSubview:label];
            cell.textField = label;
            [NSLayoutConstraint activateConstraints:@[
                [label.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:16],
                [label.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-10],
                [label.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor]
            ]];
        }
        cell.textField.stringValue = item.title.uppercaseString;
        cell.textField.font = [NSFont systemFontOfSize:9.5 weight:NSFontWeightSemibold];
        cell.textField.textColor = NSColor.secondaryLabelColor;
        return cell;
    }

    NSTableCellView *cell = [tableView makeViewWithIdentifier:@"HelpTopicCell" owner:self];
    if (!cell) {
        cell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 246, 27)];
        cell.identifier = @"HelpTopicCell";

        NSImageView *icon = [[NSImageView alloc] initWithFrame:NSZeroRect];
        icon.translatesAutoresizingMaskIntoConstraints = NO;
        icon.imageScaling = NSImageScaleProportionallyDown;
        [cell addSubview:icon];
        cell.imageView = icon;

        NSTextField *label = [NSTextField labelWithString:@""];
        label.translatesAutoresizingMaskIntoConstraints = NO;
        label.lineBreakMode = NSLineBreakByTruncatingTail;
        [cell addSubview:label];
        cell.textField = label;

        [NSLayoutConstraint activateConstraints:@[
            [icon.leadingAnchor constraintEqualToAnchor:cell.leadingAnchor constant:14],
            [icon.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor],
            [icon.widthAnchor constraintEqualToConstant:15],
            [icon.heightAnchor constraintEqualToConstant:15],
            [label.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:9],
            [label.trailingAnchor constraintEqualToAnchor:cell.trailingAnchor constant:-10],
            [label.centerYAnchor constraintEqualToAnchor:cell.centerYAnchor]
        ]];
    }
    cell.textField.stringValue = item.title;
    cell.textField.font = [NSFont systemFontOfSize:12.5 weight:NSFontWeightMedium];
    NSImage *symbol = [NSImage imageWithSystemSymbolName:item.symbolName accessibilityDescription:nil];
    symbol = [symbol imageWithSymbolConfiguration:
              [NSImageSymbolConfiguration configurationWithPointSize:12.5 weight:NSFontWeightRegular]];
    cell.imageView.image = symbol;
    [self applySelectionStyleToCell:cell selected:[tableView.selectedRowIndexes containsIndex:(NSUInteger)row]];
    return cell;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    if (_suppressSelection) return;
    NSInteger row = _topicTable.selectedRow;
    if (row < 0 || row >= (NSInteger)_rows.count) return;
    QLHelpSidebarRow *item = _rows[(NSUInteger)row];
    if (item.kind != QLHelpSidebarRowKindTopic) return;
    QLHelpTopic *topic = _topicsByIdentifier[item.topicIdentifier];
    if (!topic) return;
    [self displayTopic:topic scrollToTop:YES];
}

- (void)tableView:(NSTableView *)tableView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row {
    if (row < 0 || row >= (NSInteger)_rows.count) return;
    if (_rows[(NSUInteger)row].kind == QLHelpSidebarRowKindGroup) return;
    NSTableCellView *cell = [rowView viewAtColumn:0];
    if ([cell isKindOfClass:NSTableCellView.class]) {
        [self applySelectionStyleToCell:cell selected:rowView.isSelected];
    }
}

- (void)applySelectionStyleToCell:(NSTableCellView *)cell selected:(BOOL)selected {
    cell.textField.textColor = NSColor.labelColor;
    cell.textField.font = [NSFont systemFontOfSize:12.5 weight:selected ? NSFontWeightSemibold : NSFontWeightMedium];
    cell.imageView.contentTintColor = selected ? NSColor.controlAccentColor : NSColor.secondaryLabelColor;
}

- (void)updateRowColors {
    [_topicTable enumerateAvailableRowViewsUsingBlock:^(NSTableRowView *rowView, NSInteger row) {
        if (row < 0 || row >= (NSInteger)self->_rows.count) return;
        if (self->_rows[(NSUInteger)row].kind != QLHelpSidebarRowKindTopic) return;
        NSTableCellView *cell = [rowView viewAtColumn:0];
        if ([cell isKindOfClass:NSTableCellView.class]) {
            [self applySelectionStyleToCell:cell selected:rowView.isSelected];
        }
        [rowView setNeedsDisplay:YES];
    }];
}

#pragma mark Search field

- (void)searchFieldChanged:(id)sender {
    [self applySearchQuery:_searchField.stringValue];
}

- (void)controlTextDidChange:(NSNotification *)notification {
    if (notification.object == _searchField) {
        [self applySearchQuery:_searchField.stringValue];
    }
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    if (control != _searchField) return NO;
    if (commandSelector == @selector(cancelOperation:)) {
        if (_searchField.stringValue.length > 0) {
            [self searchForText:@""];
        } else {
            [self.window performClose:nil];
        }
        return YES;
    }
    if (commandSelector == @selector(moveDown:)) {
        [self.window makeFirstResponder:_topicTable];
        if (_topicTable.selectedRow < 0 && _rows.count > 0) {
            [self moveSelectionBy:1];
        }
        return YES;
    }
    return NO;
}

- (void)moveSelectionBy:(NSInteger)delta {
    NSInteger row = _topicTable.selectedRow;
    NSInteger count = (NSInteger)_rows.count;
    if (count == 0) return;
    if (row < 0) row = delta > 0 ? -1 : count;
    NSInteger candidate = row;
    for (NSInteger step = 0; step < count; step++) {
        candidate += delta;
        if (candidate < 0 || candidate >= count) break;
        if (_rows[(NSUInteger)candidate].kind == QLHelpSidebarRowKindTopic) {
            [_topicTable selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)candidate]
                     byExtendingSelection:NO];
            [_topicTable scrollRowToVisible:candidate];
            return;
        }
    }
}

#pragma mark Text view delegate

- (BOOL)textView:(NSTextView *)textView clickedOnLink:(id)link atIndex:(NSUInteger)charIndex {
    NSURL *url = nil;
    if ([link isKindOfClass:NSURL.class]) {
        url = link;
    } else if ([link isKindOfClass:NSString.class]) {
        url = [NSURL URLWithString:link];
    }
    if (url && [self handleHelpURL:url]) return YES;
    NSBeep();
    return YES;
}

@end
