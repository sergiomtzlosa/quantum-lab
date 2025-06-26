#import "QLParameterSet.h"

@implementation QLParameterSet

- (instancetype)init {
    return [self initWithDictionary:@{}];
}

- (instancetype)initWithDictionary:(NSDictionary<NSString *, id> *)dictionary {
    self = [super init];
    if (self) {
        _values = [dictionary mutableCopy] ?: [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)setValue:(id)value forKey:(NSString *)key {
    if (key.length == 0) {
        return;
    }
    self.values[key] = value ?: NSNull.null;
}

- (id)valueForKey:(NSString *)key {
    id value = self.values[key];
    return value == NSNull.null ? nil : value;
}

- (double)doubleForKey:(NSString *)key {
    return [[self valueForKey:key] doubleValue];
}

- (NSInteger)integerForKey:(NSString *)key {
    return [[self valueForKey:key] integerValue];
}

- (BOOL)boolForKey:(NSString *)key {
    return [[self valueForKey:key] boolValue];
}

- (void)applyDefaults:(NSArray<QLParameterDefinition *> *)definitions {
    for (QLParameterDefinition *definition in definitions) {
        if (self.values[definition.key] == nil) {
            self.values[definition.key] = definition.defaultValue;
        }
    }
}

- (QLParameterSet *)copyWithZone:(NSZone *)zone {
    return [[QLParameterSet allocWithZone:zone] initWithDictionary:self.values];
}

@end
