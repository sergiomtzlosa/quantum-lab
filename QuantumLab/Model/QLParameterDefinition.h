#import <Foundation/Foundation.h>
#import "QLTypes.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, QLParameterType) {
    QLParameterTypeDouble = 0,
    QLParameterTypeInteger = 1,
    QLParameterTypeEnum = 2,
    QLParameterTypeBool = 3
};

@interface QLParameterDefinition : NSObject

@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) NSString *label;
@property (nonatomic, copy) NSString *unit;
@property (nonatomic, copy) NSString *group;
@property (nonatomic, assign) QLParameterType type;
@property (nonatomic, strong) NSNumber *defaultValue;
@property (nonatomic, strong, nullable) NSNumber *minValue;
@property (nonatomic, strong, nullable) NSNumber *maxValue;
@property (nonatomic, copy, nullable) NSArray<NSString *> *enumLabels;
@property (nonatomic, copy, nullable) NSArray<NSNumber *> *enumValues;

// Simple visibility predicate. The field is visible when the current value for
// visibleKey matches one of visibleValues, or is >= visibleMinValue.
@property (nonatomic, copy, nullable) NSString *visibleKey;
@property (nonatomic, copy, nullable) NSArray<NSNumber *> *visibleValues;
@property (nonatomic, strong, nullable) NSNumber *visibleMinValue;

+ (instancetype)doubleWithKey:(NSString *)key
                        label:(NSString *)label
                         unit:(NSString *)unit
                        group:(NSString *)group
                     defaultValue:(double)value
                          min:(double)minValue
                          max:(double)maxValue;

+ (instancetype)integerWithKey:(NSString *)key
                         label:(NSString *)label
                          unit:(NSString *)unit
                         group:(NSString *)group
                  defaultValue:(NSInteger)value
                           min:(NSInteger)minValue
                           max:(NSInteger)maxValue;

+ (instancetype)enumWithKey:(NSString *)key
                      label:(NSString *)label
                      group:(NSString *)group
               defaultValue:(NSInteger)value
                      labels:(NSArray<NSString *> *)labels
                      values:(NSArray<NSNumber *> *)values;

+ (instancetype)booleanWithKey:(NSString *)key
                         label:(NSString *)label
                         group:(NSString *)group
                  defaultValue:(BOOL)value;

- (instancetype)visibleForKey:(NSString *)key values:(NSArray<NSNumber *> *)values;
- (instancetype)visibleForKey:(NSString *)key minValue:(double)minValue;

- (BOOL)isVisibleForValue:(nullable id)value;

@end

NS_ASSUME_NONNULL_END
