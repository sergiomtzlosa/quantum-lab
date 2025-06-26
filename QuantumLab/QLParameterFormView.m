#import "QLParameterFormView.h"

@implementation QLParameterFormView {
    NSStackView *_stack;
    NSMutableArray<QLParameterRow *> *_rows;
    NSMutableDictionary<NSString *, NSButton *> *_headers;
    NSMutableDictionary<NSString *, NSMutableArray<QLParameterRow *> *> *_rowsByGroup;
    NSMutableSet<NSString *> *_collapsedGroups;
}

- (BOOL)isFlipped { return YES; }

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (!self) return nil;
    _parameterSet = [QLParameterSet new];
    _rows = [NSMutableArray array];
    _headers = [NSMutableDictionary dictionary];
    _rowsByGroup = [NSMutableDictionary dictionary];
    _collapsedGroups = [NSMutableSet set];

    _stack = [[NSStackView alloc] initWithFrame:NSZeroRect];
    _stack.translatesAutoresizingMaskIntoConstraints = NO;
    _stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    _stack.alignment = NSLayoutAttributeLeading;
    _stack.spacing = 2.0;
    _stack.detachesHiddenViews = YES;
    [self addSubview:_stack];

    [NSLayoutConstraint activateConstraints:@[
        [_stack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
        [_stack.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-12],
        [_stack.topAnchor constraintEqualToAnchor:self.topAnchor constant:8],
        [_stack.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-12]
    ]];
    return self;
}

- (void)reloadWithDefinitions:(NSArray<QLParameterDefinition *> *)definitions
                   parameters:(QLParameterSet *)parameters {
    for (NSView *view in _stack.arrangedSubviews.copy) {
        [_stack removeArrangedSubview:view];
        [view removeFromSuperview];
    }
    [_rows removeAllObjects];
    [_headers removeAllObjects];
    [_rowsByGroup removeAllObjects];
    [_collapsedGroups removeAllObjects];

    self.parameterSet.values = [parameters.values mutableCopy] ?: [NSMutableDictionary dictionary];
    [self.parameterSet applyDefaults:definitions];

    NSString *currentGroup = nil;
    for (QLParameterDefinition *definition in definitions) {
        if (![definition.group isEqualToString:currentGroup ?: @""]) {
            currentGroup = definition.group;
            NSButton *header = [NSButton buttonWithTitle:[self headerTitleForGroup:definition.group]
                                                 target:self
                                                 action:@selector(toggleGroup:)];
            header.identifier = definition.group;
            header.bordered = NO;
            header.alignment = NSTextAlignmentLeft;
            header.font = [NSFont systemFontOfSize:10.5 weight:NSFontWeightSemibold];
            header.contentTintColor = NSColor.tertiaryLabelColor;
            header.translatesAutoresizingMaskIntoConstraints = NO;
            [header.heightAnchor constraintEqualToConstant:18].active = YES;
            [_stack addArrangedSubview:header];
            [header.widthAnchor constraintEqualToAnchor:_stack.widthAnchor].active = YES;
            [_stack setCustomSpacing:8.0 afterView:header];
            _headers[definition.group] = header;
        }

        QLParameterRow *row = [[QLParameterRow alloc] initWithDefinition:definition];
        [row setParameterValue:self.parameterSet.values[definition.key]];
        __weak typeof(self) weakSelf = self;
        __weak QLParameterRow *weakRow = row;
        row.onChange = ^{
            __strong typeof(weakSelf) self = weakSelf;
            QLParameterRow *strongRow = weakRow;
            if (!self || !strongRow) return;
            self.parameterSet.values[definition.key] = [strongRow parameterValue] ?: definition.defaultValue;
            [self refreshVisibility];
            if ([self.delegate respondsToSelector:@selector(parameterFormDidChange:key:)]) {
                [self.delegate parameterFormDidChange:self key:definition.key];
            }
        };
        [_stack addArrangedSubview:row];
        [row.widthAnchor constraintEqualToAnchor:_stack.widthAnchor].active = YES;
        [_rows addObject:row];
        NSMutableArray *groupRows = _rowsByGroup[definition.group];
        if (!groupRows) {
            groupRows = [NSMutableArray array];
            _rowsByGroup[definition.group] = groupRows;
        }
        [groupRows addObject:row];
    }
    [self refreshVisibility];
}

- (NSString *)headerTitleForGroup:(NSString *)group {
    NSString *arrow = [_collapsedGroups containsObject:group] ? @"▸" : @"▾";
    return [NSString stringWithFormat:@"%@  %@", arrow, group.uppercaseString];
}

- (void)toggleGroup:(NSButton *)sender {
    NSString *group = sender.identifier;
    if (group.length == 0) return;
    if ([_collapsedGroups containsObject:group]) {
        [_collapsedGroups removeObject:group];
    } else {
        [_collapsedGroups addObject:group];
    }
    sender.title = [self headerTitleForGroup:group];
    [self refreshVisibility];
}

- (void)refreshVisibility {
    for (NSString *group in _rowsByGroup) {
        BOOL anyVisible = NO;
        BOOL collapsed = [_collapsedGroups containsObject:group];
        for (QLParameterRow *row in _rowsByGroup[group]) {
            BOOL visibleForValues = [row isVisibleForValues:self.parameterSet.values];
            row.hidden = !visibleForValues || collapsed;
            if (visibleForValues) anyVisible = YES;
        }
        _headers[group].hidden = !anyVisible;
    }
    [self invalidateIntrinsicContentSize];
}

- (BOOL)allValid {
    for (QLParameterRow *row in _rows) {
        if ([row isVisibleForValues:self.parameterSet.values] && !row.isValid) return NO;
    }
    return YES;
}

- (void)setFormEnabled:(BOOL)enabled {
    for (QLParameterRow *row in _rows) {
        for (NSView *subview in row.subviews) {
            if ([subview isKindOfClass:NSControl.class]) {
                ((NSControl *)subview).enabled = enabled;
            }
        }
    }
}

@end
