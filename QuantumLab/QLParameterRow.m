#import "QLParameterRow.h"
#include <math.h>

@implementation QLParameterRow {
    NSTextField *_labelField;
    NSTextField *_textField;
    NSPopUpButton *_popup;
    NSButton *_checkbox;
}

- (instancetype)initWithDefinition:(QLParameterDefinition *)definition {
    self = [super initWithFrame:NSZeroRect];
    if (!self) return nil;
    _definition = definition;
    self.translatesAutoresizingMaskIntoConstraints = NO;

    _labelField = [NSTextField labelWithString:definition.label];
    _labelField.font = [NSFont systemFontOfSize:11.5];
    _labelField.textColor = NSColor.secondaryLabelColor;
    _labelField.alignment = NSTextAlignmentRight;
    _labelField.translatesAutoresizingMaskIntoConstraints = NO;
    _labelField.toolTip = [NSString stringWithFormat:@"%@%@", definition.label,
                           definition.unit.length ? [NSString stringWithFormat:@" (%@)", definition.unit] : @""];
    [self addSubview:_labelField];

    if (definition.type == QLParameterTypeEnum) {
        _popup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
        _popup.translatesAutoresizingMaskIntoConstraints = NO;
        _popup.font = [NSFont systemFontOfSize:11.5];
        [_popup addItemsWithTitles:definition.enumLabels ?: @[]];
        _popup.target = self;
        _popup.action = @selector(controlChanged:);
        [self addSubview:_popup];
        [_popup.widthAnchor constraintGreaterThanOrEqualToConstant:120].active = YES;
    } else if (definition.type == QLParameterTypeBool) {
        _checkbox = [NSButton checkboxWithTitle:@"" target:self action:@selector(controlChanged:)];
        _checkbox.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_checkbox];
    } else {
        _textField = [[NSTextField alloc] initWithFrame:NSZeroRect];
        _textField.translatesAutoresizingMaskIntoConstraints = NO;
        _textField.font = [NSFont monospacedDigitSystemFontOfSize:11.5 weight:NSFontWeightRegular];
        _textField.alignment = NSTextAlignmentRight;
        _textField.delegate = self;
        _textField.target = self;
        _textField.action = @selector(controlChanged:);
        _textField.usesSingleLineMode = YES;
        _textField.lineBreakMode = NSLineBreakByClipping;
        _textField.bezelStyle = NSTextFieldRoundedBezel;
        [self addSubview:_textField];

        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        formatter.numberStyle = NSNumberFormatterDecimalStyle;
        formatter.usesGroupingSeparator = NO;
        formatter.maximumFractionDigits = (definition.type == QLParameterTypeInteger) ? 0 : 8;
        formatter.minimumFractionDigits = 0;
        if (definition.minValue) formatter.minimum = definition.minValue;
        if (definition.maxValue) formatter.maximum = definition.maxValue;
        _textField.formatter = formatter;
    }

    [NSLayoutConstraint activateConstraints:@[
        [_labelField.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [_labelField.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [_labelField.widthAnchor constraintEqualToConstant:142.0]
    ]];

    if (_popup) {
        [NSLayoutConstraint activateConstraints:@[
            [_popup.leadingAnchor constraintEqualToAnchor:_labelField.trailingAnchor constant:8],
            [_popup.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [_popup.centerYAnchor constraintEqualToAnchor:self.centerYAnchor]
        ]];
    } else if (_checkbox) {
        [NSLayoutConstraint activateConstraints:@[
            [_checkbox.leadingAnchor constraintEqualToAnchor:_labelField.trailingAnchor constant:8],
            [_checkbox.centerYAnchor constraintEqualToAnchor:self.centerYAnchor]
        ]];
    } else {
        [NSLayoutConstraint activateConstraints:@[
            [_textField.leadingAnchor constraintEqualToAnchor:_labelField.trailingAnchor constant:8],
            [_textField.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [_textField.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [_textField.heightAnchor constraintEqualToConstant:22]
        ]];
    }
    [self.heightAnchor constraintEqualToConstant:28].active = YES;

    [self setParameterValue:definition.defaultValue];
    return self;
}

- (void)setParameterValue:(id)value {
    if (value == nil || value == NSNull.null) {
        value = self.definition.defaultValue;
    }
    if (self.definition.type == QLParameterTypeEnum) {
        NSInteger requested = [value integerValue];
        NSArray<NSNumber *> *values = self.definition.enumValues ?: @[];
        NSInteger index = [values indexOfObject:@(requested)];
        if (index == NSNotFound) index = 0;
        [_popup selectItemAtIndex:index];
    } else if (self.definition.type == QLParameterTypeBool) {
        _checkbox.state = [value boolValue] ? NSControlStateValueOn : NSControlStateValueOff;
    } else {
        double number = [value doubleValue];
        if (self.definition.type == QLParameterTypeInteger) {
            _textField.stringValue = [NSString stringWithFormat:@"%ld", (long)llround(number)];
        } else {
            _textField.stringValue = [NSString stringWithFormat:@"%.8g", number];
        }
    }
    [self validateValue];
}

- (id)parameterValue {
    if (self.definition.type == QLParameterTypeEnum) {
        NSInteger index = _popup.indexOfSelectedItem;
        NSArray<NSNumber *> *values = self.definition.enumValues ?: @[];
        if (index >= 0 && index < (NSInteger)values.count) {
            return values[(NSUInteger)index];
        }
        return self.definition.defaultValue;
    }
    if (self.definition.type == QLParameterTypeBool) {
        return @(_checkbox.state == NSControlStateValueOn);
    }
    if (self.definition.type == QLParameterTypeInteger) {
        return @((NSInteger)llround(_textField.doubleValue));
    }
    return @(_textField.doubleValue);
}

- (BOOL)isValid {
    if (self.definition.type == QLParameterTypeDouble || self.definition.type == QLParameterTypeInteger) {
        double value = _textField.doubleValue;
        if (!isfinite(value)) return NO;
        if (self.definition.minValue && value < self.definition.minValue.doubleValue) return NO;
        if (self.definition.maxValue && value > self.definition.maxValue.doubleValue) return NO;
    }
    return YES;
}

- (void)validateValue {
    if (self.definition.type == QLParameterTypeDouble || self.definition.type == QLParameterTypeInteger) {
        _textField.textColor = self.isValid ? NSColor.labelColor : NSColor.systemRedColor;
    }
}

- (void)controlChanged:(id)sender {
    [self validateValue];
    if (self.onChange) self.onChange();
}

- (void)controlTextDidEndEditing:(NSNotification *)notification {
    [self controlChanged:notification.object];
}

- (BOOL)isVisibleForValues:(NSDictionary<NSString *, id> *)values {
    if (self.definition.visibleKey.length == 0) return YES;
    return [self.definition isVisibleForValue:values[self.definition.visibleKey]];
}

- (void)updateVisibilityForValues:(NSDictionary<NSString *, id> *)values {
    self.hidden = ![self isVisibleForValues:values];
}

@end
