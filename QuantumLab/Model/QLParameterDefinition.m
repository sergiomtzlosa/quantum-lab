#import "QLParameterDefinition.h"

@implementation QLParameterDefinition

+ (instancetype)doubleWithKey:(NSString *)key
                        label:(NSString *)label
                         unit:(NSString *)unit
                        group:(NSString *)group
                 defaultValue:(double)value
                          min:(double)minValue
                          max:(double)maxValue {
    QLParameterDefinition *d = [QLParameterDefinition new];
    d.key = key;
    d.label = label;
    d.unit = unit ?: @"";
    d.group = group;
    d.type = QLParameterTypeDouble;
    d.defaultValue = @(value);
    d.minValue = @(minValue);
    d.maxValue = @(maxValue);
    return d;
}

+ (instancetype)integerWithKey:(NSString *)key
                         label:(NSString *)label
                          unit:(NSString *)unit
                         group:(NSString *)group
                  defaultValue:(NSInteger)value
                           min:(NSInteger)minValue
                           max:(NSInteger)maxValue {
    QLParameterDefinition *d = [QLParameterDefinition new];
    d.key = key;
    d.label = label;
    d.unit = unit ?: @"";
    d.group = group;
    d.type = QLParameterTypeInteger;
    d.defaultValue = @(value);
    d.minValue = @(minValue);
    d.maxValue = @(maxValue);
    return d;
}

+ (instancetype)enumWithKey:(NSString *)key
                      label:(NSString *)label
                      group:(NSString *)group
               defaultValue:(NSInteger)value
                      labels:(NSArray<NSString *> *)labels
                      values:(NSArray<NSNumber *> *)values {
    QLParameterDefinition *d = [QLParameterDefinition new];
    d.key = key;
    d.label = label;
    d.unit = @"";
    d.group = group;
    d.type = QLParameterTypeEnum;
    d.defaultValue = @(value);
    d.enumLabels = labels;
    d.enumValues = values;
    return d;
}

+ (instancetype)booleanWithKey:(NSString *)key
                         label:(NSString *)label
                         group:(NSString *)group
                  defaultValue:(BOOL)value {
    QLParameterDefinition *d = [QLParameterDefinition new];
    d.key = key;
    d.label = label;
    d.unit = @"";
    d.group = group;
    d.type = QLParameterTypeBool;
    d.defaultValue = @(value ? 1 : 0);
    return d;
}

- (instancetype)visibleForKey:(NSString *)key values:(NSArray<NSNumber *> *)values {
    self.visibleKey = key;
    self.visibleValues = values;
    self.visibleMinValue = nil;
    return self;
}

- (instancetype)visibleForKey:(NSString *)key minValue:(double)minValue {
    self.visibleKey = key;
    self.visibleValues = nil;
    self.visibleMinValue = @(minValue);
    return self;
}

- (BOOL)isVisibleForValue:(id)value {
    if (self.visibleKey.length == 0) {
        return YES;
    }
    if (value == nil || value == NSNull.null) {
        return NO;
    }
    if (self.visibleValues.count > 0) {
        NSNumber *number = [value isKindOfClass:NSNumber.class] ? value : @([value integerValue]);
        return [self.visibleValues containsObject:number];
    }
    if (self.visibleMinValue != nil) {
        return [value doubleValue] >= self.visibleMinValue.doubleValue;
    }
    return YES;
}

@end
